import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_shell.dart';
import 'app_state.dart';
import 'data/fake_backend.dart';
import 'data/media.dart';
import 'data/repositories.dart';
import 'data/supabase_backend.dart';
import 'theme.dart';

/// Switches, set with `--dart-define`:
/// - `SUPABASE_URL` and `SUPABASE_KEY`: use a different Supabase project
///   (its API URL and publishable or anon key) than the one below. Set
///   `SUPABASE_URL=none` to run on the in-memory sample backend instead.
/// - `SCREEN`: open on one screen (welcome, craft, face, discover, collabs,
///   post, requests, messages, chat, profile, settings).
/// - `LIST_STATE`: show list screens as data, loading, empty or error.
// The Creya project. The key is the project's public `anon` key, which is
// designed to ship inside an app; what it can reach is limited by the
// database's row-level security rules, not by keeping it secret.
const _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://avwkcqssjzefsrlfcant.supabase.co',
);
const _supabaseKey = String.fromEnvironment(
  'SUPABASE_KEY',
  defaultValue:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF2d2tjcXNzanplZnNybGZjYW50Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ4OTIwOTAsImV4cCI6MjExMDQ2ODA5MH0.sFAXkMoPQAjCYzEcSYYIXAFpprXO2QXz29oZQw7beEw',
);
const _screenKey = String.fromEnvironment('SCREEN');
const _listState = String.fromEnvironment('LIST_STATE', defaultValue: 'data');

Future<Backend> _backend() async {
  // Single-screen previews have no account to sign in with, so they use the
  // sample data.
  if (_supabaseUrl == 'none' || _screenKey.isNotEmpty) return fakeBackend();
  await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseKey);
  return supabaseBackend(Supabase.instance.client);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(
    CreyaApp(
      state: AppState(
        backend: await _backend(),
        picker: DeviceMediaPicker(),
        listState: ListState.values.byName(_listState),
        screenKey: _screenKey.isEmpty ? null : _screenKey,
      ),
    ),
  );
}

class CreyaApp extends StatefulWidget {
  const CreyaApp({super.key, required this.state});

  final AppState state;

  @override
  State<CreyaApp> createState() => _CreyaAppState();
}

class _CreyaAppState extends State<CreyaApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back to the app picks up anything that happened while away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.state.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: widget.state,
      child: MaterialApp(
        title: 'Creya',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const AppShell(),
      ),
    );
  }
}
