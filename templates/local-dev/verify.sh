#!/usr/bin/env bash
# verify.sh — local-dev template smoke test
#
# Runs after `docker compose up -d`. Two layers of checks:
#
# 1. Black-box HTTP probes from outside the docker network: confirms ports
#    are bound and the containers respond to the URLs operators / browsers
#    actually use.
#
# 2. nova-os doctor deployment INSIDE the nova-os container: catches
#    config drift the outer probes can't see (issuer-mismatch, weak
#    secrets, missing migrations, gateway 401s, agent files absent).
#
# Exit 0 = green. Non-zero = at least one check failed; the line above
# the summary tells you which.

set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; NC='\033[0m'
PASS=0; FAIL=0

check() {
  local name="$1"; shift
  local cmd="$*"
  printf "  %-30s " "$name"
  if eval "$cmd" > /tmp/verify.out 2>&1; then
    printf "${GREEN}OK${NC}\n"
    PASS=$((PASS+1))
  else
    printf "${RED}FAIL${NC}\n"
    sed 's/^/        /' /tmp/verify.out | head -3
    FAIL=$((FAIL+1))
  fi
}

echo
echo "═══════════════ local-dev verify.sh ═══════════════"
echo
echo "Phase 1 — outside-the-network probes"

check "containers running"             '[ $(docker compose ps --status running --quiet | wc -l) -ge 4 ]'
check "nova-os :8900 /health → 200"    'curl -sS -f -o /dev/null --max-time 3 http://localhost:8900/health'
check "nova-os OIDC discovery → 200"   'curl -sS -f -o /dev/null --max-time 3 http://localhost:8900/.well-known/openid-configuration'
check "librechat :3080 reachable"      'curl -sS -f -o /dev/null --max-time 5 http://localhost:3080/'

echo
echo "Phase 2 — inside nova-os container (the doctor)"
echo

if docker exec nova-os nova-os doctor deployment --skip-network; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1))
fi

echo
echo "═══════════════════════════════════════════════════"
if [ "$FAIL" -eq 0 ]; then
  printf "${GREEN}All checks passed (%d/%d). Deployment is ready.${NC}\n" "$PASS" $((PASS+FAIL))
  printf "\nNext: open ${YELLOW}http://localhost:3080${NC} in your browser.\n"
  exit 0
else
  printf "${RED}%d checks failed (%d/%d passed).${NC}\n" "$FAIL" "$PASS" $((PASS+FAIL))
  printf "\nCheck logs: ${YELLOW}docker compose logs nova-os${NC}\n"
  printf "Re-run: ${YELLOW}./verify.sh${NC}\n"
  exit 1
fi
