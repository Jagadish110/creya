# Creya

A Flutter mobile app where creatives (musicians, visual artists, designers and more) find each other and collaborate. Built from the "Creya Mobile Design" in Claude Design.

## Screens

Welcome, Your craft, Your face (onboarding) · Discover (swipe deck) · Collabs and Post a collab · Requests · Messages and Chat · Profile · Settings

## Status

The app runs on an in-memory backend (`lib/data/fake_backend.dart`) seeded with sample data: Google sign-in, uploads and chat replies are simulated, and nothing is saved between launches. Choosing a profile photo and talent clip uses the device's real photo library; the files stay on the device until a real backend exists. The screens only talk to the repository interfaces in `lib/data/repositories.dart`, so a real backend can replace the fake one without changing them. The database schema for that backend is in `supabase/`.

## Run it

```bash
flutter pub get
flutter run
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

## Android build note

`android/gradle.properties` sets `org.gradle.java.home` to a JDK 17 path on the original development machine, because Gradle 8.14 cannot run on the Java 25 bundled with recent Android Studio. Change or remove that line to match your machine.

## Layout

- `lib/theme.dart`: colour tokens, fonts, gradients
- `lib/app_state.dart`: navigation, drafts and what each screen shows
- `lib/data/repositories.dart`: the data layer's interfaces, one per area
- `lib/data/fake_backend.dart`: the in-memory implementation used today
- `lib/data/media.dart`: choosing a photo or clip from the device, and the upload limits
- `lib/models.dart`, `lib/mock_data.dart`: data types and sample content
- `supabase/`: database schema for the real backend (not yet connected)
- `lib/widgets.dart`, `lib/icons.dart`: shared UI pieces and icons
- `lib/screens/`: one file per area
- `assets/fonts/`: DM Sans, DM Mono and Cormorant Garamond (SIL Open Font License)
