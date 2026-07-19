-- ============================================================================
-- DEV ONLY — local stand-in for the parts of Supabase's `auth` schema that the
-- product migrations (infra/sql/0001_init.sql, 0002_rls.sql) depend on.
--
-- In a real environment Supabase (GoTrue) provides auth.users, auth.uid(), and
-- the anon/authenticated/service_role roles. This file recreates the minimum so
-- the schema + RLS apply against a plain `pgvector/pgvector:pg16` Postgres for
-- local API iteration. DO NOT run this against a real Supabase database.
-- ============================================================================

create schema if not exists auth;

create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  email text,
  created_at timestamptz not null default now()
);

-- Extra columns that real Supabase (GoTrue) provides on auth.users and that some
-- dev seeds populate (e.g. packages/ts/db/scripts/seed-demo-data.mjs). Added
-- idempotently so this shim can grow without breaking an already-shimmed DB.
alter table auth.users add column if not exists aud text default 'authenticated';
alter table auth.users add column if not exists role text default 'authenticated';
alter table auth.users add column if not exists email_confirmed_at timestamptz;
alter table auth.users add column if not exists updated_at timestamptz not null default now();

-- Supabase populates request.jwt.claim.sub from the JWT; RLS policies call
-- auth.uid() to get it. Locally we read the same GUC (settable per session).
create or replace function auth.uid() returns uuid
  language sql stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

-- Roles referenced by the RLS policies ("... to authenticated").
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin bypassrls;
  end if;
end
$$;
