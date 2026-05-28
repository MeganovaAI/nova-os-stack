#!/usr/bin/env bash
# verify.sh — single-host-prod template smoke test
#
# Four layers of checks:
#   1. TLS: cert exists, expiry > 30 days
#   2. HTTPS probes: public URLs return 2xx/3xx
#   3. OIDC issuer match: discovery doc issuer == NOVA_OS_PUBLIC_URL
#   4. nova-os doctor deployment: env vars, DB, gateway, agents
#
# Exit 0 = production-ready. Non-zero = at least one check failed
# with a one-line fix above the summary.

set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; NC='\033[0m'
PASS=0; FAIL=0

if [ ! -f .env ]; then
  printf "${RED}.env file not found. Copy .env.example to .env and fill it in.${NC}\n"
  exit 1
fi
# Pull NOVA_OS_PUBLIC_URL from .env so verify can compute the expected issuer.
# shellcheck disable=SC1091
set -a; . ./.env; set +a
URL="${NOVA_OS_PUBLIC_URL:?NOVA_OS_PUBLIC_URL must be set in .env}"

check() {
  local name="$1"; shift
  printf "  %-36s " "$name"
  if eval "$*" > /tmp/verify.out 2>&1; then
    printf "${GREEN}OK${NC}\n"; PASS=$((PASS+1))
  else
    printf "${RED}FAIL${NC}\n"
    sed 's/^/        /' /tmp/verify.out | head -3
    FAIL=$((FAIL+1))
  fi
}

echo
echo "═══════════════ single-host-prod verify.sh ═══════════════"
echo "Public URL: $URL"
echo
echo "Phase 1 — TLS cert sanity"

if [ ! -f certs/fullchain.pem ] || [ ! -f certs/privkey.pem ]; then
  printf "${RED}FAIL${NC}  certs/fullchain.pem or certs/privkey.pem missing\n"
  printf "        Obtain via certbot or your CA, then re-run.\n"
  exit 1
fi
check "cert files present"             '[ -s certs/fullchain.pem ] && [ -s certs/privkey.pem ]'
# openssl x509 -noout -checkend N exits 0 if cert valid for next N seconds.
check "cert valid > 30 days"           'openssl x509 -noout -checkend 2592000 -in certs/fullchain.pem'
check "cert matches NOVA_OS_PUBLIC_URL" 'openssl x509 -noout -text -in certs/fullchain.pem | grep -q "DNS:$(echo $URL | sed -E "s,https?://,,;s,/.*,,;s,:.*,,")"'

echo
echo "Phase 2 — HTTPS probes from outside docker"
check "containers running"             '[ $(docker compose ps --status running --quiet | wc -l) -ge 5 ]'
check "$URL/health → 200"              "curl -sS -f -o /dev/null --max-time 5 $URL/health"
check ".well-known/openid-configuration → 200" "curl -sS -f -o /dev/null --max-time 5 $URL/.well-known/openid-configuration"
check "/chat/ (LibreChat) → 2xx/3xx"   "curl -sS -o /dev/null -w '%{http_code}' --max-time 5 $URL/chat/ | grep -qE '^(2|3)'"

echo
echo "Phase 3 — OIDC issuer drift check (#521)"
# The issuer string in the discovery doc MUST exactly match NOVA_OS_PUBLIC_URL,
# otherwise LibreChat's OIDC strategy refuses to register and /oauth/openid
# breaks silently. This catches the issuer drift class that bit nova-os#521.
ADVERTISED=$(curl -sS --max-time 5 "$URL/.well-known/openid-configuration" \
  | python3 -c "import json,sys; print(json.load(sys.stdin).get('issuer',''))" 2>/dev/null)
if [ -z "$ADVERTISED" ]; then
  printf "  %-36s ${RED}FAIL${NC}  discovery doc unreachable or malformed\n" "OIDC issuer matches"
  FAIL=$((FAIL+1))
elif [ "$ADVERTISED" = "$URL" ]; then
  printf "  %-36s ${GREEN}OK${NC}  (%s)\n" "OIDC issuer matches" "$ADVERTISED"
  PASS=$((PASS+1))
else
  printf "  %-36s ${RED}FAIL${NC}  expected '%s', got '%s'\n" "OIDC issuer matches" "$URL" "$ADVERTISED"
  printf "        fix: restart nova-os (issuer is pinned at boot, NOVA_OS_PUBLIC_URL must match)\n"
  FAIL=$((FAIL+1))
fi

echo
echo "Phase 4 — nova-os doctor (inside container)"
echo

if docker exec nova-os nova-os doctor deployment; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1))
fi

echo
echo "═══════════════════════════════════════════════════════════"
if [ "$FAIL" -eq 0 ]; then
  printf "${GREEN}All checks passed (%d/%d). Deployment is production-ready.${NC}\n" "$PASS" $((PASS+FAIL))
  printf "\nUsers can access:\n"
  printf "  • LibreChat:  ${YELLOW}%s/chat/${NC}\n" "$URL"
  printf "  • Dashboard:  ${YELLOW}%s/admin/${NC}\n" "$URL"
  exit 0
else
  printf "${RED}%d checks failed (%d/%d passed).${NC}\n" "$FAIL" "$PASS" $((PASS+FAIL))
  printf "\nInspect logs: ${YELLOW}docker compose logs nova-os${NC}\n"
  exit 1
fi
