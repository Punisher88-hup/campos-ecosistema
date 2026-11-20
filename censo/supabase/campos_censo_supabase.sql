-- ═══════════════════════════════════════════════════════════════════════════
-- campOS · Censo / Mantención / Áreas comunes — Base de datos Supabase
-- Proyecto: censo-albemarle-2026 (rnfzpfxgyrspckwksecz) · región sa-east-1
-- Exportado: 2026-11-20 · v5.0.0
--
-- Este archivo es la ESTRUCTURA REAL que hoy tiene la base (tablas, índices,
-- funciones, triggers, seguridad y Realtime). Todo ya está aplicado en Supabase:
-- sirve como respaldo/documentación y para recrear la base desde cero.
-- Al final hay consultas de VERIFICACIÓN para revisar que todo quedó guardado.
--
-- Las 3 apps comparten esta misma base:
--   Censo ............ habitaciones, historial, historial_habitaciones (+ crea OT)
--   Mantención ....... ordenes_trabajo, ordenes_trabajo_areas, mantenciones
--   Áreas comunes .... areas_custom (+ crea OT de áreas)
--   Todas ............ epp_config (claves, contactos WhatsApp, URLs de las apps)
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── 1. SECUENCIAS (correlativos de OT) ─────────────────────────────────────
create sequence if not exists public.ot_correlativo start 1;   -- OT-AAAA-XXXX  (hoy va en 132)
create sequence if not exists public.seq_ot_areas   start 1;   -- OTA-AAAA-XXXX (hoy va en 47)
create sequence if not exists public.cambios_modulo_id_seq start 1;
create sequence if not exists public.cambios_inventario_id_seq start 1;

-- ─── 2. TABLAS ──────────────────────────────────────────────────────────────

-- CENSO: estado actual de cada habitación (se vacía en el cierre diario de las 22:00)
create table if not exists public.habitaciones (
  id text not null,                         -- 'A1-3' = módulo A1, habitación 3
  personas integer,
  bloqueada boolean default false,
  noche boolean default false,
  fecha text,
  fecha_salida text,
  mant_categorias text[],                   -- reporte de mantención de la habitación
  mant_estado text,
  mant_obs text,
  ts bigint,                                -- hora del guardado (celular, en ms)
  updated_at timestamptz default now(),     -- hora real del SERVIDOR (trigger)
  cambios_items jsonb default '{}'::jsonb,  -- (Reposición, en desuso)
  constraint habitaciones_pkey primary key (id)
);

-- CENSO: totales de cada día
create table if not exists public.historial (
  fecha text not null,                      -- 'AAAA-MM-DD'
  persons integer default 0,
  pct integer default 0,
  mant integer default 0,
  noche integer default 0,
  noche_persons integer default 0,
  pabellon text,
  saved text,
  auto_saved boolean default false,
  created_at timestamptz default now(),
  constraint historial_pkey primary key (fecha)
);

-- CENSO: foto de cada habitación de cada día (respaldo antes del cierre)
create table if not exists public.historial_habitaciones (
  id uuid default gen_random_uuid() not null,
  fecha date not null,
  hab_key text not null,
  modulo text,
  piso text,
  habitacion integer,
  personas integer default 0,
  bloqueada boolean default false,
  noche boolean default false,
  mant boolean default false,
  categorias text[] default '{}'::text[],
  obs text,
  creado_at timestamptz default now(),
  constraint historial_habitaciones_pkey primary key (id),
  constraint historial_habitaciones_fecha_hab_key_key unique (fecha, hab_key)
);

