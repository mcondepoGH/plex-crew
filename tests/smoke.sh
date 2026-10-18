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
  HOME="$TMP"
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

# 3b. Skills nuevas (solo si existen)
sk=agregarr
if [ -d "skills/$sk" ]; then
  check "skill $sk tiene SKILL.md" test -f "skills/$sk/SKILL.md"
  check "skill $sk tiene README.md" test -f "skills/$sk/README.md"
else
  echo "skip - skills/$sk aun no existe"
fi

# 4. Frontmatter name/description
# shellcheck disable=SC2317  # falso positivo: se invoca de forma indirecta vía check "$@"
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

# 5b. comando logs (solo lectura): aparece en help y valida el uso sin red
for f in skills/radarr/scripts/radarr.sh skills/prowlarr/scripts/prowlarr-api.sh; do
  env -i PATH="$PATH" "${DUMMY_ENV[@]}" timeout 20 bash "$f" help >"$TMP/out" 2>&1
  if grep -q 'logs' "$TMP/out"; then ok "$f help muestra logs"; else fail "$f help muestra logs"; fi
  for bad in "abc" "0" "5000" "--bogus" "--level" "--level zzz" "--grep"; do
    # shellcheck disable=SC2086
    env -i PATH="$PATH" "${DUMMY_ENV[@]}" timeout 20 bash "$f" logs $bad >"$TMP/out" 2>&1
    rc=$?
    if [ "$rc" -eq 1 ] && grep -q '^ERROR' "$TMP/out"; then ok "$f logs $bad rc 1"; else fail "$f logs $bad rc 1" "rc=$rc"; fi
  done
done
for sk in radarr prowlarr; do
  if grep -q 'logs' "skills/$sk/SKILL.md"; then ok "skills/$sk/SKILL.md documenta logs"; else fail "skills/$sk/SKILL.md documenta logs"; fi
done

# 5c. tautulli: validación de argumentos (rc 1, sin red) y help con los comandos principales
TAU=skills/tautulli/scripts/tautulli-api.sh
if [ -f "$TAU" ]; then
  env -i PATH="$PATH" "${DUMMY_ENV[@]}" timeout 20 bash "$TAU" help >"$TMP/out" 2>&1
  for c in server-info activity history user-stats libraries library-stats popular recent concurrent-streams metadata; do
    if grep -q -- "$c" "$TMP/out"; then ok "$TAU help lista $c"; else fail "$TAU help lista $c"; fi
  done
  for bad in "library-stats" "library-stats --section-id abc" "history --limit 0" "history --limit abc" "history --bogus" "history --user" "popular --days 0" "metadata" "metadata --rating-key abc" "concurrent-streams --days -1"; do
    # shellcheck disable=SC2086
    env -i PATH="$PATH" "${DUMMY_ENV[@]}" timeout 20 bash "$TAU" $bad >"$TMP/out" 2>&1
    rc=$?
    if [ "$rc" -eq 1 ] && grep -q '^ERROR' "$TMP/out"; then ok "$TAU $bad rc 1"; else fail "$TAU $bad rc 1" "rc=$rc"; fi
  done
fi

# 5d. plex: validación de argumentos (rc 1, sin red) y help con los comandos principales
PLX=skills/plex/scripts/plex-api.sh
if [ -f "$PLX" ]; then
  env -i PATH="$PATH" "${DUMMY_ENV[@]}" timeout 20 bash "$PLX" help >"$TMP/out" 2>&1
  for c in info identity libraries library recent ondeck search metadata children sessions clients playlists refresh emptytrash; do
    if grep -q -- "$c" "$TMP/out"; then ok "$PLX help lista $c"; else fail "$PLX help lista $c"; fi
  done
  for bad in "library" "library abc" "recent --limit abc" "recent --bogus" "search" "metadata" "metadata abc" "children x" "refresh" "refresh abc" "emptytrash" "emptytrash abc" "comando-desconocido-zzz"; do
    # shellcheck disable=SC2086
    env -i PATH="$PATH" "${DUMMY_ENV[@]}" timeout 20 bash "$PLX" $bad >"$TMP/out" 2>&1
    rc=$?
    if [ "$rc" -eq 1 ] && grep -q '^ERROR' "$TMP/out"; then ok "$PLX $bad rc 1"; else fail "$PLX $bad rc 1" "rc=$rc"; fi
  done
