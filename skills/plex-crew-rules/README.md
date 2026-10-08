# Skill plex-crew-rules

Reglas globales de plex-crew que aplican a todos los agentes. No tiene scripts.

## Qué hace

- **Idioma** — Responde siempre en español
- **Zona horaria** — Las horas del usuario son Europe/Madrid
- **Doble confirmación** — Dos mensajes distintos del usuario antes de cualquier operación destructiva
- **Marcador** — `PLEX_CREW_CONFIRMED=1` solo después de esa confirmación
- **Secretos** — Nunca se imprimen, registran ni versionan
- **Tareas programadas** — Sin `schedule` ni `RemoteTrigger` para tareas de red local
- **Carpetas ignoradas** — Cualquier carpeta `.@*` (caché del NAS)

Sustituye al `CLAUDE.md` del repositorio, que un plugin instalado no carga como contexto.

## Configuración

No necesita configuración. Los tres agentes (`orchestrator`, `plex-naming` y `arr-acquisition`) la cargan con el campo `skills:` de su definición.

## Ejemplos de uso

Un subagente detecta que hay que borrar una película con sus ficheros: no la borra, devuelve la propuesta al orquestador, que pide dos confirmaciones y después delega la orden con `PLEX_CREW_CONFIRMED=1`.

El usuario pide "a las 22:00": significa las 22:00 Europe/Madrid.

## Referencia de la API

La referencia detallada está en el directorio `references/`:

- **[Referencia rápida](./references/quick-reference.md)** - Reglas de un vistazo
- **[Resolución de problemas](./references/troubleshooting.md)** - Comandos bloqueados y errores habituales

## Flujo de trabajo

1. Un subagente propone una operación destructiva con rutas exactas
2. El orquestador pide dos confirmaciones en dos mensajes distintos
3. Solo entonces se delega la orden y el comando lleva el marcador
4. El hook `confirm-destructive` deniega el comando si falta el marcador

## Resolución de problemas

**Comando bloqueado por `confirm-destructive`**
→ Aún no hay doble confirmación; devuelve la propuesta al orquestador

**Se interpretó mal una hora**
→ Las horas son Europe/Madrid; no conviertas desde otra zona

## Notas

- Consulta [`hooks/README.md`](../../hooks/README.md) para el hook que exige el marcador
- Reglas específicas de servicio: [`plex-naming-rules`](../plex-naming-rules/README.md)

## Licencia

MIT
