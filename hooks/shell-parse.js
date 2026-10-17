// Análisis conservador de comandos Bash compartido por enforce-agent-scope.js y zurg-mount.js:
// troceo en segmentos/palabras/redirecciones y extracción de rutas afectadas por verbos de escritura.
const path = require('path');

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

// Envoltorios que se saltan para llegar al verbo real: opciones que consumen argumento
// (`opts`) y número de argumentos posicionales propios (`pos`, p. ej. la duración de timeout).
const WRAPPERS = {
  sudo: { opts: ['-u', '-g', '-h', '-p', '-C', '-D', '-R', '-T'], pos: 0 },
  command: { opts: [], pos: 0 },
  nohup: { opts: [], pos: 0 },
  nice: { opts: ['-n', '--adjustment'], pos: 0 },
  env: { opts: ['-u', '--unset', '-C', '--chdir', '-S'], pos: 0 },
  exec: { opts: ['-a'], pos: 0 },
  builtin: { opts: [], pos: 0 },
  time: { opts: ['-f', '-o', '--format', '--output'], pos: 0 },
  timeout: { opts: ['-s', '--signal', '-k', '--kill-after'], pos: 1 },
  ionice: { opts: ['-c', '--class', '-n', '--classdata', '-p', '-P', '-u'], pos: 0 },
  stdbuf: { opts: ['-i', '-o', '-e'], pos: 0 },
  setsid: { opts: [], pos: 0 },
  busybox: { opts: [], pos: 0 },
  flock: { opts: ['-w', '--timeout', '-E', '--conflict-exit-code'], pos: 1 },
  then: { opts: [], pos: 0 },
  do: { opts: [], pos: 0 },
  else: { opts: [], pos: 0 },
  elif: { opts: [], pos: 0 },
  if: { opts: [], pos: 0 },
  while: { opts: [], pos: 0 },
  until: { opts: [], pos: 0 },
  '!': { opts: [], pos: 0 },
  '{': { opts: [], pos: 0 },
};

// Quita asignaciones iniciales VAR=valor y envoltorios (con sus opciones y valores).
function skipWrappers(w) {
  let i = 0;
  for (;;) {
    while (i < w.length && /^[A-Za-z_]\w*=/.test(w[i].t)) i++;
    if (i >= w.length) return [];
    const name = path.basename(w[i].t);
    const wr = Object.prototype.hasOwnProperty.call(WRAPPERS, name) ? WRAPPERS[name] : null;
    if (!wr) return w.slice(i);
    i++;
    let pos = wr.pos;
    while (i < w.length) {
      const t = w[i].t;
      if (t === '--') {
        i++;
        break;
      }
      if (name === 'env' && /^[A-Za-z_]\w*=/.test(t)) {
        i++;
        continue;
      }
      if (/^-\d+$/.test(t) || (name === 'nice' && /^-n\d+$/.test(t))) {
        i++;
        continue;
      }
      if (t.startsWith('-') && t.length > 1) {
        i += wr.opts.includes(t) ? 2 : 1;
        continue;
      }
      if (pos > 0) {
        pos--;
        i++;
        continue;
      }
      break;
    }
  }
}

const WRITE_VERBS = new Set([
  'mv', 'cp', 'rm', 'rmdir', 'mkdir', 'touch', 'ln', 'tee', 'truncate', 'install', 'sed',
  'rsync', 'rename', 'unlink', 'shred', 'chmod', 'chown', 'chgrp',
]);
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
  rsync: [
    '-e', '--rsh', '--exclude', '--include', '--exclude-from', '--include-from', '--filter', '-f',
    '--files-from', '--backup-dir', '--log-file', '--bwlimit', '--partial-dir', '--temp-dir', '-T',
    '--compare-dest', '--copy-dest', '--link-dest', '--max-size', '--min-size', '--port',
    '--chmod', '--chown', '--usermap', '--groupmap', '--timeout', '--contimeout', '--rsync-path',
  ],
  shred: ['-n', '--iterations', '-s', '--size', '--random-source'],
  chmod: [],
  chown: ['--from'],
  chgrp: [],
  rename: [],
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
    if (verb === 'chmod' && !endOpts && /^-[rwxXstugoa,=+-]+$/.test(t) && !/^-[RfvcHLP]+$/.test(t)) {
      rest.push(a); // modo simbólico tipo `-x`: ocupa el lugar del modo
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
  if (verb === 'rsync') {
    // El último posicional es el destino; con --delete/--remove-source-files también se
    // modifican los orígenes. Un destino remoto host:ruta no se puede comprobar.
    if (rest.some(r => !r.exp && /^[^/]*:/.test(r.t))) return [{ t: '?remoto', exp: true }];
    const mod = args.some(a => /^--(delete|remove-source-files)/.test(a.t));
    return mod ? rest : rest.slice(-1);
  }
  if (verb === 'chmod' || verb === 'chown' || verb === 'chgrp') {
    const hasRef = args.some(a => a.t === '--reference' || a.t.startsWith('--reference='));
    return hasRef ? rest : rest.slice(1); // el primero es el modo/propietario
  }
  if (verb === 'rename') return rest.slice(1); // expresión (o 'de' en la variante util-linux)
  return res.concat(rest);
}

// Destinos de escritura de dd (of=), curl (-o/--output/-O) y wget (-O/-P; por defecto el cwd).
// Devuelve palabras a comprobar; `cwdWord` indica que escribe en el directorio de trabajo.
function downloadTargets(verb, args) {
  const res = [];
  let cwdWord = false;
  if (verb === 'dd') {
    for (const a of args) if (a.t.startsWith('of=')) res.push({ t: a.t.slice(3), exp: a.exp });
    return { res, cwdWord };
  }
  const isCurl = verb === 'curl';
  let stdout = false;
  let named = false;
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    const t = a.t;
    let val = null;
    if (isCurl) {
      if (t === '-o' || t === '--output' || t === '--output-dir') val = args[++i];
      else if (t.startsWith('--output=')) val = { t: t.slice(9), exp: a.exp };
      else if (t.startsWith('--output-dir=')) val = { t: t.slice(13), exp: a.exp };
      else if (/^-[a-zA-Z]*o$/.test(t)) val = args[++i];
      else if (t === '--remote-name' || t === '--remote-name-all' || /^-[a-zA-Z]*O[a-zA-Z]*$/.test(t)) cwdWord = true;
    } else {
      if (/^-[a-zA-Z]*[OP]$/.test(t) || t === '--output-document' || t === '--directory-prefix') {
        if (/O$/.test(t) || t === '--output-document') named = true;
        val = args[++i];
      } else if (t.startsWith('--output-document=')) {
        named = true;
        val = { t: t.slice(18), exp: a.exp };
      } else if (t.startsWith('--directory-prefix=')) val = { t: t.slice(19), exp: a.exp };
    }
    if (val) {
      if (val.t === '-' && !isCurl) stdout = true;
      else res.push(val);
    }
  }
  if (!isCurl && !stdout && !named) cwdWord = true; // wget guarda en el cwd si no hay -O
  return { res, cwdWord };
}

module.exports = { parse, skipWrappers, affectedPaths, downloadTargets, WRITE_VERBS, INTERPRETERS };
