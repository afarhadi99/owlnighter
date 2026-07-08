-- DEV ONLY — seed the fixed dev user used by the API's `Authorization: Bearer DEV`
-- path (apps/api DEV_USER_ID). Idempotent.

insert into auth.users (id, email)
values ('00000000-0000-0000-0000-0000000000de', 'dev@owlnighter.local')
on conflict (id) do nothing;

insert into public.profiles (id, display_name, is_admin, locale)
values ('00000000-0000-0000-0000-0000000000de', 'Dev User', true, 'en-US')
on conflict (id) do nothing;
