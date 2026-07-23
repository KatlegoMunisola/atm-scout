-- M1 fix: RLS policies alone don't grant access — Postgres also requires the
-- underlying table privilege before a policy is even evaluated. None of the
-- earlier M1 migrations granted these, so every table was unreachable via
-- PostgREST despite having correct RLS policies.
grant select on profiles, currencies, denominations, atms, atm_reports, atm_report_notes
  to authenticated;

-- profiles has a direct client-side "update own profile" policy (see
-- 20260722100000_init_core_tables.sql), so it needs the update privilege too.
-- All other write paths are RPC-only via security definer functions, which
-- run as the function owner and don't need direct table grants.
grant update on profiles to authenticated;
