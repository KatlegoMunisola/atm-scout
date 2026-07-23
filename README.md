# ATM Scout

Crowdsourced ATM cash-availability monitor for Botswana ("Waze for Cash"). Human reports of ATM status (Functional / Out of Order / No Cash) and denomination availability, geofenced to prevent bogus remote reports.

This is **M1**: a working, demoable app (map, geofenced reporting, crowdsourced ATM coverage). Trust scores, gamification, follows/notifications, and status decay are planned for later milestones — see `docs/ARCHITECTURE.md` (roadmap section of the original plan) for the full design.

## Stack

- **App**: Flutter (`app/`)
- **Backend**: Supabase (Postgres + PostGIS, Auth, Realtime) (`supabase/`)
- **Maps**: Mapbox

## One-time setup

1. **Flutter SDK** and **Supabase CLI** must be on your PATH. If you used this session's install: `C:\flutter\bin` and `C:\tools\supabase` were added to your user PATH — open a new terminal for it to take effect.
2. **Mapbox tokens** (two different ones — both required):
   - A **public access token** (`pk...`) from your Mapbox account, for the app itself.
   - A **secret downloads token** (`sk...`, scope "Downloads:Read"), for Android to fetch the native Mapbox SDK during build. Add it to `~/.gradle/gradle.properties` (create the file if missing):
     ```
     MAPBOX_DOWNLOADS_TOKEN=sk.your-secret-token
     ```
     Never commit this token.
3. **Supabase project**: either run everything locally (`supabase start` in this directory — needs Docker Desktop running), or create a hosted project at supabase.com and `supabase link --project-ref <ref>` then `supabase db push`.
4. **App environment**: copy `app/.env.example` to `app/.env` and fill in:
   ```
   SUPABASE_URL=...        # from `supabase start` output, or your hosted project settings
   SUPABASE_ANON_KEY=...   # same
   MAPBOX_ACCESS_TOKEN=pk...
   ```

## Running

```bash
cd supabase && supabase start   # local Postgres + Auth + Realtime via Docker
cd ../app && flutter pub get
flutter run
```

## Database changes

Add new migrations under `supabase/migrations/` (timestamp-prefixed), then:

```bash
supabase db reset   # re-applies all migrations + seed.sql locally
supabase db push    # applies to the linked hosted project
```
