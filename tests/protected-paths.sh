#!/usr/bin/env bash
# Pruebas de hooks/protected-paths.js (carpetas de sistema del NAS). Solo directorios temporales.
# Uso: bash tests/protected-paths.sh   (rc 1 si algún caso falla)
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../hooks/protected-paths.js"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

mkdir -p "$T/home" "$T/media/@Recycle" "$T/media/ok" "$T/media/@zurg/movies"
ln -s "$T/media/@Recycle" "$T/media/ok/enlace"

N=0
FAIL=0
# hook JSON [VAR=VAL...] -> imprime salida; deja rc en $RC
hook() {
  local json="$1"; shift
  OUT="$(printf '%s' "$json" | env -i PATH="$PATH" HOME="$T/home" "$@" node "$HOOK" 2>"$T/err")"
  RC=$?
}
jstr() { node -e 'process.stdout.write(JSON.stringify(process.argv[1]))' -- "$1"; }
# deny|allow NOMBRE TOOL CAMPO VALOR [AGENTE] [VAR=VAL...]
case_() {
  local want="$1" name="$2" tool="$3" field="$4" val="$5" agent="${6-}"; shift 6 2>/dev/null || shift $#
  local ag=''
  [ -n "$agent" ] && ag=",\"agent_type\":\"$agent\""
  hook "{\"tool_name\":\"$tool\",\"cwd\":$(jstr "$T/media/ok"),\"tool_input\":{\"$field\":$(jstr "$val")}$ag}" "$@"
  N=$((N + 1))
  local got=allow
  case "$OUT" in *'"permissionDecision":"deny"'*) got=deny ;; esac
  if [ "$RC" != 0 ] || [ "$got" != "$want" ]; then
    FAIL=$((FAIL + 1))
    printf 'FALLA %s (esperado %s, rc %s): %s\n' "$name" "$want" "$RC" "$OUT"
  fi
}
deny() { case_ deny "$@"; }
allow() { case_ allow "$@"; }

R="$T/media/@Recycle"
# --- Bash: denegados
deny "bash ls" Bash command "ls $R"
deny "bash cat" Bash command "cat $R/a.txt"
deny "bash rm" Bash command "rm -rf $R/a"
deny "bash mv desde" Bash command "mv $R/a $T/media/ok/"
deny "bash mv hacia" Bash command "mv $T/media/ok/a $R/"
deny "bash cp" Bash command "cp $R/a /tmp/b"
deny "bash touch" Bash command "touch /x/@Recently-Snapshot/f"
deny "bash find" Bash command "find /x/.@__thumb -name '*.jpg'"
deny "bash redireccion" Bash command "echo hola > /x/@Recycle/f"
deny "bash redireccion lectura" Bash command "cat < /x/#recycle/f"
deny "bash nombre exacto" Bash command "ls @Recycle"
deny "bash relativa" Bash command "ls @Recycle/a"
deny "bash cd + relativa" Bash command "cd /x/@eaDir && ls foo"
deny "bash cd relativo" Bash command "cd @Recycle; ls"
deny "bash bash -c" Bash command "bash -c 'ls @Recycle'"
deny "bash eval" Bash command "eval ls /x/@Recycle/a"
deny "bash \$(...)" Bash command "echo \$(ls /x/#snapshot/a)"
deny "bash opcion=ruta" Bash command "rsync --exclude=x --log-file=/x/@Recycle/log a b"
deny "bash mayusculas" Bash command "ls /x/@RECYCLE/a"
deny "bash @Transcode" Bash command "ls /x/@Transcode"
deny "bash @Download" Bash command "ls /x/@Download"
deny "bash #snapshot" Bash command "ls /x/#snapshot"
deny "bash .. a protegida" Bash command "ls $T/media/ok/../@Recycle"
deny "bash .. lexico" Bash command "ls $R/../ok"
deny "bash symlink" Bash command "ls $T/media/ok/enlace"
deny "bash symlink hijo" Bash command "cat $T/media/ok/enlace/a.txt"
deny "bash CLAUDE_CONFIRMED no salta" Bash command "PLEX_CREW_CONFIRMED=1 rm -rf /x/@Recycle/a"
# --- Bash: permitidos
allow "bash normal" Bash command "ls $T/media/ok"
allow "bash echo con espacios" Bash command 'echo "ver @Recycle en el README"'
allow "bash commit -m" Bash command 'git commit -m "ver @Recycle en el README"'
allow "bash commit -m con ruta" Bash command 'git commit -m "no tocar /x/@Recycle/a"'
allow "bash heredoc" Bash command $'cat <<EOF\n@Recycle y /x/@Recycle/a\nEOF'
allow "bash @zurg" Bash command "ls @zurg/movies"
allow "bash Recycle.txt" Bash command "cat $T/media/ok/Recycle.txt"
allow "bash comando vacio" Bash command ""
# --- tools de fichero
for ag in "" plex-naming general-purpose plex-crew:arr-acquisition; do
  deny "Read [$ag]" Read file_path "$R/a.txt" "$ag"
  deny "Edit [$ag]" Edit file_path "/x/@Recently-Snapshot/a" "$ag"
  deny "Write [$ag]" Write file_path "/x/.@__thumb/a" "$ag"
  deny "NotebookEdit [$ag]" NotebookEdit notebook_path "/x/@eaDir/a.ipynb" "$ag"
  deny "Glob path [$ag]" Glob path "/x/#recycle" "$ag"
  deny "Grep path [$ag]" Grep path "/x/@Recycle/sub" "$ag"
  deny "Bash [$ag]" Bash command "ls /x/@Recycle" "$ag"
