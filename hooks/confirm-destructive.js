// PreToolUse (Bash y mcp__zurg__*): BLOQUEA (deny) los comandos destructivos reales, salvo que
// lleven el marcador `PLEX_CREW_CONFIRMED=1` como asignación de entorno al inicio
// del MISMO segmento (separado por ; & | o salto de línea) que casa el patrón
// destructivo (p. ej. `PLEX_CREW_CONFIRMED=1 rm -rf /ruta`). El texto entrecomillado
// nunca cuenta como marcador.
// El marcador solo se pone tras la doble confirmación del usuario (dos mensajes
// distintos, incluso en modo automático). Sin marcador no hay aviso en la UI:
// el comando se deniega y el subagente debe devolver la propuesta al orquestador.
// Lo que no casa con un patrón destructivo pasa sin salida (exit 0).
// Alcance: solo se vigila el ecosistema del plugin.
//  - git: solo si el repo afectado (cwd o `git -C`) es este repositorio.
//  - borrado de ficheros: solo si las rutas del comando (resueltas contra el cwd,
//    normalizando `..`) o el cwd caen en rutas de scope.conf (carpetas de medios) o
//    en este repositorio. Rutas con `$` o `~` cuentan como "toca".
//  - sin scope.conf (sin rutas): toda operación de ficheros destructiva se deniega
//    (fallo cerrado), con o sin marcador, pidiendo crear scope.conf.
//  - docker, SQL, curl DELETE y subcomandos destructivos de las skills: siempre.
// Limitaciones conocidas: no es un sandbox. `echo`/`printf` y `git commit` no se
// comprueban contra los patrones de texto (docker/SQL/git), para evitar falsos
// positivos; consecuencia: `echo "DELETE FROM x" | psql` pasa.
const fs = require('fs');
const os = require('os');
const path = require('path');

