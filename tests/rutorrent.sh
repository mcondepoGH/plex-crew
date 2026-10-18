#!/usr/bin/env bash
# Pruebas de skills/rutorrent/scripts/rutorrent.sh con un curl simulado (sin red ni credenciales reales).
# Uso: bash tests/rutorrent.sh   (rc 1 si algún caso falla)
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RT="$HERE/../skills/rutorrent/scripts/rutorrent.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

H=0123456789ABCDEF0123456789ABCDEF01234567
LOG="$T/calls.log"

# curl simulado: registra argv y stdin (config) y responde según la URL.
cat >"$T/fakecurl" <<'FAKE'
#!/usr/bin/env bash
args="$*"
cfg="$(cat)"
printf 'ARGV %s\nCFG %s\n' "$args" "$cfg" >>"$FAKE_LOG"
body='{}'
code=200
case "$args" in
  *mode=list*) body='{"t":{"0123456789ABCDEF0123456789ABCDEF01234567":["1","0","1","1","Pelicula X","1000","10","10","1000","0","0","0","0","0","seed","0","0","0","0","0","0"]}}' ;;
  *mode=getsavepath*) body="${FAKE_SAVEPATH-\"/data/downloads/seed/x\"}" ;;
  *mode=fls*) body='[["a.mkv",1000]]' ;;
  *diskspace*) body='{"free":1,"total":2}' ;;
esac
[ -n "${FAKE_CODE:-}" ] && code="$FAKE_CODE"
[ -n "${FAKE_RC:-}" ] && exit "$FAKE_RC"
printf '%s\n%s' "$body" "$code"
FAKE
chmod +x "$T/fakecurl"

N=0
FAIL=0
# run NOMBRE RC_ESPERADO SUBCADENA_SALIDA [VAR=VAL...] -- args
run() {
  local name="$1" rc_exp="$2" needle="$3" out rc
  shift 3
  local envs=()
  while [ "$1" != "--" ]; do envs+=("$1"); shift; done
  shift
  : >"$LOG"
  out="$(env -i PATH="$PATH" HOME="$T" FAKE_LOG="$LOG" RUTORRENT_CURL_BIN="$T/fakecurl" \
    RUTORRENT_URL=http://rt.test:8080/ RUTORRENT_USER=usr RUTORRENT_PASSWORD='p"w\d' "${envs[@]}" \
    bash "$RT" "$@" 2>&1)"
  rc=$?
  N=$((N + 1))
  if [ "$rc" = "$rc_exp" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -qF -- "$needle"; }; then
    return 0
  fi
  FAIL=$((FAIL + 1))
  printf 'FALLA %s (rc %s, esperado %s)\n      salida: %s\n' "$name" "$rc" "$rc_exp" "$out"
}
calls_have() { N=$((N + 1)); grep -qF -- "$2" "$LOG" || { FAIL=$((FAIL + 1)); printf 'FALLA %s: no aparece "%s"\n' "$1" "$2"; }; }
calls_lack() { N=$((N + 1)); ! grep -qF -- "$2" "$LOG" || { FAIL=$((FAIL + 1)); printf 'FALLA %s: aparece "%s"\n' "$1" "$2"; }; }

# --- ayuda y errores de uso (sin entorno ni red)
N=$((N + 1)); env -i PATH="$PATH" HOME="$T" bash "$RT" help >/dev/null 2>&1 || { FAIL=$((FAIL + 1)); echo "FALLA help sin entorno"; }
run "comando desconocido" 1 "comando desconocido" -- zzz
run "info sin hash" 1 "falta el hash" -- info
run "info hash corto" 1 "no es un hash válido" -- info abc
run "start hash inválido" 1 "no es un hash válido" -- start "$H;rm"
run "sin variables ni .env" 1 "no existe" HOME="$T/nada" RUTORRENT_URL= -- list
mkdir -p "$T/h2/.claude/plex-crew"; printf "RUTORRENT_USER=u\n" >"$T/h2/.claude/plex-crew/.env"
run "faltan variables" 1 "faltan variables" HOME="$T/h2" RUTORRENT_URL= -- list