done
deny "Glob pattern" Glob pattern "/x/@Recycle/**/*.mkv"
deny "Glob pattern relativo" Glob pattern "**/.@__thumb/*"
deny "Grep glob" Grep glob "**/@Recycle/**"
deny "Read mayusculas" Read file_path "/x/@RECENTLY-SNAPSHOT/a"
deny "Read .. " Read file_path "$T/media/ok/../@Recycle/a"
deny "Read symlink" Read file_path "$T/media/ok/enlace/a"
deny "Write symlink" Write file_path "$T/media/ok/enlace/nuevo.txt"
allow "Read normal" Read file_path "$T/media/ok/a.txt"
allow "Read Recycle.txt" Read file_path "$T/media/ok/Recycle.txt"
allow "Read @zurg" Read file_path "$T/media/@zurg/movies/a.mkv"
allow "Glob normal" Glob pattern "**/*.mkv"
allow "Grep normal" Grep path "$T/media/ok"
# contenido de Write/Edit/Grep pattern no cuenta
hook "{\"tool_name\":\"Write\",\"cwd\":\"$T\",\"tool_input\":{\"file_path\":\"$T/n.txt\",\"content\":\"mira /x/@Recycle/a y @Recycle\"}}"
N=$((N + 1)); case "$OUT" in *deny*) FAIL=$((FAIL + 1)); echo "FALLA Write con contenido que menciona @Recycle: $OUT" ;; esac
hook "{\"tool_name\":\"Edit\",\"cwd\":\"$T\",\"tool_input\":{\"file_path\":\"$T/n.txt\",\"old_string\":\"@Recycle\",\"new_string\":\"/x/@Recycle/a\"}}"
N=$((N + 1)); case "$OUT" in *deny*) FAIL=$((FAIL + 1)); echo "FALLA Edit con texto que menciona @Recycle: $OUT" ;; esac
hook "{\"tool_name\":\"Grep\",\"cwd\":\"$T\",\"tool_input\":{\"pattern\":\"@Recycle\",\"path\":\"$T/media/ok\"}}"
N=$((N + 1)); case "$OUT" in *deny*) FAIL=$((FAIL + 1)); echo "FALLA Grep con pattern @Recycle: $OUT" ;; esac
# cwd protegido
hook "{\"tool_name\":\"Bash\",\"cwd\":\"$T/media/@Recycle\",\"tool_input\":{\"command\":\"ls\"}}"
N=$((N + 1)); case "$OUT" in *deny*) ;; *) FAIL=$((FAIL + 1)); echo "FALLA Bash con cwd protegido" ;; esac
# tool no vigilada
hook "{\"tool_name\":\"Agent\",\"cwd\":\"$T\",\"tool_input\":{\"prompt\":\"/x/@Recycle\"}}"
N=$((N + 1)); [ -z "$OUT" ] && [ "$RC" = 0 ] || { FAIL=$((FAIL + 1)); echo "FALLA tool no vigilada"; }

# --- ampliaciones
allow "extra sin configurar" Bash command "ls /x/MiPapelera/a"
deny "extra por env" Bash command "ls /x/MiPapelera/a" "" PLEX_CREW_PROTECTED_NAMES="otra:MiPapelera"
deny "env suma al defecto" Bash command "ls /x/@Recycle" "" PLEX_CREW_PROTECTED_NAMES="otra"
mkdir -p "$T/home/.claude/plex-crew"
printf '# comentario\n\n  Basura  \n' >"$T/home/.claude/plex-crew/protected-names.conf"
deny "extra por conf" Bash command "ls /x/basura/a"
deny "conf suma al defecto" Read file_path "/x/@Recycle/a"
allow "conf: comentario no cuenta" Bash command "ls /x/comentario"

# --- entrada basura: falla cerrado (exit 2)
for junk in '' 'no json'; do
  OUT="$(printf '%s' "$junk" | env -i PATH="$PATH" HOME="$T/home" node "$HOOK" 2>/dev/null)"; RC=$?
  N=$((N + 1)); [ "$RC" = 2 ] || { FAIL=$((FAIL + 1)); echo "FALLA JSON basura '$junk' (rc $RC)"; }
done
# mensaje de denegación
hook "{\"tool_name\":\"Bash\",\"cwd\":\"$T\",\"tool_input\":{\"command\":\"ls /ruta/a/medios/@Recycle\"}}"
N=$((N + 1)); case "$OUT" in *"/ruta/a/medios/@Recycle"*"carpeta de sistema del NAS"*"README"*) ;; *) FAIL=$((FAIL + 1)); echo "FALLA mensaje de denegación: $OUT" ;; esac

printf '\n%d/%d casos correctos' "$((N - FAIL))" "$N"
if [ "$FAIL" -ne 0 ]; then printf ' (%d fallan)\n' "$FAIL"; exit 1; fi
printf '\n'
