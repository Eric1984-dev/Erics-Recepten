-- Run this script in the Supabase SQL Editor.
-- Copy the project URL and publishable key from Project Settings > API into index.html.

-- Keep existing Auth-based ratings for historical averages; new votes use browser IDs.
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

-- The browser ID avoids Auth accounts; it is not a trusted anti-abuse identity.
create table if not exists public.recipe_browser_ratings (
  recipe_id text not null check (length(trim(recipe_id)) between 1 and 200),
  browser_id uuid not null,
  rating smallint not null check (rating between 1 and 5),
  created_at timestamptz not null default now(),
  primary key (recipe_id, browser_id)
);

alter table public.recipe_browser_ratings enable row level security;
revoke all on table public.recipe_browser_ratings from public, anon, authenticated;

create or replace function public.submit_recipe_rating(
  p_recipe_id text,
  p_browser_id uuid,
  p_rating smallint
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_recipe_id is null or length(trim(p_recipe_id)) not between 1 and 200 then
    raise exception using errcode = '22023', message = 'Invalid recipe ID';
  end if;
  if p_browser_id is null then
    raise exception using errcode = '22023', message = 'Missing browser ID';
  end if;
  if p_rating is null or p_rating not between 1 and 5 then
    raise exception using errcode = '22023', message = 'Rating must be between 1 and 5';
  end if;

  insert into public.recipe_browser_ratings (recipe_id, browser_id, rating)
  values (trim(p_recipe_id), p_browser_id, p_rating)
  on conflict (recipe_id, browser_id)
  do update set rating = excluded.rating;
end;
$$;

revoke all on function public.submit_recipe_rating(text, uuid, smallint) from public, anon, authenticated;
grant execute on function public.submit_recipe_rating(text, uuid, smallint) to anon, authenticated;

create or replace view public.recipe_rating_summary as
select
  recipe_id,
  count(*)::integer as rating_count,
  round(avg(rating)::numeric, 1) as average_rating
from (
  select recipe_id, rating from public.recipe_ratings
  union all
  select recipe_id, rating from public.recipe_browser_ratings
) as all_ratings
group by recipe_id;

revoke all on table public.recipe_rating_summary from public, anon, authenticated;
grant select on table public.recipe_rating_summary to anon, authenticated;
