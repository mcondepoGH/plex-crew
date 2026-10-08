# Resolución de problemas de plex-crew-rules

## Problemas con los hooks

### "Comando destructivo bloqueado"
**Causa:** El hook `confirm-destructive` encontró un comando destructivo sin el marcador `PLEX_CREW_CONFIRMED=1`

**Solución:**
1. No ejecutes el comando
2. Devuelve la propuesta (qué se borra o modifica, con rutas exactas) al orquestador
3. El orquestador pide al usuario dos confirmaciones en dos mensajes distintos
4. Solo entonces reintenta el mismo comando anteponiendo `PLEX_CREW_CONFIRMED=1 `

### Marcador presente pero sigue bloqueado
**Causa:** El marcador no está al inicio de un comando

**Solución:**
1. Debe ser una asignación de entorno al inicio del comando, o justo después de `;`, `&` o `|`
2. Con un `cd`, colócalo después del `&&`: `(cd "..." && PLEX_CREW_CONFIRMED=1 bash scripts/radarr.sh remove 123)`
3. No lo pongas al final del comando

### Escritura denegada para `plex-naming`
**Causa:** El hook `enforce-agent-scope` solo deja a ese agente escribir bajo las rutas de `scope.conf`

**Solución:**
1. No intentes eludirlo; devuélvelo al orquestador
2. Comprueba que `~/.claude/plex-crew/scope.conf` tiene una ruta absoluta por línea
3. Sin rutas configuradas, toda escritura se deniega; copia `scope.conf.example` y ajústalo

## Errores habituales

### Preguntar al usuario la zona horaria
**Causa:** Olvidar que las horas son Europe/Madrid

**Solución:** Usa Europe/Madrid y no preguntes.

### Una tarea programada no alcanza el homelab
**Causa:** Se creó con `schedule` o `RemoteTrigger`, que se ejecutan en la nube

**Solución:** Usa `CronCreate` desde el orquestador.
