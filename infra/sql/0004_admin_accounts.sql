-- Admin-panel operator accounts. Decoupled from `profiles` (mobile end-users)
-- and from Supabase Auth (this dev environment has no live Supabase project).
create table public.admin_accounts (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  password_hash text not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  is_admin boolean not null default false,
  approved_by uuid references public.admin_accounts(id),
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
-- Case-insensitive uniqueness: rcohen@mytsi.org and RCohen@mytsi.org are the same account.
create unique index admin_accounts_email_lower_idx on public.admin_accounts (lower(email));

create table public.admin_sessions (
  id uuid primary key default gen_random_uuid(),
  admin_account_id uuid not null references public.admin_accounts(id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index admin_sessions_account_idx on public.admin_sessions (admin_account_id);
create index admin_sessions_expires_idx on public.admin_sessions (expires_at);

alter table public.admin_accounts enable row level security;
alter table public.admin_sessions enable row level security;
-- No policies: these tables are only ever touched via the service-role-backed
-- Fastify API, never a client-side Supabase session. Default-deny is
-- defense-in-depth, matching the existing pattern in 0002_rls.sql.
