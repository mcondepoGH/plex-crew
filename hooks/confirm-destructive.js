// PreToolUse (Bash): BLOQUEA (deny) los comandos destructivos reales, salvo que
// lleven el marcador `PLEX_CREW_CONFIRMED=1` como asignación de entorno al inicio
// de un comando (p. ej. `PLEX_CREW_CONFIRMED=1 rm -rf /ruta`).
// El marcador solo se pone tras la doble confirmación del usuario (dos mensajes
// distintos, incluso en modo automático). Sin marcador no hay aviso en la UI:
// el comando se deniega y el subagente debe devolver la propuesta al orquestador.
// Lo que no casa con un patrón destructivo pasa sin salida (exit 0).
const fs = require('fs');

const DESTRUCTIVE = [
  /\brm\s+\S/,
  /\bunlink\b/,
  /\bshred\b/,
  /\btruncate\b/,
  /\bmkfs\b/,
  /\bdd\s+.*\bof=/,
  /\bgit\s+(reset\s+--hard|clean\s+-[a-z]*f|push\s+.*--force|push\s+.*-f\b|checkout\s+--(\s|$)|restore\b)/,
  /\bdocker(-compose)?\s+(rm|rmi|down|kill|system\s+prune|volume\s+rm)\b/,
  /\bdocker\s+compose\b[^;&|]*\b(rm|rmi|down|kill)\b/,
  /\bfind\b.*(-delete|-exec\s+rm)/,
  /\bDELETE\s+FROM\b|\bDROP\s+(TABLE|DATABASE)\b/i,
  /\bcurl\b.*-X\s*DELETE\b/i,
];

// Marcador como asignación de entorno al inicio de un comando (inicio de línea
// o tras ; & |), admitiendo otras asignaciones VAR=valor previas.
const CONFIRMED = /(^|[;&|])\s*([A-Za-z_]\w*=\S*\s+)*PLEX_CREW_CONFIRMED=1\s/;

let raw = '';
process.stdin.on('data', c => (raw += c));
process.stdin.on('end', () => {
  let cmd = '';
  try {
    const payload = JSON.parse(raw);
    cmd = (payload.tool_input && payload.tool_input.command) || '';
  } catch {
    process.exit(0);
  }
  if (!DESTRUCTIVE.some(re => re.test(cmd))) process.exit(0);
  if (CONFIRMED.test(cmd)) process.exit(0);
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PreToolUse',
        permissionDecision: 'deny',
        permissionDecisionReason:
          'Comando destructivo bloqueado. Regla del stack: doble confirmación del usuario en dos mensajes distintos antes de ejecutarlo. ' +
          'Si el usuario ya ha confirmado dos veces, en dos mensajes distintos y de forma explícita, reintenta el mismo comando anteponiendo `PLEX_CREW_CONFIRMED=1 ` ' +
          '(por ejemplo `PLEX_CREW_CONFIRMED=1 <comando>`). ' +
          'No pongas ese marcador sin una doble confirmación real: ni por iniciativa propia ni tras una sola respuesta del usuario. ' +
          'Si todavía no hay confirmación, NO ejecutes el comando: devuelve al orquestador la propuesta (qué se borra o modifica, con las rutas exactas) para que pida las dos confirmaciones al usuario.',
      },
    })
  );
  process.exit(0);
});