-- MANTENCIÓN: OT de habitaciones y pasillos (OT-AAAA-XXXX)
create table if not exists public.ordenes_trabajo (
  id uuid default gen_random_uuid() not null,
  numero_ot text not null,
  mant_id uuid,
  hab_key text not null,
  modulo text not null,
  piso text,
  habitacion integer not null,
  categorias text[] not null,
  obs_inicial text,
  prioridad text default 'Normal'::text,
  tecnico text,
  estado text default 'Abierta'::text,      -- Abierta | En proceso | Cerrada
  foto_url text,                            -- foto ANTES (base64)
  obs_cierre text,
  firma_tecnico text,                       -- en desuso desde v4.2 (se conservan las antiguas)
  firma_supervisor text,                    -- en desuso desde v4.2
  fecha_apertura timestamptz default now(),
  fecha_asignacion timestamptz,
  fecha_cierre timestamptz,
  cerrada_por text,
  creado_at timestamptz default now(),
  updated_at timestamptz default now(),
  observaciones_adicionales jsonb default '[]'::jsonb,  -- seguimiento (reporte, derivación, trabajo + foto)
  foto_cierre text,                         -- foto DESPUÉS
  constraint ordenes_trabajo_pkey primary key (id),
  constraint ordenes_trabajo_numero_ot_key unique (numero_ot)
);

-- MANTENCIÓN: OT de áreas comunes y casino (OTA-AAAA-XXXX)
create table if not exists public.ordenes_trabajo_areas (
  id uuid default gen_random_uuid() not null,
  numero_ot text not null,
  hab_key text not null,                    -- 'area-<id del área>'
  modulo text not null,                     -- nombre del área
  piso text,                                -- sector
  categorias text[] default '{}'::text[],
  obs_inicial text,
  estado text default 'Abierta'::text,
  prioridad text default 'Normal'::text,
  tecnico text,
  foto_url text,
  foto_cierre text,
  firma_tecnico text,
  firma_supervisor text,
  cerrada_por text,
  obs_cierre text,
  observaciones_adicionales jsonb default '[]'::jsonb,
  fecha_apertura timestamptz default now(),
  fecha_asignacion timestamptz,
  fecha_cierre timestamptz,
  creado_at timestamptz default now(),
  updated_at timestamptz default now(),
  constraint ordenes_trabajo_areas_pkey primary key (id)
);

-- MANTENCIÓN: registro de mantención por habitación (1 fila por habitación)
create table if not exists public.mantenciones (
  id uuid default gen_random_uuid() not null,
  hab_key text not null,
  modulo text not null,
  piso text,
  habitacion integer not null,
  categorias text[] not null,
  estado text default 'Pendiente'::text,
  obs text,
  personas integer default 0,
  fecha_inicio date,
  fecha_cierre date,
  creado_at timestamptz default now(),
  updated_at timestamptz default now(),
  constraint mantenciones_pkey primary key (id),
  constraint mantenciones_hab_key_unique unique (hab_key)
);

-- ÁREAS COMUNES: áreas agregadas por el App Manager
create table if not exists public.areas_custom (
  id text not null,
  nombre text not null,
  icon text default '📦'::text not null,
  sector text default 'Áreas Comunes'::text not null,
  creado_por text,
  creado_at timestamptz default now(),
  updated_at timestamptz default now(),
  constraint areas_custom_pkey primary key (id)
);

-- TODAS: configuración compartida (claves cifradas, contactos WhatsApp, URLs de las apps)
-- La comparte también la app EPP Prevención.
create table if not exists public.epp_config (
  clave text not null,
  valor text,
  constraint epp_config_pkey primary key (clave)
);

-- AUDITORÍA (nuevo v5): cada alta / cambio / borrado, con hora del servidor
create table if not exists public.auditoria_censo (
  id bigint generated always as identity not null,
  fecha timestamptz default now() not null,
  tabla text not null,
  accion text not null,                     -- INSERT | UPDATE | DELETE
  registro_id text,
  antes jsonb,                              -- sin fotos ni firmas (para no pesar)
  despues jsonb,
  constraint auditoria_censo_pkey primary key (id)
);

