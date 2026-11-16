# Creya

A Flutter mobile app where creatives (musicians, visual artists, designers and more) find each other and collaborate. Built from the "Creya Mobile Design" in Claude Design.

## Screens

Welcome, Your craft, Your face (onboarding) · Discover (swipe deck) · Collabs and Post a collab · Requests · Messages and Chat · Profile · Settings

## Status

The app has two backends behind the same interfaces (`lib/data/repositories.dart`):

- **Sample backend** (default): in-memory sample data. Sign-in, uploads and chat replies are simulated and nothing is saved between launches.
- **Supabase backend**: real accounts, profiles, uploads, discover, connections, collabs, chat with live messages, blocking, reports and account deletion. The schema is in `supabase/`.

Google sign-in is not set up yet. On the Supabase backend, "Continue with Google" creates an anonymous account instead, so everything else can be used for real. Choosing a profile photo and talent clip uses the device's photo library on both backends.

## Run it

```bash
flutter pub get
flutter run
```

To run against a Supabase project, pass its API URL and publishable key. The project needs the migrations in `supabase/` applied and anonymous sign-ins switched on (Authentication → Sign In / Providers):

```bash
flutter run --dart-define=SUPABASE_URL=https://<ref>.supabase.co --dart-define=SUPABASE_KEY=<publishable key>
```

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
