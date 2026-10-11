#!/usr/bin/env bash
# Banco de pruebas de los hooks (hooks/confirm-destructive.js y hooks/enforce-agent-scope.js).
# Cada caso: entrada JSON de PreToolUse -> esperado "deny" o "pasa" (sin salida, exit 0).
# Usa un directorio temporal (mktemp -d) con raíces ficticias y su propio PLEX_CREW_CONFIG;
# no toca nada fuera de él. Sale con rc 1 si algún caso falla y muestra el resumen N/M.
#
# Uso: bash tests/hooks.sh [-v]     (-v muestra también los casos que pasan)
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS="$HERE/../hooks"
CONFIRM="$HOOKS/confirm-destructive.js"
SCOPE="$HOOKS/enforce-agent-scope.js"
VERBOSE=0
[ "${1:-}" = "-v" ] && VERBOSE=1

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
T="$(cd "$T" && pwd -P)"

R="$T/movies"      # raíz de medios 1
S="$T/shows"       # raíz de medios 2
O="$T/other"       # fuera del alcance
mkdir -p "$R/x" "$R/a" "$S/y" "$O/z" "$T/home"
ln -s "$O" "$R/link"          # enlace dentro del alcance que apunta fuera
ln -s "$R" "$O/mlink"         # enlace fuera del alcance que apunta dentro
printf '#!/bin/sh\ntrue\n' >"$R/ok.sh"
printf '#!/bin/sh\ntrue\n' >"$O/bad.sh"

CONF="$T/scope.conf"
printf '# raíces de prueba\n%s\n%s\n' "$R" "$S" >"$CONF"
EMPTY="$T/empty.conf"
: >"$EMPTY"
MISSING="$T/no-existe.conf"

N=0
FAIL=0

# json TOOL CWD AGENT CMD_OR_PATH  -> JSON de entrada del hook
json() {
  TN="$1" CW="$2" AG="$3" VAL="$4" node -e '
    const e = process.env;
    const p = { tool_name: e.TN, cwd: e.CW, tool_input: e.TN === "Bash" ? { command: e.VAL } : { file_path: e.VAL } };
    if (e.AG) p.agent_type = e.AG;
    process.stdout.write(JSON.stringify(p));'
}

# check HOOK CONFIG EXPECT NOMBRE JSON [SUBCADENA_EN_MOTIVO]
check() {
  local hook="$1" conf="$2" expect="$3" name="$4" input="$5" needle="${6:-}"
  local out got
  N=$((N + 1))
  out="$(printf '%s' "$input" | PLEX_CREW_CONFIG="$conf" HOME="$T/home" node "$hook" 2>&1)"
  if printf '%s' "$out" | grep -q '"permissionDecision":"deny"'; then got=deny; else got=pasa; fi
  if [ "$got" = "$expect" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -q -- "$needle"; }; then
    [ "$VERBOSE" = 1 ] && printf 'ok    [%s] %s\n' "$expect" "$name"
  else
    FAIL=$((FAIL + 1))
    printf 'FALLA [esperado %s, obtenido %s] %s\n      entrada: %s\n      salida: %s\n' "$expect" "$got" "$name" "$input" "$out"
  fi
}

# c EXPECT NOMBRE CWD CMD     (confirm-destructive con scope.conf normal)
c() { check "$CONFIRM" "$CONF" "$1" "confirm: $2" "$(json Bash "$3" "" "$4")"; }
# s EXPECT NOMBRE CWD CMD     (enforce-agent-scope, agente plex-naming, scope.conf normal)
s() { check "$SCOPE" "$CONF" "$1" "scope: $2" "$(json Bash "$3" plex-naming "$4")"; }
# w EXPECT NOMBRE CWD PATH    (enforce-agent-scope, herramienta Write)
w() { check "$SCOPE" "$CONF" "$1" "scope: $2" "$(json Write "$3" plex-naming "$4")"; }

# =====================================================================
# confirm-destructive
# =====================================================================

