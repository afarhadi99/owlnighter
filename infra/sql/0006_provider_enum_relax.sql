-- ============================================================================
-- owlnighter — relax provider CHECK constraints
-- Widens reading_plans.provider and quiz_instances.provider to accept the two
-- new AI providers (openrouter, ai_tutor_api) alongside gemini/groq. No data
-- migration needed: existing rows only ever contain 'gemini' or 'groq'.
-- ============================================================================

alter table public.reading_plans drop constraint reading_plans_provider_check;
alter table public.reading_plans add constraint reading_plans_provider_check
  check (provider in ('gemini','groq','openrouter','ai_tutor_api'));

alter table public.quiz_instances drop constraint quiz_instances_provider_check;
alter table public.quiz_instances add constraint quiz_instances_provider_check
  check (provider in ('gemini','groq','openrouter','ai_tutor_api'));
