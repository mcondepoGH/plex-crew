# Referencia rápida de arr-language-filters

Filtros de cada sistema de un vistazo. Las reglas concretas son las que haya configurado cada usuario; aquí se indica dónde mirar.

## cli_debrid

| Regla | Qué exige | Cuándo aplica |
|-------|-----------|---------------|
| `filter_in` binario | El nombre debe cumplir tus patrones; si no, no pasa y no hay fallback a otro idioma | Todo release |
| `filter_out` | Rechaza los nombres que cumplan tus patrones de exclusión | Todo release |
| Posición de los subs | Si tus reglas distinguen palabras de subs según su posición respecto a la palabra de idioma, el orden en el nombre decide | Según tu configuración |
| Por tipo | `filter_in` y `filter_out` pueden variar entre series, películas y anime | Según tu configuración |
| Scrapers | Cada scraper activo es una fuente de candidatos (vía Prowlarr o conexión directa) | Fuentes de candidatos |

## Radarr y Sonarr

| Regla | Qué exige | Cuándo aplica |
|-------|-----------|---------------|
| Perfiles | `qualityprofiles` lista tus perfiles con su `minFormatScore` y las puntuaciones de sus formatos | Al añadir o cambiar de perfil |
| Formatos personalizados | `customformats` lista tus formatos; el de idioma aporta la puntuación que exige el perfil | Puntuación del grab |
| `minFormatScore` | Puntuación mínima del perfil; si es mayor que 0 actúa como bloqueo duro | Rechazos aparentes |
| Formato de puntuación negativa (opcional) | Si tienes uno para evitar bloqueos de un servicio externo, revisa sus condiciones | Releases bloqueados por ese servicio |
| Cambio de perfil de una serie existente | PUT sobre la serie (`qualityProfileId`), no `add` | Series existentes |

## Indexadores que solo aceptan ids (p. ej. Torrentio en Prowlarr)

- Torrentio solo funciona por id de IMDb/Kitsu; una búsqueda de texto libre puede devolver un título que no es el buscado
- Con indexadores que solo aceptan ids, usa `imdbid`; si devuelve el título equivocado, comprueba que la consulta lleva el id de IMDb

## Sincronización del mount con Radarr

1. Por lotes, con un fichero de seguimiento
2. Duplicados: conserva el confirmado en el idioma deseado con la mayor resolución
3. Ambiguos: ignóralos e infórmalos al final del lote
4. Año erróneo: corrígelo; no sobrescribas un destino existente
5. Packs con varias películas: sepáralos solo con certeza
6. Informa de cada lote al detalle