# --- básicos
c deny "rm -rf en raíz de medios sin marcador" "$T" "rm -rf $R/x"
c deny "rm de fichero en raíz" "$T" "rm $R/x/a.mkv"
c deny "rmdir en raíz" "$T" "rmdir $R/x"
c deny "unlink en raíz" "$T" "unlink $R/a/f"
c deny "shred en raíz" "$T" "shred -u $R/a/f"
c deny "truncate en raíz" "$T" "truncate -s0 $R/a/f"
c deny "dd of= en raíz" "$T" "dd if=/dev/zero of=$R/a/f bs=1M count=1"
c deny "find -delete en raíz" "$T" "find $R -name '*.nfo' -delete"
c deny "find -exec rm en raíz" "$T" "find $R -name '*.nfo' -exec rm {} \\;"
c deny "rsync --delete hacia raíz" "$T" "rsync -a --delete $O/ $R/"
c deny "rsync --delete-after hacia raíz" "$T" "rsync -a --delete-after $O/ $R/"
c deny "mv a /dev/null" "$T" "mv $R/x/a.mkv /dev/null"
c deny "rm en el repositorio" "$T" "rm -rf $HERE/../hooks"
c deny "docker rm" "$T" "docker rm plex"
c deny "docker compose down" "$T" "docker compose -f x.yml down"
c deny "SQL DELETE FROM" "$T" "sqlite3 db.sqlite 'DELETE FROM media'"
c deny "curl -X DELETE" "$T" "curl -X DELETE http://localhost:7878/api/v3/movie/1"
c deny "radarr.sh remove" "$T" "bash skills/radarr/scripts/radarr.sh remove 12"
c deny "prowlarr-api.sh delete" "$T" "prowlarr-api.sh delete 3"
c deny "arr_delete" "$T" "source skills/_lib/arr-api.sh; arr_delete radarr movie/1"
c pasa "rm fuera de las raíces" "$T" "rm -rf $O/z"
c pasa "ls" "$T" "ls -la $R"
c pasa "mv dentro de medios sigue permitido" "$T" "mv $R/a $R/b"
c pasa "mv a otra raíz" "$T" "mv $R/a $S/a"
c pasa "rsync sin --delete" "$T" "rsync -a $O/ $R/"
c pasa "docker ps" "$T" "docker ps"
c pasa "radarr.sh logs no es destructivo" "$T" "bash skills/radarr/scripts/radarr.sh logs 20 --level error"
c pasa "prowlarr-api.sh logs no es destructivo" "$T" "bash skills/prowlarr/scripts/prowlarr-api.sh logs 20 --level warn --grep delete"
c pasa "cwd en raíz y ruta fuera" "$R" "rm -rf $O/z"

# --- marcador PLEX_CREW_CONFIRMED=1 ligado al segmento
c pasa "marcador inicial" "$T" "PLEX_CREW_CONFIRMED=1 rm -rf $R/x"
c pasa "marcador tras otra asignación" "$T" "FOO=1 PLEX_CREW_CONFIRMED=1 rm -rf $R/x"
c pasa "marcador antes de otra asignación" "$T" "PLEX_CREW_CONFIRMED=1 FOO=1 rm -rf $R/x"
c pasa "marcador + envoltorio timeout" "$T" "PLEX_CREW_CONFIRMED=1 timeout 5 rm -rf $R/x"
c pasa "marcador en segundo segmento destructivo" "$T" "ls && PLEX_CREW_CONFIRMED=1 rm -rf $R/x"
c pasa "marcador en bash -c" "$T" "PLEX_CREW_CONFIRMED=1 bash -c 'rm -rf $R/x'"
c pasa "marcador con docker rm" "$T" "PLEX_CREW_CONFIRMED=1 docker rm plex"
c deny "marcador en otro segmento" "$T" "PLEX_CREW_CONFIRMED=1 ls; rm -rf $R/x"
c deny "marcador en otro segmento con &&" "$T" "PLEX_CREW_CONFIRMED=1 ls && rm -rf $R/x"
c deny "marcador en otro segmento con |" "$T" "PLEX_CREW_CONFIRMED=1 ls | rm -rf $R/x"
c deny "marcador solo en texto entrecomillado" "$T" "echo \"; PLEX_CREW_CONFIRMED=1 \"; rm -rf $R/x"
c deny "marcador en comillas simples" "$T" "echo '; PLEX_CREW_CONFIRMED=1 '; rm -rf $R/x"
c deny "marcador como argumento" "$T" "rm -rf $R/x PLEX_CREW_CONFIRMED=1"
c deny "marcador pegado (otro valor)" "$T" "PLEX_CREW_CONFIRMED=0 rm -rf $R/x"
c deny "marcador en sustitucion no cubre el rm" "$T" "PLEX_CREW_CONFIRMED=1 echo \$(rm -rf $R/x)"
c deny "marcador en el primero no cubre el segundo destructivo" "$T" "PLEX_CREW_CONFIRMED=1 rm -rf $R/x; rm -rf $R/a"

