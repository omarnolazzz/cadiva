# Supabase de Cadiva

Proyecto: `neojwbolatrirydjelpk` (región us-east-1).

Las migraciones están numeradas y se aplican en orden en **SQL Editor** del panel. Ya están aplicadas en el proyecto; este directorio sirve para recrear el servidor desde cero o para revisar qué tiene.

| Archivo | Qué hace |
|---|---|
| `001_tablas_y_rls.sql` | Tablas `productos` y `compras`, trigger de `modificado` y políticas RLS: cada cuenta solo ve sus filas. |
| `002_fotos_storage.sql` | Columna `foto` (huella) y la cubeta privada `fotos/<usuario>/<producto>.jpg` con sus políticas. |
| `003_seguimiento.sql` | Columna `seguimiento`: si el producto lleva duración o solo precio, cuando se eligió a mano. |
| `004_ofertas.sql` | Columna `oferta` en compras: la oferta (2 por S/ 4, 3x2, descuento…) en JSON. |

Una migración nueva va en el siguiente número (`005_…sql`) y nunca se edita una ya aplicada.

Las columnas `unidad` y `duracion_estimada_dias` de `productos` quedaron sin uso desde que la app dejó de manejarlas. Se conservan para que versiones anteriores de la app sigan sincronizando; se pueden borrar más adelante con una migración.

Además del SQL, el proyecto necesita en **Authentication**:
- URL Configuration → Site URL y Redirect URLs: `cadiva://auth`.
- Providers → Google activado con el ID y secreto del cliente OAuth web de Google Cloud.
