-- M1: report events + note-tracker
create table atm_reports (
  id uuid primary key default gen_random_uuid(),
  atm_id uuid not null references atms(id) on delete cascade,
  reporter_id uuid not null references profiles(id),
  status text not null check (status in ('functional', 'out_of_order', 'no_cash')),
  reported_location geography(Point, 4326) not null,
  distance_meters numeric(8,2) not null,
  geofence_verified boolean not null default false,
  gps_accuracy_meters numeric(6,2),
  created_at timestamptz not null default now()
);

create index atm_reports_atm_id_created_idx on atm_reports (atm_id, created_at desc);
create index atm_reports_reporter_idx on atm_reports (reporter_id);

alter table atm_reports enable row level security;

create policy "atm reports are viewable by authenticated users"
  on atm_reports for select
  to authenticated
  using (true);

-- No insert policy granted here on purpose: all inserts must go through the
-- submit_atm_report() RPC (see 20260722100200_rpc_submit_report.sql) so the
-- 50m geofence check is enforced server-side and cannot be bypassed by a
-- direct table insert from the client.

create table atm_report_notes (
  report_id uuid not null references atm_reports(id) on delete cascade,
  denomination_id uuid not null references denominations(id),
  dispensed boolean not null,
  primary key (report_id, denomination_id)
);

alter table atm_report_notes enable row level security;

create policy "atm report notes are viewable by authenticated users"
  on atm_report_notes for select
  to authenticated
  using (true);

-- Same rationale as atm_reports: no direct insert policy, RPC-only.
