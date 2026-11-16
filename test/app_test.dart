import 'dart:io';

import 'package:creya/app_state.dart';
import 'package:creya/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lets toast and swipe timers finish so no test ends with one pending.
const _settle = Duration(seconds: 3);

Future<AppState> _pump(
  WidgetTester tester, {
  String? screen,
  ListState listState = ListState.data,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state = AppState(screenKey: screen, listState: listState);
  await tester.pumpWidget(CreyaApp(state: state));
  await tester.pump();
  return state;
}

/// Tests otherwise render with a wide placeholder font, which would report
/// overflows that can't happen with the app's real fonts.
Future<void> _loadFonts() async {
  const families = {
    'DMSans': ['Regular', 'Medium', 'SemiBold', 'Bold'],
    'Cormorant': ['SemiBold', 'Bold', 'BoldItalic'],
    'DMMono': ['Regular'],
  };
  const files = {'Cormorant': 'CormorantGaramond'};
  for (final MapEntry(key: family, value: styles) in families.entries) {
    final loader = FontLoader(family);
    for (final style in styles) {
      final name = files[family] ?? family;
      final bytes = File('assets/fonts/$name-$style.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

void main() {
  setUpAll(_loadFonts);

  const screens = {
    'welcome': 'Continue with Google',
    'craft': 'Full name',
    'face': 'Clip ready · 0:20',
    'discover': 'Amara Okafor',
    'collabs': 'Producer for my debut EP',
    'post': 'Publish',
    'requests': 'Kenji Watanabe',
    'messages': 'Maya Lindqvist',
    'chat': 'Want me to mock up a cover for the single?',
    'profile': 'Preview as others',
    'settings': 'Push notifications',
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} renders without overflow', (tester) async {
      await _pump(tester, screen: entry.key);
      expect(find.text(entry.value), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final listState in [
    ListState.loading,
    ListState.empty,
    ListState.error,
  ]) {
    for (final screen in ['collabs', 'requests', 'messages']) {
      testWidgets('$screen shows the ${listState.name} state', (tester) async {
        await _pump(tester, screen: screen, listState: listState);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('onboarding requires a photo and clip', (tester) async {
    final state = await _pump(tester);

    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();

    await tester.tap(find.text('Create account'));
    await tester.pump();
    expect(state.stage, AppStage.face);
    expect(
      find.text('Add a profile photo and a talent clip to continue'),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel(RegExp('Choose profile photo')));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel(RegExp('Upload talent clip')));
    await tester.pump(const Duration(seconds: 2));
    expect(state.clip, ClipStatus.done);

    await tester.tap(find.text('Create account'));
    await tester.pump();
    expect(state.stage, AppStage.app);
    expect(find.text('Welcome to Creya, Jordan'), findsOneWidget);
    await tester.pump(_settle);
  });

  testWidgets('swiping past the threshold connects', (tester) async {
    final state = await _pump(tester, screen: 'discover');

    await tester.drag(find.text('Amara Okafor'), const Offset(200, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(state.visibleDeck.first, 'lucia');
    expect(find.text('Connection request sent to Amara'), findsOneWidget);
    await tester.pump(_settle);
  });

  testWidgets('a short drag snaps back and keeps the card', (tester) async {
    final state = await _pump(tester, screen: 'discover');

    await tester.drag(find.text('Amara Okafor'), const Offset(60, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(state.visibleDeck.first, 'amara');
  });

  testWidgets('skip button empties the deck to the caught-up state', (
    tester,
  ) async {
    final state = await _pump(tester, screen: 'discover');

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.bySemanticsLabel('Skip'));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(state.visibleDeck, isEmpty);
    expect(find.text('Refresh queue'), findsOneWidget);
    await tester.tap(find.text('Refresh queue'));
    await tester.pump();
    expect(state.visibleDeck, hasLength(5));
  });

  testWidgets('accepting a request removes it and opens a chat', (
    tester,
  ) async {
    final state = await _pump(tester, screen: 'requests');
    expect(state.requestBadge, 4);

    await tester.tap(find.text('Accept').first);
    await tester.pump();
    expect(state.requestBadge, 3);
    expect(state.chats.first.personId, 'kenji');
    await tester.pump(_settle);
  });

  testWidgets('sending a message gets the simulated reply', (tester) async {
    final state = await _pump(tester, screen: 'chat');

    await tester.enterText(find.byType(TextField), 'Yes please');
    await tester.tap(find.bySemanticsLabel('Send'));
    await tester.pump();
    expect(find.text('Yes please'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 600));
    expect(state.typing, isTrue);
    await tester.pump(const Duration(seconds: 2));
    expect(state.typing, isFalse);
    expect(find.text('Sounds good, let’s do it.'), findsOneWidget);
  });

  testWidgets('publishing needs a title, then lands in My posts', (
    tester,
  ) async {
    final state = await _pump(tester, screen: 'collabs');

    await tester.tap(find.text('+ Post'));
    await tester.pump();
    await tester.tap(find.text('Publish'));
    await tester.pump();
    expect(state.sub, SubScreen.post);

    await tester.enterText(find.byType(TextField).first, 'New single');
    await tester.pump();
    await tester.tap(find.text('Publish'));
    await tester.pump();
    expect(state.sub, SubScreen.none);
    expect(state.collabMode, CollabMode.mine);
    expect(find.text('New single'), findsOneWidget);
    await tester.pump(_settle);
  });

  testWidgets('renaming a post keeps its applicants', (tester) async {
    final state = await _pump(tester, screen: 'collabs');
    final post = state.mine.first;
    expect(state.applicantsFor(post), 1);

    state.editPost(post);
    state.updatePostDraft(title: 'Renamed');
    state.publishPost();
    await tester.pump();
    expect(state.applicantsFor(state.mine.first), 1);
    await tester.pump(_settle);
  });

  testWidgets('blocking hides a person everywhere', (tester) async {
    final state = await _pump(tester, screen: 'requests');

    await tester.tap(find.text('View profile').first);
    await tester.pump();
    expect(state.viewId, 'kenji');
    await tester.ensureVisible(find.text('Block'));
    await tester.tap(find.text('Block'));
    await tester.pump();
    expect(state.connections.any((r) => r.personId == 'kenji'), isFalse);
    expect(state.browse.any((c) => c.ownerId == 'kenji'), isFalse);
    await tester.pump(_settle);
  });

  testWidgets('sign out returns to a fresh welcome screen', (tester) async {
    final state = await _pump(tester, screen: 'settings');

    await tester.ensureVisible(find.text('Sign out'));
    await tester.tap(find.text('Sign out'));
    await tester.pump();
    expect(state.stage, AppStage.welcome);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('delete account asks for confirmation first', (tester) async {
    final state = await _pump(tester, screen: 'settings');

    await tester.ensureVisible(find.text('Delete account'));
    await tester.tap(find.text('Delete account'));
    await tester.pump();
    expect(state.showDeleteSheet, isTrue);
    expect(state.stage, AppStage.app);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(state.showDeleteSheet, isFalse);
    expect(state.stage, AppStage.app);
  });
}
