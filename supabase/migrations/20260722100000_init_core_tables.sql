-- M1: core reference + ATM tables
create extension if not exists postgis;

-- profiles: 1:1 with auth.users
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Scout',
  avatar_url text,
  -- forward-compat columns for later milestones (M3 trust, M4 gamification), unused in M1:
  trust_score numeric(6,2) not null default 50.00,
  points integer not null default 0,
  level integer not null default 1,
  created_at timestamptz not null default now()
);

alter table profiles enable row level security;

create policy "profiles are viewable by authenticated users"
  on profiles for select
  to authenticated
  using (true);

create policy "users can update their own profile"
  on profiles for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- auto-create a profile row when a new auth user signs up
create or replace function handle_new_user()
returns trigger
language plpgsql security definer as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', 'Scout'));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- currencies / denominations (currency-agnostic config, seeded for BWP in seed.sql)
create table currencies (
  code text primary key,
  name text not null,
  symbol text not null
);

alter table currencies enable row level security;

create policy "currencies are viewable by authenticated users"
  on currencies for select
  to authenticated
  using (true);

create table denominations (
  id uuid primary key default gen_random_uuid(),
  currency_code text not null references currencies(code),
  value numeric(12,2) not null,
  label text not null,
  sort_order integer not null,
  active boolean not null default true,
  unique (currency_code, value)
);

alter table denominations enable row level security;

create policy "denominations are viewable by authenticated users"
  on denominations for select
  to authenticated
  using (true);

-- atms
create table atms (
  id uuid primary key default gen_random_uuid(),
  bank_name text not null,
  branch_label text,
  atm_type text not null check (atm_type in ('in_branch', 'standalone')),
  currency_code text not null references currencies(code) default 'BWP',
  location geography(Point, 4326) not null,
  -- plain lat/lng columns derived from `location`, so PostgREST/Flutter clients
  -- can read coordinates directly without decoding WKB/GeoJSON client-side.
  lng double precision generated always as (ST_X(location::geometry)) stored,
  lat double precision generated always as (ST_Y(location::geometry)) stored,
  address text,
  created_by uuid references profiles(id),
  created_at timestamptz not null default now(),
  -- forward-compat, unused in M1 (populated once M2 confidence scoring lands):
  last_status text check (last_status in ('functional', 'out_of_order', 'no_cash', 'unknown')) default 'unknown',
  last_report_at timestamptz,
  confidence text check (confidence in ('high', 'medium', 'low')) default 'low'
);

create index atms_location_gix on atms using gist (location);

alter table atms enable row level security;

create policy "atms are viewable by authenticated users"
  on atms for select
  to authenticated
  using (true);

-- No insert policy on purpose: new ATMs are added via the add_atm() RPC
-- (see 20260722100200_rpc_submit_report.sql), which builds the `location`
-- geography value from plain lat/lng params so the client never has to
-- construct WKT/GeoJSON by hand.
