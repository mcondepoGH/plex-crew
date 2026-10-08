---
name: plex-crew-rules
description: Esta skill debe usarse en cualquier tarea de plex-crew. Contiene las reglas globales que aplican a todos los agentes. Úsala cuando se opere sobre el homelab Plex, y cuando el usuario pida "reglas globales", "doble confirmación", "idioma", "zona horaria", o mencione el marcador PLEX_CREW_CONFIRMED, secretos, tareas programadas o carpetas .@*.
---

# Skill de reglas globales de plex-crew

**⚠️ INVOCACIÓN OBLIGATORIA DE LA SKILL ⚠️**

**DEBES invocar esta skill (no es opcional) en cualquier tarea de plex-crew.** Los agentes la cargan al arrancar (campo `skills:`).

**Si no aplicas estas reglas, incumples tus requisitos operativos.**

Reúne las reglas que aplican al orquestador y a los dos especialistas, con independencia del servicio sobre el que operen.

## Propósito

Esta skill fija las reglas transversales del proyecto:
- Idioma y zona horaria de las respuestas
- Doble confirmación de las operaciones destructivas y uso del marcador
- Manejo de secretos
- Tareas programadas
- Carpetas que se ignoran

## Configuración

Sin configuración ni variables de entorno. Los secretos viven en `~/.claude/plex-crew/.env` (o en la ruta de `HOMELAB_ENV`).

## Reglas

### Idioma y hora
- Responde siempre en español.
- Las horas que menciona el usuario son Europe/Madrid (Sevilla). No preguntes la zona horaria.

### Doble confirmación y marcador
- Toda operación destructiva exige dos mensajes distintos del usuario, incluso en modo automático. Una sola respuesta no basta.
- Solo después de esa doble confirmación, antepón `PLEX_CREW_CONFIRMED=1 ` al comando. Si el comando usa `cd`, el marcador va justo antes del comando destructivo, después del `&&`: `(cd "..." && PLEX_CREW_CONFIRMED=1 bash scripts/radarr.sh remove 123)`.
- El hook `confirm-destructive` bloquea el comando sin el marcador. No lo añadas nunca por iniciativa propia ni tras una sola respuesta.
- Un subagente no pide la confirmación: devuelve la propuesta (qué se borra o modifica, con rutas exactas) al orquestador, que es quien pregunta al usuario.

### Secretos
- No los imprimas, no los registres en logs ni los escribas en ficheros versionados. No muestres el contenido del `.env`.
- Opera los servicios con las skills (`radarr`, `sonarr`, `prowlarr`, `plex`, `tautulli`, `seerr`, `cli_debrid`), no con `curl` y claves en línea.

### Tareas programadas
No uses `schedule` ni `RemoteTrigger` para tareas que necesiten la red local: se ejecutan en la nube y no alcanzan el homelab. Las tareas programadas del orquestador usan `CronCreate`.

### Carpetas ignoradas
Ignora cualquier carpeta `.@*` (por ejemplo `.@__thumb`): son caché del NAS. No las listes, no las renombres ni las incluyas en los resultados.

## Flujo de trabajo

1. **El subagente encuentra algo destructivo** → No lo ejecutes; devuelve la propuesta al orquestador
2. **Orquestador** → Pide al usuario dos confirmaciones en dos mensajes distintos
3. **Tras las dos confirmaciones** → Delega la orden de forma explícita; el comando se ejecuta con `PLEX_CREW_CONFIRMED=1`
4. **El usuario indica una hora** → Es Europe/Madrid; no preguntes

## Notas

- El hook `confirm-destructive` es una red de seguridad, no un sandbox
- Estas reglas sustituyen al `CLAUDE.md` del repositorio, que un plugin instalado no carga como contexto
- Las reglas específicas de cada servicio viven en sus propias skills (`plex-naming-rules`, `arr-language-filters`)

## Referencia

Para la referencia local detallada, consulta:
- **[Referencia rápida](./references/quick-reference.md)** - Reglas de un vistazo
- **[Resolución de problemas](./references/troubleshooting.md)** - Comandos bloqueados y errores habituales
- Documentación del hook: `hooks/README.md`

## Lo que NO hay que hacer

- No ejecutes una operación destructiva sin dos confirmaciones en mensajes distintos
- No antepongas `PLEX_CREW_CONFIRMED=1` sin esa doble confirmación
- No imprimas credenciales ni el contenido del `.env`
- No programes con `schedule` ni `RemoteTrigger` nada que necesite la red local
- No toques las carpetas `.@*`
