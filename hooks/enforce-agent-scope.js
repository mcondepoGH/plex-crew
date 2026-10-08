// PreToolUse (Edit|Write|NotebookEdit|Bash): limita dónde puede escribir el agente plex-naming.
// Se registra en hooks/hooks.json (plugin) y salta en todas las llamadas; solo actúa si el
// input trae agent_type `plex-naming` o `<plugin>:plex-naming`. Sin agent_type no decide,
// salvo que PLEX_CREW_ENFORCE_ALL=1 (pruebas).
//
// Rutas permitidas, en este orden de lectura:
//   1. Fichero indicado en $PLEX_CREW_CONFIG, o si no existe la variable,
//      ~/.claude/plex-crew/scope.conf (una ruta absoluta por línea; se ignoran
//      líneas vacías y comentarios con #; se expande ~).
//   2. Argumentos de línea de comandos opcionales: se añaden como rutas extra.
// Si no hay ninguna ruta, se deniega todo con instrucciones para configurarlo.
//
// Para Bash se analiza de forma conservadora el comando: se trocea por ; && || | & y
// saltos de línea, se buscan verbos de escritura (mv, cp, rm, rmdir, mkdir, touch, ln,
// tee, truncate, install, sed -i y redirecciones > / >>) y se comprueba que todas las
// rutas afectadas queden dentro del alcance. Ante la duda se deniega.
// No es un sandbox: es una red de seguridad contra errores, no contra un adversario.
const fs = require('fs');
const os = require('os');
const path = require('path');

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
      list.push(l);
    }
  } catch {
    // fichero ausente o ilegible: se considera vacío
  }
  for (const a of process.argv.slice(2)) list.push(a);
  return list.map(p => real(expandHome(p)));
}

const ALLOWED = loadAllowed();

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

// ---------- Análisis de comandos Bash ----------