-- En desuso (módulo Reposición retirado; se conservan los datos)
create table if not exists public.cambios_modulo (
  id bigint default nextval('cambios_modulo_id_seq'::regclass) not null,
  modulo text not null, item text not null, item_label text, fecha_cambio date not null,
  registrado_por text, nivel text, obs text, foto_url text, fuente text default 'manual'::text,
  created_at timestamptz default now(), updated_at timestamptz default now(),
  constraint cambios_modulo_pkey primary key (id),
  constraint chk_cm_fuente check (fuente = any (array['manual'::text, 'import_excel'::text]))
);
create table if not exists public.cambios_inventario (
  id bigint default nextval('cambios_inventario_id_seq'::regclass) not null,
  hab_key text not null, modulo text, habitacion integer, item text not null, item_label text,
  fecha_cambio date not null, registrado_por text, nivel text, obs text, foto_url text,
  created_at timestamptz default now(), updated_at timestamptz default now(),
  constraint cambios_inventario_pkey primary key (id)
);
create table if not exists public.configuracion (
  clave text not null, valor text, updated_at timestamptz default now(),
  constraint configuracion_pkey primary key (clave)
);
-- (epp_inventario y epp_solicitudes pertenecen a la app EPP Prevención y no se documentan aquí)

-- ─── 3. ÍNDICES ─────────────────────────────────────────────────────────────
create index if not exists idx_hist_hab_fecha        on public.historial_habitaciones (fecha);
create index if not exists idx_ot_estado             on public.ordenes_trabajo (estado);
create index if not exists idx_ot_habkey             on public.ordenes_trabajo (hab_key);
create index if not exists idx_ot_areas_estado       on public.ordenes_trabajo_areas (estado);
create index if not exists idx_ot_areas_hab_key      on public.ordenes_trabajo_areas (hab_key);
create index if not exists idx_areas_custom_sector   on public.areas_custom (sector);
create index if not exists auditoria_censo_fecha_idx on public.auditoria_censo (fecha desc);
create index if not exists auditoria_censo_reg_idx   on public.auditoria_censo (tabla, registro_id, fecha desc);

-- ─── 4. FUNCIONES ───────────────────────────────────────────────────────────

-- Correlativos de OT (los llama la app con sb.rpc)
create or replace function public.get_next_ot() returns bigint
language plpgsql security definer as $$
begin return nextval('ot_correlativo'); end $$;

create or replace function public.get_next_ot_area() returns integer
language plpgsql as $$
begin return nextval('seq_ot_areas'); end $$;

create or replace function public.reiniciar_correlativo_ot() returns void
language plpgsql security definer as $$
begin
  alter sequence ot_correlativo restart with 1;
  alter sequence seq_ot_areas restart with 1;
end $$;

-- updated_at con la hora del servidor
create or replace function public.fn_set_updated_at() returns trigger
language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

-- Lista LIVIANA de OT (v4.2): la fila completa, pero fotos/firmas reemplazadas por '__lite__'.
-- La app la pide como:  sb.from('ordenes_trabajo').select('r:lite_ot')
create or replace function public._ot_obs_lite(obs jsonb) returns jsonb
language sql immutable set search_path = public as $$
  select case when obs is null or jsonb_typeof(obs) <> 'array' then obs else
    coalesce((select jsonb_agg(
      case when jsonb_typeof(e)='object' then
        e
        || case when e ? 'foto' and e->'foto' <> 'null'::jsonb then jsonb_build_object('foto','__lite__') else '{}'::jsonb end
        || case when e ? 'firma_aut' and e->'firma_aut' <> 'null'::jsonb then jsonb_build_object('firma_aut','__lite__') else '{}'::jsonb end
      else e end order by i)
     from jsonb_array_elements(obs) with ordinality as t(e,i)), '[]'::jsonb) end
$$;

