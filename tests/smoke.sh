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
  DOZZLE_URL=http://dummy
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
for sk in agregarr dozzle; do
  if [ -d "skills/$sk" ]; then
    check "skill $sk tiene SKILL.md" test -f "skills/$sk/SKILL.md"
    check "skill $sk tiene README.md" test -f "skills/$sk/README.md"
  else
    echo "skip - skills/$sk aun no existe"
  fi
done

# 4. Frontmatter name/description
# shellcheck disable=SC2317,SC2329  # falso positivo: se invoca de forma indirecta vía check "$@"
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
for f in skills/radarr/scripts/radarr.sh skills/sonarr/scripts/sonarr.sh skills/prowlarr/scripts/prowlarr-api.sh; do
  env -i PATH="$PATH" "${DUMMY_ENV[@]}" timeout 20 bash "$f" help >"$TMP/out" 2>&1
  if grep -q 'logs' "$TMP/out"; then ok "$f help muestra logs"; else fail "$f help muestra logs"; fi
  for bad in "abc" "0" "5000" "--bogus" "--level" "--level zzz" "--grep"; do
    # shellcheck disable=SC2086
    env -i PATH="$PATH" "${DUMMY_ENV[@]}" timeout 20 bash "$f" logs $bad >"$TMP/out" 2>&1
    rc=$?
    if [ "$rc" -eq 1 ] && grep -q '^ERROR' "$TMP/out"; then ok "$f logs $bad rc 1"; else fail "$f logs $bad rc 1" "rc=$rc"; fi
  done
done
for sk in radarr sonarr prowlarr; do
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
  for c in search search-json exists config status add remove logs health queue indexers downloadclients customformats qualityprofiles; do
    if grep -q -- "$c" "$TMP/out"; then ok "$SNR help lista $c"; else fail "$SNR help lista $c"; fi
  done
  for bad in "search" "exists" "exists abc" "add" "add abc" "add 1 abc" "remove" "remove abc" "health x" "queue x" "indexers x" "downloadclients x" "customformats x" "qualityprofiles x" "comando-desconocido-zzz"; do
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
  for c in search search-json exists config status add add-collection remove collection-info logs health queue indexers downloadclients customformats qualityprofiles; do
    if grep -q -- "$c" "$TMP/out"; then ok "$RDR help lista $c"; else fail "$RDR help lista $c"; fi
  done
  for bad in "search" "exists" "exists abc" "add" "add abc" "add 1 abc" "add-collection" "add-collection abc" "remove" "remove abc" "collection-info" "collection-info abc" "health x" "queue x" "indexers x" "downloadclients x" "customformats x" "qualityprofiles x" "comando-desconocido-zzz"; do
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

# 5h. agregarr logs: acepta {pageInfo, results:[...]} y array plano (curl simulado, sin red)
AGR=skills/agregarr/scripts/agregarr.sh
if [ -f "$AGR" ]; then
  FB="$TMP/fakebin"; mkdir -p "$FB"
  cat >"$FB/curl" <<'FAKE'
#!/usr/bin/env bash
cat >/dev/null
printf '%s\n200' "$(cat "$FAKE_BODY")"
FAKE
  chmod +x "$FB/curl"
  printf '%s' '{"pageInfo":{"pages":1,"pageSize":1,"results":1,"page":1},"results":[{"timestamp":"T1","level":"info","label":"L","message":"hola"}]}' >"$TMP/logs-obj.json"
  printf '%s' '[{"timestamp":"T2","level":"warn","label":"L","message":"adios"}]' >"$TMP/logs-arr.json"
  for pair in "logs-obj.json:T1 [info] L: hola" "logs-arr.json:T2 [warn] L: adios"; do
    fx="${pair%%:*}"; want="${pair#*:}"
    env -i PATH="$FB:$PATH" "${DUMMY_ENV[@]}" FAKE_BODY="$TMP/$fx" timeout 20 bash "$AGR" logs 5 >"$TMP/out" 2>&1
    rc=$?
    if [ "$rc" -eq 0 ] && grep -qxF "$want" "$TMP/out"; then ok "$AGR logs con $fx"; else fail "$AGR logs con $fx" "rc=$rc $(head -c 200 "$TMP/out" | tr '\n' ' ')"; fi
  done
  # sintaxis: --level, posicional y errores de uso; el curl simulado guarda la config recibida
  cat >"$FB/curl" <<'FAKE'
