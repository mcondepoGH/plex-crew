#!/usr/bin/env bash
# Comprobaciones estáticas del plugin plex-crew. Sin red ni credenciales reales.
# Uso: bash tests/smoke.sh   (rc 1 si alguna comprobación falla)
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

TOTAL=0
PASSED=0
FAILED_NAMES=()
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ok() { TOTAL=$((TOTAL + 1)); PASSED=$((PASSED + 1)); echo "ok   - $1"; }
fail() { TOTAL=$((TOTAL + 1)); FAILED_NAMES+=("$1"); echo "FAIL - $1${2:+ ($2)}"; }
check() { # check <nombre> <comando...>
  local name="$1"; shift
  if "$@" >"$TMP/out" 2>&1; then ok "$name"; else fail "$name" "$(head -c 300 "$TMP/out" | tr '\n' ' ')"; fi
}

# Variables dummy para que los scripts de skills pasen la carga de entorno.
DUMMY_ENV=(
  HOME="$TMP" HOMELAB_ENV="$TMP/none.env"
  PROWLARR_URL=http://dummy PROWLARR_API_KEY=k
  RADARR_URL=http://dummy RADARR_API_KEY=k
  SONARR_URL=http://dummy SONARR_API_KEY=k
  PLEX_URL=http://dummy PLEX_TOKEN=k
  TAUTULLI_URL=http://dummy TAUTULLI_API_KEY=k
  SEERR_URL=http://dummy SEERR_API_KEY=k
  CLI_DEBRID_URL=http://dummy CLI_DEBRID_USER=u CLI_DEBRID_PASSWORD=p
  AGREGARR_URL=http://dummy AGREGARR_API_KEY=k
)

# 1. Sintaxis de shell
mapfile -t SH_FILES < <(find skills tests -name '*.sh' -type f | sort)
for f in "${SH_FILES[@]}"; do check "bash -n $f" bash -n "$f"; done

# 2. Sintaxis de los hooks
for f in hooks/*.js; do check "node --check $f" node --check "$f"; done

# 3. JSON
if command -v jq >/dev/null 2>&1; then
  for f in .claude-plugin/plugin.json .claude-plugin/marketplace.json hooks/hooks.json settings.json; do
    check "jq $f" jq -e . "$f"
  done
  v_plugin="$(jq -r '.version // empty' .claude-plugin/plugin.json 2>/dev/null)"
  v_market="$(jq -r '.plugins[0].version // empty' .claude-plugin/marketplace.json 2>/dev/null)"
  if [ -n "$v_plugin" ] && [ "$v_plugin" = "$v_market" ]; then
    ok "version coincide en plugin.json y marketplace.json ($v_plugin)"
  else
    fail "version coincide en plugin.json y marketplace.json" "plugin=$v_plugin marketplace=$v_market"
  fi
else
  fail "jq disponible" "instala jq"
fi

# 3b. MCP (plugin.json o .mcp.json) y skills nuevas (solo si existen)
if command -v jq >/dev/null 2>&1; then
  if [ -f .mcp.json ]; then
    check "jq .mcp.json" jq -e . .mcp.json
  fi
  if jq -e '.mcpServers.zurg.url' .claude-plugin/plugin.json >/dev/null 2>&1 \
     || { [ -f .mcp.json ] && jq -e '.mcpServers.zurg.url // .zurg.url' .mcp.json >/dev/null 2>&1; }; then
    ok "servidor MCP zurg declarado con url"
  else
    fail "servidor MCP zurg declarado con url" "falta mcpServers.zurg.url"
  fi
  if grep -q 'ZURG_MCP_URL' .env.example; then ok "ZURG_MCP_URL en .env.example"; else fail "ZURG_MCP_URL en .env.example"; fi
fi
for sk in agregarr; do
  if [ -d "skills/$sk" ]; then
    check "skill $sk tiene SKILL.md" test -f "skills/$sk/SKILL.md"
    check "skill $sk tiene README.md" test -f "skills/$sk/README.md"
  else
    echo "skip - skills/$sk aun no existe"
  fi
done

# 4. Frontmatter name/description
frontmatter_ok() { # frontmatter_ok <fichero>
  awk '
    { sub(/\r$/, "") }
    NR==1 { if ($0 != "---") exit 1; next }
    /^---[[:space:]]*$/ { closed=1; exit }
    /^name:[[:space:]]*[^[:space:]]/ { n=1 }
    /^description:[[:space:]]*[^[:space:]]/ { d=1 }
    END { exit !(closed && n && d) }
  ' "$1"
}
for f in skills/*/SKILL.md agents/*.md; do
  check "frontmatter name/description $f" frontmatter_ok "$f"
done

# 5. help (rc 0) y comando desconocido (rc 1) de cada script de skill
for f in skills/*/scripts/*.sh; do
  env -i PATH="$PATH" "${DUMMY_ENV[@]}" timeout 20 bash "$f" help >"$TMP/out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then ok "$f help rc 0"; else fail "$f help rc 0" "rc=$rc"; fi
  env -i PATH="$PATH" "${DUMMY_ENV[@]}" timeout 20 bash "$f" comando-desconocido-zzz >"$TMP/out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ]; then ok "$f comando desconocido rc 1"; else fail "$f comando desconocido rc 1" "rc=$rc"; fi
done

# 6. shellcheck (si está instalado)
if command -v shellcheck >/dev/null 2>&1; then
  check "shellcheck tests/smoke.sh" shellcheck "$ROOT/tests/smoke.sh"
fi

# 7. claude plugin validate (acepta el aviso por CLAUDE.md)
if command -v claude >/dev/null 2>&1; then
  if timeout 60 claude plugin validate . >"$TMP/out" 2>&1; then
    ok "claude plugin validate ."
  elif grep -qi 'CLAUDE.md' "$TMP/out" && ! grep -qiE 'error|✘|invalid' "$TMP/out"; then
    ok "claude plugin validate . (solo aviso de CLAUDE.md)"
  else
    fail "claude plugin validate ." "$(head -c 300 "$TMP/out" | tr '\n' ' ')"
  fi
else
  echo "skip - claude plugin validate (binario claude no encontrado)"
fi

# 8. Tests de hooks, si existen
if [ -f tests/hooks.sh ]; then
  check "tests/hooks.sh" bash tests/hooks.sh
fi

echo
echo "Resumen: $PASSED/$TOTAL comprobaciones correctas"
if [ "${#FAILED_NAMES[@]}" -gt 0 ]; then
  printf 'Fallos:\n'; printf '  - %s\n' "${FAILED_NAMES[@]}"
  exit 1
fi
exit 0
