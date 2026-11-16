import 'dart:async';

import '../mock_data.dart';
import '../models.dart';
import 'media.dart';
import 'repositories.dart';

/// An in-memory backend seeded with the design's sample content. Sign-in,
/// uploads and chat replies are simulated, and nothing is kept between runs.
///
/// Set [failing] to make every call throw, to exercise error handling.
Backend fakeBackend({bool failing = false}) {
  final store = _Store()..failing = failing;
  return Backend(
    auth: _FakeAuth(store),
    profiles: _FakeProfiles(store),
    discover: _FakeDiscover(store),
    collabs: _FakeCollabs(store),
    requests: _FakeRequests(store),
    chats: _FakeChats(store),
    safety: _FakeSafety(store),
  );
}

class _Store {
  _Store() {
    reset();
  }

  bool failing = false;
  int _nextId = 0;

  late Map<String, SwipeDirection> swipes;
  late Set<String> blocked;
  late List<Collab> browse;
  late List<MyPost> mine;
  late List<ConnectionRequest> connections;
  late List<ConnectionRequest> collabRequests;
  late List<Chat> chats;

  final events = StreamController<ChatEvent>.broadcast();
  final List<Timer> timers = [];

  void reset() {
    for (final timer in timers) {
      timer.cancel();
    }
    timers.clear();
    swipes = {};
    blocked = {};
    browse = seedBrowse();
    mine = seedMine();
    connections = seedConnections();
    collabRequests = seedCollabRequests();
    chats = seedChats();
  }

  String newId(String prefix) => '$prefix-new-${_nextId++}';

  bool visible(String personId) => !blocked.contains(personId);

  /// Every fake call goes through here, so it fails on demand and always
  /// completes asynchronously, like a real backend.
  Future<T> call<T>(T Function() body) async {
    if (failing) throw StateError('Simulated backend failure');
    return body();
  }
}

class _FakeAuth implements AuthRepository {
  _FakeAuth(this._store);

  final _Store _store;

  @override
  Future<void> signInWithGoogle() => _store.call(() {});

  @override
  Future<void> signOut() => _store.call(_store.reset);

  @override
  Future<void> deleteAccount() => _store.call(_store.reset);
}

class _FakeProfiles implements ProfileRepository {
  _FakeProfiles(this._store);

  final _Store _store;

  @override
  Future<void> uploadPhoto(PickedMedia photo) => _store.call(() {});

  @override
  Stream<int> uploadClip(PickedMedia clip) async* {
    if (_store.failing) throw StateError('Simulated backend failure');
    const step = Duration(milliseconds: 110);
    for (var pct = 7; pct < 100; pct += 7) {
      await Future<void>.delayed(step);
      yield pct;
    }
    await Future<void>.delayed(step);
    yield 100;
  }

  @override
  Future<void> saveProfile(Person profile) => _store.call(() {});
}

class _FakeDiscover implements DiscoverRepository {
  _FakeDiscover(this._store);

  final _Store _store;

  @override
  Future<List<Person>> loadDeck() => _store.call(
    () => [
      for (final id in discoverQueue)
        if (!_store.swipes.containsKey(id) && _store.visible(id)) people[id]!,
    ],
  );

  @override
  Future<void> swipe(String personId, SwipeDirection direction) =>
      _store.call(() => _store.swipes[personId] = direction);

  @override
  Future<void> undoSkips() => _store.call(
    () => _store.swipes.removeWhere(
      (_, direction) => direction == SwipeDirection.left,
    ),
  );
}

class _FakeCollabs implements CollabRepository {
  _FakeCollabs(this._store);

  final _Store _store;

  @override
  Future<List<Collab>> loadBrowse() => _store.call(
    () => _store.browse.where((c) => _store.visible(c.ownerId)).toList(),
  );

  @override
  Future<List<MyPost>> loadMine() => _store.call(() => List.of(_store.mine));