#!/usr/bin/env bash
cat >"$FAKE_CFG"
printf '%s\n200' "$(cat "$FAKE_BODY")"
FAKE
  chmod +x "$FB/curl"
  for args in "--level error" "5 error" "--lines 5 --level ERROR"; do
    : >"$TMP/cfg"
    # shellcheck disable=SC2086
    env -i PATH="$FB:$PATH" "${DUMMY_ENV[@]}" FAKE_BODY="$TMP/logs-obj.json" FAKE_CFG="$TMP/cfg" timeout 20 bash "$AGR" logs $args >"$TMP/out" 2>&1
    rc=$?
    if [ "$rc" -eq 0 ] && grep -qxF "T1 [info] L: hola" "$TMP/out" && grep -q 'filter=error' "$TMP/cfg"; then ok "$AGR logs $args"; else fail "$AGR logs $args" "rc=$rc $(head -c 200 "$TMP/out" | tr '\n' ' ')"; fi
  done
  for args in "--level" "--level x" "--bogus" "5 error extra" "--lines"; do
    # shellcheck disable=SC2086
    env -i PATH="$FB:$PATH" "${DUMMY_ENV[@]}" FAKE_BODY="$TMP/logs-obj.json" FAKE_CFG="$TMP/cfg" timeout 20 bash "$AGR" logs $args >"$TMP/out" 2>&1
    rc=$?
    if [ "$rc" -eq 1 ] && grep -q '^ERROR' "$TMP/out"; then ok "$AGR logs $args rc 1"; else fail "$AGR logs $args rc 1" "rc=$rc"; fi
  done
fi

# 5i. radarr/sonarr: comandos de solo lectura con curl simulado; los secretos no salen en la salida
FB="$TMP/fakebin"; mkdir -p "$FB"
cat >"$FB/curl" <<'FAKE'
#!/usr/bin/env bash
cfg="$(cat)"
case "$cfg" in
  *"/indexer"*) body='[{"id":1,"name":"Idx","implementation":"Torznab","protocol":"torrent","priority":25,"enableRss":true,"enableAutomaticSearch":true,"enableInteractiveSearch":false,"fields":[{"name":"apiKey","value":"SECRETO-IDX"}]}]' ;;
  *"/downloadclient"*) body='[{"id":2,"name":"Cli","implementation":"QBittorrent","protocol":"torrent","priority":1,"enable":true,"username":"USUARIO-SECRETO","password":"CLAVE-SECRETA","fields":[{"name":"password","value":"CLAVE-SECRETA"}]}]' ;;
  *"/health"*) body='[{"type":"warning","source":"IndexerCheck","message":"fallo https://h/x?apikey=SECRETO-MSG&a=1"}]' ;;
  *"/queue"*) body='{"totalRecords":1,"records":[{"id":9,"title":"Rel token=SECRETO-Q","status":"downloading","trackedDownloadState":"downloading","size":100,"sizeleft":50,"timeleft":"00:10:00","protocol":"torrent","downloadClient":"Cli"}]}' ;;
  *"/customformat"*) body='[{"id":3,"name":"CF","specifications":[{"name":"a"},{"name":"b"}]}]' ;;
  *"/qualityprofile"*) body='[{"id":7,"name":"Perfil","minFormatScore":100,"cutoffFormatScore":0,"formatItems":[{"name":"Bueno","score":100},{"name":"Cero","score":0},{"name":"Malo","score":-10000}]}]' ;;
  *) body='[]' ;;
