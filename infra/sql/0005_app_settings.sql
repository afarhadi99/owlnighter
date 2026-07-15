-- ============================================================================
-- owlnighter — 0005 app settings
-- Single admin-editable settings table: limits, flags, thresholds, catalog
-- config, and AI provider keys/models/prompts. Seeded with today's env-var
-- defaults so the table is never empty for a key the app expects.
-- ============================================================================

create table if not exists public.app_settings (
  key text primary key,
  value jsonb not null,
  is_secret boolean not null default false,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.admin_accounts(id)
);

insert into public.app_settings (key, value, is_secret) values
  ('max_books_per_user', '3'::jsonb, false),
  ('flag.groq_quiz_generation', 'true'::jsonb, false),
  ('flag.tts_pregeneration', 'true'::jsonb, false),
  ('flag.grounding_review_queue', 'true'::jsonb, false),
  ('grounding.auto_accept', '0.85'::jsonb, false),
  ('grounding.review_floor', '0.60'::jsonb, false),
  ('catalog.open_library_base_url', '"https://openlibrary.org"'::jsonb, false),
  ('catalog.google_books_api_key', 'null'::jsonb, true),
  ('ai.gemini.model', '"gemini-3.5-flash"'::jsonb, false),
  ('ai.deepgram.tts_model', '"aura-2-thalia-en"'::jsonb, false),
  ('ai_provider.groq.api_key', '""'::jsonb, true),
  ('ai_provider.groq.model', '"qwen-3.6-32b"'::jsonb, false),
  ('ai_provider.groq.system_prompt.plan_generation', '""'::jsonb, false),
  ('ai_provider.groq.system_prompt.quiz_generation', '""'::jsonb, false),
  ('ai_provider.openrouter.api_key', '""'::jsonb, true),
  ('ai_provider.openrouter.model', '""'::jsonb, false),
  ('ai_provider.openrouter.system_prompt.plan_generation', '""'::jsonb, false),
  ('ai_provider.openrouter.system_prompt.quiz_generation', '""'::jsonb, false),
  ('ai_provider.ai_tutor_api.api_key', '""'::jsonb, true),
  ('ai_provider.ai_tutor_api.workflow_id.book_grounding', '""'::jsonb, false),
  ('ai_provider.ai_tutor_api.workflow_id.plan_generation', '""'::jsonb, false),
  ('ai_provider.ai_tutor_api.workflow_id.quiz_generation', '""'::jsonb, false),
  ('ai_provider.default', '"ai_tutor_api"'::jsonb, false),
  ('ai_provider.task_override.quiz_generation', 'null'::jsonb, false),
  ('ai_provider.task_override.rewrite', 'null'::jsonb, false)
on conflict (key) do nothing;