# --- rutas: .. relativas, variables, ~, cwd, symlinks
c deny "rm relativo con .. desde cwd fuera" "$O" "rm -rf ../movies/x"
c deny "rm con a/../b hacia raíz" "$T" "rm -rf $O/../movies/x"
c deny "rm con \$VAR" "$T" "rm -rf \$R/x"
c deny "rm con \${VAR}" "$T" "rm -rf \${R}/x"
c deny "rm con ~" "$T" "rm -rf ~/algo"
c deny "rm con sustitución de comando" "$T" "rm -rf \$(echo $R/x)"
c deny "rm relativo con cwd en raíz" "$R" "rm -rf x"
c deny "cd a raíz y rm relativo" "$T" "cd $R && rm -rf x"
c deny "cd con variable (cwd desconocido) y rm relativo" "$T" "cd \$D && rm -rf x"
c deny "rm a través de symlink que apunta a raíz" "$T" "rm -rf $O/mlink/x"
c deny "xargs rm con cwd en raíz" "$R" "ls | xargs rm"
c deny "xargs -0 rm con cwd en raíz" "$R" "find . -print0 | xargs -0 rm -f"
c pasa "rm relativo con cwd fuera" "$O" "rm -rf z"
c pasa "cd fuera y rm relativo" "$R" "cd $O && rm -rf z"
c pasa "rm a través de symlink que apunta fuera" "$T" "rm $R/link/z"

# --- envoltorios y evasiones
c deny "sudo rm" "$T" "sudo rm -rf $R/x"
c deny "timeout rm" "$T" "timeout 5 rm -rf $R/x"
c deny "nice -n rm" "$T" "nice -n 10 rm -rf $R/x"
c deny "ionice rm" "$T" "ionice -c 3 rm -rf $R/x"
c deny "env rm" "$T" "env FOO=1 rm -rf $R/x"
c deny "ruta absoluta del binario" "$T" "/bin/rm -rf $R/x"
c deny "barra invertida" "$T" "\\rm -rf $R/x"
c deny "comillas en el verbo" "$T" "'rm' -rf $R/x"
c deny "bash -c" "$T" "bash -c 'rm -rf $R/x'"
c deny "eval" "$T" "eval 'rm -rf $R/x'"
c deny "subshell" "$T" "(rm -rf $R/x)"
c deny "tras &&" "$T" "true && rm -rf $R/x"
c deny "tras ||" "$T" "false || rm -rf $R/x"
c deny "salto de línea" "$T" "$(printf 'ls\nrm -rf %s' "$R/x")"
c deny "tras pipe" "$T" "echo x | rm -rf $R/x"
c deny "if/then" "$T" "if true; then rm -rf $R/x; fi"
c deny "busybox rm" "$T" "busybox rm -rf $R/x"

# --- falsos positivos que no deben bloquear
c pasa "echo que menciona rm -rf" "$T" "echo \"para borrar usa rm -rf $R/x\""
c pasa "printf que menciona rm -rf" "$T" "printf '%s\n' 'rm -rf $R/x'"
c pasa "heredoc que menciona rm -rf" "$T" "$(printf 'cat > %s/nota.txt <<EOF\nrm -rf %s/x\nEOF' "$O" "$R")"
c pasa "grep de rm -rf" "$T" "grep -r 'rm -rf' $O"
c pasa "git commit con rm -rf en el mensaje" "$T" "git commit -m 'docs: no uses rm -rf'"
c pasa "comentario con rm" "$T" "ls # rm -rf $R/x"

# --- entrada no válida: fallo cerrado (exit 2 + mensaje en stderr)
rc2() {
  local hook="$1" name="$2" input="$3" out
  N=$((N + 1))
  out="$(printf '%s' "$input" | PLEX_CREW_CONFIG="$CONF" HOME="$T/home" node "$hook" 2>&1 >/dev/null; echo "rc=$?")"
  if printf '%s' "$out" | grep -q 'rc=2$' && printf '%s' "$out" | grep -q 'JSON no válida'; then
    [ "$VERBOSE" = 1 ] && printf 'ok    [exit 2] %s\n' "$name"
  else
    FAIL=$((FAIL + 1))
    printf 'FALLA [esperado exit 2 con mensaje] %s\n      salida: %s\n' "$name" "$out"
  fi
}
rc2 "$CONFIRM" "confirm: entrada vacía" ""
rc2 "$CONFIRM" "confirm: entrada basura" "no es json"
rc2 "$SCOPE" "scope: entrada vacía" ""
rc2 "$SCOPE" "scope: entrada basura" "no es json"