esac
printf '%s\n200' "$body"
FAKE
chmod +x "$FB/curl"
for sk in radarr sonarr; do
  F="skills/$sk/scripts/$sk.sh"
  [ -f "$F" ] || continue
  for pair in "health:IndexerCheck: fallo https://h/x?apikey=***&a=1" "queue:En cola: 1" "queue:[9] Rel token=*** - downloading/downloading - 50% - restante: 00:10:00 - torrent (Cli)" \
              "indexers:[1] Idx (Torznab) - torrent - prioridad 25 - rss: true, auto: true, interactiva: false" \
              "downloadclients:[2] Cli (QBittorrent) - torrent - prioridad 1 - activo: true" "customformats:[3] CF - 2 condiciones" \
              "qualityprofiles:[7] Perfil - minFormatScore: 100, cutoffFormatScore: 0" "qualityprofiles:    Bueno: 100" "qualityprofiles:    Malo: -10000"; do
    c="${pair%%:*}"; want="${pair#*:}"
    env -i PATH="$FB:$PATH" "${DUMMY_ENV[@]}" timeout 20 bash "$F" "$c" >"$TMP/out" 2>&1
    rc=$?
    if [ "$rc" -eq 0 ] && grep -qF -- "$want" "$TMP/out" && ! grep -q 'SECRETO\|CLAVE-SECRETA\|USUARIO-SECRETO' "$TMP/out" && ! grep -q 'Cero' "$TMP/out"; then
      ok "$F $c salida filtrada ($want)"
    else
      fail "$F $c salida filtrada ($want)" "rc=$rc $(head -c 200 "$TMP/out" | tr '\n' ' ')"
    fi
  done
done

# 5j. dozzle: help, validación de argumentos (rc 1, sin red) y curl simulado (lista, logs, redacción)
DZL=skills/dozzle/scripts/dozzle.sh
if [ -f "$DZL" ]; then
  env -i PATH="$PATH" "${DUMMY_ENV[@]}" timeout 20 bash "$DZL" help >"$TMP/out" 2>&1
  for c in status containers logs --lines --grep --stderr --stdout; do
    if grep -q -- "$c" "$TMP/out"; then ok "$DZL help lista $c"; else fail "$DZL help lista $c"; fi
  done
  for bad in "logs" "logs x --lines 0" "logs x --lines 5001" "logs x --lines abc" "logs x --lines" "logs x --grep" "logs x --since hoy" "logs x --bogus" "logs a b" "logs bad/name" "status x" "containers x" "comando-desconocido-zzz"; do
    # shellcheck disable=SC2086
    env -i PATH="$PATH" "${DUMMY_ENV[@]}" timeout 20 bash "$DZL" $bad >"$TMP/out" 2>&1
    rc=$?
    if [ "$rc" -eq 1 ] && grep -q '^ERROR' "$TMP/out"; then ok "$DZL $bad rc 1"; else fail "$DZL $bad rc 1" "rc=$rc"; fi
  done
  # Sin DOZZLE_URL ni .env: error claro, y no pide clave de API
  env -i PATH="$PATH" HOME="$TMP" timeout 20 bash "$DZL" status >"$TMP/out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && ! grep -q 'API_KEY' "$TMP/out"; then ok "$DZL sin DOZZLE_URL rc 1 y sin pedir clave"; else fail "$DZL sin DOZZLE_URL rc 1 y sin pedir clave" "rc=$rc"; fi

  DB="$TMP/dozzlebin"; mkdir -p "$DB"
  cat >"$DB/curl" <<'FAKE'
#!/usr/bin/env bash
args="$*"
cat >/dev/null 2>&1 </dev/null || true
case "$args" in
  *"/api/events/stream"*)
    printf 'retry: 3000\n\nevent: server-version\ndata: {"version":"v9.9.9"}\n\nevent: containers-changed\ndata: [{"id":"aaa111","name":"radarr","state":"running","health":"healthy","host":"h1"},{"id":"bbb222","name":"sonarr","state":"exited","host":"h1"}]\n\n' ;;
  *"/api/containers/logs"*)
    printf '%s\n' "$args" >>"$FAKE_LOG"
    printf 'linea uno\nERROR fallo apikey=SECRETO1 y token: SECRETO2\nAuthorization: Bearer SECRETO3\n{"password":"SECRETO4"}\nlinea final\n200' ;;
