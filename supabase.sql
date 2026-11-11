-- ============================================================
-- Muro compartido de la invitación de XV de Bianca
-- Pegá TODO este archivo en Supabase > SQL Editor > New query > Run.
-- Se puede correr más de una vez sin romper nada.
-- ============================================================

-- ---------- Canciones para el DJ ----------
create table if not exists public.canciones (
  id      bigint generated always as identity primary key,
  creado  timestamptz not null default now(),
  tema    text not null check (char_length(tema) between 1 and 80),
  artista text check (artista is null or char_length(artista) <= 60),
  nombre  text check (nombre is null or char_length(nombre) <= 40),
  visible boolean not null default true
);

-- ---------- Fotos que suben los invitados ----------
-- Cada foto entra con aprobada = false y NO se ve en el muro
-- hasta que la apruebes desde Table Editor > fotos.
create table if not exists public.fotos (
  id       bigint generated always as identity primary key,
  creado   timestamptz not null default now(),
  ruta     text not null unique check (ruta ~ '^[a-z0-9-]{10,60}\.jpg$'),
  nombre   text check (nombre is null or char_length(nombre) <= 40),
  aprobada boolean not null default false
);

alter table public.canciones enable row level security;
alter table public.fotos     enable row level security;

grant select, insert on public.canciones to anon;
grant select, insert on public.fotos     to anon;

-- Los invitados solo pueden LEER lo visible/aprobado y AGREGAR filas nuevas.
-- No pueden editar ni borrar nada, ni aprobarse sus propias fotos.
drop policy if exists "leer canciones visibles" on public.canciones;
create policy "leer canciones visibles" on public.canciones
  for select to anon using (visible);

drop policy if exists "agregar canciones" on public.canciones;
create policy "agregar canciones" on public.canciones
  for insert to anon with check (visible = true);

drop policy if exists "leer fotos aprobadas" on public.fotos;
create policy "leer fotos aprobadas" on public.fotos
  for select to anon using (aprobada);

drop policy if exists "agregar fotos" on public.fotos;
create policy "agregar fotos" on public.fotos
  for insert to anon with check (aprobada = false);

-- ---------- Almacenamiento de las fotos ----------
-- Bucket público de lectura, máximo 3 MB por archivo, solo JPG.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fotos-invitados', 'fotos-invitados', true, 3145728, array['image/jpeg'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "subir fotos de invitados" on storage.objects;
create policy "subir fotos de invitados" on storage.objects
  for insert to anon with check (bucket_id = 'fotos-invitados');

-- ============================================================
-- Cómo moderar
--   Aprobar una foto:   Table Editor > fotos > tildar "aprobada"
--   Aprobar todas:      update public.fotos set aprobada = true;
--   Ocultar una canción: Table Editor > canciones > destildar "visible"
--   Lista para el DJ:    Table Editor > canciones > Export to CSV
--
-- Si preferís que las fotos se publiquen solas, sin aprobar una por una:
--   alter table public.fotos alter column aprobada set default true;
--   drop policy "agregar fotos" on public.fotos;
--   create policy "agregar fotos" on public.fotos for insert to anon with check (true);
-- ============================================================
