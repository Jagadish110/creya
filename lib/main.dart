import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_shell.dart';
import 'app_state.dart';
import 'data/fake_backend.dart';
import 'theme.dart';

/// Development switches, set with `--dart-define`:
/// - `SCREEN`: open on one screen (welcome, craft, face, discover, collabs,
///   post, requests, messages, chat, profile, settings).
/// - `LIST_STATE`: show list screens as data, loading, empty or error.
const _screenKey = String.fromEnvironment('SCREEN');
const _listState = String.fromEnvironment('LIST_STATE', defaultValue: 'data');

void main() {
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
        backend: fakeBackend(),
        listState: ListState.values.byName(_listState),
        screenKey: _screenKey.isEmpty ? null : _screenKey,
      ),
    ),
  );
}

class CreyaApp extends StatelessWidget {
  const CreyaApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'Creya',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const AppShell(),
      ),
    );
  }
}
