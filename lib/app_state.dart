import 'dart:async';

import 'package:flutter/widgets.dart';

import 'data/fake_backend.dart';
import 'data/media.dart';
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
  AppState({
    Backend? backend,
    MediaPicker? picker,
    ListState? listState,
    String? screenKey,
  }) : backend = backend ?? fakeBackend(),
       picker = picker ?? const SampleMediaPicker(),
       _forcedListState = listState == ListState.data ? null : listState {
    _reset();
    _chatEvents = this.backend.chats.events.listen(_onChatEvent);
    if (screenKey != null) {
      _applyScreenKey(screenKey);
      if (stage == AppStage.app) unawaited(_load());
    } else {
      launching = true;
      unawaited(_resume());
    }
  }

  final Backend backend;
  final MediaPicker picker;

  /// A development override that pins list screens to one variant.
  ListState? _forcedListState;
  ListState _loadState = ListState.loading;

  /// Which variant list screens show.
  ListState get listState => _forcedListState ?? _loadState;

  /// True until the first load finishes, so Discover doesn't claim the user
  /// is all caught up before it knows.
  bool get deckLoading => _loadState == ListState.loading;

  /// True at startup while checking for a saved sign-in, so the Welcome
  /// screen doesn't flash up for someone who is already signed in.
  bool launching = false;

  late AppStage stage;
  late AppTab tab;
  late SubScreen sub;
  Person? _viewed;
  late bool previewing;

  late String myId;
  late int myHue;
  late int myConnections;
  late String name;
  late String city;
  late String creative;
  late List<String> genres;
  late String bio;
  late bool hasPhoto;
  String? photoPath;
  late ClipStatus clip;
  late int uploadPct;

  /// The clip being uploaded or already attached.
  PickedMedia? clipMedia;

  /// True while the onboarding screens are being reused to edit the profile.
  late bool editingProfile;
  _ProfileSnapshot? _beforeEdit;

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

  /// Backend calls still in flight, and whether a refresh is running.
  int _pending = 0;
  bool _refreshing = false;

  /// People swiped this session, so a deck reload that races a swipe can't
  /// bring them back.
  final Set<String> _swiped = {};

  /// True while an earlier page of the open chat is loading.
  bool loadingOlder = false;
  bool _disposed = false;

  void _reset() {
    _clipUpload?.cancel();
    _clipUpload = null;
    _toastTimer?.cancel();
    _swiped.clear();
    loadingOlder = false;

    stage = AppStage.welcome;
    tab = AppTab.discover;
    sub = SubScreen.none;
    _viewed = null;
    previewing = false;
    myId = 'me';
    myHue = 275;
    myConnections = 24;
    name = 'Jordan Reyes';
    city = 'London';
    creative = 'Music Producer';
    genres = ['Afrobeats', 'House', 'Soul'];
    bio =
        'Producer and mix engineer. I make records that feel like summer evenings.';
    hasPhoto = false;
    photoPath = null;
    clip = ClipStatus.idle;
    uploadPct = 0;
    clipMedia = null;
    editingProfile = false;
    _beforeEdit = null;
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
        clipMedia = const PickedMedia(
          name: 'studio-session.mov',
          length: MediaLimits.clipLength,
        );
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
      _deck = deck.where((p) => !_swiped.contains(p.id)).toList();
      _browse = browse;
      _mine = mine;
      _connections = connections;
      _collabRequests = collabRequests;
      _chats = [for (final chat in chats) _keepHistory(chat)];
      _loadState = ListState.data;
    } catch (_) {
      if (!quiet) _loadState = ListState.error;
    }
    notifyListeners();
    // A chat opened before its list arrived still needs its messages.
    final open = activeChat;
    if (open != null && !open.historyLoaded) await _loadHistory(open);
  }

  /// A reloaded chat only carries its latest message, so messages already
  /// on screen are carried over from the copy it replaces.
  Chat _keepHistory(Chat fresh) {
    final old = _chatById(fresh.id);
    if (old == null || !old.historyLoaded) return fresh;
    return Chat(
      id: fresh.id,
      person: fresh.person,
      lastActivity: fresh.lastActivity,
      unread: fresh.unread,
      messages: old.messages,
      historyLoaded: true,
      hasOlder: old.hasOlder,
    );
  }

  /// Brings everything up to date without disturbing the screen. Skipped
  /// while a change is still on its way to the backend, so the reload can't
  /// briefly undo it.
  Future<void> refresh() async {
    if (stage != AppStage.app || _pending > 0 || _refreshing) return;
    if (_loadState != ListState.data) return;
    _refreshing = true;
    try {
      await _load(quiet: true);
    } finally {
      _refreshing = false;
    }
  }

  /// Runs a backend call for a change already shown on screen. On failure it
  /// tells the user and reloads, which undoes the change; [undo] reverts
  /// anything the reload can't. Returns whether the call succeeded.
  Future<bool> _sync(
    Future<void> Function() call, {
    void Function()? undo,
  }) async {
    _pending++;
    try {
      await call();
      return true;
    } catch (_) {
      undo?.call();
      showToast('Something went wrong. Please try again.');
      if (stage == AppStage.app) await _load(quiet: true);
      return false;
    } finally {
      _pending--;
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
    id: myId,
    name: name.isEmpty ? 'Your name' : name,
    creative: creative,
    city: city.isEmpty ? '—' : city,
    genres: genres,
    bio: bio,
    hue: myHue,
    connections: myConnections,
    photo: photoPath,
    clip: clipMedia?.path,
  );

  /// `Clip ready`, with the clip's length when it is known.
  String get clipReadyLabel {
    final length = clipMedia?.length;
    return length == null
        ? 'Clip ready'
        : 'Clip ready · ${formatClipLength(length)}';
  }

  /// The clip being uploaded, as `name · m:ss`.
  String get clipUploadLabel {
    final length = clipMedia?.length;
    return length == null
        ? clipName
        : '$clipName · ${formatClipLength(length)}';
  }

  String get clipName => clipMedia?.name ?? 'Your clip';

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
    unawaited(refresh());
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
      leaveCraft();
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

  /// Signs in, then picks up where this person left off: straight into the
  /// app if they have a finished profile, otherwise the profile form.
  Future<void> signIn() async {
    if (!await _sync(backend.auth.signInWithGoogle)) return;
    await _resume(newcomerStage: AppStage.craft);
  }

  /// Loads the signed-in user's profile and opens the right screen for it.
  /// With nobody signed in, opens [newcomerStage].
  Future<void> _resume({AppStage newcomerStage = AppStage.welcome}) async {
    MyProfile? mine;
    try {
      mine = await backend.profiles.loadMine();
    } catch (_) {
      launching = false;
      showToast("Couldn't reach Creya. Check your connection.");
      return;
    }
    launching = false;
    if (mine == null) return goToStage(newcomerStage);

    final person = mine.person;
    myId = person.id;
    myHue = person.hue;
    myConnections = person.connections;
    name = person.name;
    city = person.city;
    if (person.creative.isNotEmpty) creative = person.creative;
    genres = person.genres;
    bio = person.bio;
    hasPhoto = person.photo != null;
    photoPath = person.photo;
    final savedClip = person.clip;
    if (savedClip != null) {
      clip = ClipStatus.done;
      clipMedia = PickedMedia(name: 'Your clip', path: savedClip);
    }

    if (!mine.onboarded) return goToStage(AppStage.craft);
    stage = AppStage.app;
    await _load();
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

  /// Asks the picker for a file, reporting a rejected one to the user.
  Future<PickedMedia?> _pick(Future<PickedMedia?> Function() pick) async {
    try {
      return await pick();
    } on MediaRejected catch (rejected) {
      showToast(rejected.message);
    } catch (_) {
      showToast("Couldn't open your photo library.");
    }
    return null;
  }

  Future<void> addPhoto() async {
    final photo = await _pick(picker.pickPhoto);
    if (photo == null) return;
    final hadPhoto = hasPhoto;
    final previousPath = photoPath;
    hasPhoto = true;
    photoPath = photo.path;
    notifyListeners();
    if (!await _sync(() => backend.profiles.uploadPhoto(photo))) {
      hasPhoto = hadPhoto;
      photoPath = previousPath;
      notifyListeners();
    }
  }

  Future<void> uploadClip() async {
    if (clip == ClipStatus.uploading) return;
    final picked = await _pick(picker.pickClip);
    if (picked == null || clip == ClipStatus.uploading) return;
    final previous = clipMedia;
    clipMedia = picked;
    clip = ClipStatus.uploading;
    uploadPct = 0;
    notifyListeners();
    _clipUpload = backend.profiles
        .uploadClip(picked)
        .listen(
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
            // Fall back to the clip that was attached before, if there was one.
            clipMedia = previous;
            clip = previous != null ? ClipStatus.done : ClipStatus.idle;
            uploadPct = 0;
            showToast('Upload failed. Please try again.');
          },
          cancelOnError: true,
        );
  }

  /// Finishes the last onboarding step: creates the account, or saves the
  /// changes when editing an existing profile.
  Future<void> finishOnboarding() async {
    if (!canCreateAccount) {
      showToast(
        clip == ClipStatus.uploading
            ? 'Your clip is still uploading'
            : 'Add a profile photo and a talent clip to continue',
      );
      return;
    }
    if (!await _sync(() => backend.profiles.saveProfile(me))) return;
    stage = AppStage.app;
    if (editingProfile) {
      editingProfile = false;
      _beforeEdit = null;
      showToast('Profile updated');
      return;
    }
    selectTab(AppTab.discover);
    showToast('Welcome to Creya, ${me.firstName}');
    await _load();
  }

  // ---- Editing the profile -----------------------------------------------

  /// Reopens the onboarding fields on the user's current profile.
  void editProfile() {
    _beforeEdit = _ProfileSnapshot(this);
    editingProfile = true;
    stage = AppStage.craft;
    notifyListeners();
  }

  /// Leaves the first form step: back to Welcome during sign-up, or back to
  /// the profile with every change dropped when editing.
  void leaveCraft() {
    if (!editingProfile) return goToStage(AppStage.welcome);
    _clipUpload?.cancel();
    _clipUpload = null;
    _beforeEdit?.restore(this);
    _beforeEdit = null;
    editingProfile = false;
    stage = AppStage.app;
    notifyListeners();
  }

  // ---- Discover ----------------------------------------------------------

  Future<void> finishSwipe(Person person, SwipeDirection direction) async {
    _swiped.add(person.id);
    _deck = _deck.where((p) => p.id != person.id).toList();
    if (direction == SwipeDirection.right) {
      showToast('Connection request sent to ${person.firstName}');
    } else {
      notifyListeners();
    }
    final sent = await _sync(
      () => backend.discover.swipe(person.id, direction),
      undo: () => _swiped.remove(person.id),
    );
    if (!sent) return;
    if (_deck.length < _deckTopUpAt) await _topUpDeck();
  }

  static const _deckTopUpAt = 3;

  /// Fetches more people as the deck runs low. Failing is fine: the user
  /// still has the cards in hand and "Refresh queue" when those run out.
  Future<void> _topUpDeck() async {
    try {
      final more = await backend.discover.loadDeck();
      final held = {for (final p in _deck) p.id};
      _deck = [
        ..._deck,
        for (final p in more)
          if (!held.contains(p.id) && !_swiped.contains(p.id)) p,
      ];
      notifyListeners();
    } catch (_) {}
  }

  /// Brings skipped people back round.
  Future<void> resetDeck() => _sync(() async {
    await backend.discover.undoSkips();
    _swiped.clear();
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
    await Future.wait([
      _sync(() => backend.chats.markRead(chat.id)),
      if (!chat.historyLoaded) _loadHistory(chat),
    ]);
  }

  /// Loads the newest page of a chat, replacing its one-message preview.
  Future<void> _loadHistory(Chat chat) async {
    final preview = List.of(chat.messages);
    try {
      final page = await backend.chats.loadMessages(chat.id);
      // Keep whatever arrived or was sent while the page was loading, unless
      // the page already includes it.
      bool inPage(Message m) => page.messages.any(
        (saved) => m.id != null
            ? saved.id == m.id
            : saved.me == m.me && saved.body == m.body,
      );
      final since = [
        for (final m in chat.messages)
          if (!preview.contains(m) && !inPage(m)) m,
      ];
      chat.messages
        ..clear()
        ..addAll(page.messages)
        ..addAll(since);
      chat.historyLoaded = true;
      chat.hasOlder = page.hasOlder;
      notifyListeners();
    } catch (_) {
      showToast("Couldn't load this chat. Please try again.");
    }
  }

  /// Loads the page before the earliest message on screen.
  Future<void> loadOlderMessages() async {
    final chat = activeChat;
    if (chat == null || !chat.hasOlder || loadingOlder) return;
    if (chat.messages.isEmpty) return;
    loadingOlder = true;
    notifyListeners();
    try {
      final page = await backend.chats.loadMessages(
        chat.id,
        before: chat.messages.first.sentAt,
      );
      chat.messages.insertAll(0, page.messages);
      chat.hasOlder = page.hasOlder;
    } catch (_) {
      showToast("Couldn't load earlier messages.");
    }
    loadingOlder = false;
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    final body = text.trim();
    final chat = activeChat;
    if (body.isEmpty || chat == null) return;
    chat.lastActivity = DateTime.now();
    chat.messages.add(Message(me: true, body: body, sentAt: DateTime.now()));
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
        if (message.id != null &&
            chat.messages.any((m) => m.id == message.id)) {
          return;
        }
        // An unopened chat only ever holds its latest message.
        if (!chat.historyLoaded) chat.messages.clear();
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

  Future<void> reportViewed() async {
    final person = _viewed;
    if (person == null) return;
    showToast('Report sent. Our team reviews every one.');
    await _sync(
      () => backend.safety.report(person.id, reason: 'Reported from profile'),
    );
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

/// The profile as it was before an edit began, to put back on cancel.
class _ProfileSnapshot {
  _ProfileSnapshot(AppState app)
    : name = app.name,
      city = app.city,
      creative = app.creative,
      genres = app.genres,
      bio = app.bio,
      hasPhoto = app.hasPhoto,
      photoPath = app.photoPath,
      clip = app.clip,
      clipMedia = app.clipMedia;

  final String name;
  final String city;
  final String creative;
  final List<String> genres;
  final String bio;
  final bool hasPhoto;
  final String? photoPath;
  final ClipStatus clip;
  final PickedMedia? clipMedia;

  void restore(AppState app) {
    app.name = name;
    app.city = city;
    app.creative = creative;
    app.genres = genres;
    app.bio = bio;
    app.hasPhoto = hasPhoto;
    app.photoPath = photoPath;
    // An upload still running when the edit began can't be resumed.
    app.clip = clip == ClipStatus.uploading ? ClipStatus.idle : clip;
    app.clipMedia = clipMedia;
    app.uploadPct = 0;
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