fi

# 5e. sonarr: validación de argumentos (rc 1, sin red) y help con los comandos principales
SNR=skills/sonarr/scripts/sonarr.sh
if [ -f "$SNR" ]; then
  env -i PATH="$PATH" "${DUMMY_ENV[@]}" timeout 20 bash "$SNR" help >"$TMP/out" 2>&1
  for c in search search-json exists config status add remove; do
    if grep -q -- "$c" "$TMP/out"; then ok "$SNR help lista $c"; else fail "$SNR help lista $c"; fi
  done
  for bad in "search" "exists" "exists abc" "add" "add abc" "add 1 abc" "remove" "remove abc" "comando-desconocido-zzz"; do
    # shellcheck disable=SC2086
    env -i PATH="$PATH" "${DUMMY_ENV[@]}" timeout 20 bash "$SNR" $bad >"$TMP/out" 2>&1
    rc=$?
    if [ "$rc" -eq 1 ] && grep -q '^ERROR' "$TMP/out"; then ok "$SNR $bad rc 1"; else fail "$SNR $bad rc 1" "rc=$rc"; fi
  done
fi

# 5f. radarr: validación de argumentos (rc 1, sin red) y help con los comandos principales
RDR=skills/radarr/scripts/radarr.sh
if [ -f "$RDR" ]; then
  env -i PATH="$PATH" "${DUMMY_ENV[@]}" timeout 20 bash "$RDR" help >"$TMP/out" 2>&1
  for c in search search-json exists config status add add-collection remove collection-info logs; do
    if grep -q -- "$c" "$TMP/out"; then ok "$RDR help lista $c"; else fail "$RDR help lista $c"; fi
  done
  for bad in "search" "exists" "exists abc" "add" "add abc" "add 1 abc" "add-collection" "add-collection abc" "remove" "remove abc" "collection-info" "collection-info abc" "comando-desconocido-zzz"; do
    # shellcheck disable=SC2086
    env -i PATH="$PATH" "${DUMMY_ENV[@]}" timeout 20 bash "$RDR" $bad >"$TMP/out" 2>&1
    rc=$?
    if [ "$rc" -eq 1 ] && grep -q '^ERROR' "$TMP/out"; then ok "$RDR $bad rc 1"; else fail "$RDR $bad rc 1" "rc=$rc"; fi
  done
fi

# 5g. prowlarr: validación de argumentos (rc 1, sin red) y help con los comandos principales
PRW=skills/prowlarr/scripts/prowlarr-api.sh
if [ -f "$PRW" ]; then
  env -i PATH="$PATH" "${DUMMY_ENV[@]}" timeout 20 bash "$PRW" help >"$TMP/out" 2>&1
  for c in search tv-search movie-search indexers stats test test-all enable disable delete apps sync status health logs; do
    if grep -q -- "$c" "$TMP/out"; then ok "$PRW help lista $c"; else fail "$PRW help lista $c"; fi
  done
  for bad in "search" "search x --limit abc" "tv-search" "movie-search" "test" "test abc" "enable" "enable abc" "disable" "disable abc" "delete" "delete abc" "comando-desconocido-zzz"; do
    # shellcheck disable=SC2086
    env -i PATH="$PATH" "${DUMMY_ENV[@]}" timeout 20 bash "$PRW" $bad >"$TMP/out" 2>&1
    rc=$?
    if [ "$rc" -eq 1 ] && grep -q '^ERROR' "$TMP/out"; then ok "$PRW $bad rc 1"; else fail "$PRW $bad rc 1" "rc=$rc"; fi
  done
fi

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

# 9. Tests de la skill rutorrent (curl simulado), si existen
if [ -f tests/rutorrent.sh ]; then
  check "tests/rutorrent.sh" bash tests/rutorrent.sh
fi

# 10. Tests del hook protected-paths, si existen
if [ -f tests/protected-paths.sh ]; then
  check "tests/protected-paths.sh" bash tests/protected-paths.sh
fi

echo
echo "Resumen: $PASSED/$TOTAL comprobaciones correctas"
if [ "${#FAILED_NAMES[@]}" -gt 0 ]; then
  printf 'Fallos:\n'; printf '  - %s\n' "${FAILED_NAMES[@]}"
  exit 1
fi
exit 0
