import 'dart:io';

import 'package:creya/app_state.dart';
import 'package:creya/data/fake_backend.dart';
import 'package:creya/data/media.dart';
import 'package:creya/data/repositories.dart';
import 'package:creya/main.dart';
import 'package:creya/mock_data.dart';
import 'package:creya/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lets toast and swipe timers finish so no test ends with one pending.
const _settle = Duration(seconds: 3);

Future<AppState> _pump(
  WidgetTester tester, {
  String? screen,
  ListState listState = ListState.data,
  Backend? backend,
  MediaPicker? picker,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state = AppState(
    backend: backend,
    picker: picker,
    screenKey: screen,
    listState: listState,
  );
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

/// Refuses every swipe, to check that a failed action is undone.
class _OfflineDiscover implements DiscoverRepository {
  _OfflineDiscover(this._inner);

  final DiscoverRepository _inner;

  @override
  Future<List<Person>> loadDeck() => _inner.loadDeck();

  @override
  Future<void> swipe(String personId, SwipeDirection direction) =>
      Future.error(StateError('offline'));

  @override
  Future<void> undoSkips() => _inner.undoSkips();
}

/// A photo library whose next pick is decided by the test.
class _ScriptedPicker implements MediaPicker {
  PickedMedia? next;
  MediaRejected? rejection;

  Future<PickedMedia?> _pick() async {
    final rejected = rejection;
    if (rejected != null) throw rejected;
    return next;
  }

  @override
  Future<PickedMedia?> pickPhoto() => _pick();

  @override
  Future<PickedMedia?> pickClip() => _pick();
}

/// Hands out the Discover queue two people at a time, like a paged backend.
class _PagedDiscover implements DiscoverRepository {
  final _swiped = <String>{};

  @override
  Future<List<Person>> loadDeck() async => [
    for (final id in discoverQueue)
      if (!_swiped.contains(id)) people[id]!,
  ].take(2).toList();

  @override
  Future<void> swipe(String personId, SwipeDirection direction) async =>
      _swiped.add(personId);

  @override
  Future<void> undoSkips() async => _swiped.clear();
}

/// One chat with a long history, served a page at a time.
class _LongChat implements ChatRepository {
  final history = [
    for (var i = 1; i <= 70; i++)
      Message(
        id: 'msg$i',
        me: i.isEven,
        body: 'Message $i',
        sentAt: DateTime(2026, 1, 1).add(Duration(minutes: i)),
      ),
  ];
  var pagesServed = 0;

  @override
  Future<List<Chat>> loadChats() async => [
    Chat(
      id: 'h1',
      person: people['maya']!,
      lastActivity: history.last.sentAt,
      unread: false,
      messages: [history.last],
    ),
  ];

  @override
  Future<MessagePage> loadMessages(
    String chatId, {
    DateTime? before,
    int limit = 30,
  }) async {
    pagesServed++;
    final earlier = [
      for (final m in history)
        if (before == null || m.sentAt.isBefore(before)) m,
    ];
    final start = earlier.length > limit ? earlier.length - limit : 0;
    return MessagePage(messages: earlier.sublist(start), hasOlder: start > 0);
  }

  @override
  Stream<ChatEvent> get events => const Stream.empty();

  @override
  Future<void> send(String chatId, String body) async {}

  @override
  Future<void> markRead(String chatId) async {}
}

Backend _backendWith({DiscoverRepository? discover, ChatRepository? chats}) {
  final base = fakeBackend();
  return Backend(
    auth: base.auth,
    profiles: base.profiles,
    discover: discover ?? base.discover,
    collabs: base.collabs,
    requests: base.requests,
    chats: chats ?? base.chats,
    safety: base.safety,
  );
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('the deck tops itself up as it runs low', (tester) async {
    final state = await _pump(
      tester,
      screen: 'discover',
      backend: _backendWith(discover: _PagedDiscover()),
    );
    expect(state.visibleDeck.map((p) => p.id), ['amara', 'lucia']);

    await tester.tap(find.bySemanticsLabel('Skip'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(state.visibleDeck.map((p) => p.id), ['lucia', 'theo']);
  });

  testWidgets('a long chat loads a page at a time as you scroll back', (
    tester,
  ) async {
    final chats = _LongChat();
    final state = await _pump(
      tester,
      screen: 'chat',
      backend: _backendWith(chats: chats),
    );
    final chat = state.activeChat!;
    expect(chat.messages, hasLength(30));
    expect(chat.messages.last.body, 'Message 70');
    expect(find.text('Message 70'), findsOneWidget);
    expect(find.text('You connected · say hello'), findsNothing);

    // Scrolling back towards the start fetches earlier pages.
    for (var i = 0; i < 12 && chat.hasOlder; i++) {
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 500),
      );
      await tester.pump();
      await tester.pump();
    }
    expect(chat.messages, hasLength(70));
    expect(chat.messages.first.body, 'Message 1');
    expect(chats.pagesServed, 3);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, 4000),
    );
    await tester.pump();
    expect(find.text('You connected · say hello'), findsOneWidget);
    expect(chats.pagesServed, 3);

    // A background refresh keeps the pages already on screen.
    await state.refresh();
    expect(state.activeChat!.messages, hasLength(70));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a short chat stays at the top of the screen', (tester) async {
    await _pump(tester, screen: 'chat');
    final first = tester.getTopLeft(find.text('You connected · say hello'));
    final last = tester.getTopLeft(
      find.text('Want me to mock up a cover for the single?'),
    );
    expect(first.dy, lessThan(200));
    expect(last.dy, greaterThan(first.dy));
    expect(last.dy, lessThan(500));
  });

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
    expect(state.visibleDeck.first.id, 'lucia');
    expect(find.text('Connection request sent to Amara'), findsOneWidget);
    await tester.pump(_settle);
  });

  testWidgets('a short drag snaps back and keeps the card', (tester) async {
    final state = await _pump(tester, screen: 'discover');

    await tester.drag(find.text('Amara Okafor'), const Offset(60, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(state.visibleDeck.first.id, 'amara');
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

  testWidgets('posts with the same title keep separate applicants', (
    tester,
  ) async {
    final state = await _pump(tester, screen: 'collabs');
    final original = state.mine.first;

    state.openNewPost();
    state.updatePostDraft(title: original.title);
    await state.publishPost();
    await tester.pump();
    expect(state.mine, hasLength(3));
    expect(state.applicantsFor(state.mine.first), 0);
    expect(state.applicantsFor(original), 1);

    await state.deletePost(state.mine.first);
    await tester.pump();
    expect(state.applicantsFor(original), 1);
    expect(state.requestBadge, 4);
    await tester.pump(_settle);
  });

  testWidgets('a skipped person comes back on refresh, a connected one '
      'does not', (tester) async {
    final state = await _pump(tester, screen: 'discover');
    final deck = state.visibleDeck;

    await state.finishSwipe(deck[0], SwipeDirection.right);
    await state.finishSwipe(deck[1], SwipeDirection.left);
    await state.resetDeck();
    await tester.pump();
    final ids = state.visibleDeck.map((p) => p.id);
    expect(ids, isNot(contains(deck[0].id)));
    expect(ids, contains(deck[1].id));
    await tester.pump(_settle);
  });

  testWidgets('a failed load shows the error state', (tester) async {
    final state = await _pump(
      tester,
      screen: 'collabs',
      backend: fakeBackend(failing: true),
    );
    expect(state.listState, ListState.error);
    expect(find.text('Producer for my debut EP'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a refused action is undone and reported', (tester) async {
    final real = fakeBackend();
    final state = await _pump(
      tester,
      screen: 'discover',
      backend: Backend(
        auth: real.auth,
        profiles: real.profiles,
        discover: _OfflineDiscover(real.discover),
        collabs: real.collabs,
        requests: real.requests,
        chats: real.chats,
        safety: real.safety,
      ),
    );

    await tester.tap(find.bySemanticsLabel('Skip'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(state.visibleDeck.first.id, 'amara');
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    await tester.pump(_settle);
  });

  testWidgets('backing out of the photo library changes nothing', (
    tester,
  ) async {
    final state = await _pump(
      tester,
      screen: 'craft',
      picker: _ScriptedPicker(),
    );
    state.goToStage(AppStage.face);
    await tester.pump();

    await tester.tap(find.bySemanticsLabel(RegExp('Choose profile photo')));
    await tester.tap(find.bySemanticsLabel(RegExp('Upload talent clip')));
    await tester.pump();
    expect(state.hasPhoto, isFalse);
    expect(state.clip, ClipStatus.idle);
    expect(state.toastMessage, isNull);
  });

  testWidgets('a clip over the limit is refused with the reason', (
    tester,
  ) async {
    final picker = _ScriptedPicker()
      ..rejection = const MediaRejected('That clip is 0:45 long.');
    final state = await _pump(tester, screen: 'craft', picker: picker);
    state.goToStage(AppStage.face);
    await tester.pump();

    await tester.tap(find.bySemanticsLabel(RegExp('Upload talent clip')));
    await tester.pump();
    expect(state.clip, ClipStatus.idle);
    expect(find.text('That clip is 0:45 long.'), findsOneWidget);
    await tester.pump(_settle);
  });

  testWidgets('the chosen clip shows its own name and length', (tester) async {
    final picker = _ScriptedPicker()
      ..next = const PickedMedia(
        name: 'live-set.mp4',
        length: Duration(seconds: 14),
      );
    final state = await _pump(tester, screen: 'craft', picker: picker);
    state.goToStage(AppStage.face);
    await tester.pump();

    await tester.tap(find.bySemanticsLabel(RegExp('Upload talent clip')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('live-set.mp4 · 0:14'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Clip ready · 0:14'), findsOneWidget);
  });

  testWidgets('editing the profile saves changes', (tester) async {
    final state = await _pump(tester, screen: 'profile');
    state.addPhoto();
    state.uploadClip();
    await tester.pump(const Duration(seconds: 2));

    await tester.ensureVisible(find.text('Edit profile'));
    await tester.tap(find.text('Edit profile'));
    await tester.pump();
    expect(find.text('Full name'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Jordan Vale');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    expect(state.stage, AppStage.app);
    expect(state.tab, AppTab.profile);
    expect(find.text('Profile updated'), findsOneWidget);
    expect(find.text('Jordan Vale'), findsOneWidget);
    await tester.pump(_settle);
  });

  testWidgets('backing out of an edit drops the changes', (tester) async {
    final state = await _pump(tester, screen: 'profile');

    await tester.ensureVisible(find.text('Edit profile'));
    await tester.tap(find.text('Edit profile'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'Someone Else');
    state.addGenre('Techno');
    await tester.pump();

    expect(state.handleBack(), isTrue);
    await tester.pump();
    expect(state.stage, AppStage.app);
    expect(state.name, 'Jordan Reyes');
    expect(state.genres, isNot(contains('Techno')));
    expect(find.text('Jordan Reyes'), findsOneWidget);
  });
}
