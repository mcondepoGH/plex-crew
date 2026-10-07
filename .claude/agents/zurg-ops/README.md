# Operaciones de zurg (`zurg-ops`)

Especialista en zurg y el mount de Real-Debrid: diagnóstico, estado, releases, configuración, backups y errores de import de Radarr/Sonarr ligados a zurg.

## Cuándo se usa y qué no hace

Ejemplos:

- "Revisa el estado de zurg" o "pasa el doctor".
- "¿Por qué Radarr no importa desde el mount?" (rutas de los clientes).
- "Cambia esta clave de configuración" (con backup previo).
- "¿Cuánta cuota queda en el proveedor?"

Límites:

- No tiene tools de borrado, restauración ni reinicio: devuelve la propuesta al orquestador para la doble confirmación.
- No renombra nombres de Plex (eso es [`plex-naming`](../plex-naming/README.md)).
- Opera solo con tools `mcp__zurg__*`; no tiene `Bash` ni `Edit`.

## Funciones

- Empezar siempre por lectura con estas tools:
  - `zurg_system_doctor`
  - `zurg_mount_status`
  - `zurg_clients_paths`
  - `zurg_diagnostics_logs`
- Diagnosticar proveedores, tráfico, proceso y memoria.
- Consultar la biblioteca y releases concretos.
- Cambiar configuración: backup previo con `zurg_system_backup_create` y mostrar el cambio antes de aplicarlo.
- Informar con datos exactos (clave, valor anterior, valor nuevo, resultado).

## Tools

- Lectura de ficheros:
  - `Read`: leer ficheros
  - `Glob`: localizar ficheros por patrón
  - `Grep`: buscar contenido

### Tools `mcp__zurg__*`

- `clients`
  - `zurg_clients_paths`: rutas que ven Radarr/Sonarr y su relación con el mount
  - `zurg_clients_status`: estado de la integración con los clientes
  - `zurg_clients_qbittorrent_jobs`: trabajos de la API tipo qBittorrent
  - `zurg_clients_sabnzbd_jobs`: trabajos de la API tipo SABnzbd
- `config`
  - `zurg_config_drift`: diferencias entre la configuración en uso y la guardada
  - `zurg_config_file`: ver el fichero de configuración
  - `zurg_config_get`: leer una clave
  - `zurg_config_keys`: listar las claves disponibles
  - `zurg_config_set`: cambiar una clave (requiere backup previo)
- `diagnostics`
  - `zurg_diagnostics_logs`: leer los logs
  - `zurg_diagnostics_traffic`: tráfico del servicio
  - `zurg_diagnostics_process`: información del proceso
  - `zurg_diagnostics_memory`: uso de memoria
- `library`
  - `zurg_library_list`: listar releases
  - `zurg_library_search`: buscar releases
  - `zurg_library_status`: estado de la biblioteca
- `mount`
  - `zurg_mount_status`: estado del montaje
- `plex`
  - `zurg_plex_status`: estado de la integración con Plex
- `provider`
  - `zurg_provider_account`: cuenta y cuota del proveedor
  - `zurg_provider_health`: salud de los proveedores
  - `zurg_provider_list`: listar proveedores
  - `zurg_provider_test`: probar un proveedor
  - `zurg_provider_traffic`: tráfico por proveedor
- `release`
  - `zurg_release_get`: datos de un release
  - `zurg_release_files`: ficheros de un release
- `repair`
  - `zurg_repair_status`: estado de las reparaciones
  - `zurg_repair_outlook`: previsión de reparaciones
- `server`
  - `zurg_server_info`: información del servidor
- `system`
  - `zurg_system_backups`: listar backups
  - `zurg_system_backup_create`: crear un backup
  - `zurg_system_doctor`: chequeo general

## Skills que usa

- [`zurg-rules`](../../skills/zurg-rules/README.md)

## Hooks y salvaguardas

| Salvaguarda | Efecto |
|---|---|
| `confirm-destructive` | Registrado para `Bash` en todo el proyecto; este agente no tiene `Bash`, así que no le afecta en la práctica |
| [`enforce-agent-scope`](../../../hooks/README.md#enforce-agent-scopejs) | No está registrado en este agente (solo en `plex-naming`) |
| Doble confirmación | Al no tener tools destructivas, cualquier borrado, restauración o reinicio se propone al orquestador, que pide dos confirmaciones al usuario |

## Colaboración con otros agentes

- Lo invoca el orquestador con `Agent`; no lanza subagentes.
- Si el problema es de nombres de Plex, lo devuelve para que el orquestador lo derive a `plex-naming`; si es de adquisición, a `arr-acquisition`.
- Propone las operaciones destructivas; la ejecución, tras la doble confirmación, la ordena el orquestador.
