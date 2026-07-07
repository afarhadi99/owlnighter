-- ============================================================================
-- owlnighter — Row Level Security
-- Posture (from the blueprint):
--   * User tables: readable/writable only by auth.uid() = user_id
--   * books / tts_assets: readable by any authenticated user; writes = service role
--   * grounding tables: service role / admin only (RLS on, no permissive policy)
-- The service role key bypasses RLS and is used ONLY by the backend.
-- ============================================================================

-- Enable RLS everywhere user data can be reached.
alter table public.profiles                enable row level security;
alter table public.books                   enable row level security;
alter table public.user_books              enable row level security;
alter table public.reading_plans           enable row level security;
alter table public.reading_plan_steps      enable row level security;
alter table public.reading_sessions        enable row level security;
alter table public.quiz_instances          enable row level security;
alter table public.quiz_questions          enable row level security;
alter table public.quiz_attempts           enable row level security;
alter table public.streak_days             enable row level security;
alter table public.push_tokens             enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.tts_assets              enable row level security;
alter table public.book_catalog_candidates enable row level security;
alter table public.book_grounding_runs     enable row level security;
alter table public.book_grounding_sources  enable row level security;
alter table public.book_grounding_facts    enable row level security;
alter table public.book_grounding_embeddings enable row level security;
alter table public.book_preview_segments   enable row level security;
alter table public.quiz_generation_runs    enable row level security;

-- ---- profiles: self only ----
create policy profiles_self_select on public.profiles
  for select using (auth.uid() = id);
create policy profiles_self_update on public.profiles
  for update using (auth.uid() = id);

-- ---- books: authenticated read; no client write ----
create policy books_auth_read on public.books
  for select to authenticated using (true);

-- ---- generic owner tables ----
create policy user_books_owner on public.user_books
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy reading_plans_owner on public.reading_plans
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy reading_sessions_owner on public.reading_sessions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy quiz_instances_owner on public.quiz_instances
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy quiz_attempts_owner on public.quiz_attempts
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy streak_days_owner on public.streak_days
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy push_tokens_owner on public.push_tokens
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy notification_prefs_owner on public.notification_preferences
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---- steps: readable if you own the parent plan ----
create policy plan_steps_owner_read on public.reading_plan_steps
  for select using (
    exists (
      select 1 from public.reading_plans p
      where p.id = reading_plan_steps.plan_id and p.user_id = auth.uid()
    )
  );

-- ---- quiz_questions: readable if you own the parent quiz ----
create policy quiz_questions_owner_read on public.quiz_questions
  for select using (
    exists (
      select 1 from public.quiz_instances q
      where q.id = quiz_questions.quiz_id and q.user_id = auth.uid()
    )
  );

-- ---- tts_assets: authenticated read; writes = service role ----
create policy tts_assets_auth_read on public.tts_assets
  for select to authenticated using (true);

-- Grounding tables + quiz_generation_runs: intentionally NO policy.
-- With RLS enabled and no permissive policy, only the service role can touch
-- them. Admin reads go through the backend using the service role.
