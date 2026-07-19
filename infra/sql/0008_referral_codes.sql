-- ============================================================================
-- owlnighter — 0008 referral codes
-- Admin-issued invite codes gating new-account activation. Every new profile
-- (whether the auth.users row came from email/password signup or Google
-- OAuth) redeems exactly one code before a `profiles` row is created — see
-- apps/api/src/services/referral.ts.
-- ============================================================================

create table if not exists public.referral_codes (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  label text,
  max_uses integer check (max_uses is null or (max_uses > 0 and max_uses <= 1000000)),
  use_count integer not null default 0,
  is_active boolean not null default true,
  expires_at timestamptz,
  created_by uuid references public.admin_accounts(id),
  created_at timestamptz not null default now()
);
-- Case-insensitive uniqueness, matching the admin_accounts email pattern.
create unique index if not exists referral_codes_code_lower_idx on public.referral_codes (lower(code));

create table if not exists public.referral_redemptions (
  id uuid primary key default gen_random_uuid(),
  referral_code_id uuid not null references public.referral_codes(id),
  user_id uuid not null unique references public.profiles(id) on delete cascade,
  redeemed_at timestamptz not null default now()
);
create index if not exists referral_redemptions_code_idx on public.referral_redemptions (referral_code_id);

alter table public.referral_codes enable row level security;
alter table public.referral_redemptions enable row level security;
-- No policies: these tables are only ever touched via the service-role-backed
-- Fastify API, never a client-side Supabase session. Default-deny is
-- defense-in-depth, matching the existing pattern in 0002_rls.sql and
-- 0004_admin_accounts.sql.