# --- sin scope.conf: fallo cerrado
check "$CONFIRM" "$MISSING" deny "confirm: sin scope.conf, rm fuera de todo" "$(json Bash "$T" "" "rm -rf $O/z")" "scope.conf"
check "$CONFIRM" "$EMPTY" deny "confirm: scope.conf vacío, rm" "$(json Bash "$T" "" "rm -rf $O/z")" "scope.conf"
check "$CONFIRM" "$MISSING" deny "confirm: sin scope.conf, el marcador no lo evita" "$(json Bash "$T" "" "PLEX_CREW_CONFIRMED=1 rm -rf $O/z")" "scope.conf"
check "$CONFIRM" "$MISSING" deny "confirm: sin scope.conf, rsync --delete" "$(json Bash "$T" "" "rsync -a --delete a/ b/")" "scope.conf"
check "$CONFIRM" "$MISSING" deny "confirm: sin scope.conf, find -delete" "$(json Bash "$T" "" "find . -delete")" "scope.conf"
check "$CONFIRM" "$MISSING" pasa "confirm: sin scope.conf, ls pasa" "$(json Bash "$T" "" "ls -la")"
check "$CONFIRM" "$MISSING" pasa "confirm: sin scope.conf, mv genérico pasa" "$(json Bash "$T" "" "mv a b")"
check "$CONFIRM" "$MISSING" deny "confirm: sin scope.conf, docker rm sigue pidiendo marcador" "$(json Bash "$T" "" "docker rm x")"
check "$CONFIRM" "$MISSING" pasa "confirm: sin scope.conf, docker rm con marcador" "$(json Bash "$T" "" "PLEX_CREW_CONFIRMED=1 docker rm x")"

# --- entrada rara
check "$CONFIRM" "$CONF" pasa "confirm: JSON inválido pasa" "no es json"
check "$CONFIRM" "$CONF" pasa "confirm: sin comando pasa" '{"tool_input":{}}'

# =====================================================================
# enforce-agent-scope (agente plex-naming)
# =====================================================================

# --- básicos
s pasa "touch dentro" "$R" "touch $R/a/f"
s pasa "mv dentro" "$R" "mv $R/a/f $R/a/g"
s pasa "cp dentro" "$R" "cp $R/ok.sh $R/a/g"
s deny "cp con origen fuera (conservador)" "$R" "cp $O/bad.sh $R/a/g"
s pasa "mkdir dentro (otra raíz)" "$R" "mkdir -p $S/nuevo"
s pasa "rm dentro" "$R" "rm $R/a/f"
s pasa "ls fuera (solo lectura)" "$R" "ls $O"
s pasa "cat fuera (solo lectura)" "$R" "cat $O/bad.sh"
s pasa "redirección a /dev/null" "$R" "ls $O > /dev/null 2>&1"
s pasa "redirección dentro" "$R" "echo hola > $R/a/nota.txt"
s pasa "mv con relativos dentro" "$R/a" "mv f g"
s pasa "sed sin -i fuera" "$R" "sed s/a/b/ $O/bad.sh"
s deny "touch fuera" "$R" "touch $O/f"
s deny "mv hacia fuera" "$R" "mv $R/a/f $O/f"
s deny "cp hacia fuera" "$R" "cp $R/ok.sh $O/f"
s deny "rm fuera" "$R" "rm -rf $O/z"
s deny "mkdir fuera" "$R" "mkdir $O/nuevo"
s deny "ln fuera" "$R" "ln -s $R/ok.sh $O/enlace"
s deny "tee fuera" "$R" "echo x | tee $O/f"
s deny "truncate fuera" "$R" "truncate -s0 $O/bad.sh"
s deny "install fuera" "$R" "install -m 644 $R/ok.sh $O/f"
s deny "sed -i fuera" "$R" "sed -i s/a/b/ $O/bad.sh"
s deny "redirección > fuera" "$R" "echo x > $O/f"
s deny "redirección >> fuera" "$R" "echo x >> $O/f"
s deny "redirección &> fuera" "$R" "echo x &> $O/f"
s deny "cp -t fuera" "$R" "cp -t $O $R/ok.sh"
s deny "mv --target-directory= fuera" "$R" "mv --target-directory=$O $R/ok.sh"
s deny "segundo comando fuera" "$R" "touch $R/a/f && touch $O/f"
s deny "tras punto y coma" "$R" "ls; rm $O/bad.sh"
s deny "relativo hacia fuera desde cwd" "$R/a" "touch ../../other/f"
s deny "relativo con .. de escape" "$R" "touch $R/../other/f"
s deny "cd fuera y escribir relativo" "$R" "cd $O && touch f"
s deny "variable sin resolver" "$R" "touch \$X/f"
s deny "sustitución de comando en ruta" "$R" "touch \$(echo $O)/f"
s deny "sustitución con escritura dentro" "$R" "echo \$(touch $O/f)"
s deny "eval" "$R" "eval 'touch $O/f'"
s deny "bash -c" "$R" "bash -c 'touch $O/f'"
s deny "xargs" "$R" "ls | xargs touch"
s deny "find -delete" "$R" "find $O -delete"
s deny "find -exec" "$R" "find $R -exec touch $O/f {} \\;"
s deny "python inline con ruta fuera" "$R" "python3 -c \"open('$O/f','w')\""
s deny "heredoc no oculta el comando posterior" "$R" "$(printf 'cat <<EOF\nhola\nEOF\ntouch %s/f' "$O")"

