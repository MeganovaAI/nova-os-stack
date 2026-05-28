#!/usr/bin/env bash
# verify.sh — partner-tls-terminated template smoke test
#
# TLS terminates upstream (partner's reverse proxy), so this script
# only checks the LOCAL HTTP surface that the proxy will route to.
# The partner is responsible for an end-to-end test through their
# public URL.
#
# Three layers:
#   1. Local HTTP probes
#   2. OIDC issuer match — issuer in discovery doc must equal
#      NOVA_OS_PUBLIC_URL exactly (catches #521 drift class)
#   3. nova-os doctor deployment — full audit
#
# Exit 0 = local surface ready for partner proxy to route to.

set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; NC='\033[0m'
PASS=0; FAIL=0

if [ ! -f .env ]; then
  printf "${RED}.env file not found. Copy .env.example to .env and fill it in.${NC}\n"
  exit 1
fi
# shellcheck disable=SC1091
set -a; . ./.env; set +a
PUBLIC_URL="${NOVA_OS_PUBLIC_URL:?NOVA_OS_PUBLIC_URL must be set in .env}"
INTERNAL_PORT="${NOVA_OS_INTERNAL_PORT:-8900}"
LIBRECHAT_PORT="${LIBRECHAT_INTERNAL_PORT:-3080}"

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
echo "═══════════════ partner-tls-terminated verify.sh ═══════════════"
echo "Public URL (advertised):  $PUBLIC_URL"
echo "Internal nova-os:         http://localhost:$INTERNAL_PORT"
echo "Internal LibreChat:       http://localhost:$LIBRECHAT_PORT"
echo
echo "Phase 1 — local HTTP probes (what partner's proxy reaches)"

check "containers running"             '[ $(docker compose ps --status running --quiet | wc -l) -ge 5 ]'
check "nova-os :$INTERNAL_PORT /health" "curl -sS -f -o /dev/null --max-time 3 http://localhost:$INTERNAL_PORT/health"
check "OIDC discovery doc → 200"        "curl -sS -f -o /dev/null --max-time 3 http://localhost:$INTERNAL_PORT/.well-known/openid-configuration"
check "librechat :$LIBRECHAT_PORT"       "curl -sS -f -o /dev/null --max-time 5 http://localhost:$LIBRECHAT_PORT/"

echo
echo "Phase 2 — OIDC issuer drift check (#521)"

ADVERTISED=$(curl -sS --max-time 5 "http://localhost:$INTERNAL_PORT/.well-known/openid-configuration" \
  | python3 -c "import json,sys; print(json.load(sys.stdin).get('issuer',''))" 2>/dev/null || true)
if [ -z "$ADVERTISED" ]; then
  printf "  %-36s ${RED}FAIL${NC}  discovery doc unreachable\n" "OIDC issuer matches"
  FAIL=$((FAIL+1))
elif [ "$ADVERTISED" = "$PUBLIC_URL" ]; then
  printf "  %-36s ${GREEN}OK${NC}  (%s)\n" "OIDC issuer matches" "$ADVERTISED"
  PASS=$((PASS+1))
else
  printf "  %-36s ${RED}FAIL${NC}  expected '%s', got '%s'\n" "OIDC issuer matches" "$PUBLIC_URL" "$ADVERTISED"
  printf "        fix: NOVA_OS_PUBLIC_URL must equal the partner's external URL, restart\n"
  FAIL=$((FAIL+1))
fi

echo
echo "Phase 3 — nova-os doctor (inside container)"
echo

if docker exec nova-os nova-os doctor deployment; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1))
fi

echo
echo "═══════════════════════════════════════════════════════════════"
if [ "$FAIL" -eq 0 ]; then
  printf "${GREEN}Local surface ready (%d/%d).${NC}\n" "$PASS" $((PASS+FAIL))
  printf "\n${YELLOW}Partner-side step (not automated):${NC}\n"
  printf "  Have the partner curl ${YELLOW}%s/health${NC} from their network.\n" "$PUBLIC_URL"
  printf "  HTTP 200 there confirms their reverse proxy is routing correctly.\n"
  printf "  If that fails, their proxy is misconfigured — see README.md\n"
  printf "  for header / timeout requirements.\n"
  exit 0
else
  printf "${RED}%d checks failed (%d/%d passed).${NC}\n" "$FAIL" "$PASS" $((PASS+FAIL))
  printf "\nInspect logs: ${YELLOW}docker compose logs nova-os${NC}\n"
  exit 1
fi
