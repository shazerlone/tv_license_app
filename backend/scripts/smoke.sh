#!/usr/bin/env bash
# Millimore post-deploy smoke test.
# Usage:  BASE="https://<your-host>/v1" ./scripts/smoke.sh
# Checks the live backend end-to-end with the seeded admin login. Exits non-zero
# on the first failure so it's CI-friendly.
set -u
BASE="${BASE:-http://localhost:3000/v1}"
EMAIL="${EMAIL:-admin@millimore.app}"
PASSWORD="${PASSWORD:-password}"
pass=0; fail=0
ok()   { echo "  ✅ $1"; pass=$((pass+1)); }
bad()  { echo "  ❌ $1"; fail=$((fail+1)); }
json() { python3 -c "import sys,json;d=json.load(sys.stdin);print(d$1)" 2>/dev/null; }

echo "Smoke testing: $BASE"

# 1) health
if curl -fsS "$BASE/health" >/dev/null 2>&1; then ok "health"; else bad "health (is the host/URL right?)"; fi

# 2) public config
CFG=$(curl -fsS "$BASE/config" 2>/dev/null)
if echo "$CFG" | grep -q "maxLeverage"; then ok "GET /config"; else bad "GET /config"; fi

# 3) login (seeded admin)
TOKEN=$(curl -fsS "$BASE/auth/login" -H 'content-type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" 2>/dev/null | json "['token']")
if [ -n "${TOKEN:-}" ]; then ok "login ($EMAIL)"; else bad "login — check the DB seeded (migrations ran) and credentials"; fi

# 4) authed call
if [ -n "${TOKEN:-}" ]; then
  ME=$(curl -fsS "$BASE/me" -H "authorization: Bearer $TOKEN" 2>/dev/null | json "['id']")
  [ -n "${ME:-}" ] && ok "GET /me (authed)" || bad "GET /me (authed)"
  # 5) an admin-only call
  MET=$(curl -fsS "$BASE/admin/metrics" -H "authorization: Bearer $TOKEN" 2>/dev/null | json "['totalUsers']")
  [ -n "${MET:-}" ] && ok "GET /admin/metrics (admin)" || bad "GET /admin/metrics (admin)"
fi

# 6) admin UI served at /
ROOT_CT=$(curl -fsS -o /dev/null -w '%{http_code}' "${BASE%/v1}/" 2>/dev/null)
[ "$ROOT_CT" = "200" ] && ok "admin UI served at /" || bad "admin UI at / (got HTTP $ROOT_CT)"

echo ""
echo "Passed: $pass   Failed: $fail"
[ "$fail" -eq 0 ] && echo "🎉 All good — you're live." || { echo "⚠️  Some checks failed."; exit 1; }
