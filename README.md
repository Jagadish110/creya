# Creya

A Flutter mobile app where creatives (musicians, visual artists, designers and more) find each other and collaborate. Built from the "Creya Mobile Design" in Claude Design.

## Screens

Welcome, Your craft, Your face (onboarding) · Discover (swipe deck) · Collabs and Post a collab · Requests · Messages and Chat · Profile · Settings

## Status

The app has two backends behind the same interfaces (`lib/data/repositories.dart`):

- **Supabase backend** (default): real accounts with Google sign-in, profiles, uploads, discover, connections, collabs, chat with live messages, blocking, reports and account deletion. The schema is in `supabase/`. It is set up to use the Creya project named in `lib/main.dart`.
- **Sample backend**: in-memory sample data, with simulated sign-in, uploads and chat replies. Used by the tests and by single-screen previews (`--dart-define=SCREEN=...`), or on request with `--dart-define=SUPABASE_URL=none`.

## Run it

```bash
flutter pub get
flutter run
```

To use a different Supabase project, pass its API URL and key:

```bash
flutter run --dart-define=SUPABASE_URL=https://<ref>.supabase.co --dart-define=SUPABASE_KEY=<anon or publishable key>
```

### Google sign-in setup

Google sign-in opens the browser and returns to the app through the link `com.joincreya.creya://login-callback`. In the Supabase dashboard:

1. Authentication → Sign In / Providers → **Google**: switch it on and enter the **Web application** OAuth client's ID and secret from Google Cloud.
2. Authentication → URL Configuration → **Redirect URLs**: add `com.joincreya.creya://login-callback`.
3. In Google Cloud, the Web client's **Authorized redirect URIs** must include `https://<ref>.supabase.co/auth/v1/callback`.

To open on a single screen, or to see the loading, empty and error states:

```bash
flutter run --dart-define=SCREEN=chat --dart-define=LIST_STATE=loading
```

`SCREEN` is one of `welcome`, `craft`, `face`, `discover`, `collabs`, `post`, `requests`, `messages`, `chat`, `profile`, `settings`. `LIST_STATE` is one of `data`, `loading`, `empty`, `error`.

## Tests

```bash
flutter test
```

The Supabase backend has its own tests, which run against a real Supabase stack and are skipped otherwise. With Docker and the Supabase CLI:

```bash
supabase start
SUPABASE_TEST_URL=http://127.0.0.1:54321 SUPABASE_TEST_KEY=<publishable key it prints> flutter test test/backend
```

## Android build note

`android/gradle.properties` sets `org.gradle.java.home` to a JDK 17 path on the original development machine, because Gradle 8.14 cannot run on the Java 25 bundled with recent Android Studio. Change or remove that line to match your machine.

## Layout

- `lib/theme.dart`: colour tokens, fonts, gradients
- `lib/app_state.dart`: navigation, drafts and what each screen shows
- `lib/data/repositories.dart`: the data layer's interfaces, one per area
- `lib/data/fake_backend.dart`: the in-memory sample backend
- `lib/data/supabase_backend.dart`: the Supabase backend
- `lib/data/media.dart`: choosing a photo or clip from the device, and the upload limits
- `lib/models.dart`, `lib/mock_data.dart`: data types and sample content
- `supabase/`: database schema and local-stack config for the Supabase backend
- `lib/widgets.dart`, `lib/icons.dart`: shared UI pieces and icons
- `lib/screens/`: one file per area
- `assets/fonts/`: DM Sans, DM Mono and Cormorant Garamond (SIL Open Font License)