create or replace function public.lite_ot(r public.ordenes_trabajo) returns jsonb
language sql stable set search_path = public as $$
  select to_jsonb(r) || jsonb_build_object(
    'foto_url',        case when r.foto_url         is null then null else '__lite__' end,
    'foto_cierre',     case when r.foto_cierre      is null then null else '__lite__' end,
    'firma_tecnico',   case when r.firma_tecnico    is null then null else '__lite__' end,
    'firma_supervisor',case when r.firma_supervisor is null then null else '__lite__' end,
    'observaciones_adicionales', public._ot_obs_lite(r.observaciones_adicionales))
$$;

create or replace function public.lite_ota(r public.ordenes_trabajo_areas) returns jsonb
language sql stable set search_path = public as $$
  select to_jsonb(r) || jsonb_build_object(
    'foto_url',        case when r.foto_url         is null then null else '__lite__' end,
    'foto_cierre',     case when r.foto_cierre      is null then null else '__lite__' end,
    'firma_tecnico',   case when r.firma_tecnico    is null then null else '__lite__' end,
    'firma_supervisor',case when r.firma_supervisor is null then null else '__lite__' end,
    'observaciones_adicionales', public._ot_obs_lite(r.observaciones_adicionales))
$$;

-- Protección de fotos (v4.2): si la app guarda una OT liviana, se reponen las fotos reales.
create or replace function public.ot_restaurar_lite() returns trigger
language plpgsql set search_path = public as $$
declare
  m constant text := '__lite__';
  arr jsonb := '[]'::jsonb; e jsonb; o jsonb; k text;
begin
  if new.foto_url = m then new.foto_url := old.foto_url; end if;
  if new.firma_tecnico = m then new.firma_tecnico := old.firma_tecnico; end if;
  if new.firma_supervisor = m then new.firma_supervisor := old.firma_supervisor; end if;

  if new.observaciones_adicionales is not null
     and jsonb_typeof(new.observaciones_adicionales) = 'array'
     and strpos(new.observaciones_adicionales::text, m) > 0 then
    for e in select x from jsonb_array_elements(new.observaciones_adicionales) as t(x) loop
      if jsonb_typeof(e) = 'object' and strpos(e::text, m) > 0 then
        o := null;
        select x into o from jsonb_array_elements(coalesce(old.observaciones_adicionales,'[]'::jsonb)) as t(x)
         where jsonb_typeof(x)='object'
           and x->>'fecha' is not distinct from e->>'fecha'
           and x->>'tipo'  is not distinct from e->>'tipo'
           and x->>'texto' is not distinct from e->>'texto'
         limit 1;
        foreach k in array array['foto','firma_aut'] loop
          if e->>k = m then
            if o is not null and o ? k then e := jsonb_set(e, array[k], o->k);
            else e := e - k; end if;
          end if;
        end loop;
      end if;
      arr := arr || jsonb_build_array(e);
    end loop;
    new.observaciones_adicionales := arr;
  end if;

  if new.foto_cierre = m then
    new.foto_cierre := coalesce(old.foto_cierre,
      (select x->>'foto' from jsonb_array_elements(coalesce(new.observaciones_adicionales,'[]'::jsonb)) with ordinality as t(x,i)
        where jsonb_typeof(x)='object' and x->>'tipo'='trabajo' and coalesce(x->>'foto','') not in ('', m)
        order by i desc limit 1));
  end if;
  return new;
end $$;

-- Auditoría (v5)
create or replace function public.fn_auditoria_censo() returns trigger
language plpgsql security definer set search_path = public as $$
declare a jsonb; d jsonb; rid text;
  pesadas text[] := array['foto_url','foto_cierre','firma_tecnico','firma_supervisor','observaciones_adicionales'];
begin
  if tg_op <> 'INSERT' then a := to_jsonb(old) - pesadas; end if;
  if tg_op <> 'DELETE' then d := to_jsonb(new) - pesadas; end if;
  rid := coalesce(d->>'id', a->>'id', d->>'fecha', a->>'fecha');
  if tg_op = 'UPDATE' and a = d then return null; end if;
  insert into public.auditoria_censo(tabla, accion, registro_id, antes, despues)
  values (tg_table_name, tg_op, rid, a, d);
  return null;
