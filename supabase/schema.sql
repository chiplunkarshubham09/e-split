-- Split Expense — run this in the Supabase SQL Editor (once per project).
-- Then paste Project URL + anon key into E-split/Info.plist (SUPABASE_URL, SUPABASE_ANON_KEY).
-- Re-run this file after policy updates (safe to run again).
-- Auth → Providers → Email: leave Email enabled, and turn Confirm email OFF while testing.

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null,
  email text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text not null default '',
  currency text not null default 'INR',
  type text,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  is_archived boolean not null default false,
  invite_code text not null unique
);

create table if not exists public.group_members (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  name text not null,
  email text not null default '',
  role text not null check (role in ('admin', 'member')),
  joined_at timestamptz not null default now(),
  unique (group_id, user_id)
);

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  title text not null,
  amount numeric(12,2) not null,
  category text not null,
  paid_by uuid not null references public.profiles (id),
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  notes text not null default '',
  split_method text not null
);

create table if not exists public.expense_splits (
  id uuid primary key default gen_random_uuid(),
  expense_id uuid not null references public.expenses (id) on delete cascade,
  user_id uuid not null references public.profiles (id),
  amount numeric(12,2) not null,
  percentage numeric(8,2),
  shares numeric(8,2)
);

create table if not exists public.settlements (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  from_user uuid not null references public.profiles (id),
  to_user uuid not null references public.profiles (id),
  amount numeric(12,2) not null,
  status text not null check (status in ('pending', 'paid')),
  created_at timestamptz not null default now(),
  settled_at timestamptz
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', 'You'),
    coalesce(new.email, '')
  )
  on conflict (id) do update
    set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

create or replace function public.preview_group(p_code text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  g public.groups;
  payload json;
begin
  select * into g
  from public.groups
  where invite_code = upper(trim(p_code))
  limit 1;

  if g.id is null then
    return null;
  end if;

  select json_build_object(
    'group', row_to_json(g),
    'members', coalesce((
      select json_agg(row_to_json(m))
      from public.group_members m
      where m.group_id = g.id
    ), '[]'::json)
  ) into payload;

  return payload;
end;
$$;

create or replace function public.join_group(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  g public.groups;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select * into g
  from public.groups
  where invite_code = upper(trim(p_code))
  limit 1;

  if g.id is null then
    raise exception 'Invalid invite';
  end if;

  insert into public.group_members (group_id, user_id, name, email, role)
  select g.id, p.id, p.name, p.email, 'member'
  from public.profiles p
  where p.id = auth.uid()
  on conflict (group_id, user_id) do nothing;

  return g.id;
end;
$$;

alter table public.profiles enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.expenses enable row level security;
alter table public.expense_splits enable row level security;
alter table public.settlements enable row level security;

-- SECURITY DEFINER helpers avoid infinite recursion in RLS (policies must not query
-- group_members with a policy that itself reads group_members).
create or replace function public.is_group_member(_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.group_members
    where group_id = _group_id and user_id = auth.uid()
  );
$$;

create or replace function public.is_group_admin(_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.group_members
    where group_id = _group_id and user_id = auth.uid() and role = 'admin'
  );
$$;

create or replace function public.shares_group_with(_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.group_members mine
    join public.group_members theirs on mine.group_id = theirs.group_id
    where mine.user_id = auth.uid() and theirs.user_id = _user_id
  );
$$;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.shares_group_with(id));

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
  for insert to authenticated
  with check (id = auth.uid());

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

drop policy if exists "groups_member_select" on public.groups;
create policy "groups_member_select" on public.groups
  for select to authenticated
  using (created_by = auth.uid() or public.is_group_member(id));

drop policy if exists "groups_insert_own" on public.groups;
create policy "groups_insert_own" on public.groups
  for insert to authenticated
  with check (created_by = auth.uid());

drop policy if exists "groups_update_admin" on public.groups;
create policy "groups_update_admin" on public.groups
  for update to authenticated
  using (public.is_group_admin(id));

drop policy if exists "groups_delete_admin" on public.groups;
create policy "groups_delete_admin" on public.groups
  for delete to authenticated
  using (public.is_group_admin(id));

drop policy if exists "members_select" on public.group_members;
create policy "members_select" on public.group_members
  for select to authenticated
  using (user_id = auth.uid() or public.is_group_member(group_id));

drop policy if exists "members_insert_admin" on public.group_members;
create policy "members_insert_admin" on public.group_members
  for insert to authenticated
  with check (user_id = auth.uid() or public.is_group_admin(group_id));

drop policy if exists "members_update_admin" on public.group_members;
create policy "members_update_admin" on public.group_members
  for update to authenticated
  using (public.is_group_admin(group_id));

drop policy if exists "members_delete_admin" on public.group_members;
create policy "members_delete_admin" on public.group_members
  for delete to authenticated
  using (public.is_group_admin(group_id));

drop policy if exists "expenses_member_all" on public.expenses;
create policy "expenses_member_all" on public.expenses
  for all to authenticated
  using (public.is_group_member(group_id))
  with check (public.is_group_member(group_id));

drop policy if exists "splits_member_all" on public.expense_splits;
create policy "splits_member_all" on public.expense_splits
  for all to authenticated
  using (exists (
    select 1 from public.expenses e
    where e.id = expense_splits.expense_id and public.is_group_member(e.group_id)
  ))
  with check (exists (
    select 1 from public.expenses e
    where e.id = expense_splits.expense_id and public.is_group_member(e.group_id)
  ));

drop policy if exists "settlements_member_all" on public.settlements;
create policy "settlements_member_all" on public.settlements
  for all to authenticated
  using (public.is_group_member(group_id))
  with check (public.is_group_member(group_id));

create or replace function public.add_member_by_email(p_group_id uuid, p_email text, p_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  target public.profiles;
  member_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if not public.is_group_admin(p_group_id) then
    raise exception 'Only admins can add members';
  end if;

  select * into target
  from public.profiles
  where lower(email) = lower(trim(p_email))
  limit 1;

  if target.id is null then
    raise exception 'NO_PROFILE';
  end if;

  insert into public.group_members (group_id, user_id, name, email, role)
  values (
    p_group_id,
    target.id,
    coalesce(nullif(trim(p_name), ''), target.name),
    target.email,
    'member'
  )
  on conflict (group_id, user_id) do update
    set name = excluded.name
  returning id into member_id;

  if member_id is null then
    select id into member_id
    from public.group_members
    where group_id = p_group_id and user_id = target.id;
  end if;

  return member_id;
end;
$$;

grant execute on function public.join_group(text) to authenticated;
grant execute on function public.preview_group(text) to authenticated;
grant execute on function public.is_group_member(uuid) to authenticated;
grant execute on function public.is_group_admin(uuid) to authenticated;
grant execute on function public.shares_group_with(uuid) to authenticated;
grant execute on function public.add_member_by_email(uuid, text, text) to authenticated;
