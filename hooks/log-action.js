// PostToolUse / PostToolUseFailure (Bash|Edit|Write|NotebookEdit|mcp__zurg__*): añade una línea por
// acción de cualquier agente (hilo principal y subagentes) a
//   ~/.claude/plex-crew/logs/<AAAA-MM-DD>-auto.log
// Formato: HH:MM:SS (<zona horaria de la máquina>) | <agent_type|main> | <herramienta> | <detalle> | OK|FALLO
//   - detalle: comando Bash, ruta (file_path / notebook_path) o, en tools mcp__zurg__*, el input en JSON;
//     una línea, máx. 300 caracteres. La columna herramienta lleva el nombre completo de la tool.
//   - OK/FALLO sale del evento (doc oficial: PostToolUse = la herramienta tuvo éxito,
//     PostToolUseFailure = falló), no de tool_response, cuya forma no está documentada
//     de forma estable para todas las herramientas.
// Los secretos se redactan (***) ANTES de recortar. Nunca bloquea (exit 0 siempre) y no
// escribe en stdout. Carpeta 0700 y fichero 0600; no sigue symlinks al abrir el fichero.
// Solo para pruebas: PLEX_CREW_LOG_DIR redirige la carpeta (por defecto, la ruta real).
const fs = require('fs');
const os = require('os');
const path = require('path');

const zurg = require('./zurg-tools');

const MAX = 300;

function redact(s) {
  return s
    // contraseñas en URLs: scheme://user:pass@host
    .replace(/(\b[a-z][a-z0-9+.-]*:\/\/)[^\s/@:'"]+:[^\s/@'"]+@/gi, '$1***@')
    // cabeceras Authorization (con o sin esquema), valor hasta fin de línea/comilla
    .replace(/(authorization\s*[:=]\s*)(?:(?:bearer|basic|token)\s+)?[^\s'"]+/gi, '$1***')
    .replace(/\b(bearer|basic)\s+[A-Za-z0-9._~+\/=-]{8,}/gi, '$1 ***')
    // pares clave=valor / clave: valor / "clave":"valor" con nombres típicos de secreto
    .replace(
      /((?:x-plex-token|x-api-key|api[_-]?key|apikey|access[_-]?token|auth[_-]?token|refresh[_-]?token|token|secret|client[_-]?secret|password|passwd|pwd)["']?\s*[:=]\s*["']?)[^\s&"',;]+/gi,
      '$1***'
    )
    // claves hex largas (>=32) y base64/base64url largas (>=40) sueltas
    .replace(/\b[0-9a-fA-F]{32,}\b/g, '***')
    .replace(/[A-Za-z0-9+]{40,}={0,2}/g, m => (/[A-Za-z]/.test(m) && /[0-9]/.test(m) ? '***' : m));
}

// Hora local de la máquina (zona del sistema / TZ), sin zona fija.
function localTime(now) {
  const f = (opts) => new Intl.DateTimeFormat('en-CA', { hourCycle: 'h23', ...opts });
  const p = Object.fromEntries(
    f({ year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit' })
      .formatToParts(now).map(x => [x.type, x.value])
  );
  let zone = '';
  try { zone = new Intl.DateTimeFormat().resolvedOptions().timeZone || ''; } catch {}
  if (!zone) {
    const o = -now.getTimezoneOffset(), a = Math.abs(o);
    zone = `UTC${o < 0 ? '-' : '+'}${String(Math.floor(a / 60)).padStart(2, '0')}:${String(a % 60).padStart(2, '0')}`;
  }
  return { date: `${p.year}-${p.month}-${p.day}`, time: `${p.hour}:${p.minute}:${p.second}`, zone };
}

// Para zurg_config_set y similares: {"key":"<nombre secreto>","value":"..."} -> value redactado.
const SECRET_NAME = /token|secret|password|passwd|pwd|api[_-]?key|apikey|authorization/i;
function maskPairs(v) {
  if (Array.isArray(v)) return v.map(maskPairs);
  if (!v || typeof v !== 'object') return v;
  const o = {};
  const named = ['key', 'name', 'field', 'setting'].some(k => typeof v[k] === 'string' && SECRET_NAME.test(v[k]));
  for (const [k, x] of Object.entries(v)) o[k] = named && /^(value|val|new_value)$/i.test(k) ? '***' : maskPairs(x);
  return o;
}

function summarize(tool, input) {
  let d = '';
  if (tool === 'Bash') d = input.command || '';
  else if (zurg.isZurg(tool)) d = JSON.stringify(maskPairs(input));
  else d = input.file_path || input.notebook_path || '';
  d = redact(String(d)).replace(/\s+/g, ' ').trim();
  return d.length > MAX ? d.slice(0, MAX - 1) + '…' : d;
}

let raw = '';
process.stdin.on('data', c => (raw += c));
process.stdin.on('end', () => {
  try {
    const p = JSON.parse(raw);
    const tool = String(p.tool_name || '');
    if (!zurg.isZurg(tool) && !['Bash', 'Edit', 'Write', 'NotebookEdit'].includes(tool)) return;
    const input = p.tool_input && typeof p.tool_input === 'object' ? p.tool_input : {};
    const agent = String(p.agent_type || 'main').replace(/[\s|]+/g, '_');
    const result = p.hook_event_name === 'PostToolUseFailure' ? 'FALLO' : 'OK';
    const t = localTime(new Date());
    const line = `${t.time} (${t.zone}) | ${agent} | ${tool} | ${summarize(tool, input)} | ${result}\n`;

    const dir = process.env.PLEX_CREW_LOG_DIR || path.join(os.homedir(), '.claude', 'plex-crew', 'logs');
    fs.mkdirSync(dir, { recursive: true, mode: 0o700 });
    const fd = fs.openSync(
      path.join(dir, `${t.date}-auto.log`),
      fs.constants.O_WRONLY | fs.constants.O_APPEND | fs.constants.O_CREAT | fs.constants.O_NOFOLLOW,
      0o600
    );
    try { fs.writeSync(fd, line); } finally { fs.closeSync(fd); }
  } catch {
    // nunca falla la sesión
  }
});
