import 'dart:async';

import 'package:flutter/widgets.dart';

import 'data/fake_backend.dart';
import 'data/repositories.dart';
import 'models.dart';

enum AppStage { welcome, craft, face, app }

enum AppTab { discover, collabs, requests, messages, profile }

enum SubScreen { none, post, chat, person, settings }

enum ClipStatus { idle, uploading, done }

enum ListState { data, loading, empty, error }

enum CollabMode { browse, mine }

enum RequestMode { connections, collabs }

/// What the screens show and what the user can do. Navigation, drafts and
/// toasts live here; the data itself comes from the [Backend] repositories.
///
/// Actions update the screen straight away and then tell the backend. If the
/// backend refuses, the user sees a message and the data is reloaded.
class AppState extends ChangeNotifier {
  AppState({Backend? backend, ListState? listState, String? screenKey})
    : backend = backend ?? fakeBackend(),
      _forcedListState = listState == ListState.data ? null : listState {
    _reset();
    _chatEvents = this.backend.chats.events.listen(_onChatEvent);
    if (screenKey != null) _applyScreenKey(screenKey);
    if (stage == AppStage.app) unawaited(_load());
  }

  final Backend backend;

  /// A development override that pins list screens to one variant.
  ListState? _forcedListState;
  ListState _loadState = ListState.loading;

  /// Which variant list screens show.
  ListState get listState => _forcedListState ?? _loadState;

  /// True until the first load finishes, so Discover doesn't claim the user
  /// is all caught up before it knows.
  bool get deckLoading => _loadState == ListState.loading;

  late AppStage stage;
  late AppTab tab;
  late SubScreen sub;
  Person? _viewed;
  late bool previewing;

  late String name;
  late String city;
  late String creative;
  late List<String> genres;
  late String bio;
  late bool hasPhoto;
  late ClipStatus clip;
  late int uploadPct;

  late List<Person> _deck;

  late CollabMode collabMode;
  late RequestMode requestMode;
  late List<Collab> _browse;
  late List<MyPost> _mine;
  late List<ConnectionRequest> _connections;
  late List<ConnectionRequest> _collabRequests;
  late List<Chat> _chats;

  String? chatId;
  late bool typing;
  late List<String> blocked;
  late bool notifications;
  late bool showDeleteSheet;
  String? toastMessage;

  late String postTitle;
  late String postSkill;
  late String postDesc;
  String? editingPostId;

  StreamSubscription<int>? _clipUpload;
  late final StreamSubscription<ChatEvent> _chatEvents;
  Timer? _toastTimer;
  int _tempIds = 0;
  bool _disposed = false;

  void _reset() {
    _clipUpload?.cancel();
    _clipUpload = null;
    _toastTimer?.cancel();

    stage = AppStage.welcome;
    tab = AppTab.discover;
    sub = SubScreen.none;
    _viewed = null;
    previewing = false;
    name = 'Jordan Reyes';
    city = 'London';
    creative = 'Music Producer';
    genres = ['Afrobeats', 'House', 'Soul'];
    bio =
        'Producer and mix engineer. I make records that feel like summer evenings.';
    hasPhoto = false;
    clip = ClipStatus.idle;
    uploadPct = 0;
    _deck = [];
    collabMode = CollabMode.browse;
    requestMode = RequestMode.connections;
    _browse = [];
    _mine = [];
    _connections = [];
    _collabRequests = [];
    _chats = [];
    _loadState = ListState.loading;
    chatId = null;
    typing = false;
    blocked = [];
    notifications = true;
    showDeleteSheet = false;
    toastMessage = null;
    postTitle = '';
    postSkill = 'Vocalist';
    postDesc = '';
    editingPostId = null;
  }

