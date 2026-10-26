-- Run this script in the Supabase SQL Editor.
-- Enable Anonymous Sign-Ins in Authentication > Sign In / Providers before voting.
-- Copy the project URL and publishable key from Project Settings > API into index.html.

create table if not exists public.recipe_ratings (
  recipe_id text not null check (length(trim(recipe_id)) between 1 and 200),
  user_id uuid not null references auth.users (id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  created_at timestamptz not null default now(),
  primary key (recipe_id, user_id)
);

alter table public.recipe_ratings enable row level security;

revoke all on table public.recipe_ratings from anon, authenticated;
grant select, insert, update on table public.recipe_ratings to authenticated;

drop policy if exists "Users can read their own recipe ratings" on public.recipe_ratings;
create policy "Users can read their own recipe ratings"
  on public.recipe_ratings
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can add their own recipe ratings" on public.recipe_ratings;
create policy "Users can add their own recipe ratings"
  on public.recipe_ratings
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own recipe ratings" on public.recipe_ratings;
create policy "Users can update their own recipe ratings"
  on public.recipe_ratings
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create or replace view public.recipe_rating_summary as
select
  recipe_id,
  count(*)::integer as rating_count,
  round(avg(rating)::numeric, 1) as average_rating
from public.recipe_ratings
group by recipe_id;

revoke all on table public.recipe_rating_summary from public, anon, authenticated;
grant select on table public.recipe_rating_summary to anon, authenticated;
