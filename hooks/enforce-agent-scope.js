// PreToolUse (Edit|Write|NotebookEdit): solo permite escribir bajo las rutas pasadas como argumentos.
// Uso: node enforce-agent-scope.js <ruta-absoluta-permitida>...
const path = require('path');

const ALLOWED = process.argv
  .slice(2)
  .map(p => path.resolve(p));

function out(decision, reason) {
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PreToolUse',
        permissionDecision: decision,
        permissionDecisionReason: reason,
      },
    })
  );
}

let raw = '';
process.stdin.on('data', c => (raw += c));
process.stdin.on('end', () => {
  let target = '';
  try {
    const input = JSON.parse(raw).tool_input || {};
    target = input.file_path || input.notebook_path || '';
  } catch {
    process.exit(0);
  }
  if (!target) process.exit(0);

  const resolved = path.resolve(target);
  const ok = ALLOWED.some(a => resolved === a || resolved.startsWith(a + path.sep));
  if (ok) process.exit(0);

  out('deny', `Ruta fuera del alcance de este agente: ${resolved}. Permitido: ${ALLOWED.join(', ') || '(ninguna)'}.`);
  process.exit(0);
});
