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
outf=""
prev=""
for a in "$@"; do [ "$prev" = "-o" ] && outf="$a"; prev="$a"; done
case "$args" in
  *mode=list*) body='{"t":{"0123456789ABCDEF0123456789ABCDEF01234567":["1","0","1","1","Pelicula X","1000","10","10","1000","0","0","0","0","0","seed","0","0","0","0","0","0"]}}' ;;
  *mode=getsavepath*) body="${FAKE_SAVEPATH-\"/data/downloads/seed/x\"}" ;;
  *mode=fls*) body='[["a.mkv",1000]]' ;;
  *diskspace*) body='{"free":1,"total":2}' ;;
  *addtorrent.php*)
    code="${FAKE_CODE:-302}"
    printf '%s\n%s\n%s' "" "$code" "http://rt.test:8080/php/addtorrent.php?${FAKE_ADD_QUERY-result[]=Success&name[]=x&json=1}"
    exit 0 ;;
  *cmd=getfile*) body="${FAKE_TORRENT-d8:announce3:urle}" ;;
esac
[ -n "${FAKE_CODE:-}" ] && code="$FAKE_CODE"
[ -n "${FAKE_RC:-}" ] && exit "$FAKE_RC"
if [ -n "$outf" ]; then printf '%s' "$body" >"$outf"; printf '%s' "$code"; exit 0; fi
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

# --- add: el resultado viene en el 302 (Location: ...addtorrent.php?result[]=...)
run "add 302 Success" 0 "OK" -- add "$T/a.torrent"
run "add 302 Success con --dir" 0 "OK" -- add "$T/a.torrent" --dir /data/downloads/seed --no-add-name
run "add 302 Duplicate" 0 "ya estaba" FAKE_ADD_QUERY='result[]=Duplicate&json=1' -- add "$T/a.torrent"
run "add 302 FailedDirectory" 1 "FailedDirectory" FAKE_ADD_QUERY='result[]=FailedDirectory&json=1' -- add "$T/a.torrent" --dir /data/downloads/seed
run "add 302 Failed" 1 "(Failed)" FAKE_ADD_QUERY='result[]=Failed&json=1' -- add "$T/a.torrent"
run "add 302 FailedURL" 1 "FailedURL" FAKE_ADD_QUERY='result[]=FailedURL&json=1' -- add "magnet:?xt=urn:btih:abc"
run "add 302 codificado %5B%5D" 0 "OK" FAKE_ADD_QUERY='result%5B%5D=Success&json=1' -- add "$T/a.torrent"
run "add 302 sin resultado" 1 "no devolvió" FAKE_ADD_QUERY='json=1' -- add "$T/a.torrent"
run "add HTTP 500" 1 "HTTP 500" FAKE_CODE=500 -- add "$T/a.torrent"
run "add 302 mixto (uno falla)" 1 "FailedURL" FAKE_ADD_QUERY='result[]=Success&result[]=FailedURL&json=1' -- add "$T/a.torrent"

# --- add --dir / --no-add-name
run "add --dir" 0 "" -- add "$T/a.torrent" --dir /data/downloads/seed/ --label X
calls_have "add dir_edit sin barra final" "dir_edit=/data/downloads/seed "
calls_lack "add dir sin no-add-name" "not_add_path"
run "add --dir --no-add-name" 0 "" -- add "$T/a.torrent" --dir /data/downloads/seed --no-add-name --stopped
calls_have "add dir_edit" "dir_edit=/data/downloads/seed"
calls_have "add not_add_path" "not_add_path=1"
calls_have "add conserva stopped" "torrents_start_stopped=1"
run "add sin dir no manda dir_edit" 0 "" -- add "$T/a.torrent" --label X
calls_lack "add sin dir: sin dir_edit" "dir_edit"
calls_lack "add sin dir: sin not_add_path" "not_add_path"
calls_have "add sin dir: label" "label=X"
run "add --no-add-name sin dir" 1 "requiere --dir" -- add "$T/a.torrent" --no-add-name
run "add --dir relativa" 1 "absoluta" -- add "$T/a.torrent" --dir data/x
run "add --dir .." 1 "'..'" -- add "$T/a.torrent" --dir /data/../etc
run "add --dir .@" 1 ".@" -- add "$T/a.torrent" --dir /data/.@__thumb
run "add --dir biblioteca" 1 "biblioteca" -- add "$T/a.torrent" --dir /data/media/movies
run "add --dir biblioteca con flag" 0 "" -- add "$T/a.torrent" --dir /data/media/movies --allow-library
run "add --dir fuera de ALLOWED" 1 "RUTORRENT_ALLOWED_DIR" RUTORRENT_ALLOWED_DIR=/data/downloads -- add "$T/a.torrent" --dir /otra
run "add --dir sin valor" 1 "falta el valor de --dir" -- add "$T/a.torrent" --dir
calls_lack "add rechazado sin red" "addtorrent.php"

