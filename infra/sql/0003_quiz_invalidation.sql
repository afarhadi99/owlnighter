-- ============================================================================
-- owlnighter — 0003 quiz invalidation
-- Admins can retire a bad quiz. Invalidated quizzes are skipped when a step's
-- quiz is reused (see generateStepQuiz/loadQuizInstance), so the reader gets a
-- freshly generated quiz instead of the retired one.
-- ============================================================================

alter table public.quiz_instances
  add column if not exists invalidated_at timestamptz,
  add column if not exists invalidation_reason text;

-- Reuse lookups filter on (step_id, user_id) where invalidated_at is null; a
-- partial index keeps that path fast as the table grows.
create index if not exists quiz_instances_active_idx
  on public.quiz_instances (step_id, user_id)
  where invalidated_at is null;