# --- symlinks
s deny "escritura a través de symlink que sale del alcance" "$R" "touch $R/link/f"
s deny "rm a través de symlink que sale" "$R" "rm $R/link/z"
s deny "mv a través de symlink que sale" "$R" "mv $R/ok.sh $R/link/ok.sh"
w deny "Write a través de symlink que sale" "$R" "$R/link/f"
s pasa "escritura por symlink de fuera hacia dentro" "$R" "touch $O/mlink/a/f"

# --- envoltorios
s deny "sudo" "$R" "sudo touch $O/f"
s deny "sudo -u" "$R" "sudo -u plex touch $O/f"
s deny "nohup" "$R" "nohup touch $O/f"
s deny "nice -n 5" "$R" "nice -n 5 touch $O/f"
s deny "nice -5" "$R" "nice -5 touch $O/f"
s deny "env con asignación" "$R" "env FOO=1 touch $O/f"
s deny "env -u" "$R" "env -u FOO touch $O/f"
s deny "timeout" "$R" "timeout 10 touch $O/f"
s deny "timeout -s KILL" "$R" "timeout -s KILL 10 touch $O/f"
s deny "ionice" "$R" "ionice -c 2 -n 7 touch $O/f"
s deny "stdbuf" "$R" "stdbuf -o0 touch $O/f"
s deny "setsid" "$R" "setsid touch $O/f"
s deny "busybox" "$R" "busybox touch $O/f"
s deny "flock" "$R" "flock $T/lock touch $O/f"
s deny "command" "$R" "command touch $O/f"
s deny "time" "$R" "time touch $O/f"
s deny "wrappers encadenados" "$R" "sudo nice -n 5 timeout 10 ionice -c 3 touch $O/f"
s deny "ruta absoluta del binario" "$R" "/bin/touch $O/f"
s deny "if/then" "$R" "if true; then touch $O/f; fi"
s pasa "timeout con destino dentro" "$R" "timeout 10 touch $R/a/f"
s pasa "nice -n con destino dentro" "$R" "nice -n 5 mv $R/a/f $R/a/g"
s pasa "ionice con destino dentro" "$R" "ionice -c 3 rm $R/a/g"
s pasa "stdbuf con destino dentro" "$R" "stdbuf -oL cp $R/ok.sh $R/a/h"
s pasa "flock con destino dentro" "$R" "flock $T/lock touch $R/a/f"

# --- rsync
s deny "rsync hacia fuera" "$R" "rsync -a $R/a/ $O/"
s deny "rsync -av hacia fuera" "$R" "rsync -av $R/a/ $O/dest"
s deny "rsync --delete hacia fuera" "$R" "rsync -a --delete $R/a/ $O/"
s deny "rsync destino remoto" "$R" "rsync -a $R/a/ host:/backup/"
s deny "rsync -e ssh remoto" "$R" "rsync -a -e ssh $R/a/ user@host:/x"
s deny "rsync --remove-source-files desde fuera" "$R" "rsync -a --remove-source-files $O/z/ $R/a/"
s pasa "rsync dentro" "$R" "rsync -a $O/z/ $R/a/"
s pasa "rsync --exclude dentro" "$R" "rsync -a --exclude '*.nfo' $R/a/ $S/y/"
s pasa "rsync --delete dentro" "$R" "rsync -a --delete $R/a/ $S/y/"

