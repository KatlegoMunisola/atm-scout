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

## Release / distribution (Android)

Test builds go out via [Firebase App Distribution](https://firebase.google.com/docs/app-distribution),
built and uploaded by the `.github/workflows/distribute.yml` GitHub Actions workflow.

### Cutting a new build for testers

Go to the repo's **Actions** tab → **Distribute to Firebase App Distribution** →
**Run workflow**. Optionally fill in release notes and a tester group (defaults to
`testers`). The workflow builds a signed release APK, runs `flutter analyze`/`flutter
test` as a gate, and uploads it — testers get notified automatically.

### One-time setup (already done for this repo, documented for reference)

1. Generate a release keystore and keep the file + passwords in a password manager —
   this is the app's permanent signing identity, unrecoverable if lost:
   ```bash
   keytool -genkeypair -v -keystore release.keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Register the Android app (`com.atmscout.app.atm_scout`) under the Firebase project
   via Firebase Console → Project Settings → Your apps → Add app → Android, and commit
   the downloaded `google-services.json` to `app/android/app/google-services.json`
   (this file isn't a secret — it's project identifiers, not private key material).
3. Create a tester group and add tester emails: Firebase Console → App Distribution →
   Testers & Groups.
4. Create a GCP service account scoped to the `roles/firebaseappdistro.admin` role for
   CI to authenticate as, and download its JSON key:
   ```bash
   gcloud iam service-accounts create github-actions-appdistribution \
     --project=<project-id> --display-name="GitHub Actions App Distribution"
   gcloud projects add-iam-policy-binding <project-id> \
     --member="serviceAccount:github-actions-appdistribution@<project-id>.iam.gserviceaccount.com" \
     --role="roles/firebaseappdistro.admin"
   gcloud iam service-accounts keys create key.json \
     --iam-account=github-actions-appdistribution@<project-id>.iam.gserviceaccount.com
   ```
5. Add these repository secrets (GitHub → Settings → Secrets and variables →
   Actions): `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `MAPBOX_ACCESS_TOKEN`,
   `MAPBOX_DOWNLOADS_TOKEN`, `ANDROID_KEYSTORE_BASE64` (base64 of the `.jks` file),
   `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`,
   `FIREBASE_APP_ID` (from Firebase Console → Project Settings, after step 2),
   `FIREBASE_SERVICE_ACCOUNT_JSON` (the full JSON content from step 4).

### Local release builds

For local testing of a real signed release build (recommended before trusting a new
CI config), create `app/android/key.properties` (gitignored) pointing at a local copy
of the keystore:

```properties
storePassword=<value>
keyPassword=<value>
keyAlias=upload
storeFile=release.keystore.jks
```

Place the keystore file at `app/android/app/release.keystore.jks`, then run
`flutter build apk --release` from `app/`. Without `key.properties` present, release
builds fall back to debug signing so `flutter run --release` keeps working for anyone
without release secrets.
