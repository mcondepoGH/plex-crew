// PostToolUse / PostToolUseFailure (Bash|Edit|Write|NotebookEdit): añade una línea por
// acción de cualquier agente (hilo principal y subagentes) a
//   ~/.claude/plex-crew/logs/<AAAA-MM-DD>-auto.log
// Formato: HH:MM:SS (Europe/Madrid) | <agent_type|main> | <herramienta> | <detalle> | OK|FALLO
//   - detalle: comando Bash o ruta (file_path / notebook_path), una línea, máx. 300 caracteres.
//   - OK/FALLO sale del evento (doc oficial: PostToolUse = la herramienta tuvo éxito,
//     PostToolUseFailure = falló), no de tool_response, cuya forma no está documentada
//     de forma estable para todas las herramientas.
// Los secretos se redactan (***) ANTES de recortar. Nunca bloquea (exit 0 siempre) y no
// escribe en stdout. Carpeta 0700 y fichero 0600; no sigue symlinks al abrir el fichero.
// Solo para pruebas: PLEX_CREW_LOG_DIR redirige la carpeta (por defecto, la ruta real).
const fs = require('fs');
const os = require('os');
const path = require('path');

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

function madrid(now) {
  const f = (opts) => new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Madrid', hourCycle: 'h23', ...opts });
  const p = Object.fromEntries(
    f({ year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit' })
      .formatToParts(now).map(x => [x.type, x.value])
  );
  return { date: `${p.year}-${p.month}-${p.day}`, time: `${p.hour}:${p.minute}:${p.second}` };
}

function summarize(tool, input) {
  let d = '';
  if (tool === 'Bash') d = input.command || '';
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
    if (!['Bash', 'Edit', 'Write', 'NotebookEdit'].includes(tool)) return;
    const input = p.tool_input && typeof p.tool_input === 'object' ? p.tool_input : {};
    const agent = String(p.agent_type || 'main').replace(/[\s|]+/g, '_');
    const result = p.hook_event_name === 'PostToolUseFailure' ? 'FALLO' : 'OK';
    const t = madrid(new Date());
    const line = `${t.time} (Europe/Madrid) | ${agent} | ${tool} | ${summarize(tool, input)} | ${result}\n`;

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
