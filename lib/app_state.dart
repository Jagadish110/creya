import 'dart:async';

import 'package:flutter/widgets.dart';

import 'mock_data.dart';
import 'models.dart';

enum AppStage { welcome, craft, face, app }

enum AppTab { discover, collabs, requests, messages, profile }

enum SubScreen { none, post, chat, person, settings }

enum ClipStatus { idle, uploading, done }

enum ListState { data, loading, empty, error }

enum CollabMode { browse, mine }

enum RequestMode { connections, collabs }

enum SwipeDirection { left, right }

/// All app state and behaviour, ported from the design's prototype logic.
/// Everything lives in memory: nothing is sent anywhere or kept between runs.
class AppState extends ChangeNotifier {
  AppState({this.listState = ListState.data, String? screenKey}) {
    _reset();
    if (screenKey != null) _applyScreenKey(screenKey);
  }

  /// Which variant list screens show. Only [ListState.data] occurs today; the
  /// others are the design's states, ready for when real data can fail.
  ListState listState;

  late AppStage stage;
  late AppTab tab;
  late SubScreen sub;
  String? viewId;
  late bool previewing;

  late String name;
  late String city;
  late String creative;
  late List<String> genres;
  late String bio;
  late bool hasPhoto;
  late ClipStatus clip;
  late int uploadPct;

  late List<String> deck;
  late List<String> skipped;

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

  Timer? _uploadTimer;
  Timer? _toastTimer;
  final List<Timer> _chatTimers = [];

  void _reset() {
    _uploadTimer?.cancel();
    _toastTimer?.cancel();
    for (final timer in _chatTimers) {
      timer.cancel();
    }
    _chatTimers.clear();

    stage = AppStage.welcome;
    tab = AppTab.discover;
    sub = SubScreen.none;
    viewId = null;
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
    deck = List.of(discoverQueue);
    skipped = [];
    collabMode = CollabMode.browse;
    requestMode = RequestMode.connections;
    _browse = List.of(seedBrowse);
    _mine = List.of(seedMine);
    _connections = List.of(seedConnections);
    _collabRequests = List.of(seedCollabRequests);
    _chats = seedChats();
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

  List<String> get visibleDeck => deck.where(_visible).toList();

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

  List<Collab> get browse =>
      _forceEmpty ? const [] : _browse.where((c) => _visible(c.ownerId)).toList();

  List<MyPost> get mine => _forceEmpty ? const [] : List.of(_mine);

  int get myPostCount => _mine.length;

  int applicantsFor(MyPost post) =>
      _collabRequests.where((r) => r.post == post.title).length;

  List<Chat> get chats =>
      _forceEmpty ? const [] : _chats.where((c) => _visible(c.personId)).toList();

  Chat? get activeChat {
    for (final chat in _chats) {
      if (chat.id == chatId) return chat;
    }
    return null;
  }

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
    viewId = null;
    showDeleteSheet = false;
    notifyListeners();
  }