# --- rename, unlink, shred
s deny "rename fuera" "$R" "rename s/a/b/ $O/z"
s deny "rename -n fuera" "$R" "rename -v s/a/b/ $O/bad.sh"
s pasa "rename dentro" "$R" "rename s/a/b/ $R/a/f"
s deny "unlink fuera" "$R" "unlink $O/bad.sh"
s pasa "unlink dentro" "$R" "unlink $R/a/f"
s deny "shred fuera" "$R" "shred -u $O/bad.sh"
s deny "shred -n fuera" "$R" "shred -n 3 -u $O/bad.sh"
s pasa "shred dentro" "$R" "shred -u $R/a/f"
s deny "rmdir fuera" "$R" "rmdir $O/z"

# --- chmod, chown, chgrp
s deny "chmod fuera" "$R" "chmod 644 $O/bad.sh"
s deny "chmod -R fuera" "$R" "chmod -R 755 $O"
s deny "chmod modo simbólico fuera" "$R" "chmod u+x $O/bad.sh"
s deny "chmod -x fuera" "$R" "chmod -x $O/bad.sh"
s deny "chmod --reference fuera" "$R" "chmod --reference=$R/ok.sh $O/bad.sh"
s pasa "chmod dentro" "$R" "chmod 644 $R/ok.sh"
s pasa "chmod -R dentro" "$R" "chmod -R 755 $R/a"
s pasa "chmod -x dentro" "$R" "chmod -x $R/ok.sh"
s deny "chown fuera" "$R" "chown plex:plex $O/bad.sh"
s deny "chown -R fuera" "$R" "chown -R plex $O"
s pasa "chown dentro" "$R" "chown plex:plex $R/ok.sh"
s deny "chgrp fuera" "$R" "chgrp plex $O/bad.sh"
s pasa "chgrp dentro" "$R" "chgrp plex $R/ok.sh"

# --- dd, curl, wget
s deny "dd of= fuera" "$R" "dd if=/dev/zero of=$O/f bs=1 count=1"
s pasa "dd of= dentro" "$R" "dd if=/dev/zero of=$R/a/f bs=1 count=1"
s pasa "dd sin of=" "$R" "dd if=$O/bad.sh bs=1 count=1"
s deny "curl -o fuera" "$R" "curl -o $O/f http://x/y"
s deny "curl --output fuera" "$R" "curl --output $O/f http://x/y"
s deny "curl --output= fuera" "$R" "curl --output=$O/f http://x/y"
s deny "curl -sSLo fuera" "$R" "curl -sSLo $O/f http://x/y"
s deny "curl -O con cwd fuera" "$O" "curl -O http://x/y"
s deny "curl --output-dir fuera" "$R" "curl --output-dir $O -O http://x/y"
s pasa "curl -o dentro" "$R" "curl -o $R/a/f http://x/y"
s pasa "curl a stdout" "$O" "curl -s http://x/y"
s pasa "curl -O con cwd dentro" "$R/a" "curl -O http://x/y"
s deny "wget -O fuera" "$R" "wget -O $O/f http://x/y"
s deny "wget --output-document fuera" "$R" "wget --output-document=$O/f http://x/y"
s deny "wget -P fuera" "$R" "wget -P $O http://x/y"
s deny "wget sin -O con cwd fuera" "$O" "wget http://x/y"
s deny "wget -qO fuera" "$R" "wget -qO $O/f http://x/y"
s pasa "wget -O dentro" "$R" "wget -O $R/a/f http://x/y"
s pasa "wget -O - a stdout" "$O" "wget -qO - http://x/y"
s pasa "wget con cwd dentro" "$R/a" "wget http://x/y"

# --- sh script / source / .
s deny "sh script fuera" "$R" "sh $O/bad.sh"
s deny "bash script fuera" "$R" "bash $O/bad.sh"
s deny "bash -x script fuera" "$R" "bash -x $O/bad.sh"
s deny "source fuera" "$R" "source $O/bad.sh"
s deny ". script fuera" "$R" ". $O/bad.sh"
s deny "script relativo fuera del alcance" "$O" "bash ./bad.sh"
s pasa "sh script dentro" "$R" "sh $R/ok.sh"
s pasa "source dentro" "$R" "source $R/ok.sh"
s pasa ". script dentro" "$R" ". $R/ok.sh"
s pasa "script relativo dentro" "$R" "bash ./ok.sh"

