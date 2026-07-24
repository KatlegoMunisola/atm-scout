-- M3: let users correct outdated ATM info (bank name, branch label, type,
-- deposit support), reposition a misplaced pin, and report an ATM as no
-- longer existing at its recorded location.

alter table atms
  add column deposit_support text
    check (deposit_support in ('yes', 'no', 'unknown'))
    not null default 'unknown';

-- ATMs are never hard-deleted (so past reports/audit history stay intact) -
-- removed_at marks one as gone and the RLS policy below hides it from
-- everyone's map, without destroying the row.
alter table atms add column removed_at timestamptz;

drop policy "atms are viewable by authenticated users" on atms;
create policy "atms are viewable by authenticated users"
  on atms for select
  to authenticated
  using (removed_at is null);

-- Extend the existing report vocabulary with 'removed': an assertion that
-- there's no ATM at this location anymore. Reuses the same geofenced
-- submit_atm_report() RPC and atm_reports table as status reports, since
-- it's the same kind of claim ("I stood here and observed X").
alter table atm_reports drop constraint atm_reports_status_check;
alter table atm_reports add constraint atm_reports_status_check
  check (status in ('functional', 'out_of_order', 'no_cash', 'removed'));

create or replace function submit_atm_report(
  p_atm_id uuid,
  p_lat double precision,
  p_lng double precision,
  p_accuracy_meters numeric,
  p_status text,
  p_denominations jsonb   -- [{"denomination_id": "...", "dispensed": true}, ...]
) returns atm_reports
language plpgsql
security definer
set search_path = public
as $$
declare
  v_atm_location geography;
  v_distance numeric;
  v_verified boolean;
  v_report atm_reports;
  v_point geography := ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography;
  v_removed_reports integer;
begin
  if auth.uid() is null then
    raise exception 'AUTH_REQUIRED' using errcode = '28000';
  end if;

  select location into v_atm_location from atms where id = p_atm_id;
  if v_atm_location is null then
    raise exception 'ATM_NOT_FOUND' using errcode = 'P0002';
  end if;

  v_distance := ST_Distance(v_atm_location, v_point);
  v_verified := ST_DWithin(v_atm_location, v_point, 50);

  if not v_verified then
    raise exception 'GEOFENCE_FAILED: % meters from ATM (max 50m)', round(v_distance, 1)
      using errcode = 'P0001';
  end if;

  insert into atm_reports (
    atm_id, reporter_id, status, reported_location,
    distance_meters, geofence_verified, gps_accuracy_meters
  )
  values (
    p_atm_id, auth.uid(), p_status, v_point,
    v_distance, true, p_accuracy_meters
  )
  returning * into v_report;

  insert into atm_report_notes (report_id, denomination_id, dispensed)
  select v_report.id, (d->>'denomination_id')::uuid, (d->>'dispensed')::boolean
  from jsonb_array_elements(p_denominations) d;

  if p_status = 'removed' then
    -- Require corroboration from more than one reporter before hiding an
    -- ATM from everyone's map - a single report shouldn't be able to wipe a
    -- real ATM off the map.
    select count(distinct reporter_id) into v_removed_reports
    from atm_reports
    where atm_id = p_atm_id and status = 'removed';

    if v_removed_reports >= 2 then
      update atms set removed_at = v_report.created_at where id = p_atm_id;
    end if;
  else
    update atms
    set last_status = p_status, last_report_at = v_report.created_at
    where id = p_atm_id;
  end if;

  return v_report;
end;
$$;

revoke all on function submit_atm_report(uuid, double precision, double precision, numeric, text, jsonb) from public;
grant execute on function submit_atm_report(uuid, double precision, double precision, numeric, text, jsonb) to authenticated;

-- New RPC: correct static ATM details, or reposition the pin. Field edits
-- require the same 50m geofence as a status report; repositioning doesn't -
-- you can't be "near" a pin you're saying is in the wrong place, so it just
-- trusts the reporter's own GPS reading as the corrected location, the same
-- trust level the app already places in every other report's coordinates.
create or replace function submit_atm_correction(
  p_atm_id uuid,
  p_lat double precision,
  p_lng double precision,
  p_accuracy_meters numeric,
  p_reposition boolean default false,
  p_bank_name text default null,
  p_branch_label text default null,
  p_atm_type text default null,
  p_deposit_support text default null
) returns atms
language plpgsql
security definer
set search_path = public
as $$
declare
  v_atm_location geography;
  v_point geography := ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography;
  v_atm atms;
begin
  if auth.uid() is null then
    raise exception 'AUTH_REQUIRED' using errcode = '28000';
  end if;

  select location into v_atm_location from atms where id = p_atm_id and removed_at is null;
  if v_atm_location is null then
    raise exception 'ATM_NOT_FOUND' using errcode = 'P0002';
  end if;

  if not p_reposition then
    if not ST_DWithin(v_atm_location, v_point, 50) then
      raise exception 'GEOFENCE_FAILED: % meters from ATM (max 50m)',
        round(ST_Distance(v_atm_location, v_point), 1)
        using errcode = 'P0001';
    end if;
  end if;

  update atms
  set
    location = case when p_reposition then v_point else location end,
    bank_name = coalesce(p_bank_name, bank_name),
    branch_label = case
      when p_branch_label is null then branch_label
      when p_branch_label = '' then null
      else p_branch_label
    end,
    atm_type = coalesce(p_atm_type, atm_type),
    deposit_support = coalesce(p_deposit_support, deposit_support)
  where id = p_atm_id
  returning * into v_atm;

  return v_atm;
end;
$$;

revoke all on function submit_atm_correction(uuid, double precision, double precision, numeric, boolean, text, text, text, text) from public;
grant execute on function submit_atm_correction(uuid, double precision, double precision, numeric, boolean, text, text, text, text) to authenticated;