const zurg = require('./zurg-tools');
const { expandScopeLine } = require('./zurg-mounts');

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
    .flatMap(l => expandScopeLine(l) || [l]) // marcador @zurg[/subruta]; mal formado o sin montaje: se ignora
    .map(l => norm(l.startsWith('~') ? path.join(os.homedir(), l.slice(1)) : l));
}

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
  /\bplex-api\.sh["']?\s+["']?emptytrash\b/,
  /\brutorrent\.sh["']?\s+["']?remove(-with-data)?["']?(\s|$)/,
  // ruTorrent / rTorrent a mano: quitar torrents, borrar datos o ejecutar órdenes por RPC.
  /\bcurl\b.*\bmode=remove(withdata)?\b/,
  /\bcurl\b.*\/plugins\/erasedata\b/,
  /\bcurl\b(?=.*\/RPC2\b)(?=.*(\bd\.erase\b|\bexecute\d*(\.\w+)*\b|(-d|--data[\w-]*)[\s=]+["']?@))/,
  /\brtxmlrpc\b.*(\bd\.erase\b|\bexecute\d*(\.\w+)*\b|--(delete|cull)\b)/,
  /\brtcontrol\b.*--(delete|cull)\b/,
  // Funciones destructivas de las librerías de las skills (_lib/arr-api.sh).
  /\barr_delete\b/,
];

// ---------- Análisis del comando ----------

// Divide el comando en segmentos (por ; & | saltos de línea y paréntesis sin comillas)
// y en palabras, respetando comillas. Cada segmento conserva su texto (`raw`, con el
// cuerpo de heredoc) y sus palabras; el texto entrecomillado nunca separa segmentos ni
// cuenta como asignación inicial. Las sustituciones $(...) y `...` van aparte en `subs`.
function parse(cmd) {
  const segs = [];
  const subs = [];
  let seg = { words: [], raw: '' };
  let buf = '';
  let has = false;
  let exp = false;
  let skipNext = false; // la palabra siguiente es destino de una redirección
  let heredocs = [];
  let start = 0;

  const flush = () => {
    if (!has) return;
    if (skipNext) skipNext = false;
    else seg.words.push({ t: buf, exp });
    buf = '';
    has = false;
    exp = false;
  };
  const endSeg = i => {
    flush();
    seg.raw += cmd.slice(start, i);
    if (seg.words.length) segs.push(seg);
    seg = { words: [], raw: '' };
    start = i + 1;
    skipNext = false;
  };
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
          if (cmd[j] === '$') exp = true;
          buf += cmd[j++];
        }
      }
      i = j;
    } else if (c === '\\') {
      if (n === '\n') i++;
      else if (n !== undefined) {
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
    } else if (c === '$') {
      has = true;
      exp = true;
      buf += c;
    } else if (c === '~' && !has) {
      has = true;
      exp = true;
      buf += c;
    } else if (c === ' ' || c === '\t') {
      flush();
    } else if (c === '\n') {
      endSeg(i);
      for (const d of heredocs) {
        let pos = i + 1;
        while (pos < cmd.length) {
          let eol = cmd.indexOf('\n', pos);
          if (eol === -1) eol = cmd.length;
          const line = cmd.slice(pos, eol).replace(/^\t+/, '').trim();
          pos = eol + 1;
          if (line === d) break;
        }
        const prev = segs[segs.length - 1];
        if (prev) prev.raw += '\n' + cmd.slice(i + 1, Math.min(pos, cmd.length));
        i = Math.min(pos - 1, cmd.length);
        start = i + 1;
      }
      heredocs = [];
    } else if (c === ';' || c === '(' || c === ')') {
      endSeg(i);
    } else if (c === '|') {
      endSeg(i);
      if (n === '|' || n === '&') {
        i++;
        start = i + 1;
      }
    } else if (c === '&') {
      if (n === '>') {
        flush();
        skipNext = true;
        i += cmd[i + 2] === '>' ? 2 : 1;
      } else {
        endSeg(i);
        if (n === '&') {
          i++;
          start = i + 1;
        }
      }
    } else if (c === '>' || c === '<') {
      if (c === '<' && n === '(') {
        const e = closeParen(i + 1);
        subs.push(cmd.slice(i + 2, e));
        flush();
        i = e;
        continue;
      }
      if (has && !exp && /^\d+$/.test(buf)) {
        buf = '';
        has = false;
      } else flush();
      if (c === '<' && n === '<' && cmd[i + 2] !== '<') {
        i += cmd[i + 2] === '-' ? 2 : 1;
        const m = cmd.slice(i + 1).match(/^\s*(?:"([^"]*)"|'([^']*)'|\\?([^\s;&|<>()]+))/);
        if (m) heredocs.push(m[1] || m[2] || m[3]);
        skipNext = true;
      } else {
        if (c === '<' && n === '<') i += 2; // here-string <<<
        else if (n === '>' || n === '|' || n === '&') i++;
        skipNext = true;
      }
    } else {
      has = true;
      buf += c;
    }
  }
  endSeg(cmd.length);
  return { segs, subs };
}

// Envoltorios que se saltan para llegar al verbo real: opciones que consumen
// argumento y número de argumentos posicionales propios.
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
  xargs: { opts: ['-I', '-L', '-n', '-P', '-s', '-d', '-E', '-a', '--max-args', '--max-procs', '--delimiter'], pos: 0 },
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

