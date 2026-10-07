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

- Empezar siempre por lectura: `zurg_system_doctor`, `zurg_mount_status`, `zurg_clients_paths`, `zurg_diagnostics_logs`.
- Diagnosticar proveedores, tráfico, proceso y memoria.
- Consultar la biblioteca y releases concretos.
- Cambiar configuración: backup previo con `zurg_system_backup_create` y mostrar el cambio antes de aplicarlo.
- Tratar el "Unable to connect" cerca de las 12:00 Madrid como el reinicio diario: esperar y reintentar.
- Informar con datos exactos (clave, valor anterior, valor nuevo, resultado).

## Tools

| Tool | Para qué sirve |
|---|---|
| `Read`, `Glob`, `Grep` | Leer y localizar ficheros |

### Tools `mcp__zurg__*`

| Prefijo | Tool | Uso |
|---|---|---|
| `clients` | `zurg_clients_paths` | Rutas que ven Radarr/Sonarr y su relación con el mount |
| `clients` | `zurg_clients_status` | Estado de la integración con los clientes |
| `clients` | `zurg_clients_qbittorrent_jobs` | Trabajos de la API tipo qBittorrent |
| `clients` | `zurg_clients_sabnzbd_jobs` | Trabajos de la API tipo SABnzbd |
| `config` | `zurg_config_drift` | Diferencias entre la configuración en uso y la guardada |
| `config` | `zurg_config_file` | Ver el fichero de configuración |
| `config` | `zurg_config_get` | Leer una clave |
| `config` | `zurg_config_keys` | Listar las claves disponibles |
| `config` | `zurg_config_set` | Cambiar una clave (requiere backup previo) |
| `diagnostics` | `zurg_diagnostics_logs` | Leer los logs |
| `diagnostics` | `zurg_diagnostics_traffic` | Tráfico del servicio |
| `diagnostics` | `zurg_diagnostics_process` | Información del proceso |
| `diagnostics` | `zurg_diagnostics_memory` | Uso de memoria |
| `library` | `zurg_library_list` | Listar releases |
| `library` | `zurg_library_search` | Buscar releases |
| `library` | `zurg_library_status` | Estado de la biblioteca |
| `mount` | `zurg_mount_status` | Estado del montaje |
| `plex` | `zurg_plex_status` | Estado de la integración con Plex |
| `provider` | `zurg_provider_account` | Cuenta y cuota del proveedor |
| `provider` | `zurg_provider_health` | Salud de los proveedores |
| `provider` | `zurg_provider_list` | Listar proveedores |
| `provider` | `zurg_provider_test` | Probar un proveedor |
| `provider` | `zurg_provider_traffic` | Tráfico por proveedor |
| `release` | `zurg_release_get` | Datos de un release |
| `release` | `zurg_release_files` | Ficheros de un release |
| `repair` | `zurg_repair_status` | Estado de las reparaciones |
| `repair` | `zurg_repair_outlook` | Previsión de reparaciones |
| `server` | `zurg_server_info` | Información del servidor |
| `system` | `zurg_system_backups` | Listar backups |
| `system` | `zurg_system_backup_create` | Crear un backup |
| `system` | `zurg_system_doctor` | Chequeo general |

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