# --- scripts de skills del plugin (bash/sh/source/ejecución directa) fuera de scope.conf
# Se usa una copia del hook en un plugin ficticio para poder probar enlaces que escapan.
PL="$T/plug"
mkdir -p "$PL/hooks" "$PL/skills/plex/scripts" "$PL/skills/_lib"
cp "$SCOPE" "$PL/hooks/enforce-agent-scope.js"
printf '#!/bin/sh\ntrue\n' >"$PL/skills/plex/scripts/plex-api.sh"
printf 'true\n' >"$PL/skills/_lib/load-env.sh"
printf 'x\n' >"$PL/hooks/confirm-destructive.js"
printf '#!/bin/sh\ntrue\n' >"$PL/hooks/x.sh"
ln -s "$O/bad.sh" "$PL/skills/plex/scripts/evil.sh"
ln -s "$PL/hooks" "$PL/skills/plex/scripts/hk"
PS="$PL/hooks/enforce-agent-scope.js"
# p EXPECT NOMBRE CMD   (hook copiado, cwd en raíz de medios, sin CLAUDE_PLUGIN_ROOT en el entorno del hook)
p() { check "$PS" "$CONF" "$1" "scope-skill: $2" "$(json Bash "$R" plex-naming "$3")"; }
p pasa "bash script de skill absoluto" "bash $PL/skills/plex/scripts/plex-api.sh libraries"
p pasa "sh script de skill absoluto" "sh $PL/skills/plex/scripts/plex-api.sh libraries"
p pasa "source lib de skill" "source $PL/skills/_lib/load-env.sh"
p pasa "bash con \${CLAUDE_PLUGIN_ROOT} entre comillas" 'bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" libraries'
p pasa "bash con \${CLAUDE_PLUGIN_ROOT} sin comillas" 'bash ${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh libraries'
p pasa "bash con \$CLAUDE_PLUGIN_ROOT sin llaves" 'bash $CLAUDE_PLUGIN_ROOT/skills/plex/scripts/plex-api.sh libraries'
p pasa "bash con \$CLAUDE_PLUGIN_ROOT entre comillas" 'bash "$CLAUDE_PLUGIN_ROOT/skills/plex/scripts/plex-api.sh" libraries'
p pasa "ejecución directa de script de skill" "$PL/skills/plex/scripts/plex-api.sh libraries"
p pasa "ejecución directa con \${CLAUDE_PLUGIN_ROOT}" '"${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" libraries'
p deny "bash hooks/confirm-destructive.js" "bash $PL/hooks/confirm-destructive.js"
p deny "bash script de hooks/ con \${CLAUDE_PLUGIN_ROOT}" 'bash "${CLAUDE_PLUGIN_ROOT}/hooks/x.sh"'
p deny "bash /tmp/x.sh fuera" "bash $O/bad.sh"
p deny "bash \${OTRA_VAR}/x.sh" 'bash "${OTRA_VAR}/x.sh"'
p deny "bash \$HOME/x.sh" 'bash "$HOME/x.sh"'
p deny "skills/../hooks/x.sh" "bash $PL/skills/../hooks/x.sh"
p deny "\${CLAUDE_PLUGIN_ROOT}/skills/../hooks/x.sh" 'bash "${CLAUDE_PLUGIN_ROOT}/skills/../hooks/x.sh"'
p deny "symlink de skill que escapa fuera" "bash $PL/skills/plex/scripts/evil.sh"
p deny "symlink de skill a hooks/" "bash $PL/skills/plex/scripts/hk/x.sh"
p deny "\${CLAUDE_PLUGIN_ROOT} con otra expansión" 'bash "${CLAUDE_PLUGIN_ROOT}/skills/$X/scripts/plex-api.sh"'
# el entorno distinto: se prueba aparte porque check no pasa variables
N=$((N + 1))
out="$(printf '%s' "$(json Bash "$R" plex-naming 'bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh"')" | CLAUDE_PLUGIN_ROOT="$O" PLEX_CREW_CONFIG="$CONF" HOME="$T/home" node "$PS" 2>&1)"
if ! printf '%s' "$out" | grep -q '"permissionDecision":"deny"'; then FAIL=$((FAIL + 1)); printf 'FALLA [esperado deny] scope-skill: CLAUDE_PLUGIN_ROOT apunta a otro plugin\n'; fi
N=$((N + 1))
out="$(printf '%s' "$(json Bash "$R" plex-naming 'bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh"')" | CLAUDE_PLUGIN_ROOT="$PL" PLEX_CREW_CONFIG="$CONF" HOME="$T/home" node "$PS" 2>&1)"
if printf '%s' "$out" | grep -q '"permissionDecision":"deny"'; then FAIL=$((FAIL + 1)); printf 'FALLA [esperado pasa] scope-skill: CLAUDE_PLUGIN_ROOT coincide\n'; fi