end $$;

-- Borra auditoría de más de 90 días (corre como máximo una vez por hora)
create or replace function public.fn_auditoria_purga() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if extract(minute from now()) = 0 then
    delete from public.auditoria_censo where fecha < now() - interval '90 days';
  end if;
  return null;
end $$;

revoke execute on function public.fn_auditoria_censo() from anon, authenticated, public;
revoke execute on function public.fn_auditoria_purga() from anon, authenticated, public;
grant execute on function public.lite_ot(public.ordenes_trabajo) to anon, authenticated;
grant execute on function public.lite_ota(public.ordenes_trabajo_areas) to anon, authenticated;
grant execute on function public._ot_obs_lite(jsonb) to anon, authenticated;

-- ─── 5. TRIGGERS ────────────────────────────────────────────────────────────
drop trigger if exists trg_hab_updated_at on public.habitaciones;
create trigger trg_hab_updated_at before update on public.habitaciones for each row execute function public.fn_set_updated_at();

drop trigger if exists trg_ot_restaurar_lite on public.ordenes_trabajo;
create trigger trg_ot_restaurar_lite before update on public.ordenes_trabajo for each row execute function public.ot_restaurar_lite();
drop trigger if exists trg_ota_restaurar_lite on public.ordenes_trabajo_areas;
create trigger trg_ota_restaurar_lite before update on public.ordenes_trabajo_areas for each row execute function public.ot_restaurar_lite();

drop trigger if exists trg_audit on public.habitaciones;
create trigger trg_audit after insert or update or delete on public.habitaciones for each row execute function public.fn_auditoria_censo();
drop trigger if exists trg_audit on public.historial;
create trigger trg_audit after insert or update or delete on public.historial for each row execute function public.fn_auditoria_censo();
drop trigger if exists trg_audit on public.ordenes_trabajo;
create trigger trg_audit after insert or update or delete on public.ordenes_trabajo for each row execute function public.fn_auditoria_censo();
drop trigger if exists trg_audit on public.ordenes_trabajo_areas;
create trigger trg_audit after insert or update or delete on public.ordenes_trabajo_areas for each row execute function public.fn_auditoria_censo();
drop trigger if exists trg_audit on public.areas_custom;
create trigger trg_audit after insert or update or delete on public.areas_custom for each row execute function public.fn_auditoria_censo();
drop trigger if exists trg_audit_purga on public.auditoria_censo;
create trigger trg_audit_purga after insert on public.auditoria_censo for each statement execute function public.fn_auditoria_purga();

drop trigger if exists tg_cambios_modulo_updated on public.cambios_modulo;
create trigger tg_cambios_modulo_updated before update on public.cambios_modulo for each row execute function public.fn_set_updated_at();
drop trigger if exists tg_cambios_inventario_updated on public.cambios_inventario;
create trigger tg_cambios_inventario_updated before update on public.cambios_inventario for each row execute function public.fn_set_updated_at();

-- ─── 6. SEGURIDAD (RLS) ─────────────────────────────────────────────────────
-- Estado actual: las apps entran con la clave pública (anon) y las tablas aceptan
-- lectura/escritura pública. La clave de cada nivel se valida en la app.
-- La auditoría es solo lectura: nadie puede borrar el rastro desde las apps.
alter table public.habitaciones           enable row level security;
alter table public.historial              enable row level security;
alter table public.historial_habitaciones enable row level security;
alter table public.ordenes_trabajo        enable row level security;
alter table public.ordenes_trabajo_areas  enable row level security;
alter table public.mantenciones           enable row level security;
alter table public.areas_custom           enable row level security;
alter table public.epp_config             enable row level security;
alter table public.auditoria_censo        enable row level security;
alter table public.cambios_modulo         enable row level security;
alter table public.cambios_inventario     enable row level security;
alter table public.configuracion          enable row level security;

