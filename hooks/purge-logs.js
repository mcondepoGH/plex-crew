// SessionStart (startup|resume): purga determinista de los logs de más de 7 días.
// Borra solo ficheros regulares `*.log` directamente en ~/.claude/plex-crew/logs/ (sin
// recursión, sin seguir symlinks, nunca fuera de esa carpeta). Carpeta ausente o symlink:
// no hace nada. Nunca bloquea ni falla la sesión (exit 0 siempre) y no escribe en stdout
// (en SessionStart el stdout se añade al contexto del modelo).
// Solo para pruebas: PLEX_CREW_LOG_DIR redirige la carpeta (por defecto, la ruta real).
const fs = require('fs');
const os = require('os');
const path = require('path');

const MAX_AGE_MS = 7 * 24 * 3600 * 1000;

try {
  const dir = process.env.PLEX_CREW_LOG_DIR || path.join(os.homedir(), '.claude', 'plex-crew', 'logs');
  const st = fs.lstatSync(dir);
  if (st.isDirectory() && !st.isSymbolicLink()) {
    const limit = Date.now() - MAX_AGE_MS;
    for (const name of fs.readdirSync(dir)) {
      if (!name.endsWith('.log') || name.includes('/') || name.includes('\\')) continue;
      try {
        const f = path.join(dir, name);
        const s = fs.lstatSync(f); // lstat: un symlink no cuenta como fichero regular
        if (s.isFile() && s.mtimeMs < limit) fs.unlinkSync(f);
      } catch {
        // un fichero problemático no detiene la purga
      }
    }
  }
} catch {
  // carpeta inexistente o ilegible: nada que hacer
}
process.exit(0);
