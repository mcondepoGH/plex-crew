# Skill de Plex

Controla y supervisa tu Plex Media Server.

## Qué hace

- **Explorar** — Ver bibliotecas y secciones
- **Buscar** — Encontrar películas, series y música en todas las bibliotecas
- **Estado** — Comprobar las sesiones de reproducción activas y la información del servidor
- **Añadido recientemente** — Ver el contenido más reciente añadido a las bibliotecas
- **On Deck** — Ver el contenido pendiente de continuar
- **Clientes** — Listar los clientes/reproductores de Plex disponibles

Todas las operaciones son de solo lectura y usan la API de Plex Media Server.

## Configuración

### 1. Obtén tu token de Plex

**Opción A: desde plex.tv**
1. Ve a https://plex.tv/claim
2. Inicia sesión en tu cuenta de Plex
3. Copia el token de reclamación (empieza por `claim-`)

**Opción B: desde el XML de la app de Plex**
1. Abre cualquier elemento multimedia en tu app de Plex
2. Consulta el código fuente de la página o inspecciona el tráfico de red
3. Busca `X-Plex-Token` en el XML o en las cabeceras
4. Copia el valor del token

### 2. Define las variables de entorno

Crea tu configuración de Plex:

```bash
export PLEX_URL="http://192.168.1.100:32400"
export PLEX_TOKEN="<your_plex_token>"
```

O añádelas al perfil de tu shell (`~/.bashrc`, `~/.zshrc`):

```bash
echo 'export PLEX_URL="http://192.168.1.100:32400"' >> ~/.bashrc
echo 'export PLEX_TOKEN="<your_plex_token>"' >> ~/.bashrc
source ~/.bashrc
```

**Opciones de configuración:**
- `PLEX_URL`: URL de tu servidor Plex (formato: `http://IP:PUERTO`, puerto por defecto: 32400)
- `PLEX_TOKEN`: tu token de autenticación de Plex

### 3. Pruébalo

```bash
curl -s "$PLEX_URL/?X-Plex-Token=$PLEX_TOKEN" -H "Accept: application/json"
```

## Ejemplos de uso

Todos los ejemplos usan `curl` con tus variables de entorno.

### Obtener la información del servidor

```bash
curl -s "$PLEX_URL/?X-Plex-Token=$PLEX_TOKEN" \
  -H "Accept: application/json" | jq
```

### Explorar bibliotecas

Lista todas las secciones de biblioteca (Películas, Series, Música, etc.):

```bash
curl -s "$PLEX_URL/library/sections?X-Plex-Token=$PLEX_TOKEN" \
  -H "Accept: application/json" | jq
```

### Listar el contenido de una biblioteca

```bash
# Sustituye 1 por la clave de tu sección de biblioteca obtenida arriba
curl -s "$PLEX_URL/library/sections/1/all?X-Plex-Token=$PLEX_TOKEN" \
  -H "Accept: application/json" | jq
```

### Buscar

Busca en todas las bibliotecas:

```bash
curl -s "$PLEX_URL/search?query=Inception&X-Plex-Token=$PLEX_TOKEN" \
  -H "Accept: application/json" | jq
```

### Obtener lo añadido recientemente

Consulta el contenido más reciente añadido a tus bibliotecas:

```bash
curl -s "$PLEX_URL/library/recentlyAdded?X-Plex-Token=$PLEX_TOKEN" \
  -H "Accept: application/json" | jq
```

### Obtener On Deck (continuar viendo)

```bash
curl -s "$PLEX_URL/library/onDeck?X-Plex-Token=$PLEX_TOKEN" \
  -H "Accept: application/json" | jq
```

### Obtener las sesiones activas

Consulta qué se está reproduciendo:

```bash
curl -s "$PLEX_URL/status/sessions?X-Plex-Token=$PLEX_TOKEN" \
  -H "Accept: application/json" | jq
```

### Listar los clientes disponibles

Consulta todos los clientes/reproductores de Plex conectados:

```bash
curl -s "$PLEX_URL/clients?X-Plex-Token=$PLEX_TOKEN" \
  -H "Accept: application/json" | jq
```

## Flujo de trabajo

Cuando un usuario pregunte por Plex:

1. **"¿Qué hay en Plex?"** → Obtén lo añadido recientemente
2. **"Busca una película"** → Busca el título
3. **"¿Qué se está reproduciendo?"** → Obtén las sesiones activas
4. **"Muestra mis bibliotecas"** → Explora las bibliotecas
5. **"Continuar viendo"** → Obtén los elementos de On Deck

## Tipos de sección de biblioteca

Tipos de biblioteca habituales (las claves de sección varían según la configuración):
- **Películas** (normalmente la sección 1)
- **Series** (normalmente la sección 2)
- **Música** (normalmente la sección 3)
- **Fotos** (normalmente la sección 4)

Ejecuta el comando de exploración para ver las claves de sección de tu servidor.

## Referencia de la API

Hay documentación detallada de la API en el directorio `references/`:

- **[Endpoints de la API](./references/api-endpoints.md)** - Referencia completa de endpoints
- **[Referencia rápida](./references/quick-reference.md)** - Operaciones habituales con ejemplos listos para copiar y pegar
- **[Resolución de problemas](./references/troubleshooting.md)** - Soluciones a problemas de autenticación, conexión y errores comunes

## Formato de respuesta de la API

### Salida JSON

Añade `-H "Accept: application/json"` para obtener respuestas JSON (por defecto es XML):

```bash
curl -s "$PLEX_URL/endpoint?X-Plex-Token=$PLEX_TOKEN" \
  -H "Accept: application/json"
```

### Claves de contenido

Los elementos multimedia se referencian con claves como `/library/metadata/12345`. Usa estas claves para operar sobre elementos concretos.

## Resolución de problemas

**"Unauthorized" o error 401**
→ Tu token de Plex no es válido o ha caducado: genera uno nuevo

**"Connection refused"**
→ Comprueba la URL del servidor y asegúrate de que Plex Media Server está en ejecución

**"Empty response"**
→ Puede que la clave de la sección de biblioteca sea incorrecta: ejecuta el comando de exploración para ver las secciones disponibles

**El token no funciona**
→ Asegúrate de que no hay comillas ni espacios extra en el token

## Notas

- Plex Media Server usa el puerto 32400 por defecto
- Las claves de sección de biblioteca (1, 2, 3...) varían según la configuración del servidor
- Todas las operaciones son de solo lectura y seguras para supervisar
- Para controlar la reproducción, debes apuntar a un cliente concreto
- Las respuestas JSON son más claras que el XML por defecto
- Requiere `curl` y, opcionalmente, `jq` para procesar JSON

## Seguridad

- No expongas nunca tu token de Plex en registros ni commits
- Usa variables de entorno para las credenciales
- Mantén tu token seguro: concede acceso completo a tu servidor
- Considera usar el token de una cuenta restringida si está disponible

## Licencia

MIT
