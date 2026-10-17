// PreToolUse (Edit|Write|NotebookEdit|Bash|mcp__zurg__*): limita dónde puede escribir el agente plex-naming.
// Se registra en hooks/hooks.json (plugin) y salta en todas las llamadas; solo actúa si el
// input trae agent_type `plex-naming` o `<plugin>:plex-naming`. Sin agent_type no decide,
// salvo que PLEX_CREW_ENFORCE_ALL=1 (pruebas).
//
// Rutas permitidas, en este orden de lectura:
//   1. Fichero indicado en $PLEX_CREW_CONFIG, o si no existe la variable,
//      ~/.claude/plex-crew/scope.conf (una ruta absoluta por línea; se ignoran
//      líneas vacías y comentarios con #; se expande ~; `@zurg` o `@zurg/<subruta>` se
//      sustituye por cada montaje de zurg detectado, ver zurg-mounts.js).
//   2. Argumentos de línea de comandos opcionales: se añaden como rutas extra.
// Si no hay ninguna ruta, se deniega todo con instrucciones para configurarlo.
//
// Para Bash se analiza de forma conservadora el comando: se trocea por ; && || | & y
// saltos de línea, se buscan verbos de escritura (mv, cp, rm, rmdir, mkdir, touch, ln,
// tee, truncate, install, sed -i, rsync, rename, unlink, shred, chmod, chown, chgrp, dd of=,
// curl/wget -o/-O y redirecciones > / >>; sh/source/. solo con scripts dentro del alcance) y se comprueba que todas las
// rutas afectadas queden dentro del alcance. Ante la duda se deniega.
// No es un sandbox: es una red de seguridad contra errores, no contra un adversario.
const fs = require('fs');
const os = require('os');
const path = require('path');

const zurg = require('./zurg-tools');
const { expandScopeLine } = require('./zurg-mounts');

const HOME = os.homedir();

function expandHome(p) {
  if (p === '~') return HOME;
  if (p.startsWith('~/')) return path.join(HOME, p.slice(2));
  return p;
}

// Resuelve symlinks del tramo existente más profundo para evitar escapes por enlaces.
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

function loadAllowed() {
  const file = process.env.PLEX_CREW_CONFIG || path.join(HOME, '.claude', 'plex-crew', 'scope.conf');
  const list = [];
  try {
    for (const line of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
      const l = line.trim();
      if (!l || l.startsWith('#')) continue;
      const ex = expandScopeLine(l); // marcador @zurg[/subruta]; null si es una ruta normal
      if (ex) list.push(...ex);
      else if (ex === null) list.push(l);
    }
  } catch {
    // fichero ausente o ilegible: se considera vacío
  }
  for (const a of process.argv.slice(2)) list.push(a);
  return list.map(p => real(expandHome(p)));
}

const ALLOWED = loadAllowed();

// Raíz del plugin (este fichero vive en <raíz>/hooks). Los scripts de las skills
// (<raíz>/skills/*/scripts/*.sh y skills/_lib/*.sh) pueden ejecutarse con bash/sh/source.
const PLUGIN_ROOT = real(path.resolve(__dirname, '..'));
const ENV_ROOT = process.env.CLAUDE_PLUGIN_ROOT;
const ENV_ROOT_OK = !ENV_ROOT || real(ENV_ROOT) === PLUGIN_ROOT;

// Devuelve la ruta absoluta del script si es un script de skill del plugin; si no, null.
// Expande ${CLAUDE_PLUGIN_ROOT} y $CLAUDE_PLUGIN_ROOT al inicio; cualquier otra expansión se rechaza.
function skillScript(w, cwd, cwdKnown) {
  let t = w.t;
  if (w.exp) {
    const m = /^(?:\$\{CLAUDE_PLUGIN_ROOT\}|\$CLAUDE_PLUGIN_ROOT)(\/.*)$/.exec(t);
    if (!m || !ENV_ROOT_OK || m[1].includes('$') || m[1].includes('`')) return null;
    t = PLUGIN_ROOT + m[1];
  } else {
    t = expandHome(t);
    if (!path.isAbsolute(t) && !cwdKnown) return null;
  }
  const r = real(path.resolve(cwd, t));
  const rel = path.relative(path.join(PLUGIN_ROOT, 'skills'), r);
  if (rel.startsWith('..') || path.isAbsolute(rel)) return null;
  return /^([^/]+\/scripts|_lib)\/.+\.sh$/.test(rel.split(path.sep).join('/')) ? r : null;
}