# --- lectura
run "list" 0 "Pelicula X" -- list
calls_have "list usa httprpc" "/plugins/httprpc/action.php"
calls_have "list: URL sin barra doble" "http://rt.test:8080/plugins"
calls_have "auth por config" 'user = "usr:p\"w\\d"'
# sin USER/PASSWORD: funciona y no se pasa auth
run "sin credenciales" 0 "Pelicula X" RUTORRENT_USER= RUTORRENT_PASSWORD= -- list
calls_lack "sin auth: no -K -" "-K -"
calls_lack "sin auth: no user" "user ="
calls_have "sin auth: llama a httprpc" "/plugins/httprpc/action.php"
# con credenciales: auth con -K -
run "con credenciales" 0 "Pelicula X" -- list
calls_have "con auth: -K -" "-K -"
N=$((N + 1)); if grep '^ARGV' "$LOG" | grep -qF -e 'usr' -e 'p"w'; then FAIL=$((FAIL + 1)); echo "FALLA: credenciales en argv"; fi
run "list --raw" 0 '"t"' -- list --raw
run "info" 0 "Pelicula X" -- info "${H,,}"
calls_lack "info no borra" "remove"
run "files" 0 "a.mkv" -- files "$H"
run "diskspace" 0 '"free"' -- diskspace
run "HTTP 401" 1 "401" FAKE_CODE=401 -- list
run "HTTP 500" 1 "HTTP 500" FAKE_CODE=500 -- list
run "sin conexión" 1 "no se pudo conectar" FAKE_RC=7 -- list
run "timeout" 1 "tiempo de espera" FAKE_RC=28 -- list

# --- escritura segura
run "start" 0 "" -- start "$H"
calls_have "start modo" "mode=start"
run "stop" 0 "" -- stop "$H"
run "recheck" 0 "" -- recheck "$H"
run "label" 0 "" -- label "$H" "Peliculas"
calls_have "label valor" "v=Peliculas"
run "add url" 0 "" -- add "magnet:?xt=urn:btih:abc" --label X --stopped
calls_have "add url" "url=magnet:?xt=urn:btih:abc"
calls_have "add stopped" "torrents_start_stopped=1"
run "add fichero inexistente" 1 "no existe el fichero" -- add "$T/no.torrent"
printf 'x' >"$T/a.torrent"
run "add fichero" 0 "" -- add "$T/a.torrent"
calls_have "add fichero" "torrent_file[]=@$T/a.torrent"
run "add no torrent" 1 ".torrent" -- add "$HERE/rutorrent.sh"

# --- create: validación de rutas
run "create ok" 0 "" -- create /data/downloads/seed/x --tracker http://t/a --private
calls_have "create start_seeding=0" "start_seeding=0"
calls_have "create private" "private=1"
run "create relativa" 1 "absoluta" -- create seed/x
run "create .." 1 "'..'" -- create /data/downloads/seed/../x
run "create .@" 1 ".@" -- create /data/downloads/.@__thumb/x
run "create movies" 1 "biblioteca" -- create /data/media/movies/x
run "create Shows" 1 "biblioteca" -- create /data/media/Shows/x
run "create movies con flag" 0 "" -- create /data/media/movies/x --allow-library
run "create fuera de ALLOWED" 1 "RUTORRENT_ALLOWED_DIR" RUTORRENT_ALLOWED_DIR=/data/downloads/seed -- create /data/downloads/otra/x
run "create dentro de ALLOWED" 0 "" RUTORRENT_ALLOWED_DIR=/data/downloads/seed/ -- create /data/downloads/seed/x
run "create prefijo parecido" 1 "RUTORRENT_ALLOWED_DIR" RUTORRENT_ALLOWED_DIR=/data/downloads/seed -- create /data/downloads/seedx/y
run "create rechazado" 1 "" -- create /x/movies/y
calls_lack "create rechazado sin red" "create/action.php"

# --- destructivos
run "remove" 0 "" -- remove "$H"
calls_have "remove modo" "mode=remove"
calls_lack "remove no es removewithdata" "removewithdata"
run "remove-with-data ok" 0 "ruta de guardado" -- remove-with-data "$H"
calls_have "removewithdata llamado" "mode=removewithdata"
run "remove-with-data muestra files" 0 "a.mkv" -- remove-with-data "$H"
run "remove-with-data en biblioteca" 1 "biblioteca" FAKE_SAVEPATH='"/data/media/movies/x"' -- remove-with-data "$H"
calls_lack "no borra en biblioteca" "removewithdata"
run "remove-with-data con flag" 0 "" FAKE_SAVEPATH='"/data/media/shows/x"' -- remove-with-data "$H" --allow-library
run "remove-with-data fuera de ALLOWED" 1 "RUTORRENT_ALLOWED_DIR" RUTORRENT_ALLOWED_DIR=/data/downloads/seed FAKE_SAVEPATH='"/data/otro/x"' -- remove-with-data "$H"
calls_lack "no borra fuera de ALLOWED" "removewithdata"
run "remove-with-data ruta vacía" 1 "no se pudo determinar" FAKE_SAVEPATH='""' -- remove-with-data "$H"
run "remove-with-data ruta .@" 1 ".@" FAKE_SAVEPATH='"/data/.@__thumb/x"' -- remove-with-data "$H"
run "remove-with-data sin hash" 1 "falta el hash" -- remove-with-data

printf '\n%d/%d casos correctos' "$((N - FAIL))" "$N"
if [ "$FAIL" -ne 0 ]; then printf ' (%d fallan)\n' "$FAIL"; exit 1; fi
printf '\n'
