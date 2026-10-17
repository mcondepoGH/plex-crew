// Clasificación por NOMBRE de las tools MCP de zurg (prefijo `mcp__zurg__`), compartida por
// confirm-destructive.js y enforce-agent-scope.js. El MCP debe registrarse con el nombre `zurg`.
// Nombres tomados de la tabla de skills/zurg/SKILL.md. Lo que no está en ninguna lista es
// DESCONOCIDO y se trata como destructivo (fallo cerrado), incluidos los nombres "por confirmar".
const PREFIX = 'mcp__zurg__';

// Solo lectura: pasan sin marcador.
const READ_ONLY = new Set([
  'server_info',
  'library_status',
  'library_directories',
  'provider_health',
  'zurg_library_search',
  'zurg_plex_match_release',
  'zurg_plex_status',
  'zurg_repair_status',
  'zurg_mount_status',
  'zurg_clients_paths',
]);

// Renombrado: permitido sin marcador (queda en el log); para plex-naming, sujeto a scope.conf.
const RENAME = new Set(['zurg_release_rename', 'zurg_release_files_rename']);

const isZurg = tool => typeof tool === 'string' && tool.startsWith(PREFIX);
const shortName = tool => tool.slice(PREFIX.length);
const kind = tool => {
  const n = shortName(tool);
  if (READ_ONLY.has(n)) return 'read';
  if (RENAME.has(n)) return 'rename';
  return 'other'; // escritura, destructiva o desconocida
};

// Recorre el tool_input y llama a fn(clave, valor) con cada valor string.
function walk(v, fn, key = '') {
  if (typeof v === 'string') fn(key, v);
  else if (Array.isArray(v)) v.forEach(x => walk(x, fn, key));
  else if (v && typeof v === 'object') for (const [k, x] of Object.entries(v)) walk(x, fn, k);
}

// El marcador cuenta si aparece en algún valor string del input (no en claves).
function hasMarker(input) {
  let found = false;
  walk(input, (_k, s) => {
    if (s.includes('PLEX_CREW_CONFIRMED=1')) found = true;
  });
  return found;
}

const PATH_KEYS = /^(path|paths|from|to|src|source|dest|destination|new_path|old_path|newpath|oldpath|target|directory|dir|folder|file|filepath|file_path)$/i;

// Valores de campos de ruta que parecen ruta (contienen `/`); los nombres sueltos no cuentan.
function pathValues(input) {
  const out = [];
  walk(input, (k, s) => {
    if (PATH_KEYS.test(k) && s.includes('/')) out.push(s);
  });
  return out;
}

module.exports = { isZurg, shortName, kind, hasMarker, pathValues, READ_ONLY, RENAME };
