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
/// - `SUPABASE_URL` and `SUPABASE_KEY`: run against that Supabase project
///   (its API URL and publishable key). Without them the app runs on the
///   in-memory sample backend.
/// - `SCREEN`: open on one screen (welcome, craft, face, discover, collabs,
///   post, requests, messages, chat, profile, settings).
/// - `LIST_STATE`: show list screens as data, loading, empty or error.
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseKey = String.fromEnvironment('SUPABASE_KEY');
const _screenKey = String.fromEnvironment('SCREEN');
const _listState = String.fromEnvironment('LIST_STATE', defaultValue: 'data');

Future<Backend> _backend() async {
  if (_supabaseUrl.isEmpty || _supabaseKey.isEmpty) return fakeBackend();
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