# --- confirm-destructive no bloquea invocaciones de scripts de skills
c pasa "bash script de skill (plex-api.sh)" "$R" "bash $HERE/../skills/plex/scripts/plex-api.sh libraries"
c pasa "bash script de skill con \${CLAUDE_PLUGIN_ROOT}" "$R" 'bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" libraries'
c pasa "bash script de skill sin comillas" "$R" 'bash ${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh libraries'

# --- herramientas Edit/Write y rutas relativas con cwd
w pasa "Write dentro" "$T" "$R/a/f"
w deny "Write fuera" "$T" "$O/f"
w pasa "Write relativo dentro (cwd en raíz)" "$R" "a/f"
w deny "Write relativo fuera (cwd fuera)" "$O" "f"
w deny "Write relativo con .. de escape" "$R" "../other/f"
w pasa "Write relativo con .. que vuelve dentro" "$O" "../movies/a/f"
w deny "Write relativo desde cwd fuera aunque exista en raíz" "$T" "ok.sh"
check "$SCOPE" "$CONF" deny "scope: Edit fuera" "$(json Edit "$T" plex-naming "$O/f")"
check "$SCOPE" "$CONF" pasa "scope: Edit dentro" "$(json Edit "$T" plex-naming "$R/a/f")"
check "$SCOPE" "$CONF" deny "scope: NotebookEdit fuera" "$(TN=NotebookEdit CW="$T" AG=plex-naming VAL="$O/n.ipynb" node -e 'const e=process.env;process.stdout.write(JSON.stringify({tool_name:e.TN,cwd:e.CW,agent_type:e.AG,tool_input:{notebook_path:e.VAL}}))')"

# --- agent_type y herramientas ajenas
check "$SCOPE" "$CONF" pasa "scope: otro agent_type pasa" "$(json Bash "$R" arr-acquisition "touch $O/f")"
check "$SCOPE" "$CONF" pasa "scope: sin agent_type pasa" "$(json Bash "$R" "" "touch $O/f")"
check "$SCOPE" "$CONF" deny "scope: agent_type con prefijo de plugin" "$(json Bash "$R" plex-crew:plex-naming "touch $O/f")"
check "$SCOPE" "$CONF" pasa "scope: otro agent_type con prefijo pasa" "$(json Bash "$R" plex-crew:arr-acquisition "touch $O/f")"
check "$SCOPE" "$CONF" pasa "scope: herramienta Read ajena" "$(TN=Read CW="$T" AG=plex-naming VAL="$O/f" node -e 'const e=process.env;process.stdout.write(JSON.stringify({tool_name:e.TN,cwd:e.CW,agent_type:e.AG,tool_input:{file_path:e.VAL}}))')"

# --- sin scope.conf: fallo cerrado
check "$SCOPE" "$MISSING" deny "scope: sin scope.conf, Bash" "$(json Bash "$R" plex-naming "touch $R/a/f")" "scope.conf"
check "$SCOPE" "$MISSING" deny "scope: sin scope.conf, Write" "$(json Write "$R" plex-naming "$R/a/f")" "scope.conf"
check "$SCOPE" "$EMPTY" deny "scope: scope.conf vacío, Bash" "$(json Bash "$R" plex-naming "ls")" "scope.conf"
check "$SCOPE" "$MISSING" pasa "scope: sin scope.conf, otro agent_type pasa" "$(json Bash "$R" arr-acquisition "touch $R/a/f")"
check "$SCOPE" "$MISSING" pasa "scope: sin scope.conf, sin agent_type pasa" "$(json Bash "$R" "" "touch $R/a/f")"

# =====================================================================
PASSED=$((N - FAIL))
printf '\n%d/%d casos correctos' "$PASSED" "$N"
if [ "$FAIL" -ne 0 ]; then
  printf ' (%d fallan)\n' "$FAIL"
  exit 1
fi
printf '\n'