drop policy if exists acceso_publico_habitaciones on public.habitaciones;
create policy acceso_publico_habitaciones on public.habitaciones for all to public using (true) with check (true);
drop policy if exists acceso_publico_historial on public.historial;
create policy acceso_publico_historial on public.historial for all to public using (true) with check (true);
drop policy if exists allow_all_hist_hab on public.historial_habitaciones;
create policy allow_all_hist_hab on public.historial_habitaciones for all to public using (true) with check (true);
drop policy if exists acceso_publico on public.ordenes_trabajo;
create policy acceso_publico on public.ordenes_trabajo for all to public using (true) with check (true);
drop policy if exists allow_all_areas on public.ordenes_trabajo_areas;
create policy allow_all_areas on public.ordenes_trabajo_areas for all to public using (true) with check (true);
drop policy if exists acceso_publico on public.mantenciones;
create policy acceso_publico on public.mantenciones for all to public using (true) with check (true);
drop policy if exists areas_custom_select on public.areas_custom;
drop policy if exists areas_custom_insert on public.areas_custom;
drop policy if exists areas_custom_update on public.areas_custom;
drop policy if exists areas_custom_delete on public.areas_custom;
create policy areas_custom_select on public.areas_custom for select to public using (true);
create policy areas_custom_insert on public.areas_custom for insert to public with check (true);
create policy areas_custom_update on public.areas_custom for update to public using (true);
create policy areas_custom_delete on public.areas_custom for delete to public using (true);
drop policy if exists public_all on public.epp_config;
create policy public_all on public.epp_config for all to public using (true) with check (true);
drop policy if exists auditoria_lectura on public.auditoria_censo;
create policy auditoria_lectura on public.auditoria_censo for select to anon, authenticated using (true);
drop policy if exists anon_all_cambios_modulo on public.cambios_modulo;
create policy anon_all_cambios_modulo on public.cambios_modulo for all to public using (true) with check (true);
drop policy if exists anon_all_cambios_inventario on public.cambios_inventario;
create policy anon_all_cambios_inventario on public.cambios_inventario for all to public using (true) with check (true);
drop policy if exists acceso_publico_configuracion on public.configuracion;
create policy acceso_publico_configuracion on public.configuracion for all to public using (true) with check (true);

-- ─── 7. REALTIME (avisos al instante entre las 3 apps) ─────────────────────
-- FIX v5: 'habitaciones' NO estaba publicada → los otros equipos no veían los cambios.
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='habitaciones') then
    alter publication supabase_realtime add table public.habitaciones; end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='ordenes_trabajo') then
    alter publication supabase_realtime add table public.ordenes_trabajo; end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='ordenes_trabajo_areas') then
    alter publication supabase_realtime add table public.ordenes_trabajo_areas; end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='areas_custom') then
    alter publication supabase_realtime add table public.areas_custom; end if;
end $$;
alter table public.habitaciones replica identity full;

-- ─── 8. CONFIGURACIÓN: URL de las 3 apps ────────────────────────────────────
-- Las apps leen esta fila al abrir. Si publicas en otras direcciones de Netlify,
-- cambia SOLO este valor (no hace falta tocar los HTML).
insert into public.epp_config (clave, valor) values ('campos_apps',
  '{"censo":"https://censo-2026.netlify.app/","mant":"https://mantencion-albemarle.netlify.app/","areas":"https://areas-albemarle.netlify.app/"}')
on conflict (clave) do nothing;
-- update public.epp_config set valor = '{"censo":"https://...","mant":"https://...","areas":"https://..."}' where clave = 'campos_apps';


-- ═══════════════════════════════════════════════════════════════════════════
-- 9. CONSULTAS DE VERIFICACIÓN (copiar y ejecutar en el SQL Editor)
-- ═══════════════════════════════════════════════════════════════════════════

