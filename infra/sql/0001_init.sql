-- ============================================================================
-- owlnighter — initial schema
-- Target: Supabase Postgres. Run against a local `supabase start` or hosted db.
-- Separates CANONICAL book identity from GROUNDED claims so admins can inspect,
-- override, and re-run enrichment without corrupting the product-facing record.
-- ============================================================================

create extension if not exists pgcrypto;   -- gen_random_uuid()
create extension if not exists vector;      -- pgvector semantic search

-- ---------------------------------------------------------------------------
-- Profiles (1:1 with auth.users)
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  locale text not null default 'en-US',
  is_admin boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Canonical book identity (product-facing)
-- ---------------------------------------------------------------------------
create table if not exists public.books (
  id uuid primary key default gen_random_uuid(),
  canonical_title text not null,
  canonical_author text[] not null default '{}',
  isbn13 text,
  google_books_id text,
  open_library_key text,
  edition_label text,
  language_code text,
  published_year int,
  page_count int,
  cover_url text,
  metadata_confidence numeric(4,3) not null default 0.0,
  grounding_status text not null default 'pending'
    check (grounding_status in ('pending','grounded','partial','blocked')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists books_isbn13_idx on public.books (isbn13);
create index if not exists books_google_id_idx on public.books (google_books_id);

create table if not exists public.user_books (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  book_id uuid not null references public.books(id) on delete cascade,
  status text not null default 'active'
    check (status in ('active','paused','completed','archived')),
  current_page int,
  target_nightly_pages int,
  preferred_reading_time_local time,
  timezone text not null default 'UTC',
  created_at timestamptz not null default now(),
  unique (user_id, book_id)
);
create index if not exists user_books_user_idx on public.user_books (user_id);

-- ---------------------------------------------------------------------------
-- Reading plans + steps
-- ---------------------------------------------------------------------------
create table if not exists public.reading_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  book_id uuid not null references public.books(id) on delete cascade,
  provider text not null check (provider in ('gemini','groq')),
  provider_model text not null,
  plan_version int not null default 1,
  nightly_goal_pages int not null,
  pacing_mode text not null check (pacing_mode in ('gentle','standard','intensive')),
  starts_on date not null default current_date,
  ends_on date,
  created_at timestamptz not null default now()
);
create index if not exists reading_plans_user_idx on public.reading_plans (user_id);

create table if not exists public.reading_plan_steps (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.reading_plans(id) on delete cascade,
  step_index int not null,
  page_start int,
  page_end int,
  chapter_hint text,
  title text not null,
  short_prompt text,
  quiz_mode text not null check (quiz_mode in ('grounded','preview','user_text','fallback')),
  tts_asset_id uuid,
  unlocks_at timestamptz,
  created_at timestamptz not null default now(),
  unique (plan_id, step_index)
);

-- ---------------------------------------------------------------------------
-- Sessions, quizzes, attempts
-- ---------------------------------------------------------------------------
create table if not exists public.reading_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  step_id uuid not null references public.reading_plan_steps(id) on delete cascade,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  pages_read int
);
create index if not exists reading_sessions_user_idx on public.reading_sessions (user_id);

create table if not exists public.quiz_instances (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  step_id uuid not null references public.reading_plan_steps(id) on delete cascade,
  session_id uuid references public.reading_sessions(id) on delete set null,
  quiz_mode text not null check (quiz_mode in ('grounded','preview','user_text','fallback')),
  provider text not null check (provider in ('gemini','groq')),
  provider_model text not null,
  confidence numeric(4,3) not null default 0.0,
  created_at timestamptz not null default now()
);
create index if not exists quiz_instances_user_idx on public.quiz_instances (user_id);

create table if not exists public.quiz_questions (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references public.quiz_instances(id) on delete cascade,
  ordinal int not null,
  kind text not null check (kind in ('multiple_choice','true_false','short_answer')),
  prompt text not null,
  options jsonb,
  correct_answer text not null,
  explanation text,
  source_citation_index int,
  unique (quiz_id, ordinal)
);