// Devuelve { marker, verb, args } de un segmento: salta asignaciones iniciales y
// envoltorios. `marker` es true si PLEX_CREW_CONFIRMED=1 está entre las asignaciones.
function unwrap(w) {
  let i = 0;
  let marker = false;
  for (;;) {
    while (i < w.length && /^[A-Za-z_]\w*=/.test(w[i].t)) {
      if (w[i].t === 'PLEX_CREW_CONFIRMED=1') marker = true;
      i++;
    }
    if (i >= w.length) return null;
    const name = path.basename(w[i].t);
    const wr = Object.prototype.hasOwnProperty.call(WRAPPERS, name) ? WRAPPERS[name] : null;
    if (!wr) break;
    i++;
    let pos = wr.pos;
    while (i < w.length) {
      const t = w[i].t;
      if (t === '--') {
        i++;
        break;
      }
      if (name === 'env' && /^[A-Za-z_]\w*=/.test(t)) {
        if (t === 'PLEX_CREW_CONFIRMED=1') marker = true;
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
  return { marker, verb: path.basename(w[i].t), args: w.slice(i + 1) };
}

// Rutas candidatas de los argumentos: no-opciones y valores de --opt=valor / of=valor.
function pathTokens(args) {
  const out = [];
  let endOpts = false;
  for (const a of args) {
    let t = a.t;
    if (!endOpts && t === '--') {
      endOpts = true;
      continue;
    }
    if (!endOpts && t.startsWith('-') && t.length > 1) {
      const eq = t.indexOf('=');
      if (eq === -1) continue;
      t = t.slice(eq + 1);
    } else if (/^of=/.test(t)) {
      t = t.slice(3);
    }
    if (t) out.push({ t, exp: a.exp || /[$~]/.test(t) });
  }
  return out;
}

// Las rutas del comando o el cwd afectan a alguna de las raíces. Cada token que parezca
// ruta se resuelve contra cwd (normaliza `..`); los que llevan `$` o `~` cuentan como
// "toca". Sin tokens (p. ej. `xargs rm`), decide el cwd.
function touches(args, cwd, roots) {
  const toks = pathTokens(args);
  const base = cwd || process.cwd();
  for (const tok of toks) {
    if (tok.exp || /[$~`]/.test(tok.t)) return true;
    if (!cwd && !path.isAbsolute(tok.t)) return true; // cwd desconocido
    const p = norm(path.resolve(base, tok.t));
    if (roots.some(r => inside(p, r))) return true;
  }
  if (toks.length === 0) {
    if (!cwd) return true;
    const c = norm(cwd);
    return roots.some(r => inside(c, r));
  }
  return false;
}

function gitTargetsRepo(cmd, cwd) {
  const m = cmd.match(/\bgit\s+(?:-C\s+("[^"]+"|'[^']+'|\S+)\s+)?/);
  const dir = m && m[1] ? m[1].replace(/^["']|["']$/g, '') : cwd;
  if (!dir) return false;
  const base = cwd || process.cwd();
  return inside(norm(path.resolve(base, dir)), norm(PLUGIN_ROOT));
}

// ¿El verbo con sus argumentos es una operación destructiva de ficheros?
function isFileOp(verb, args) {
  const ts = args.map(a => a.t);
  if (/^(rm|rmdir|unlink|shred|truncate)$/.test(verb)) return true;
  if (/^mkfs(\..+)?$/.test(verb)) return true;
  if (verb === 'dd') return ts.some(t => /^of=/.test(t));
  if (verb === 'rsync') return ts.some(t => /^--(delete|remove-source-files)/.test(t));
  if (verb === 'mv') return ts.includes('/dev/null'); // mv genérico dentro de medios sigue permitido
  if (verb === 'find') {
    if (ts.includes('-delete')) return true;
    for (let i = 0; i < ts.length - 1; i++) {
      if (/^-(exec|execdir|ok|okdir)$/.test(ts[i]) && /^(rm|rmdir|unlink|shred)$/.test(path.basename(ts[i + 1]))) return true;
    }
  }
  return false;
}

const NO_REGEX_VERBS = /^(echo|printf)$/;

// Analiza un comando; devuelve los hallazgos { kind, confirmed } (uno por segmento y tipo).
function analyze(cmd, cwd0, roots, inherited, depth) {
  const hits = [];
  if (depth > 4) return hits;
  const { segs, subs } = parse(cmd);
  let cwd = cwd0;
  for (const seg of segs) {
    const u = unwrap(seg.words);
    if (!u) continue;
    const confirmed = u.marker || inherited;
    const { verb, args } = u;
    if (verb === 'cd') {
      const t = args.find(a => !a.t.startsWith('-'));
      if (!t) cwd = os.homedir();
      else if (t.exp || t.t === '-') cwd = '';
      else cwd = path.resolve(cwd || process.cwd(), t.t);
      continue;
    }
    if (/^(bash|sh|zsh|dash|ksh)$/.test(verb)) {
      const i = args.findIndex(a => /^-[a-zA-Z]*c[a-zA-Z]*$/.test(a.t));
      if (i !== -1 && args[i + 1]) hits.push(...analyze(args[i + 1].t, cwd, roots, confirmed, depth + 1));
    }
    if (verb === 'eval') hits.push(...analyze(args.map(a => a.t).join(' '), cwd, roots, confirmed, depth + 1));
    const quiet = NO_REGEX_VERBS.test(verb) || (verb === 'git' && args.some(a => a.t === 'commit'));
    if (!quiet) {
      if (DESTRUCTIVE.some(re => re.test(seg.raw))) hits.push({ kind: 'destructive', confirmed });
      if (GIT_OPS.some(re => re.test(seg.raw)) && gitTargetsRepo(seg.raw, cwd)) hits.push({ kind: 'git', confirmed });
    }
    if (isFileOp(verb, args)) {
      if (roots.length === 0) hits.push({ kind: 'noscope', confirmed });
      else if (touches(args, cwd, [...roots, norm(PLUGIN_ROOT)])) hits.push({ kind: 'file', confirmed });
    }
  }
  for (const s of subs) hits.push(...analyze(s, cwd, roots, false, depth + 1));
  return hits;
}

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

let raw = '';
process.stdin.on('data', c => (raw += c));
process.stdin.on('end', () => {
  let cmd = '';
  let cwd = '';
  try {
    const payload = JSON.parse(raw);
    if (zurg.isZurg(payload.tool_name)) {
      // Tools MCP de zurg: se clasifican por nombre (ver zurg-tools.js).
      const k = zurg.kind(payload.tool_name);
      if (k !== 'other' || zurg.hasMarker(payload.tool_input)) process.exit(0);
      deny(
        `Tool MCP de zurg bloqueada (${payload.tool_name}): no es de solo lectura ni de renombrado, o su nombre no está clasificado (fallo cerrado). ` +
          'Regla del stack: doble confirmación del usuario en dos mensajes distintos. Si ya la hay, reintenta la misma tool poniendo el texto `PLEX_CREW_CONFIRMED=1` ' +
          'en algún campo de texto libre de sus argumentos (por ejemplo un campo de nota, motivo o comentario, si el esquema lo tiene). ' +
          'Si el esquema no tiene ningún campo de texto libre, no se puede confirmar desde aquí: devuelve la propuesta al orquestador. ' +
          'No pongas el marcador sin doble confirmación real.'
      );
    }
    cmd = (payload.tool_input && payload.tool_input.command) || '';
    cwd = payload.cwd || '';
  } catch {
    process.stderr.write('plex-crew hook: entrada JSON no válida; bloqueado por seguridad\n');
    process.exit(2);
  }
  const roots = mediaRoots();
  const hits = analyze(cmd, cwd, roots, false, 0);
  if (hits.some(h => h.kind === 'noscope')) {
    deny(
      'Operación de ficheros destructiva bloqueada: no hay rutas en scope.conf, así que no se puede saber qué es seguro borrar (fallo cerrado; el marcador no lo evita). ' +
        'Crea ~/.claude/plex-crew/scope.conf (plantilla en scope.conf.example en la raíz del repositorio) con una ruta absoluta por línea, ' +
        'o define PLEX_CREW_CONFIG apuntando a otro fichero, y vuelve a intentarlo.'
    );
  }
  if (hits.every(h => h.confirmed)) process.exit(0);
  deny(
    'Comando destructivo bloqueado. Regla del stack: doble confirmación del usuario en dos mensajes distintos antes de ejecutarlo. ' +
      'Si el usuario ya ha confirmado dos veces, en dos mensajes distintos y de forma explícita, reintenta el mismo comando anteponiendo `PLEX_CREW_CONFIRMED=1 ` ' +
      'al comando destructivo (por ejemplo `PLEX_CREW_CONFIRMED=1 <comando>`; el marcador debe ir en el mismo segmento, no en otro tramo separado por ; & |). ' +
      'No pongas ese marcador sin una doble confirmación real: ni por iniciativa propia ni tras una sola respuesta del usuario. ' +
      'Si todavía no hay confirmación, NO ejecutes el comando: devuelve al orquestador la propuesta (qué se borra o modifica, con las rutas exactas) para que pida las dos confirmaciones al usuario.'
  );
});