-- 9.1 Salud general del censo de hoy
select
  (select count(*) from habitaciones)                                  as habitaciones_con_fila,
  (select count(*) from habitaciones where personas > 0)               as ocupadas,
  (select coalesce(sum(personas),0) from habitaciones where not coalesce(bloqueada,false)) as personas,
  (select max(updated_at) from habitaciones)                           as ultimo_guardado,
  (select persons from historial where fecha = to_char(now() at time zone 'America/Santiago','YYYY-MM-DD')) as total_guardado_hoy;

-- 9.2 ¿Cada día quedó respaldado? (debe haber 1 fila en historial y ~312 en historial_habitaciones)
select h.fecha, h.persons, h.saved, count(hh.*) as habitaciones_respaldadas
from historial h left join historial_habitaciones hh on hh.fecha::text = h.fecha
group by h.fecha, h.persons, h.saved order by h.fecha desc limit 14;

-- 9.3 "Se guardó y desapareció": historia completa de UNA habitación (cambia 'A1-3')
select fecha at time zone 'America/Santiago' as hora_chile, accion,
       antes->>'personas' as personas_antes, despues->>'personas' as personas_despues,
       despues->>'ts' as ts_celular, despues->'mant_categorias' as mantencion
from auditoria_censo where tabla = 'habitaciones' and registro_id = 'A1-3'
order by fecha desc limit 50;

-- 9.4 Borrados de hoy (fuera del cierre de las 22:00 no debería haber)
select fecha at time zone 'America/Santiago' as hora_chile, registro_id, antes->>'personas' as personas
from auditoria_censo
where tabla = 'habitaciones' and accion = 'DELETE'
  and fecha >= date_trunc('day', now() at time zone 'America/Santiago') at time zone 'America/Santiago'
order by fecha desc;

-- 9.5 Cambios de habitación que bajaron personas (posible pisada por un equipo con datos viejos)
select fecha at time zone 'America/Santiago' as hora_chile, registro_id,
       antes->>'personas' as antes, despues->>'personas' as despues,
       (despues->>'ts')::bigint - (antes->>'ts')::bigint as diferencia_ts_ms
from auditoria_censo
where tabla = 'habitaciones' and accion = 'UPDATE'
  and (despues->>'ts')::bigint < (antes->>'ts')::bigint
order by fecha desc limit 50;

-- 9.6 OT por estado (pabellones y áreas)
select 'Habitaciones' as tipo, estado, count(*) from ordenes_trabajo group by estado
union all
select 'Áreas comunes', estado, count(*) from ordenes_trabajo_areas group by estado
order by 1, 2;

-- 9.7 OT abiertas hace más de 3 días
select numero_ot, modulo, coalesce(habitacion::text, piso) as lugar, estado, tecnico,
       (now() - fecha_apertura) as antiguedad
from ordenes_trabajo where estado <> 'Cerrada' and fecha_apertura < now() - interval '3 days'
union all
select numero_ot, modulo, piso, estado, tecnico, (now() - fecha_apertura)
from ordenes_trabajo_areas where estado <> 'Cerrada' and fecha_apertura < now() - interval '3 days'
order by antiguedad desc;

-- 9.8 Habitaciones con mantención reportada en el censo pero SIN OT abierta
select h.id, h.mant_categorias, h.mant_obs, h.updated_at
from habitaciones h
where coalesce(array_length(h.mant_categorias,1),0) > 0
  and not exists (select 1 from ordenes_trabajo o where o.hab_key = h.id and o.estado <> 'Cerrada');

-- 9.9 Peso de las tablas (control de la cuota de Supabase)
select relname as tabla, pg_size_pretty(pg_total_relation_size(c.oid)) as tamano
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r'
order by pg_total_relation_size(c.oid) desc;

-- 9.10 Realtime: tablas publicadas (deben aparecer las 4)
select tablename from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public';

-- 9.11 Actividad de las últimas 24 h por tabla y acción
select tabla, accion, count(*) from auditoria_censo
where fecha > now() - interval '24 hours' group by 1, 2 order by 1, 2;