  void openPerson(String personId) {
    sub = SubScreen.person;
    viewId = personId;
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
    viewId = null;
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

  void addPhoto() {
    hasPhoto = true;
    notifyListeners();
  }

  /// Simulates the clip upload shown in the design.
  void uploadClip() {
    if (clip == ClipStatus.uploading) return;
    _uploadTimer?.cancel();
    clip = ClipStatus.uploading;
    uploadPct = 0;
    notifyListeners();
    _uploadTimer = Timer.periodic(const Duration(milliseconds: 110), (timer) {
      uploadPct = (uploadPct + 7).clamp(0, 100);
      if (uploadPct >= 100) {
        clip = ClipStatus.done;
        timer.cancel();
      }
      notifyListeners();
    });
  }

  void finishOnboarding() {
    if (!canCreateAccount) {
      showToast('Add a profile photo and a talent clip to continue');
      return;
    }
    stage = AppStage.app;
    selectTab(AppTab.discover);
    showToast('Welcome to Creya, ${name.split(' ').first}');
  }

  // ---- Discover ----------------------------------------------------------

  void finishSwipe(String personId, SwipeDirection direction) {
    deck = deck.where((id) => id != personId).toList();
    if (direction == SwipeDirection.left) {
      skipped = [...skipped, personId];
      notifyListeners();
    } else {
      showToast('Connection request sent to ${people[personId]!.firstName}');
    }
  }

  void resetDeck() {
    final remaining = discoverQueue.where((id) => !skipped.contains(id));
    deck = remaining.isNotEmpty ? remaining.toList() : List.of(discoverQueue);
    skipped = [];
    notifyListeners();
  }

  // ---- Collabs -----------------------------------------------------------

  void setCollabMode(CollabMode mode) {
    collabMode = mode;
    notifyListeners();
  }

  void apply(Collab collab) {
    if (collab.applied) return;
    _browse = _browse
        .map((c) => c.id == collab.id ? c.markApplied() : c)
        .toList();
    showToast(
      'Applied. ${people[collab.ownerId]!.firstName} will see your request',
    );
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

  void publishPost() {
    if (!canPublish) return;
    final editingId = editingPostId;
    if (editingId != null) {
      final previous = _mine.firstWhere((m) => m.id == editingId);
      _mine = _mine
          .map(
            (m) => m.id == editingId
                ? MyPost(
                    id: m.id,
                    title: postTitle,
                    skill: postSkill,
                    desc: postDesc,
                    time: m.time,
                  )
                : m,
          )
          .toList();
      // Applicants are linked by title, so a rename must carry them along.
      _collabRequests = _collabRequests
          .map(
            (r) => r.post == previous.title
                ? ConnectionRequest(
                    id: r.id,
                    personId: r.personId,
                    post: postTitle,
                  )
                : r,
          )
          .toList();
    } else {
      _mine = [
        MyPost(
          id: 'm${DateTime.now().millisecondsSinceEpoch}',
          title: postTitle,
          skill: postSkill,
          desc: postDesc,
          time: 'now',
        ),
        ..._mine,
      ];
    }
    sub = SubScreen.none;
    collabMode = CollabMode.mine;
    showToast(editingId != null ? 'Post updated' : 'Collab published');
  }

  void deletePost(MyPost post) {
    _mine = _mine.where((m) => m.id != post.id).toList();
    _collabRequests = _collabRequests
        .where((r) => r.post != post.title)
        .toList();
    showToast('Post deleted');
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

  void acceptRequest(ConnectionRequest request) {
    _removeRequest(request);
    final exists = _chats.any((c) => c.personId == request.personId);
    if (!exists) {
      _chats = [
        Chat(
          id: 'h${DateTime.now().millisecondsSinceEpoch}',
          personId: request.personId,
          time: 'now',
          unread: false,
          messages: [],
        ),
        ..._chats,
      ];
    }
    showToast(
      'Accepted. Chat opened with ${people[request.personId]!.firstName}',
    );
  }

  void declineRequest(ConnectionRequest request) {
    _removeRequest(request);
    showToast('Request declined');
  }

  // ---- Messages ----------------------------------------------------------

  void openChat(Chat chat) {
    chat.unread = false;
    sub = SubScreen.chat;
    chatId = chat.id;
    notifyListeners();
  }

  /// Sends a message, followed by the design's simulated reply.
  void sendMessage(String text) {
    final body = text.trim();
    final chat = activeChat;
    if (body.isEmpty || chat == null) return;
    chat.time = 'now';
    chat.messages.add(Message(me: true, body: body));
    notifyListeners();
    _chatTimers.add(
      Timer(const Duration(milliseconds: 500), () {
        typing = true;
        notifyListeners();
      }),
    );
    _chatTimers.add(
      Timer(const Duration(milliseconds: 1800), () {
        typing = false;
        chat.messages.add(
          const Message(me: false, body: 'Sounds good, let’s do it.'),
        );
        notifyListeners();
      }),
    );
  }

  // ---- Profile and safety ------------------------------------------------

  void connectWithViewed() {
    final id = viewId;
    if (id == null) return;
    deck = deck.where((x) => x != id).toList();
    sub = SubScreen.none;
    viewId = null;
    showToast('Connection request sent to ${people[id]!.firstName}');
  }

  void blockViewed() {
    final id = viewId;
    if (id == null) return;
    blocked = [...blocked, id];
    sub = SubScreen.none;
    viewId = null;
    showToast("${people[id]!.firstName} blocked. They won't appear anywhere.");
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

  /// Sign out and delete both return to a fresh Welcome screen, as designed.
  void signOut() {
    _reset();
    notifyListeners();
  }

  void retry() {
    listState = ListState.data;
    notifyListeners();
  }

  @override
  void dispose() {
    _uploadTimer?.cancel();
    _toastTimer?.cancel();
    for (final timer in _chatTimers) {
      timer.cancel();
    }
    super.dispose();
  }
}

/// Makes the [AppState] available to the widget tree and rebuilds on change.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  }
}
