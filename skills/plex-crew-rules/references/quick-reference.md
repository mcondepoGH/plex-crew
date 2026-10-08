# Referencia rápida de plex-crew-rules

Reglas de un vistazo.

| Regla | Qué exige | Cuándo aplica |
|-------|-----------|---------------|
| Idioma | Responder siempre en español | Siempre |
| Hora | Las horas del usuario son Europe/Madrid; no preguntes la zona | Crons, programaciones, logs |
| Doble confirmación | Dos mensajes distintos del usuario, incluso en modo automático | Operaciones destructivas |
| Marcador | `PLEX_CREW_CONFIRMED=1 ` antes del comando, solo tras la confirmación; con `cd`, después del `&&` | Comandos `Bash` destructivos |
| Secretos | Viven en `~/.claude/plex-crew/.env`; nunca se imprimen, registran ni versionan | Siempre |
| Tareas programadas | Sin `schedule` ni `RemoteTrigger` para tareas de red local | Programación |
| Carpetas `.@*` | Se ignoran: caché del NAS | Cualquier listado o renombrado |

## Colocación del marcador

```bash
# Correcto
PLEX_CREW_CONFIRMED=1 bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" remove 603
(cd "${CLAUDE_PLUGIN_ROOT}/skills/radarr" && PLEX_CREW_CONFIRMED=1 bash scripts/radarr.sh remove 603)

# Incorrecto: el marcador no está al inicio de un comando
bash scripts/radarr.sh remove 603 PLEX_CREW_CONFIRMED=1
```

## Comandos que el hook bloquea sin el marcador

`rm`, `unlink`, `shred`, `truncate`, `mkfs`, `dd of=`, `git` destructivo (`reset --hard`, `clean -f`, `push --force`, `checkout --`, `restore`), `docker rm/rmi/down/kill/system prune/volume rm`, `find -delete`, SQL `DELETE FROM` / `DROP`, `curl -X DELETE`, `radarr.sh remove`, `sonarr.sh remove` y `prowlarr-api.sh delete`.