function out(reason) {
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

const listaPermitidas = () => ALLOWED.join(', ');

function inScope(p) {
  const r = real(p);
  return ALLOWED.some(a => r === a || r.startsWith(a + path.sep));
}

const { parse, skipWrappers, affectedPaths, downloadTargets, WRITE_VERBS, INTERPRETERS } = require('./shell-parse');


function analyze(cmd, cwd0, depth = 0) {
  const problems = [];
  if (depth > 4) {
    problems.push('comando demasiado anidado');
    return problems;
  }
  const { segs, subs } = parse(cmd);
  let cwd = cwd0;
  let cwdKnown = true;

  const resolve = w => {
    if (w.exp) return { err: `ruta con expansión sin resolver (${w.t})` };
    const p = expandHome(w.t);
    if (!path.isAbsolute(p) && !cwdKnown) return { err: `ruta relativa con directorio de trabajo desconocido (${w.t})` };
    return { p: path.resolve(cwd, p) };
  };
  const check = w => {
    const r = resolve(w);
    if (r.err) {
      problems.push(`comando no analizable, simplifícalo: ${r.err}`);
    } else if (!inScope(r.p)) {
      problems.push(`ruta fuera del alcance: ${r.p}`);
    }
  };

  for (const seg of segs) {
    const words = skipWrappers(seg.words);

    // Redirecciones de salida: son escrituras en sí mismas.
    for (const r of seg.redirs) {
      if (!r.exp && ['/dev/null', '/dev/stdout', '/dev/stderr'].includes(r.t)) continue;
      check(r);
    }
    if (!words.length) continue;

    const name = path.basename(words[0].t);
    const args = words.slice(1);

    if (name === 'cd') {
      const target = args.find(a => !a.t.startsWith('-'));
      if (!target) cwd = HOME;
      else if (target.exp || target.t === '-') cwdKnown = false;
      else cwd = path.resolve(cwd, expandHome(target.t));
      continue;
    }
    if (name === 'eval' || name === 'xargs') {
      problems.push(`comando no analizable, simplifícalo: uso de ${name}`);
      continue;
    }
    if (/^(bash|sh|zsh|dash|ksh)$/.test(name) && args.some(a => /^-[a-zA-Z]*c[a-zA-Z]*$/.test(a.t))) {
      problems.push(`comando no analizable, simplifícalo: uso de ${name} -c`);
      continue;
    }
    if (name === 'find' && args.some(a => /^-(exec|execdir|ok|okdir|delete)$/.test(a.t))) {
      problems.push('comando no analizable, simplifícalo: find con -exec/-delete');
      continue;
    }
    if (/^(bash|sh|zsh|dash|ksh)$/.test(name) || name === 'source' || name === '.') {
      // Un script de shell puede escribir donde quiera: solo se admite si está dentro del alcance.
      const script = args.find(a => !a.t.startsWith('-'));
      if (script && !skillScript(script, cwd, cwdKnown)) check(script);
      continue;
    }
    if (INTERPRETERS.test(name)) {
      const inline = new Set(['-c', '-e', '-p', '-E', '--eval', '--print']);
      for (let i = 0; i < args.length; i++) {
        const a = args[i];
        if (inline.has(a.t) || /^-[a-zA-Z]*[ce]$/.test(a.t)) {
          const code = args[++i];
          if (!code) break;
          if (code.exp) problems.push('comando no analizable, simplifícalo: código inline con expansión');
          for (const m of code.t.matchAll(/(?:^|[\s'"=(,])(~?\/[^\s'"),;]*)/g)) {
            if (!inScope(path.resolve(cwd, expandHome(m[1])))) problems.push(`ruta fuera del alcance: ${path.resolve(cwd, expandHome(m[1]))}`);
          }
          continue;
        }
        if (a.t.startsWith('-')) continue;
        check(a);
      }
      if (!cwdKnown) problems.push('comando no analizable, simplifícalo: directorio de trabajo desconocido');
      continue;
    }
    if (name === 'dd' || name === 'curl' || name === 'wget') {
      const d = downloadTargets(name, args);
      d.res.forEach(check);
      if (d.cwdWord) {
        if (!cwdKnown) problems.push('comando no analizable, simplifícalo: directorio de trabajo desconocido');
        else if (!inScope(cwd)) problems.push(`ruta fuera del alcance: ${cwd} (directorio de trabajo)`);
      }
      continue;
    }
    if (WRITE_VERBS.has(name)) {
      const targets = affectedPaths(name, args);
      if (targets) targets.forEach(check);
      continue;
    }
  }

  for (const s of subs) problems.push(...analyze(s, cwd, depth + 1));
  return problems;
}

// ---------- Entrada ----------

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
  // Registrado a nivel de plugin: salta para todas las llamadas. Solo restringe al
  // agente plex-naming (agent_type `plex-naming` o `<plugin>:plex-naming`).
  const agentType = payload.agent_type || '';
  const isTarget = agentType
    ? agentType === 'plex-naming' || agentType.endsWith(':plex-naming')
    : process.env.PLEX_CREW_ENFORCE_ALL === '1';
  if (!isTarget) process.exit(0);

  const tool = payload.tool_name || '';
  const input = payload.tool_input || {};
  const isZ = zurg.isZurg(tool);
  if (!isZ && !['Edit', 'Write', 'NotebookEdit', 'Bash'].includes(tool)) process.exit(0);
  // Tools MCP de zurg: solo las de renombrado se comprueban contra scope.conf; el resto
  // las gobierna confirm-destructive.js (lectura pasa; lo demás pide marcador).
  if (isZ && zurg.kind(tool) !== 'rename') process.exit(0);

  if (ALLOWED.length === 0) {
    out(
      'No hay rutas permitidas para este agente. Crea ~/.claude/plex-crew/scope.conf ' +
        '(hay una plantilla en scope.conf.example en la raíz del repositorio) con una ruta absoluta por línea, ' +
        'o define la variable PLEX_CREW_CONFIG apuntando a otro fichero.'
    );
  }

  if (isZ) {
    const paths = zurg.pathValues(input);
    if (paths.length === 0) {
      out(
        `La tool ${tool} escribe, pero su input no expone ninguna ruta reconocible (campos path, from, to, new_path, directory...), ` +
          'así que no se puede comprobar contra scope.conf (fallo cerrado). Devuelve la propuesta al orquestador.'
      );
    }
    const bad = paths.map(p => path.resolve(payload.cwd || process.cwd(), expandHome(p))).filter(r => !inScope(r));
    if (bad.length === 0) process.exit(0);
    out(`Ruta fuera del alcance de este agente en ${tool}: ${[...new Set(bad)].join(', ')}. Rutas permitidas: ${listaPermitidas()}.`);
  }

  if (tool === 'Bash') {
    const cmd = input.command || '';
    if (!cmd) process.exit(0);
    const problems = [...new Set(analyze(cmd, payload.cwd || process.cwd()))];
    if (problems.length === 0) process.exit(0);
    out(`Comando Bash denegado por el alcance de este agente: ${problems.join('; ')}. Rutas permitidas: ${listaPermitidas()}.`);
  }

  const target = input.file_path || input.notebook_path || '';
  if (!target) process.exit(0);
  const resolved = path.resolve(payload.cwd || process.cwd(), expandHome(target));
  if (inScope(resolved)) process.exit(0);
  out(`Ruta fuera del alcance de este agente: ${resolved}. Rutas permitidas: ${listaPermitidas()}.`);
});
