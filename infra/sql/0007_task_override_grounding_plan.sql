-- ============================================================================
-- owlnighter — unlock book_grounding/plan_generation task overrides
-- The AI router no longer hardcodes book_grounding/plan_generation to Gemini
-- (packages/ts/ai/src/router.ts); every task now resolves via
-- taskOverrides[task] ?? default ?? "ai_tutor_api". These two settings rows
-- were never seeded because the override was previously unreachable — add
-- them now so the admin panel's AI Providers page has something to read/set,
-- matching the existing quiz_generation/rewrite override rows.
-- ============================================================================

insert into public.app_settings (key, value, is_secret) values
  ('ai_provider.task_override.book_grounding', 'null'::jsonb, false),
  ('ai_provider.task_override.plan_generation', 'null'::jsonb, false)
on conflict (key) do nothing;
