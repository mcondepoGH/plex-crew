// PreToolUse (Bash): BLOQUEA (deny) los comandos destructivos reales, salvo que
// lleven el marcador `PLEX_CREW_CONFIRMED=1` como asignación de entorno al inicio
// de un comando (p. ej. `PLEX_CREW_CONFIRMED=1 rm -rf /ruta`).
// El marcador solo se pone tras la doble confirmación del usuario (dos mensajes
// distintos, incluso en modo automático). Sin marcador no hay aviso en la UI:
// el comando se deniega y el subagente debe devolver la propuesta al orquestador.
// Lo que no casa con un patrón destructivo pasa sin salida (exit 0).
// Alcance: solo se vigila el ecosistema del plugin.
//  - git: solo si el repo afectado (cwd o `git -C`) es este repositorio.
//  - borrado de ficheros: solo si el comando o el cwd tocan rutas de scope.conf
//    (carpetas de medios de Plex) o este repositorio.
//  - docker, SQL, curl DELETE y subcomandos destructivos de las skills: siempre.
const fs = require('fs');
const os = require('os');
const path = require('path');

const PLUGIN_ROOT = path.resolve(__dirname, '..');

const norm = p => {
  let r = p;
  try { r = fs.realpathSync(p); } catch {}
  return path.resolve(r).replace(/\\/g, '/').replace(/\/+$/, '').toLowerCase();
};
const inside = (p, root) => p === root || p.startsWith(root + '/');

function mediaRoots() {
  const file = process.env.PLEX_CREW_CONFIG || path.join(os.homedir(), '.claude', 'plex-crew', 'scope.conf');
  let lines = [];
  try { lines = fs.readFileSync(file, 'utf8').split(/\r?\n/); } catch {}
  return lines
    .map(l => l.trim())
    .filter(l => l && !l.startsWith('#'))
    .map(l => norm(l.startsWith('~') ? path.join(os.homedir(), l.slice(1)) : l));
}

// El comando o el cwd afectan a alguna de las raíces.
function touches(cmd, cwd, roots) {
  const text = cmd.replace(/\\/g, '/').toLowerCase();
  const c = cwd ? norm(cwd) : '';
  return roots.some(r => inside(c, r) || text.includes(r));
}

function gitTargetsRepo(cmd, cwd) {
  const m = cmd.match(/\bgit\s+(?:-C\s+("[^"]+"|'[^']+'|\S+)\s+)?/);
  const dir = m && m[1] ? m[1].replace(/^["']|["']$/g, '') : cwd;
  if (!dir) return false;
  const base = cwd || process.cwd();
  return inside(norm(path.resolve(base, dir)), norm(PLUGIN_ROOT));
}

const FILE_OPS = [
  /\brm\s+\S/,
  /\bunlink\b/,
  /\bshred\b/,
  /\btruncate\b/,
  /\bmkfs\b/,
  /\bdd\s+.*\bof=/,
  /\bfind\b.*(-delete|-exec\s+rm)/,
];

const GIT_OPS = [
  /\bgit\s+(?:-C\s+("[^"]+"|'[^']+'|\S+)\s+)?(reset\s+--hard|clean\s+-[a-z]*f|push\s+.*--force|push\s+.*-f\b|checkout\s+--(\s|$)|restore\b)/,
];

const DESTRUCTIVE = [
  /\bdocker(-compose)?\s+(rm|rmi|down|kill|system\s+prune|volume\s+rm)\b/,
  /\bdocker\s+compose\b[^;&|]*\b(rm|rmi|down|kill)\b/,
  /\bDELETE\s+FROM\b|\bDROP\s+(TABLE|DATABASE)\b/i,
  /\bcurl\b.*(-X\s*|--request[\s=]+)["']?DELETE\b/i,
  // Skills de servicios: subcomandos destructivos (con bash, ruta relativa o absoluta).
  /\b(radarr|sonarr)\.sh["']?\s+["']?remove\b/,
  /\bprowlarr-api\.sh["']?\s+["']?delete\b/,
  // Funciones destructivas de las librerías de las skills (_lib/arr-api.sh).
  /\barr_delete\b/,
];

// Marcador como asignación de entorno al inicio de un comando (inicio de línea
// o tras ; & |), admitiendo otras asignaciones VAR=valor previas.
const CONFIRMED = /(^|[;&|])\s*([A-Za-z_]\w*=\S*\s+)*PLEX_CREW_CONFIRMED=1\s/;

let raw = '';
process.stdin.on('data', c => (raw += c));
process.stdin.on('end', () => {
  let cmd = '';
  let cwd = '';
  try {
    const payload = JSON.parse(raw);
    cmd = (payload.tool_input && payload.tool_input.command) || '';
    cwd = payload.cwd || '';
  } catch {
    process.exit(0);
  }
  const hit =
    DESTRUCTIVE.some(re => re.test(cmd)) ||
    (GIT_OPS.some(re => re.test(cmd)) && gitTargetsRepo(cmd, cwd)) ||
    (FILE_OPS.some(re => re.test(cmd)) && touches(cmd, cwd, [...mediaRoots(), norm(PLUGIN_ROOT)]));
  if (!hit) process.exit(0);
  if (CONFIRMED.test(cmd)) process.exit(0);
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PreToolUse',
        permissionDecision: 'deny',
        permissionDecisionReason:
          'Comando destructivo bloqueado. Regla del stack: doble confirmación del usuario en dos mensajes distintos antes de ejecutarlo. ' +
          'Si el usuario ya ha confirmado dos veces, en dos mensajes distintos y de forma explícita, reintenta el mismo comando anteponiendo `PLEX_CREW_CONFIRMED=1 ` ' +
          '(por ejemplo `PLEX_CREW_CONFIRMED=1 <comando>`). ' +
          'No pongas ese marcador sin una doble confirmación real: ni por iniciativa propia ni tras una sola respuesta del usuario. ' +
          'Si todavía no hay confirmación, NO ejecutes el comando: devuelve al orquestador la propuesta (qué se borra o modifica, con las rutas exactas) para que pida las dos confirmaciones al usuario.',
      },
    })
  );
  process.exit(0);
});
