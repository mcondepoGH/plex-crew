// PreToolUse (Bash|Edit|Write|NotebookEdit): en un montaje de zurg solo se renombra lo existente;
// nunca se crean carpetas ni ficheros. Aplica a TODOS los agentes y a la sesión principal.
// Sin override: PLEX_CREW_CONFIRMED=1 no lo salta. Única excepción: rutas bajo `__magic__`.
//
// Qué es un "montaje de zurg" (se suman ambas fuentes):
//   1. Autodetección con /proc/self/mountinfo (o el fichero de $PLEX_CREW_MOUNTINFO, para pruebas):
//      mount FUSE (fstype `fuse*`) cuya fuente u opciones mencionan rclone o zurg.
//   2. Lista configurable de rutas: $PLEX_CREW_ZURG_MOUNTS (separadas por `:`) y
//      ~/.claude/plex-crew/zurg-mounts.conf (una ruta por línea, # comentarios). Si no hay ni
//      variable ni entradas en el fichero, valor por defecto: /workspace/mnt/zurg-mnt.
//      Con la variable definida pero vacía no hay lista (solo autodetección).
//
// Bloquea (destino en zurg): mkdir, touch, tee, truncate, cp, install, ln, rsync, sed -i, dd of=,
// curl/wget -o/-O, redirecciones > y >>, mv desde fuera del montaje, e inline de python/node/perl/ruby
// con ruta de zurg y verbos de escritura. Write/Edit/NotebookEdit sobre rutas en zurg.
// Permite: lecturas y mv/rename dentro del mismo montaje. Los borrados los cubre confirm-destructive.js.
// Como el resto de hooks, es una red de seguridad contra errores, no un sandbox.
const fs = require('fs');
const os = require('os');
const path = require('path');

const { parse, skipWrappers, affectedPaths, downloadTargets, INTERPRETERS } = require('./shell-parse');

const HOME = os.homedir();
const DEFAULT_MOUNTS = ['/workspace/mnt/zurg-mnt'];

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

// ---------- Montajes de zurg ----------

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
  if (env !== undefined) list.push(...env.split(':').map(s => s.trim()).filter(Boolean));
  try {
    for (const line of fs.readFileSync(path.join(HOME, '.claude', 'plex-crew', 'zurg-mounts.conf'), 'utf8').split(/\r?\n/)) {
      const l = line.trim();
      if (l && !l.startsWith('#')) list.push(l);
    }
  } catch {
    // sin fichero
  }
  if (env === undefined && list.length === 0) list.push(...DEFAULT_MOUNTS);
  return list.map(p => real(expandHome(p)));
}

const DETECTED = new Set(detectedMounts().map(real));
const ROOTS = [...new Set([...configuredMounts(), ...DETECTED])];
// Texto que delata una ruta hacia zurg aunque no se pueda resolver (variables sin expandir).
const HINTS = ROOTS.map(r => r.toLowerCase());
const hinted = t => /zurg/i.test(t) || HINTS.some(h => t.toLowerCase().includes(h));

// Devuelve { root, magic } si la ruta (aunque no exista) cae en un montaje zurg; si no, null.
function zurgInfo(p) {
  const rp = real(p);
  let root = null;
  for (const r of ROOTS) if (inside(rp, r) && (!root || r.length > root.length)) root = r;
  if (!root) return null;
  const rel = path.relative(root, rp).split(path.sep).filter(Boolean);
  const idx = rel.indexOf('__magic__');
  let magic = idx === 0;
  if (idx === 1 && !DETECTED.has(root)) {
    try {
      magic = fs.statSync(path.join(root, rel[0])).isDirectory(); // lista: <montaje>/zurg/__magic__ con zurg ya existente (solo en rutas de la lista)
    } catch {
      magic = false;
    }
  }
  return { root, magic, rp };
}

// ---------- Análisis ----------