  @override
  Future<void> apply(String collabId) => _store.call(() {
    _store.browse = [
      for (final c in _store.browse) c.id == collabId ? c.markApplied() : c,
    ];
  });

  @override
  Future<MyPost> createPost(PostDraft draft) => _store.call(() {
    final post = MyPost(
      id: _store.newId('m'),
      title: draft.title,
      skill: draft.skill,
      desc: draft.desc,
      createdAt: DateTime.now(),
    );
    _store.mine = [post, ..._store.mine];
    return post;
  });

  @override
  Future<MyPost> updatePost(String postId, PostDraft draft) => _store.call(() {
    final updated = _store.mine
        .firstWhere((m) => m.id == postId)
        .withDraft(draft);
    _store.mine = [for (final m in _store.mine) m.id == postId ? updated : m];
    _store.collabRequests = [
      for (final r in _store.collabRequests)
        r.postId == postId ? r.withPostTitle(draft.title) : r,
    ];
    return updated;
  });

  @override
  Future<void> deletePost(String postId) => _store.call(() {
    _store.mine = _store.mine.where((m) => m.id != postId).toList();
    _store.collabRequests = _store.collabRequests
        .where((r) => r.postId != postId)
        .toList();
  });
}

class _FakeRequests implements RequestRepository {
  _FakeRequests(this._store);

  final _Store _store;

  List<ConnectionRequest> _visible(List<ConnectionRequest> requests) =>
      requests.where((r) => _store.visible(r.personId)).toList();

  @override
  Future<List<ConnectionRequest>> loadConnectionRequests() =>
      _store.call(() => _visible(_store.connections));

  @override
  Future<List<ConnectionRequest>> loadCollabRequests() =>
      _store.call(() => _visible(_store.collabRequests));

  @override
  Future<Chat?> respond(ConnectionRequest request, {required bool accept}) =>
      _store.call(() {
        bool other(ConnectionRequest r) => r.id != request.id;
        _store.connections = _store.connections.where(other).toList();
        _store.collabRequests = _store.collabRequests.where(other).toList();
        if (!accept) return null;

        for (final chat in _store.chats) {
          if (chat.personId == request.personId) return chat.copy();
        }
        final chat = Chat(
          id: _store.newId('h'),
          person: request.person,
          lastActivity: DateTime.now(),
          unread: false,
          messages: const [],
        );
        _store.chats = [chat, ..._store.chats];
        return chat.copy();
      });
}

class _FakeChats implements ChatRepository {
  _FakeChats(this._store);

  final _Store _store;

  @override
  Future<List<Chat>> loadChats() => _store.call(
    () => [
      for (final chat in _store.chats)
        if (_store.visible(chat.personId)) chat.copy(),
    ],
  );

  @override
  Stream<ChatEvent> get events => _store.events.stream;

  @override
  Future<void> send(String chatId, String body) => _store.call(() {
    final chat = _store.chats.firstWhere((c) => c.id == chatId);
    chat.messages.add(Message(me: true, body: body));
    chat.lastActivity = DateTime.now();

    // The design's simulated reply.
    _store.timers.add(
      Timer(const Duration(milliseconds: 500), () {
        _store.events.add(TypingChanged(chatId, typing: true));
      }),
    );
    _store.timers.add(
      Timer(const Duration(milliseconds: 1800), () {
        const reply = Message(me: false, body: 'Sounds good, let’s do it.');
        chat.messages.add(reply);
        _store.events.add(TypingChanged(chatId, typing: false));
        _store.events.add(MessageReceived(chatId, reply));
      }),
    );
  });

  @override
  Future<void> markRead(String chatId) => _store.call(() {
    for (final chat in _store.chats) {
      if (chat.id == chatId) chat.unread = false;
    }
  });
}

class _FakeSafety implements SafetyRepository {
  _FakeSafety(this._store);

  final _Store _store;

  @override
  Future<void> block(String personId) =>
      _store.call(() => _store.blocked.add(personId));
}
