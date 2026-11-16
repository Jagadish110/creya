# Creya

A Flutter mobile app where creatives (musicians, visual artists, designers and more) find each other and collaborate. Built from the "Creya Mobile Design" in Claude Design.

## Screens

Welcome, Your craft, Your face (onboarding) · Discover (swipe deck) · Collabs and Post a collab · Requests · Messages and Chat · Profile · Settings

## Status

This is the front end only. All data is sample data held in memory (`lib/mock_data.dart`), and Google sign-in, photo and clip uploads, and chat replies are simulated. Nothing is saved between launches.

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
- `lib/app_state.dart`: all app state and behaviour
- `lib/models.dart`, `lib/mock_data.dart`: data types and sample content
- `lib/widgets.dart`, `lib/icons.dart`: shared UI pieces and icons
- `lib/screens/`: one file per area
- `assets/fonts/`: DM Sans, DM Mono and Cormorant Garamond (SIL Open Font License)