create table if not exists public.quiz_attempts (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references public.quiz_instances(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  answers jsonb not null,
  correct_count int not null,
  total_count int not null,
  passed boolean not null,
  created_at timestamptz not null default now()
);
create index if not exists quiz_attempts_user_idx on public.quiz_attempts (user_id);

-- ---------------------------------------------------------------------------
-- Streaks, push, notifications, tts
-- ---------------------------------------------------------------------------
create table if not exists public.streak_days (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  xp int not null default 0,
  created_at timestamptz not null default now(),
  unique (user_id, day)
);

create table if not exists public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null,
  platform text not null check (platform in ('ios','android','web')),
  app_version text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (token)
);
create index if not exists push_tokens_user_idx on public.push_tokens (user_id);

create table if not exists public.notification_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  nightly_reminder boolean not null default true,
  streak_warning boolean not null default true,
  reminder_time_local time not null default '20:30',
  timezone text not null default 'UTC',
  updated_at timestamptz not null default now()
);

create table if not exists public.tts_assets (
  id uuid primary key default gen_random_uuid(),
  asset_key text not null unique,          -- content hash of text + voice config
  provider text not null default 'deepgram',
  voice_model text not null,
  locale text not null default 'en',
  storage_path text not null,              -- Supabase Storage object path
  duration_ms int,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Grounding & provenance
-- ---------------------------------------------------------------------------
create table if not exists public.book_catalog_candidates (
  id uuid primary key default gen_random_uuid(),
  book_id uuid references public.books(id) on delete cascade,
  source text not null check (source in ('google_books','open_library')),
  source_id text not null,
  payload jsonb not null,
  created_at timestamptz not null default now()
);

create table if not exists public.book_grounding_runs (
  id uuid primary key default gen_random_uuid(),
  book_id uuid not null references public.books(id) on delete cascade,
  provider text not null,
  provider_model text not null,
  run_kind text not null check (run_kind in ('identify','enrich','reconcile','preview_extract')),
  input_hash text not null,
  status text not null default 'running' check (status in ('running','succeeded','failed')),
  citations_json jsonb not null default '[]'::jsonb,
  raw_result jsonb,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);
create index if not exists grounding_runs_book_idx on public.book_grounding_runs (book_id);

create table if not exists public.book_grounding_sources (
  id uuid primary key default gen_random_uuid(),
  grounding_run_id uuid not null references public.book_grounding_runs(id) on delete cascade,
  source_type text not null check (source_type in ('google_books','open_library','web')),
  source_url text,
  source_title text,
  source_snippet text,
  citation_index int not null,
  trust_score numeric(4,3) not null default 0.5
);

create table if not exists public.book_grounding_facts (
  id uuid primary key default gen_random_uuid(),
  grounding_run_id uuid not null references public.book_grounding_runs(id) on delete cascade,
  fact_type text not null check (fact_type in ('page_count','chapter_map','character','theme','preview_segment')),
  key text not null,
  value_json jsonb not null,
  confidence numeric(4,3) not null,
  provenance_source_ids uuid[] not null default '{}',
  created_at timestamptz not null default now()
);

create table if not exists public.book_grounding_embeddings (
  id uuid primary key default gen_random_uuid(),
  fact_id uuid not null references public.book_grounding_facts(id) on delete cascade,
  embedding vector(768),
  created_at timestamptz not null default now()
);

create table if not exists public.book_preview_segments (
  id uuid primary key default gen_random_uuid(),
  book_id uuid not null references public.books(id) on delete cascade,
  page_start int,
  page_end int,
  segment_text text not null,
  source_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.quiz_generation_runs (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid references public.quiz_instances(id) on delete cascade,
  provider text not null,
  provider_model text not null,
  input_hash text not null,
  status text not null default 'running' check (status in ('running','succeeded','failed','fallback')),
  attempts int not null default 1,
  raw_result jsonb,
  created_at timestamptz not null default now()
);
