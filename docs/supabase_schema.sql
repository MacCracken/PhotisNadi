-- Supabase schema for Photis Nadi cloud sync
-- Run this in the Supabase SQL editor to set up tables

-- Enable RLS
alter default privileges in schema public grant all on tables to postgres, anon, authenticated, service_role;

-- Projects table
create table if not exists public.projects (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  key text not null,
  description text,
  created_at timestamptz not null default now(),
  modified_at timestamptz not null default now(),
  color text not null default '#4A90E2',
  icon_name text,
  task_counter integer not null default 0,
  is_archived boolean not null default false
);

alter table public.projects enable row level security;

create policy "Users can manage their own projects"
  on public.projects for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Tasks table
create table if not exists public.tasks (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  description text,
  status text not null default 'todo',
  priority text not null default 'medium',
  created_at timestamptz not null default now(),
  modified_at timestamptz not null default now(),
  due_date timestamptz,
  project_id uuid references public.projects(id) on delete set null,
  tags jsonb not null default '[]'::jsonb,
  task_key text,
  depends_on jsonb not null default '[]'::jsonb
);

alter table public.tasks enable row level security;

create policy "Users can manage their own tasks"
  on public.tasks for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Rituals table
create table if not exists public.rituals (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  description text,
  is_completed boolean not null default false,
  created_at timestamptz not null default now(),
  last_completed timestamptz,
  reset_time timestamptz,
  streak_count integer not null default 0,
  frequency text not null default 'daily'
);

alter table public.rituals enable row level security;

create policy "Users can manage their own rituals"
  on public.rituals for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Tags table
create table if not exists public.tags (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  color text not null,
  project_id uuid not null references public.projects(id) on delete cascade
);

alter table public.tags enable row level security;

create policy "Users can manage their own tags"
  on public.tags for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Indexes for performance
create index if not exists idx_tasks_user_id on public.tasks(user_id);
create index if not exists idx_tasks_project_id on public.tasks(project_id);
create index if not exists idx_projects_user_id on public.projects(user_id);
create index if not exists idx_rituals_user_id on public.rituals(user_id);
create index if not exists idx_tags_user_id on public.tags(user_id);
create index if not exists idx_tags_project_id on public.tags(project_id);

-- Enable realtime for sync
alter publication supabase_realtime add table public.tasks;
alter publication supabase_realtime add table public.projects;
alter publication supabase_realtime add table public.rituals;
alter publication supabase_realtime add table public.tags;
