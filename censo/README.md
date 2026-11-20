# Censo Albemarle · 3 apps vinculadas (v5.0.0)

Sistema del Campamento Albemarle (Newrest) separado en tres apps que comparten
la misma base de datos Supabase (`censo-albemarle-2026`).

| Carpeta | App | Quién entra |
|---|---|---|
| `censo/` | Censo de habitaciones | Operación, Supervisión, Gerencia, App Manager |
| `mantencion/` | Órdenes de trabajo (pabellones y áreas comunes) | Jefe de Operaciones, Mantención, Gerencia, App Manager |
| `areas-comunes/` | Reportes de áreas comunes y casino | Operación, Supervisión, Jefe de Operaciones, Gerencia, App Manager |
| `supabase/` | Estructura de la base y consultas de verificación | — |

## Cómo se vinculan

- Un reporte de mantención en **Censo** o en **Áreas comunes** crea la OT al
  instante en Supabase, y la app de **Mantención** la recibe por Realtime (con aviso sonoro).
- Los links de WhatsApp de cada OT abren directamente la app de Mantención.
- Las claves de cada nivel son las mismas en las tres apps (`epp_config.censo_claves`).
- Las URL de las tres apps se leen de `epp_config` (`clave = 'campos_apps'`).
  Si cambian, se actualiza esa fila, no el código.

## Publicar en Netlify (un sitio por carpeta, desde este repositorio)

En Netlify: **Add new site → Import an existing project → GitHub → campos-ecosistema**.
Crea un sitio por app con esta configuración:

| Sitio | Branch | Base directory | Build command | Publish directory |
|---|---|---|---|---|
| censo-2026 (el actual) | main | `censo/censo` | *(vacío)* | `censo/censo` |
| mantencion-albemarle-6d34 | main | `censo/mantencion` | *(vacío)* | `censo/mantencion` |
| areas-albemarle | main | `censo/areas-comunes` | *(vacío)* | `censo/areas-comunes` |

Desde ese momento cada `git push` a `main` actualiza las tres apps solas.

## Base de datos

`supabase/campos_censo_supabase.sql` documenta la estructura real de la base
(ya aplicada): tablas, índices, funciones, triggers, seguridad (RLS) y Realtime.
La sección 9 trae consultas para revisar que todo quede guardado; por ejemplo,
la 9.3 muestra la historia completa de una habitación desde la tabla `auditoria_censo`.

## Pendiente de seguridad

Si un nivel no tiene clave guardada en la nube, la app usa una clave por defecto
escrita en el código. Hoy solo **Jefe de Operaciones** tiene clave en la nube.
Entra como App Manager → Configuración y define las claves de Supervisión,
Gerencia, App Manager y Mantención para que las del código dejen de servir.
