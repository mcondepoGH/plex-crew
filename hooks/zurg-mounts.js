// Detección de montajes de zurg, compartida por zurg-mount.js, enforce-agent-scope.js y
// confirm-destructive.js. Qué es un "montaje de zurg" (se suman ambas fuentes):
//   1. Autodetección con /proc/self/mountinfo (o el fichero de $PLEX_CREW_MOUNTINFO, para pruebas):
//      mount FUSE (fstype `fuse*`) cuya fuente u opciones mencionan rclone o zurg.
//   2. Lista configurable de rutas: $PLEX_CREW_ZURG_MOUNTS (separadas por `:`) y
//      ~/.claude/plex-crew/zurg-mounts.conf (una ruta por línea, # comentarios). Sin valor por
//      defecto: sin lista y sin montaje FUSE detectado no se protege ninguna ruta.
//
// Además expone expandScopeLine(): resuelve el marcador `@zurg` de scope.conf.
const fs = require('fs');
const os = require('os');
const path = require('path');

const HOME = os.homedir();

const expandHome = p => (p === '~' ? HOME : p.startsWith('~/') ? path.join(HOME, p.slice(2)) : p);

// Resuelve symlinks y `..` del tramo existente más profundo; el resto se añade tal cual.
function real(p) {
  const rest = [];
  let cur = path.resolve(p);
  while (!fs.existsSync(cur)) {
    const parent = path.dirname(cur);
    if (parent === cur) return path.resolve(p);
    rest.unshift(path.basename(cur));
    cur = parent;
  }
  try {
    return path.join(fs.realpathSync(cur), ...rest);
  } catch {
    return path.resolve(p);
  }
}

const inside = (p, root) => p === root || p.startsWith(root === '/' ? '/' : root + '/');

const unescapeMi = s => s.replace(/\\([0-7]{3})/g, (_m, o) => String.fromCharCode(parseInt(o, 8)));

function detectedMounts() {
  const file = process.env.PLEX_CREW_MOUNTINFO || '/proc/self/mountinfo';
  const roots = [];
  let txt = '';
  try {
    txt = fs.readFileSync(file, 'utf8');
  } catch {
    return roots; // sin mountinfo: solo la lista configurable
  }
  for (const line of txt.split('\n')) {
    const i = line.indexOf(' - ');
    if (i === -1) continue;
    const pre = line.slice(0, i).split(' ');
    const post = line.slice(i + 3).split(' ');
    if (pre.length < 5 || post.length < 2) continue;
    const fstype = post[0];
    if (!/^fuse/i.test(fstype)) continue;
    if (!/rclone|zurg/i.test(`${fstype} ${post.slice(1).join(' ')}`)) continue;
    roots.push(path.resolve(unescapeMi(pre[4])));
  }
  return roots;
}

function configuredMounts() {
  const list = [];
  const env = process.env.PLEX_CREW_ZURG_MOUNTS;
  if (env) list.push(...env.split(':').map(s => s.trim()).filter(Boolean));
  try {
    for (const line of fs.readFileSync(path.join(HOME, '.claude', 'plex-crew', 'zurg-mounts.conf'), 'utf8').split(/\r?\n/)) {
      const l = line.trim();
      if (l && !l.startsWith('#')) list.push(l);
    }
  } catch {
    // sin fichero
  }
  return list.map(p => real(expandHome(p)));
}

const DETECTED = new Set(detectedMounts().map(real));
const ROOTS = [...new Set([...configuredMounts(), ...DETECTED])];

// Marcador `@zurg` de scope.conf: `@zurg` o `@zurg/<subruta>` como PRIMER componente.
// Devuelve la lista de rutas a las que se expande la línea, o null si la línea no es del marcador
// (se trata como ruta normal). Una línea del marcador mal formada o sin montaje válido devuelve []
// (se ignora; fallo cerrado). Cada expansión <montaje>/<subruta> solo cuenta si ya existe como
// directorio: si la lista apunta a /ruta/a/montaje y la carpeta real es /ruta/a/montaje/zurg/movies,
// `@zurg/movies` daría /ruta/a/montaje/movies, que no existe, y se descarta. Los montajes anidados se expanden tal cual los detecta la lógica de montajes.
function expandScopeLine(line) {
  const m = /^@zurg(?:\/(.*))?$/.exec(line);
  if (!m) return null;
  const sub = (m[1] || '').split('/').filter(Boolean);
  // Solo nombres planos: sin ., .., ~, variables, globs ni espacios raros.
  if (sub.some(s => !/^[A-Za-z0-9_][A-Za-z0-9_.@+-]*$/.test(s) || s === '..')) return [];
  const out = [];
  for (const root of ROOTS) {
    const p = real(path.join(root, ...sub));
    if (!inside(p, root)) continue; // un enlace que escapa del montaje no cuenta
    try {
      if (!fs.statSync(p).isDirectory()) continue;
    } catch {
      continue;
    }
    if (!out.includes(p)) out.push(p);
  }
  return out;
}

module.exports = { HOME, expandHome, real, inside, DETECTED, ROOTS, expandScopeLine };
