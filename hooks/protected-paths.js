// PreToolUse (Bash|Read|Glob|Grep|Edit|Write|NotebookEdit): carpetas de sistema del NAS
// (@Recycle, @Recently-Snapshot, .@__thumb...) que el stack no debe tocar NI LEER.
// Aplica a TODOS los agentes y a la sesión principal (no mira agent_type).
// Sin override: PLEX_CREW_CONFIRMED=1 no lo salta.
//
// Una ruta está protegida si alguno de sus componentes (separados por `/`) es un nombre protegido
// (sin distinguir mayúsculas) o empieza por `.@`. Lista por defecto abajo; se amplía con
// $PLEX_CREW_PROTECTED_NAMES (separados por `:`) y ~/.claude/plex-crew/protected-names.conf
// (un nombre por línea, # comentarios). Ver hooks/README.md.
//
// Bash: cada palabra del comando (tras quitar comillas) cuenta si, mirada como ruta, tiene un
// componente protegido; el texto suelto con espacios (echo "ver @Recycle en el README") no cuenta.
// Se resuelven `..` y enlaces simbólicos (ancestro existente) y se sigue `cd`.
// Como el resto de hooks, es una red de seguridad contra errores, no un sandbox.
const fs = require('fs');
const os = require('os');
const path = require('path');

const { parse } = require('./shell-parse');

const HOME = os.homedir();
const DEFAULT_NAMES = ['@Recycle', '@Recently-Snapshot', '@Transcode', '@Download', '@eaDir', '#recycle', '#snapshot'];

function loadNames() {
  const names = new Set(DEFAULT_NAMES.map(n => n.toLowerCase()));
  const add = n => {
    n = (n || '').trim();
    if (n && !n.includes('/')) names.add(n.toLowerCase());
  };
  (process.env.PLEX_CREW_PROTECTED_NAMES || '').split(':').forEach(add);
  try {
    const txt = fs.readFileSync(path.join(HOME, '.claude', 'plex-crew', 'protected-names.conf'), 'utf8');
    for (const line of txt.split('\n')) {
      const l = line.trim();
      if (l && !l.startsWith('#')) add(l);
    }
  } catch {
    // sin fichero: solo defecto + variable
  }
  return names;
}
const NAMES = loadNames();

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

// Devuelve el componente protegido de una ruta (texto), o null.
function protectedComponent(p) {
  for (const c of p.split('/')) {
    if (!c) continue;
    if (c.startsWith('.@') || NAMES.has(c.toLowerCase())) return c;
  }
  return null;
}

// ¿Esta ruta (relativa a cwd) está protegida, en bruto o ya resuelta? Devuelve la ruta a mostrar o null.
function checkPath(p, cwd) {
  if (!p) return null;
  const raw = expandHome(p);
  if (protectedComponent(raw)) return p;
  let abs;
  try {
    abs = real(path.resolve(cwd, raw));
  } catch {
    return null;
  }
  return protectedComponent(abs) ? (abs === path.resolve(cwd, raw) ? p : `${p} (resuelve a ${abs})`) : null;
}

// ---------- Bash ----------

function analyze(cmd, cwd0, depth = 0) {
  const hits = [];
  if (depth > 4) return hits;
  const { segs, subs } = parse(cmd);
  let cwd = cwd0;
  const test = t => {
    const h = checkPath(t, cwd);
    if (h) hits.push(h);
    // --opt=valor, of=ruta, host:ruta
    const m = t.match(/^(?:--?[\w-]+|[A-Za-z_]+)=(.+)$/);
    if (m) {
      const h2 = checkPath(m[1], cwd);
      if (h2) hits.push(h2);
    }
  };
  for (const seg of segs) {
    for (const r of seg.redirs) test(r.t);
    const words = seg.words;
    if (!words.length) continue;
    const name = path.basename(words[0].t);
    // texto libre de git: mensajes de commit/tag, no son rutas
    const skipVal = new Set();
    if (name === 'git') {
      words.forEach((w, i) => {
        if (/^-[a-zA-Z]*m$|^--message$/.test(w.t)) skipVal.add(i + 1);
        if (/^--message=/.test(w.t)) skipVal.add(i);
      });
    }
    if (name === 'cd') {
      const t = words.slice(1).find(a => !a.t.startsWith('-'));
      if (!t) cwd = HOME;
      else if (!t.exp && t.t !== '-') {
        test(t.t);
        cwd = path.resolve(cwd, expandHome(t.t));
      }
      continue;
    }
    // recursión: bash -c "...", eval ...
    const shellIdx = words.findIndex(w => /^(bash|sh|zsh|dash|ksh)$/.test(path.basename(w.t)));
    if (shellIdx !== -1) {
      const i = words.findIndex((a, k) => k > shellIdx && /^-[a-zA-Z]*c[a-zA-Z]*$/.test(a.t));
      if (i !== -1 && words[i + 1]) hits.push(...analyze(words[i + 1].t, cwd, depth + 1));
    }
    const evalIdx = words.findIndex(w => w.t === 'eval');
    if (evalIdx !== -1) hits.push(...analyze(words.slice(evalIdx + 1).map(a => a.t).join(' '), cwd, depth + 1));
    words.forEach((w, i) => {
      if (!skipVal.has(i)) test(w.t);
    });
  }
  // El parser descarta las redirecciones de entrada (`< ruta`): se revisan aparte, sobre el texto.
  for (const m of cmd.matchAll(/(?:^|[^<\d])<\s*(?!<)(?:"([^"]*)"|'([^']*)'|([^\s;&|()<>]+))/g)) {
    const h = checkPath(m[1] || m[2] || m[3], cwd0);
    if (h) hits.push(h);
  }
  for (const s of subs) hits.push(...analyze(s, cwd, depth + 1));
  return hits;
}

// ---------- Entrada ----------

function deny(what, shown) {
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PreToolUse',
        permissionDecision: 'deny',
        permissionDecisionReason:
          `${what} denegado: la ruta ${shown} es una carpeta de sistema del NAS (QNAP u otro: papelera, snapshots, miniaturas...) ` +
          'que el stack no debe tocar ni leer. No hay confirmación que lo permita (PLEX_CREW_CONFIRMED=1 no vale aquí). ' +
          'Trabaja con las carpetas de medios y no incluyas estas en el comando. ' +
          'Para ver o ampliar la lista de nombres protegidos, consulta la sección protected-paths.js de hooks/README.md.',
      },
    })
  );
  process.exit(0);
}

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
  const str = v => (typeof v === 'string' ? v : '');

  if (tool === 'Bash') {
    const cmd = str(input.command);
    if (!cmd) process.exit(0);
    const cw = protectedComponent(real(cwd)) ? cwd : null;
    const hits = [...new Set(analyze(cmd, cwd))];
    if (hits.length) deny('Comando Bash', hits[0]);
    if (cw) deny('Comando Bash', `${cw} (directorio de trabajo)`);
    process.exit(0);
  }

  let cands = [];
  if (tool === 'Read' || tool === 'Edit' || tool === 'Write') cands = [input.file_path];
  else if (tool === 'NotebookEdit') cands = [input.notebook_path, input.file_path];
  else if (tool === 'Glob') cands = [input.path, input.pattern];
  else if (tool === 'Grep') cands = [input.path, input.glob];
  for (const c of cands.map(str)) {
    const h = checkPath(c, cwd);
    if (h) deny(`${tool}`, h);
  }
  process.exit(0);
});
