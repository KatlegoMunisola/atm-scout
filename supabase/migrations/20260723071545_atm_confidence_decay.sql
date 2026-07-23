-- M2: ATM confidence + status decay.
-- Populates the atms.confidence/last_status columns that have sat dormant
-- since M1 (see 20260722100000_init_core_tables.sql), via a scheduled job
-- rather than computed-on-read, matching those columns' original intent as
-- stored, populated values.

create extension if not exists pg_cron;

-- Not client-callable (no auth.uid() guard, no grant to authenticated) —
-- only pg_cron's internal scheduler should invoke this, as the job owner.
create or replace function refresh_atm_confidence()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Revert stale ATMs (no report in 4+ days) back to unknown status.
  update atms
  set last_status = 'unknown'
  where last_report_at is not null
    and last_report_at < now() - interval '4 days'
    and last_status <> 'unknown';

  -- Recompute confidence from each ATM's most recent 3 reports:
  --  high   - at least 3 reports, all agreeing, most recent within 4 days
  --  medium - at least 1 report, most recent within 4 days (but not "high")
  --  low    - no reports, or nothing recent enough to trust
  with ranked_reports as (
    select
      atm_id,
      status,
      created_at,
      row_number() over (partition by atm_id order by created_at desc) as rn
    from atm_reports
  ),
  last_three as (
    select atm_id, status, created_at
    from ranked_reports
    where rn <= 3
  ),
  aggregated as (
    select
      atm_id,
      count(*) as report_count,
      count(distinct status) as distinct_statuses,
      max(created_at) as most_recent_at
    from last_three
    group by atm_id
  ),
  computed as (
    select
      a.id as atm_id,
      case
        when agg.report_count >= 3
          and agg.distinct_statuses = 1
          and agg.most_recent_at >= now() - interval '4 days'
          then 'high'
        when agg.report_count >= 1
          and agg.most_recent_at >= now() - interval '4 days'
          then 'medium'
        else 'low'
      end as new_confidence
    from atms a
    left join aggregated agg on agg.atm_id = a.id
  )
  update atms a
  set confidence = computed.new_confidence
  from computed
  where computed.atm_id = a.id
    and a.confidence is distinct from computed.new_confidence;
end;
$$;

revoke all on function refresh_atm_confidence() from public;

select cron.schedule(
  'atm-confidence-decay',
  '0 * * * *', -- hourly
  $$select public.refresh_atm_confidence()$$
);