  /// Opens directly on a screen, using the design's screen keys. Used by
  /// `--dart-define=SCREEN=<key>` to review a single screen during development.
  void _applyScreenKey(String key) {
    switch (key) {
      case 'welcome':
        stage = AppStage.welcome;
      case 'craft':
        stage = AppStage.craft;
      case 'face':
        stage = AppStage.face;
        hasPhoto = true;
        clip = ClipStatus.done;
      case 'discover':
        stage = AppStage.app;
        tab = AppTab.discover;
      case 'collabs':
        stage = AppStage.app;
        tab = AppTab.collabs;
      case 'post':
        stage = AppStage.app;
        tab = AppTab.collabs;
        sub = SubScreen.post;
        postTitle = 'Vocalist for a summer house single';
        postDesc =
            'Warm, sunset-y house track. Need a topline and hook, remote is fine.';
      case 'requests':
        stage = AppStage.app;
        tab = AppTab.requests;
      case 'messages':
        stage = AppStage.app;
        tab = AppTab.messages;
      case 'chat':
        stage = AppStage.app;
        tab = AppTab.messages;
        sub = SubScreen.chat;
        chatId = 'h1';
      case 'profile':
        stage = AppStage.app;
        tab = AppTab.profile;
      case 'settings':
        stage = AppStage.app;
        tab = AppTab.profile;
        sub = SubScreen.settings;
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  // ---- Talking to the backend --------------------------------------------

  /// Loads everything the main app shows. With [quiet], the current content
  /// stays on screen while it reloads.
  Future<void> _load({bool quiet = false}) async {
    if (!quiet) {
      _loadState = ListState.loading;
      notifyListeners();
    }
    try {
      final (deck, browse, mine, connections, collabRequests, chats) = await (
        backend.discover.loadDeck(),
        backend.collabs.loadBrowse(),
        backend.collabs.loadMine(),
        backend.requests.loadConnectionRequests(),
        backend.requests.loadCollabRequests(),
        backend.chats.loadChats(),
      ).wait;
      _deck = deck;
      _browse = browse;
      _mine = mine;
      _connections = connections;
      _collabRequests = collabRequests;
      _chats = chats;
      _loadState = ListState.data;
    } catch (_) {
      if (!quiet) _loadState = ListState.error;
    }
    notifyListeners();
  }

  /// Runs a backend call for a change already shown on screen. On failure it
  /// tells the user and reloads, which undoes the change. Returns whether the
  /// call succeeded.
  Future<bool> _sync(Future<void> Function() call) async {
    try {
      await call();
      return true;
    } catch (_) {
      showToast('Something went wrong. Please try again.');
      if (stage == AppStage.app) await _load(quiet: true);
      return false;
    }
  }

  /// Retries after a failed load.
  Future<void> retry() {
    _forcedListState = null;
    return _load();
  }

  // ---- Derived values ----------------------------------------------------

  bool _visible(String personId) => !blocked.contains(personId);

  bool get _forceEmpty => listState == ListState.empty;

  Person get me => Person(
    id: 'me',
    name: name.isEmpty ? 'Your name' : name,
    creative: creative,
    city: city.isEmpty ? '—' : city,
    genres: genres,
    bio: bio,
    hue: 275,
    connections: 24,
  );

  /// The person whose profile is open, if any.
  Person? get viewed => _viewed;

  String? get viewId => _viewed?.id;

  List<Person> get visibleDeck => _deck.where((p) => _visible(p.id)).toList();

  List<ConnectionRequest> get connections =>
      _connections.where((r) => _visible(r.personId)).toList();

  List<ConnectionRequest> get collabRequests =>
      _collabRequests.where((r) => _visible(r.personId)).toList();

  int get requestBadge => connections.length + collabRequests.length;

  List<ConnectionRequest> get currentRequests {
    if (_forceEmpty) return const [];
    return requestMode == RequestMode.connections
        ? connections
        : collabRequests;
  }

  List<Collab> get browse => _forceEmpty
      ? const []
      : _browse.where((c) => _visible(c.ownerId)).toList();

  List<MyPost> get mine => _forceEmpty ? const [] : List.of(_mine);

  int get myPostCount => _mine.length;

  int applicantsFor(MyPost post) =>
      _collabRequests.where((r) => r.postId == post.id).length;

  List<Chat> get chats => _forceEmpty
      ? const []
      : _chats.where((c) => _visible(c.personId)).toList();

  Chat? _chatById(String? id) {
    for (final chat in _chats) {
      if (chat.id == id) return chat;
    }
    return null;
  }

  Chat? get activeChat => _chatById(chatId);

  bool get canCreateAccount => hasPhoto && clip == ClipStatus.done;

  bool get canPublish => postTitle.trim().isNotEmpty;

  // ---- Navigation --------------------------------------------------------

  void goToStage(AppStage next) {
    stage = next;
    notifyListeners();
  }

  void selectTab(AppTab next) {
    tab = next;
    sub = SubScreen.none;
    previewing = false;
    _viewed = null;
    showDeleteSheet = false;
    notifyListeners();
  }

  void openPerson(Person person) {
    sub = SubScreen.person;
    _viewed = person;
    notifyListeners();
  }

  void openSettings() {
    sub = SubScreen.settings;
    notifyListeners();
  }

  void previewMyProfile() {
    sub = SubScreen.person;
    previewing = true;
    notifyListeners();
  }

  void closeSub() {
    final backToChat =
        sub == SubScreen.person &&
        chatId != null &&
        tab == AppTab.messages &&
        !previewing;
    sub = backToChat ? SubScreen.chat : SubScreen.none;
    previewing = false;
    _viewed = null;
    notifyListeners();
  }

  /// Handles the Android back gesture. Returns true if it was consumed.
  bool handleBack() {
    if (showDeleteSheet) {
      cancelDelete();
      return true;
    }
    if (stage == AppStage.face) {
      goToStage(AppStage.craft);
      return true;
    }
    if (stage == AppStage.craft) {
      goToStage(AppStage.welcome);
      return true;
    }
    if (stage == AppStage.app && sub != SubScreen.none) {
      closeSub();
      return true;
    }
    if (stage == AppStage.app && tab != AppTab.discover) {
      selectTab(AppTab.discover);
      return true;
    }
    return false;
  }

  // ---- Toast -------------------------------------------------------------

  void showToast(String message) {
    _toastTimer?.cancel();
    toastMessage = message;
    notifyListeners();
    _toastTimer = Timer(const Duration(milliseconds: 2200), () {
      toastMessage = null;
      notifyListeners();
    });
  }

  // ---- Onboarding --------------------------------------------------------

  Future<void> signIn() async {
    if (await _sync(backend.auth.signInWithGoogle)) {
      goToStage(AppStage.craft);
    }
  }

  void updateProfile({
    String? name,
    String? city,
    String? creative,
    String? bio,
  }) {
    this.name = name ?? this.name;
    this.city = city ?? this.city;
    this.creative = creative ?? this.creative;
    this.bio = bio ?? this.bio;
    notifyListeners();
  }

  void addGenre(String value) {
    final genre = value.trim();
    if (genre.isEmpty || genres.contains(genre)) return;
    genres = [...genres, genre];
    notifyListeners();
  }

  void removeGenre(String genre) {
    genres = genres.where((g) => g != genre).toList();
    notifyListeners();
  }

  Future<void> addPhoto() async {
    hasPhoto = true;
    notifyListeners();
    if (!await _sync(backend.profiles.uploadPhoto)) {
      hasPhoto = false;
      notifyListeners();
    }
  }

  void uploadClip() {
    if (clip == ClipStatus.uploading) return;
    clip = ClipStatus.uploading;
    uploadPct = 0;
    notifyListeners();
    _clipUpload = backend.profiles.uploadClip().listen(
      (pct) {
        uploadPct = pct.clamp(0, 100);
        notifyListeners();
      },
      onDone: () {
        clip = ClipStatus.done;
        uploadPct = 100;
        notifyListeners();
      },
      onError: (Object _) {
        clip = ClipStatus.idle;
        uploadPct = 0;
        showToast('Upload failed. Please try again.');
      },
      cancelOnError: true,
    );
  }

  Future<void> finishOnboarding() async {
    if (!canCreateAccount) {
      showToast('Add a profile photo and a talent clip to continue');
      return;
    }
    if (!await _sync(() => backend.profiles.saveProfile(me))) return;
    stage = AppStage.app;
    selectTab(AppTab.discover);
    showToast('Welcome to Creya, ${me.firstName}');
    await _load();
  }

  // ---- Discover ----------------------------------------------------------

  Future<void> finishSwipe(Person person, SwipeDirection direction) async {
    _deck = _deck.where((p) => p.id != person.id).toList();
    if (direction == SwipeDirection.right) {
      showToast('Connection request sent to ${person.firstName}');
    } else {
      notifyListeners();
    }
    await _sync(() => backend.discover.swipe(person.id, direction));
  }

  /// Brings skipped people back round.
  Future<void> resetDeck() => _sync(() async {
    await backend.discover.undoSkips();
    _deck = await backend.discover.loadDeck();
    notifyListeners();
  });

  // ---- Collabs -----------------------------------------------------------

  void setCollabMode(CollabMode mode) {
    collabMode = mode;
    notifyListeners();
  }

  Future<void> apply(Collab collab) async {
    if (collab.applied) return;
    _browse = [
      for (final c in _browse) c.id == collab.id ? c.markApplied() : c,
    ];
    showToast('Applied. ${collab.owner.firstName} will see your request');
    await _sync(() => backend.collabs.apply(collab.id));
  }

  void openNewPost() {
    sub = SubScreen.post;
    editingPostId = null;
    postTitle = '';
    postDesc = '';
    postSkill = 'Vocalist';
    notifyListeners();
  }

  void editPost(MyPost post) {
    sub = SubScreen.post;
    editingPostId = post.id;
    postTitle = post.title;
    postSkill = post.skill;
    postDesc = post.desc;
    notifyListeners();
  }

  void updatePostDraft({String? title, String? skill, String? desc}) {
    postTitle = title ?? postTitle;
    postSkill = skill ?? postSkill;
    postDesc = desc ?? postDesc;
    notifyListeners();
  }

  Future<void> publishPost() async {
    if (!canPublish) return;
    final draft = PostDraft(title: postTitle, skill: postSkill, desc: postDesc);
    final editingId = editingPostId;
    sub = SubScreen.none;
    collabMode = CollabMode.mine;

    if (editingId != null) {
      _mine = [
        for (final m in _mine) m.id == editingId ? m.withDraft(draft) : m,
      ];
      _collabRequests = [
        for (final r in _collabRequests)
          r.postId == editingId ? r.withPostTitle(draft.title) : r,
      ];
      showToast('Post updated');
      await _sync(() => backend.collabs.updatePost(editingId, draft));
      return;
    }

    // Shown at once under a placeholder id, then swapped for the saved post.
    final placeholder = MyPost(
      id: 'pending-${_tempIds++}',
      title: draft.title,
      skill: draft.skill,
      desc: draft.desc,
      createdAt: DateTime.now(),
    );
    _mine = [placeholder, ..._mine];
    showToast('Collab published');
    await _sync(() async {
      final saved = await backend.collabs.createPost(draft);
      _mine = [for (final m in _mine) m.id == placeholder.id ? saved : m];
      notifyListeners();
    });
  }

  Future<void> deletePost(MyPost post) async {
    _mine = _mine.where((m) => m.id != post.id).toList();
    _collabRequests = _collabRequests
        .where((r) => r.postId != post.id)
        .toList();
    showToast('Post deleted');
    await _sync(() => backend.collabs.deletePost(post.id));
  }

  void viewApplicants() {
    tab = AppTab.requests;
    requestMode = RequestMode.collabs;
    notifyListeners();
  }

  // ---- Requests ----------------------------------------------------------

  void setRequestMode(RequestMode mode) {
    requestMode = mode;
    notifyListeners();
  }

  void _removeRequest(ConnectionRequest request) {
    _connections = _connections.where((r) => r.id != request.id).toList();
    _collabRequests = _collabRequests.where((r) => r.id != request.id).toList();
  }

  Future<void> acceptRequest(ConnectionRequest request) async {
    _removeRequest(request);
    showToast('Accepted. Chat opened with ${request.person.firstName}');
    await _sync(() async {
      final chat = await backend.requests.respond(request, accept: true);
      if (chat != null && _chatById(chat.id) == null) {
        _chats = [chat, ..._chats];
        notifyListeners();
      }
    });
  }

  Future<void> declineRequest(ConnectionRequest request) async {
    _removeRequest(request);
    showToast('Request declined');
    await _sync(() => backend.requests.respond(request, accept: false));
  }

  // ---- Messages ----------------------------------------------------------

  Future<void> openChat(Chat chat) async {
    chat.unread = false;
    sub = SubScreen.chat;
    chatId = chat.id;
    typing = false;
    notifyListeners();
    await _sync(() => backend.chats.markRead(chat.id));
  }

  Future<void> sendMessage(String text) async {
    final body = text.trim();
    final chat = activeChat;
    if (body.isEmpty || chat == null) return;
    chat.lastActivity = DateTime.now();
    chat.messages.add(Message(me: true, body: body));
    notifyListeners();
    await _sync(() => backend.chats.send(chat.id, body));
  }

  void _onChatEvent(ChatEvent event) {
    final chat = _chatById(event.chatId);
    if (chat == null) {
      // A chat this session has not loaded yet.
      if (stage == AppStage.app) unawaited(_load(quiet: true));
      return;
    }
    final open = sub == SubScreen.chat && chatId == chat.id;
    switch (event) {
      case TypingChanged(:final typing):
        if (!open) return;
        this.typing = typing;
      case MessageReceived(:final message):
        chat.messages.add(message);
        chat.lastActivity = DateTime.now();
        if (open) {
          unawaited(backend.chats.markRead(chat.id).catchError((_) {}));
        } else {
          chat.unread = true;
        }
    }
    notifyListeners();
  }

  // ---- Profile and safety ------------------------------------------------

  Future<void> connectWithViewed() async {
    final person = _viewed;
    if (person == null) return;
    _deck = _deck.where((p) => p.id != person.id).toList();
    sub = SubScreen.none;
    _viewed = null;
    showToast('Connection request sent to ${person.firstName}');
    await _sync(() => backend.discover.swipe(person.id, SwipeDirection.right));
  }

  Future<void> blockViewed() async {
    final person = _viewed;
    if (person == null) return;
    blocked = [...blocked, person.id];
    sub = SubScreen.none;
    _viewed = null;
    showToast("${person.firstName} blocked. They won't appear anywhere.");
    if (!await _sync(() => backend.safety.block(person.id))) {
      blocked = blocked.where((id) => id != person.id).toList();
      notifyListeners();
    }
  }

  // ---- Settings ----------------------------------------------------------

  void toggleNotifications() {
    notifications = !notifications;
    notifyListeners();
  }

  void askDeleteAccount() {
    showDeleteSheet = true;
    notifyListeners();
  }

  void cancelDelete() {
    showDeleteSheet = false;
    notifyListeners();
  }

  /// Returns to a fresh Welcome screen, as designed.
  Future<void> signOut() => _leave(backend.auth.signOut);

  Future<void> deleteAccount() => _leave(backend.auth.deleteAccount);

  Future<void> _leave(Future<void> Function() call) async {
    try {
      await call();
    } catch (_) {
      showDeleteSheet = false;
      showToast('Something went wrong. Please try again.');
      return;
    }
    _reset();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _clipUpload?.cancel();
    _chatEvents.cancel();
    _toastTimer?.cancel();
    super.dispose();
  }
}

/// Makes the [AppState] available to the widget tree and rebuilds on change.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  }
}
