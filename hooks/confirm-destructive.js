// PreToolUse (Bash): pide confirmación explícita antes de comandos destructivos.
const fs = require('fs');

const DESTRUCTIVE = [
  /\brm\s+(-[a-zA-Z]*[rf][a-zA-Z]*\s+)/,
  /\brm\s+\S/,
  /\bunlink\b/,
  /\bshred\b/,
  /\btruncate\b/,
  /\bmkfs\b/,
  /\bdd\s+.*\bof=/,
  /\bgit\s+(reset\s+--hard|clean\s+-[a-z]*f|push\s+.*--force|push\s+-f|checkout\s+--\s|restore\s)/,
  /\bdocker(-compose)?\s+(rm|rmi|down|stop|kill|restart|system\s+prune|volume\s+rm)\b/,
  /\bdocker\s+compose\s+(down|rm|stop|kill|restart)\b/,
  /\b(chown|chmod)\s+(-[a-zA-Z]*R|.*\s-R)\b/,
  /\bfind\b.*(-delete|-exec\s+rm)/,
  /(^|[^<0-9])>\s*(?!\/dev\/null)[^&\s|]/,
  /\bDELETE\s+FROM\b|\bDROP\s+(TABLE|DATABASE)\b/i,
  /\bcurl\b.*-X\s*(DELETE|PUT|POST)\b/i,
];

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
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PreToolUse',
        permissionDecision: 'ask',
        permissionDecisionReason:
          'Comando potencialmente destructivo. Regla del stack: doble confirmación explícita del usuario antes de ejecutarlo.',
      },
    })
  );
  process.exit(0);
});