# --- getfile
ID=4f2a9c.12
run "getfile con --out" 0 "$T/out1.torrent" -- getfile "$ID" --out "$T/out1.torrent"
calls_have "getfile endpoint" "/plugins/create/action.php"
calls_have "getfile cmd" "cmd=getfile"
calls_have "getfile no" "no=$ID"
N=$((N + 1)); [ "$(head -c1 "$T/out1.torrent")" = d ] || { FAIL=$((FAIL + 1)); echo "FALLA getfile: contenido"; }
N=$((N + 1)); [ "$(stat -c %a "$T/out1.torrent")" = 600 ] || { FAIL=$((FAIL + 1)); echo "FALLA getfile: permisos"; }
N=$((N + 1)); [ -z "$(ls -A "$T" | grep '^\.getfile')" ] || { FAIL=$((FAIL + 1)); echo "FALLA getfile: temporal sobrante"; }
N=$((N + 1)); grep '^ARGV' "$LOG" | grep -qF -e 'usr' -e 'p"w' && { FAIL=$((FAIL + 1)); echo "FALLA getfile: credenciales en argv"; }
run "getfile no sobrescribe" 1 "--force" -- getfile "$ID" --out "$T/out1.torrent"
calls_lack "no sobrescribe sin red" "getfile"
printf 'viejo' >"$T/out2.torrent"
run "getfile --force" 0 "" FAKE_TORRENT='d4:infod4:name1:xee' -- getfile "$ID" --out "$T/out2.torrent" --force
N=$((N + 1)); [ "$(head -c1 "$T/out2.torrent")" = d ] || { FAIL=$((FAIL + 1)); echo "FALLA getfile --force: no sobrescribió"; }
ln -s "$T/nada" "$T/roto.torrent"
run "getfile enlace roto sin force" 1 "--force" -- getfile "$ID" --out "$T/roto.torrent"
run "getfile sin id" 1 "falta el id" -- getfile
run "getfile id inválido" 1 "id de tarea válido" -- getfile 'x;rm -rf'
run "getfile id sin punto" 1 "id de tarea válido" -- getfile 4f2a9c
run "getfile id ruta" 1 "id de tarea válido" -- getfile ../../x.1
run "getfile --out .." 1 "'..'" -- getfile "$ID" --out "$T/../x.torrent"
run "getfile --out sin .torrent" 1 ".torrent" -- getfile "$ID" --out "$T/x.bin"
run "getfile --out carpeta inexistente" 1 "no existe la carpeta" -- getfile "$ID" --out "$T/nodir/x.torrent"
run "getfile cuerpo vacío" 1 "vacío" FAKE_TORRENT= -- getfile "$ID" --out "$T/v.torrent"
N=$((N + 1)); [ ! -e "$T/v.torrent" ] || { FAIL=$((FAIL + 1)); echo "FALLA getfile: dejó fichero vacío"; }
run "getfile no bencode" 1 "no es un .torrent" FAKE_TORRENT='<html>' -- getfile "$ID" --out "$T/h.torrent"
run "getfile HTTP 404" 1 "HTTP 404" FAKE_CODE=404 -- getfile "$ID" --out "$T/n.torrent"
run "getfile HTTP 401" 1 "401" FAKE_CODE=401 -- getfile "$ID" --out "$T/n.torrent"
run "getfile sin conexión" 1 "no se pudo conectar" FAKE_RC=7 -- getfile "$ID" --out "$T/n.torrent"
N=$((N + 1)); [ ! -e "$T/n.torrent" ] || { FAIL=$((FAIL + 1)); echo "FALLA getfile: fichero tras error"; }
mkdir -p "$T/tmpd"
run "getfile sin --out usa TMPDIR" 0 "$T/tmpd/rutorrent-getfile." TMPDIR="$T/tmpd" -- getfile "$ID"
N=$((N + 1)); f=$(ls "$T"/tmpd/rutorrent-getfile.*/"$ID.torrent" 2>/dev/null); { [ -n "$f" ] && [ "$(stat -c %a "$f")" = 600 ] && [ "$(stat -c %a "$(dirname "$f")")" = 700 ]; } || { FAIL=$((FAIL + 1)); echo "FALLA getfile temporal: ruta/permisos"; }
run "getfile error sin --out no deja carpeta" 1 "HTTP 404" TMPDIR="$T/tmpd" FAKE_CODE=404 -- getfile 1a.2
N=$((N + 1)); [ "$(ls "$T/tmpd" | wc -l)" = 1 ] || { FAIL=$((FAIL + 1)); echo "FALLA getfile: carpeta temporal sobrante"; }

# --- create: validación de rutas
run "create ok" 0 "" -- create /data/downloads/seed/x --tracker http://t/a --private
calls_have "create siembra por defecto" "start_seeding=1"
calls_lack "create por defecto no envía start_seeding=0" "start_seeding=0"
run "create --no-seed" 0 "" -- create /data/downloads/seed/x --no-seed
calls_have "create --no-seed envía start_seeding=0" "start_seeding=0"
calls_lack "create --no-seed no envía start_seeding=1" "start_seeding=1"
run "create --no-seed antes de la ruta" 0 "" -- create --no-seed /data/downloads/seed/x --private
calls_have "create --no-seed + --private" "start_seeding=0"
run "create ok" 0 "" -- create /data/downloads/seed/x --tracker http://t/a --private
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
