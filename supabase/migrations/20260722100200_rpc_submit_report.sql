-- M1: server-authoritative RPCs (report submission + adding new ATMs)
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

  update atms
  set last_status = p_status, last_report_at = v_report.created_at
  where id = p_atm_id;

  return v_report;
end;
$$;

revoke all on function submit_atm_report(uuid, double precision, double precision, numeric, text, jsonb) from public;
grant execute on function submit_atm_report(uuid, double precision, double precision, numeric, text, jsonb) to authenticated;

-- M1: add a new crowdsourced ATM (client supplies plain lat/lng; this builds the geography point)
create or replace function add_atm(
  p_bank_name text,
  p_atm_type text,
  p_lat double precision,
  p_lng double precision,
  p_branch_label text default null,
  p_address text default null,
  p_currency_code text default 'BWP'
) returns atms
language plpgsql
security definer
set search_path = public
as $$
declare
  v_atm atms;
begin
  if auth.uid() is null then
    raise exception 'AUTH_REQUIRED' using errcode = '28000';
  end if;

  insert into atms (bank_name, branch_label, atm_type, currency_code, location, address, created_by)
  values (
    p_bank_name,
    p_branch_label,
    p_atm_type,
    p_currency_code,
    ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
    p_address,
    auth.uid()
  )
  returning * into v_atm;

  return v_atm;
end;
$$;

revoke all on function add_atm(text, text, double precision, double precision, text, text, text) from public;
grant execute on function add_atm(text, text, double precision, double precision, text, text, text) to authenticated;
