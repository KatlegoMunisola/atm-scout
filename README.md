# ATM Scout

A crowdsourced map of ATM cash availability in Botswana. Think "Waze for cash": people standing at an ATM report whether it works, and everyone else sees the latest status before making the trip.

## The problem

In Botswana, ATMs often run out of cash, especially around month end, and there is no way to know before you get there. Drivers go from ATM to ATM, queue, and find the machine out of order or empty. ATM Scout lets people who are physically at an ATM share what they see, so others can plan.

## Features

- **Live map:** all known ATMs on a Mapbox map, with a status for each: functional, out of order, no cash, or unknown.
- **Quick reports:** report an ATM's status and which notes it dispensed (P10, P20, P50, P100, P200) in a few taps.
- **Geofenced reporting:** you can only report on an ATM when you are within 50 metres of it. The check runs on the server as well as in the app, so remote or made-up reports are rejected.
- **Confidence badges:** each ATM shows how much to trust its status (high, medium or low) based on how recent and how consistent its reports are. Statuses older than four days fall back to unknown.
- **Crowdsourced coverage:** add an ATM that is missing from the map.
- **Corrections:** fix an ATM's bank name, branch label, type and deposit support, move a misplaced pin, or report that an ATM no longer exists. Removed ATMs are hidden but never deleted, so report history stays intact.
- **Sign-in:** passwordless email sign-in with a one-time code.
- **Seed data:** 124 ATMs across Botswana, sourced from OpenStreetMap.

## How it works

```
Flutter app (Riverpod, go_router)
  |-- Mapbox            map and ATM pins
  |-- Geolocator        device position for geofencing
  '-- Supabase
        |-- Auth        email one-time code
        |-- Postgres + PostGIS   ATMs, reports, denominations
        |-- RPC submit_atm_report()   server-side 50 m check, then insert
        '-- pg_cron     hourly confidence and status decay
```

**Geofencing.** Reports go through a database function, `submit_atm_report()`, rather than a direct insert. It requires a signed-in user, measures the distance between the reporter and the ATM with PostGIS, and rejects anything beyond 50 metres. The same radius is defined in the app, so users see an error before they submit.

**Confidence and decay.** A job runs every hour and looks at each ATM's three most recent reports:

| Confidence | Rule |
| --- | --- |
| High | At least 3 reports, all agreeing, the latest within 4 days |
| Medium | At least 1 report, the latest within 4 days |
| Low | No reports, or nothing recent enough to trust |

An ATM with no report for more than four days reverts to an unknown status.

**Data security.** Row-level security is enabled on every table, and the report and add-ATM functions run with checks inside the database rather than trusting the client.

## Tech stack

- **App:** Flutter and Dart, Riverpod for state, go_router for navigation, `geolocator` for location, `mapbox_maps_flutter` for maps
- **Backend:** Supabase (Postgres, PostGIS, Auth, Realtime), `pg_cron` for scheduled jobs
- **CI and distribution:** GitHub Actions (`flutter analyze` and `flutter test`), Firebase App Distribution for Android test builds

## Project structure

| Folder | Contents |
| --- | --- |
| `app/lib/features/` | Map, ATM detail, quick report, add and edit ATM, sign-in |
| `app/lib/core/` | Configuration, geofence service, Supabase client |
| `app/lib/shared/` | Models, widgets and utilities |
| `app/test/` | Unit and widget tests |
| `supabase/migrations/` | Schema, functions, security policies and seed data |
| `.github/workflows/` | CI and test-build distribution |

## Getting started

### Requirements
- Flutter SDK and the Supabase CLI
- Docker Desktop, if you run Supabase locally
- A Mapbox account with two tokens:
  - a **public access token** (`pk...`) for the app
  - a **secret downloads token** (`sk...`, scope `Downloads:Read`) so Android can fetch the Mapbox SDK at build time. Add it to `~/.gradle/gradle.properties` as `MAPBOX_DOWNLOADS_TOKEN=sk...` and never commit it.

### Set up and run

1. **Backend:** run it locally with `supabase start` from the `supabase/` folder, or create a hosted project, then run `supabase link --project-ref <ref>` and `supabase db push`.
2. **Environment:** copy `app/.env.example` to `app/.env` and fill in:
   ```
   SUPABASE_URL=...
   SUPABASE_ANON_KEY=...
   MAPBOX_ACCESS_TOKEN=pk...
   ```
3. **Run the app:**
   ```bash
   cd app
   flutter pub get
   flutter run
   ```

### Tests

```bash
cd app
flutter analyze
flutter test
```

### Database changes

Add a timestamp-prefixed migration under `supabase/migrations/`, then run `supabase db reset` to re-apply everything locally, or `supabase db push` to apply it to the linked project.

### Share a build with testers

Go to the repository's **Actions** tab, choose **Distribute to Firebase App Distribution** and click **Run workflow**. It runs analysis and tests, builds a signed release APK and sends it to your tester group. Required repository secrets are the Supabase and Mapbox values above, the Android keystore and its passwords, `FIREBASE_APP_ID` and `FIREBASE_SERVICE_ACCOUNT_JSON`.

## Roadmap

Built:
- [x] **M1:** map, geofenced reporting, adding ATMs
- [x] **M2:** confidence badges and status decay
- [x] **M3:** ATM corrections, deposit support, removal reports

Planned:
- [ ] Reporter trust scores
- [ ] Gamification
- [ ] Follow an ATM and get notifications when its status changes

## Limitations

- The 50-metre check relies on the phone's GPS, which can be spoofed. Trust scores are planned to reduce the impact of bad reports.
- Coverage starts from OpenStreetMap data and depends on users to add and correct ATMs.
- Statuses are only as good as the latest reports, so quiet ATMs show a low confidence.

## Data credit

Initial ATM locations come from [OpenStreetMap](https://www.openstreetmap.org/copyright), licensed under the ODbL.

## Author

Katlego Caangu Munisola, [katlego.tech](https://katlego.tech/)