// Divide el comando en segmentos con palabras y redirecciones, respetando comillas,
// sustituciones $(...) y heredocs. Las sustituciones se devuelven aparte en `subs`.
function parse(cmd) {
  const segs = [];
  const subs = [];
  let seg = { words: [], redirs: [] };
  let buf = '';
  let has = false;
  let exp = false;
  let pending = null; // { kind: 'out'|'in'|'heredoc', amp }
  let heredocs = [];

  const flush = () => {
    if (!has) return;
    const w = { t: buf, exp };
    if (pending) {
      if (pending.kind === 'out') {
        if (!(pending.amp && /^(\d+|-)$/.test(buf))) seg.redirs.push(w);
      } else if (pending.kind === 'heredoc') {
        heredocs.push(buf);
      }
      pending = null;
    } else {
      seg.words.push(w);
    }
    buf = '';
    has = false;
    exp = false;
  };
  const endSeg = () => {
    flush();
    if (seg.words.length || seg.redirs.length) segs.push(seg);
    seg = { words: [], redirs: [] };
  };
  // Devuelve el índice del cierre de un paréntesis balanceado que abre en i (cmd[i] === '(').
  const closeParen = i => {
    let depth = 0;
    for (let j = i; j < cmd.length; j++) {
      if (cmd[j] === '(') depth++;
      else if (cmd[j] === ')' && --depth === 0) return j;
    }
    return cmd.length - 1;
  };
  const closeTick = i => {
    let j = i + 1;
    while (j < cmd.length && cmd[j] !== '`') j += cmd[j] === '\\' ? 2 : 1;
    return Math.min(j, cmd.length - 1);
  };

  for (let i = 0; i < cmd.length; i++) {
    const c = cmd[i];
    const n = cmd[i + 1];
    if (c === "'") {
      has = true;
      const j = cmd.indexOf("'", i + 1);
      const end = j === -1 ? cmd.length : j;
      buf += cmd.slice(i + 1, end);
      i = end;
    } else if (c === '"') {
      has = true;
      let j = i + 1;
      while (j < cmd.length && cmd[j] !== '"') {
        if (cmd[j] === '\\' && j + 1 < cmd.length) {
          buf += cmd[j + 1];
          j += 2;
        } else if (cmd[j] === '$' && cmd[j + 1] === '(') {
          const e = closeParen(j + 1);
          subs.push(cmd.slice(j + 2, e));
          buf += cmd.slice(j, e + 1);
          exp = true;
          j = e + 1;
        } else if (cmd[j] === '`') {
          const e = closeTick(j);
          subs.push(cmd.slice(j + 1, e));
          buf += cmd.slice(j, e + 1);
          exp = true;
          j = e + 1;
        } else {
          if (cmd[j] === '$' && /[A-Za-z_{@*#?0-9!-]/.test(cmd[j + 1] || '')) exp = true;
          buf += cmd[j++];
        }
      }
      i = j;
    } else if (c === '\\') {
      if (n === '\n') {
        i++;
      } else if (n !== undefined) {
        has = true;
        buf += n;
        i++;
      }
    } else if (c === '$' && n === '(') {
      const e = closeParen(i + 1);
      subs.push(cmd.slice(i + 2, e));
      has = true;
      exp = true;
      buf += cmd.slice(i, e + 1);
      i = e;
    } else if (c === '`') {
      const e = closeTick(i);
      subs.push(cmd.slice(i + 1, e));
      has = true;
      exp = true;
      buf += cmd.slice(i, e + 1);
      i = e;
    } else if (c === '$' && /[A-Za-z_{@*#?0-9!-]/.test(n || '')) {
      has = true;
      exp = true;
      buf += c;
    } else if (c === ' ' || c === '\t') {
      flush();
    } else if (c === '\n') {
      endSeg();
      for (const d of heredocs) {
        let pos = i + 1;
        while (pos < cmd.length) {
          let eol = cmd.indexOf('\n', pos);
          if (eol === -1) eol = cmd.length;
          const line = cmd.slice(pos, eol).replace(/^\t+/, '').trim();
          pos = eol + 1;
          if (line === d) break;
        }
        i = Math.min(pos - 1, cmd.length);
      }
      heredocs = [];
    } else if (c === ';') {
      endSeg();
    } else if (c === '|') {
      endSeg();
      if (n === '|' || n === '&') i++;
    } else if (c === '&') {
      if (n === '&') {
        endSeg();
        i++;
      } else if (n === '>') {
        flush();
        pending = { kind: 'out', amp: false };
        i += cmd[i + 2] === '>' ? 2 : 1;
      } else {
        endSeg();
      }
    } else if (c === '>') {
      if (has && !exp && /^\d+$/.test(buf)) {
        buf = '';
        has = false;
      } else {
        flush();
      }
      let amp = false;
      if (n === '>') i++;
      else if (n === '|') i++;
      else if (n === '&') {
        amp = true;
        i++;
      }
      pending = { kind: 'out', amp };
    } else if (c === '<') {
      if (has && !exp && /^\d+$/.test(buf)) {
        buf = '';
        has = false;
      } else {
        flush();
      }
      if (n === '(') {
        const e = closeParen(i + 1);
        subs.push(cmd.slice(i + 2, e));
        i = e;
      } else if (n === '<' && cmd[i + 2] === '<') {
        pending = { kind: 'in' };
        i += 2;
      } else if (n === '<') {
        pending = { kind: 'heredoc' };
        i += cmd[i + 2] === '-' ? 2 : 1;
      } else {
        pending = { kind: 'in' };
        if (n === '&') i++;
      }
    } else if (c === '(' || c === ')') {
      endSeg();
    } else if (c === '#' && !has) {
      while (i + 1 < cmd.length && cmd[i + 1] !== '\n') i++;
    } else {
      has = true;
      buf += c;
    }
  }
  endSeg();
  return { segs, subs };
}

const WRAPPERS = new Set(['sudo', 'command', 'nohup', 'nice', 'env', 'exec', 'builtin', 'time', 'then', 'do', 'else', 'elif', 'if', 'while', 'until', '!', '{']);
const WRITE_VERBS = new Set(['mv', 'cp', 'rm', 'rmdir', 'mkdir', 'touch', 'ln', 'tee', 'truncate', 'install', 'sed']);
const INTERPRETERS = /^(python\d*(\.\d+)?|perl|node|nodejs|ruby)$/;
// Opciones que consumen el argumento siguiente (no son rutas afectadas).
const OPT_WITH_VALUE = {
  mkdir: ['-m', '--mode'],
  install: ['-m', '--mode', '-o', '--owner', '-g', '--group'],
  touch: ['-d', '--date', '-t', '-r', '--reference'],
  truncate: ['-s', '--size', '-r', '--reference'],
  cp: ['--backup', '-S', '--suffix'],
  mv: ['--backup', '-S', '--suffix'],
  tee: [],
  ln: ['-S', '--suffix'],
  rm: [],
  rmdir: [],
  sed: [],
};
const TARGET_DIR_OPTS = ['-t', '--target-directory'];

// Extrae las palabras que son rutas afectadas por un verbo de escritura.
function affectedPaths(verb, args) {
  const res = [];
  const withValue = new Set(OPT_WITH_VALUE[verb] || []);
  let endOpts = false;
  const rest = [];
  let sedInPlace = false;
  let sedScriptViaOpt = false;
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    const t = a.t;
    if (!endOpts && t === '--') {
      endOpts = true;
      continue;
    }
    if (!endOpts && t.startsWith('-') && t.length > 1) {
      if ((verb === 'cp' || verb === 'mv' || verb === 'install' || verb === 'ln') && TARGET_DIR_OPTS.includes(t)) {
        if (args[i + 1]) res.push(args[++i]);
        continue;
      }
      if ((verb === 'cp' || verb === 'mv' || verb === 'install' || verb === 'ln') && t.startsWith('--target-directory=')) {
        res.push({ t: t.slice('--target-directory='.length), exp: a.exp });
        continue;
      }
      if (verb === 'sed') {
        if (t === '--in-place' || t.startsWith('--in-place=') || /^-[a-zA-Z]*i/.test(t)) sedInPlace = true;
        if (t === '-e' || t === '-f' || t === '--expression' || t === '--file') {
          sedScriptViaOpt = true;
          i++;
        }
        continue;
      }
      if (withValue.has(t)) i++;
      continue;
    }
    rest.push(a);
  }
  if (verb === 'sed') {
    if (!sedInPlace) return null; // sed sin -i no escribe ficheros
    return sedScriptViaOpt ? rest : rest.slice(1);
  }
  return res.concat(rest);
}

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
    const words = seg.words.slice();
    while (words.length && (/^[A-Za-z_]\w*=/.test(words[0].t) || WRAPPERS.has(words[0].t))) words.shift();

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
    process.exit(0);
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
  if (!['Edit', 'Write', 'NotebookEdit', 'Bash'].includes(tool)) process.exit(0);

  if (ALLOWED.length === 0) {
    out(
      'No hay rutas permitidas para este agente. Crea ~/.claude/plex-crew/scope.conf ' +
        '(hay una plantilla en scope.conf.example en la raíz del repositorio) con una ruta absoluta por línea, ' +
        'o define la variable PLEX_CREW_CONFIG apuntando a otro fichero.'
    );
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
  const resolved = path.resolve(expandHome(target));
  if (inScope(resolved)) process.exit(0);
  out(`Ruta fuera del alcance de este agente: ${resolved}. Rutas permitidas: ${listaPermitidas()}.`);
});