const CREATORS = /^(mkdir|touch|tee|truncate|install|ln|cp|mv|rsync)$/;
const WRITE_WORD = /(^|[\s;&|(])(mkdir|touch|tee|truncate|install|ln|cp|rsync|dd|sed|mv)(\s|$)/;
const PY_WRITE = /write|mkdir|makedirs|touch|copy|move|symlink|truncate|\.save|dump|open\([^)]*['"][wax]|createWriteStream|appendFile/i;

function analyze(cmd, cwd0, depth = 0) {
  const problems = [];
  if (depth > 4) return problems;
  const { segs, subs } = parse(cmd);
  let cwd = cwd0;
  let cwdSus = false; // cwd desconocido pero con pinta de zurg

  // ¿Es zurg esta palabra? Marca el problema si lo es y no es la excepción __magic__.
  const test = (w, what) => {
    if (w.exp) {
      if (hinted(w.t)) problems.push(`${what}: ruta con expansión sin resolver que apunta a zurg (${w.t}), no se puede comprobar`);
      return null;
    }
    const p = expandHome(w.t);
    if (!path.isAbsolute(p) && cwdSus) {
      problems.push(`${what}: ruta relativa con directorio de trabajo desconocido dentro de zurg (${w.t})`);
      return null;
    }
    const abs = path.resolve(cwd, p);
    const z = zurgInfo(abs);
    if (z && !z.magic) problems.push(`${what}: ${abs}`);
    return z;
  };
  const testCwd = what => {
    const z = zurgInfo(cwd);
    if (z && !z.magic) problems.push(`${what}: ${cwd} (directorio de trabajo)`);
  };

  for (const seg of segs) {
    for (const r of seg.redirs) {
      if (!r.exp && ['/dev/null', '/dev/stdout', '/dev/stderr'].includes(r.t)) continue;
      test(r, 'redirección de salida');
    }
    const words = skipWrappers(seg.words);
    if (!words.length) continue;
    const name = path.basename(words[0].t);
    const args = words.slice(1);

    if (name === 'cd') {
      const t = args.find(a => !a.t.startsWith('-'));
      if (!t) cwd = HOME;
      else if (t.exp || t.t === '-') {
        if (hinted(t.t)) cwdSus = true;
      }
      else cwd = path.resolve(cwd, expandHome(t.t));
      continue;
    }
    if (/^(bash|sh|zsh|dash|ksh)$/.test(name)) {
      const i = args.findIndex(a => /^-[a-zA-Z]*c[a-zA-Z]*$/.test(a.t));
      if (i !== -1 && args[i + 1]) problems.push(...analyze(args[i + 1].t, cwd, depth + 1));
      continue;
    }
    if (name === 'eval') {
      problems.push(...analyze(args.map(a => a.t).join(' '), cwd, depth + 1));
      continue;
    }
    if (name === 'xargs' || (name === 'find' && args.some(a => /^-(exec|execdir|ok|okdir)$/.test(a.t)))) {
      const txt = words.map(w => w.t).join(' ');
      if (WRITE_WORD.test(txt) && (hinted(txt) || zurgInfo(cwd))) {
        problems.push(`${name} con un verbo de escritura en un contexto de zurg, no se puede comprobar: ${txt}`);
      }
      continue;
    }
    if (INTERPRETERS.test(name)) {
      for (let i = 0; i < args.length; i++) {
        if (/^(-c|-e|-p|-E|--eval|--print)$/.test(args[i].t) || /^-[a-zA-Z]*[ce]$/.test(args[i].t)) {
          const code = args[++i];
          if (!code) break;
          if (PY_WRITE.test(code.t) && (hinted(code.t) || ROOTS.some(r => code.t.includes(r)))) {
            problems.push('código inline que escribe y menciona una ruta de zurg, no se puede comprobar');
          }
        }
      }
      continue;
    }
    if (name === 'dd' || name === 'curl' || name === 'wget') {
      const d = downloadTargets(name, args);
      d.res.forEach(w => test(w, `${name} escribe`));
      if (d.cwdWord) testCwd(`${name} escribe en el directorio de trabajo`);
      continue;
    }
    if (name === 'sed' || CREATORS.test(name)) {
      const t = affectedPaths(name, args);
      if (!t) continue; // sed sin -i
      if (name === 'mv' || name === 'cp' || name === 'install' || name === 'ln') {
        const hasT = args.some(a => a.t === '-t' || a.t === '--target-directory' || a.t.startsWith('--target-directory='));
        let dest;
        let srcs;
        if (hasT) {
          dest = t[0];
          srcs = t.slice(1);
        } else if (t.length === 0) {
          continue;
        } else if (t.length === 1 && name === 'ln') {
          testCwd('ln crea el enlace en el directorio de trabajo');
          continue;
        } else {
          dest = t[t.length - 1];
          srcs = t.slice(0, -1);
        }
        if (name === 'mv') {
          const zd = dest.exp ? null : zurgInfo(path.resolve(cwd, expandHome(dest.t)));
          if (dest.exp && hinted(dest.t)) problems.push(`mv: destino con expansión sin resolver que apunta a zurg (${dest.t})`);
          if (zd && !zd.magic) {
            for (const s of srcs) {
              const zs = s.exp ? null : zurgInfo(path.resolve(cwd, expandHome(s.t)));
              if (!zs || zs.root !== zd.root) {
                problems.push(`mv desde fuera del montaje (${s.t}) hacia ${zd.rp}`);
              }
            }
          }
        } else {
          test(dest, name);
        }
        continue;
      }
      t.forEach(w => test(w, name));
    }
  }

  for (const s of subs) problems.push(...analyze(s, cwd, depth + 1));
  return problems;
}

// ---------- Entrada ----------

function deny(reason) {
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PreToolUse',
        permissionDecision: 'deny',
        permissionDecisionReason: reason,
      },
    })
  );
  process.exit(0);
}

const MSG_TAIL =
  'Regla del stack: en un montaje de zurg solo se renombra lo que ya existe; nunca se crean carpetas ni ficheros, ' +
  'y no hay confirmación que lo permita (PLEX_CREW_CONFIRMED=1 no vale aquí). ' +
  'Única excepción: la carpeta `__magic__` del montaje. Si hace falta crear algo, hazlo fuera de zurg o en `__magic__`; ' +
  'para renombrar usa mv/rename dentro del mismo montaje o las tools zurg_*.';

let raw = '';
process.stdin.on('data', c => (raw += c));
process.stdin.on('end', () => {
  let payload;
  try {
    payload = JSON.parse(raw);
  } catch {
    process.stderr.write('plex-crew hook: entrada JSON no válida; bloqueado por seguridad\n');
    process.exit(2);
  }
  const tool = payload.tool_name || '';
  const input = payload.tool_input || {};
  const cwd = payload.cwd || process.cwd();

  if (tool === 'Bash') {
    const cmd = input.command || '';
    if (!cmd) process.exit(0);
    const problems = [...new Set(analyze(cmd, cwd))];
    if (problems.length === 0) process.exit(0);
    deny(`Comando Bash denegado: escribe en un montaje de zurg (${problems.join('; ')}). ${MSG_TAIL}`);
  }
  if (['Edit', 'Write', 'NotebookEdit'].includes(tool)) {
    const target = input.file_path || input.notebook_path || '';
    if (!target) process.exit(0);
    const abs = path.resolve(cwd, expandHome(target));
    const z = zurgInfo(abs);
    if (z && !z.magic) deny(`${tool} denegado: ${abs} está en un montaje de zurg (${z.root}). ${MSG_TAIL}`);
  }
  process.exit(0);
});