esac
FAKE
  chmod +x "$DB/curl"
  : >"$TMP/dz.log"
  env -i PATH="$DB:$PATH" "${DUMMY_ENV[@]}" timeout 20 bash "$DZL" containers >"$TMP/out" 2>&1
  if grep -q 'Dozzle v9.9.9 - 2 contenedores, 1 en ejecución' "$TMP/out" && grep -q '^radarr .*running .*healthy' "$TMP/out" && grep -q '^sonarr .*exited' "$TMP/out"; then ok "$DZL containers con curl simulado"; else fail "$DZL containers con curl simulado" "$(head -c 200 "$TMP/out" | tr '\n' ' ')"; fi
  env -i PATH="$DB:$PATH" "${DUMMY_ENV[@]}" FAKE_LOG="$TMP/dz.log" timeout 20 bash "$DZL" logs RADARR --lines 4 >"$TMP/out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && [ "$(wc -l <"$TMP/out")" -eq 4 ] && grep -q "^Authorization: \*\*\*$" "$TMP/out" && grep -q 'linea final' "$TMP/out" && ! grep -q 'SECRETO' "$TMP/out" && grep -q 'apikey=\*\*\*' "$TMP/out"; then ok "$DZL logs recorta a N y oculta secretos"; else fail "$DZL logs recorta a N y oculta secretos" "rc=$rc $(head -c 300 "$TMP/out" | tr '\n' ' ')"; fi
  if grep -q 'container=h1/aaa111' "$TMP/dz.log" && grep -q 'stdout=1' "$TMP/dz.log" && grep -q 'stderr=1' "$TMP/dz.log"; then ok "$DZL logs pide host/id y ambos flujos"; else fail "$DZL logs pide host/id y ambos flujos" "$(cat "$TMP/dz.log")"; fi
  : >"$TMP/dz.log"
  env -i PATH="$DB:$PATH" "${DUMMY_ENV[@]}" FAKE_LOG="$TMP/dz.log" timeout 20 bash "$DZL" logs bbb --grep error --stderr --since 2026-11-05T08:00:00Z >"$TMP/out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && [ "$(wc -l <"$TMP/out")" -eq 1 ] && grep -q '^ERROR fallo' "$TMP/out" && grep -q 'container=h1/bbb222' "$TMP/dz.log" && grep -q 'stderr=1' "$TMP/dz.log" && ! grep -q 'stdout=1' "$TMP/dz.log" && grep -q 'from=2026-11-05T08:00:00Z' "$TMP/dz.log"; then ok "$DZL logs --grep --stderr --since por id"; else fail "$DZL logs --grep --stderr --since por id" "rc=$rc $(head -c 300 "$TMP/out" | tr '\n' ' ') | $(cat "$TMP/dz.log")"; fi
  env -i PATH="$DB:$PATH" "${DUMMY_ENV[@]}" FAKE_LOG="$TMP/dz.log" timeout 20 bash "$DZL" logs zzz >"$TMP/out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^ERROR: contenedor no encontrado' "$TMP/out"; then ok "$DZL logs contenedor inexistente rc 1"; else fail "$DZL logs contenedor inexistente rc 1" "rc=$rc"; fi
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

# 7b. Reglas de texto: orquestador, backups, servicios en desuso, carpetas .@*
check "orquestador delega fuera de dominio en general-purpose sin preguntar" grep -q 'se delega directamente en un agente genérico (`general-purpose`), sin preguntar' agents/orchestrator.md
check "orquestador ya no pregunta cómo seguir fuera de dominio" bash -c '! grep -q "pregunta cómo seguir" agents/orchestrator.md'
check "rules: exención de retención de backups" grep -q 'Exención de retención de backups' skills/plex-crew-rules/SKILL.md
check "rules: servicios no configurados o en desuso" grep -q 'Servicios no configurados o en desuso' skills/plex-crew-rules/SKILL.md
check "arr-acquisition avisa de servicios no usados" grep -q 'Servicios no usados' agents/arr-acquisition.md
check "rules: carpetas .@* se ignoran en silencio" grep -q 'Se ignoran en silencio' skills/plex-crew-rules/SKILL.md

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
