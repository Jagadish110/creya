import 'dart:async';
import 'dart:io';

import 'package:supabase/supabase.dart';

import '../models.dart';
import 'media.dart';
import 'repositories.dart';

/// The real backend: every repository backed by one Supabase project, using
/// the schema in `supabase/migrations/`. The database's row-level rules
/// decide what each call may see or change; nothing here is trusted.
Backend supabaseBackend(SupabaseClient client) {
  final core = _Core(client);
  return Backend(
    auth: _SupabaseAuth(core),
    profiles: _SupabaseProfiles(core),
    discover: _SupabaseDiscover(core),
    collabs: _SupabaseCollabs(core),
    requests: _SupabaseRequests(core),
    chats: _SupabaseChats(core),
    safety: _SupabaseSafety(core),
  );
}

typedef _Row = Map<String, dynamic>;

const _avatars = 'avatars';
const _clips = 'clips';
const _buckets = [_avatars, _clips, 'collab-media'];

/// What the repositories share: the client and row-to-model mapping.
class _Core {
  _Core(this.client);

  final SupabaseClient client;

  String get userId {
    final id = client.auth.currentUser?.id;
    if (id == null) throw StateError('Not signed in');
    return id;
  }

  /// Temporary links to private files, keyed by their path in [bucket]. A
  /// file that can't be signed is left out, so its placeholder shows instead.
  Future<Map<String, String>> _sign(
    String bucket,
    Iterable<Object?> paths,
  ) async {
    final wanted = paths.whereType<String>().toSet().toList();
    if (wanted.isEmpty) return const {};
    try {
      final signed = await client.storage
          .from(bucket)
          .createSignedUrlsResult(wanted, const Duration(days: 1).inSeconds);
      return {
        for (final s in signed.whereType<SignedUrlSuccess>())
          s.path: s.signedUrl,
      };
    } on StorageException {
      return const {};
    }
  }

  /// Turns `profiles` rows into people, in the same order.
  Future<List<Person>> people(List<_Row> rows) async {
    final (photos, clips) = await (
      _sign(_avatars, rows.map((r) => r['photo_path'])),
      _sign(_clips, rows.map((r) => r['clip_path'])),
    ).wait;
    return [
      for (final row in rows)
        Person(
          id: row['id'] as String,
          name: row['name'] as String,
          creative: row['creative'] as String,
          city: row['city'] as String,
          genres: (row['genres'] as List).cast<String>(),
          bio: row['bio'] as String,
          hue: _hueFor(row['id'] as String),
          connections: row['connection_count'] as int,
          photo: photos[row['photo_path']],
          clip: clips[row['clip_path']],
        ),
    ];
  }

  /// People by id, for rows that only carry a profile id.
  Future<Map<String, Person>> peopleById(Iterable<String> ids) async {
    final wanted = ids.toSet().toList();
    if (wanted.isEmpty) return const {};
    final rows = await client.from('profiles').select().inFilter('id', wanted);
    return {for (final person in await people(rows)) person.id: person};
  }

  /// A steady placeholder colour for each person.
  static int _hueFor(String id) =>
      id.codeUnits.fold(0, (sum, unit) => sum + unit) % 360;
}

DateTime _time(Object? value) => DateTime.parse(value as String).toLocal();

class _SupabaseAuth implements AuthRepository {
  _SupabaseAuth(this._core);

  final _Core _core;

  /// Stands in for Google sign-in until it is configured: creates an
  /// anonymous account so the rest of the app can be used for real. Needs
  /// "anonymous sign-ins" switched on in the project's auth settings.
  @override
  Future<void> signInWithGoogle() async {
    if (_core.client.auth.currentUser != null) return;
    await _core.client.auth.signInAnonymously();
  }

  @override
  Future<void> signOut() => _core.client.auth.signOut();

  @override
  Future<void> deleteAccount() async {
    final userId = _core.userId;
    // Stored files first: the database can't remove them.
    for (final bucket in _buckets) {
      final storage = _core.client.storage.from(bucket);
      final files = await storage.list(path: userId);
      if (files.isNotEmpty) {
        await storage.remove([for (final f in files) '$userId/${f.name}']);
      }
    }
    await _core.client.rpc<void>('delete_my_account');
    await _core.client.auth.signOut(scope: SignOutScope.local);
  }
}

class _SupabaseProfiles implements ProfileRepository {
  _SupabaseProfiles(this._core);

  final _Core _core;

  /// Uploaded files the profile doesn't point at yet; see [saveProfile].
  String? _pendingPhoto;
  String? _pendingClip;

  @override
  Future<MyProfile?> loadMine() async {
    final userId = _core.client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _core.client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    final person = (await _core.people([row])).single;
    return MyProfile(person: person, onboarded: row['onboarded_at'] != null);
  }

  Future<String> _upload(String bucket, PickedMedia media) async {
    final source = media.path;
    if (source == null) throw StateError('Nothing to upload');
    final dot = media.name.lastIndexOf('.');
    final extension = dot < 0 ? '' : media.name.substring(dot).toLowerCase();
    // A fresh name each time, so a replaced file is never served from cache.
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final path = '${_core.userId}/$stamp$extension';
    await _core.client.storage
        .from(bucket)
        .upload(
          path,
          File(source),
          fileOptions: FileOptions(contentType: _contentTypes[extension]),
        );
    return path;
  }

  @override
  Future<void> uploadPhoto(PickedMedia photo) async {
    _pendingPhoto = await _upload(_avatars, photo);
  }

  @override
  Stream<int> uploadClip(PickedMedia clip) async* {
    yield 0;
    _pendingClip = await _upload(_clips, clip);
    yield 100;
  }

  @override
  Future<void> saveProfile(Person profile) async {
    final userId = _core.userId;
    final profiles = _core.client.from('profiles');
    final before = await profiles
        .select('photo_path, clip_path')
        .eq('id', userId)
        .single();
    await profiles
        .update({
          'name': profile.name,
          'city': profile.city,
          'creative': profile.creative,
          'genres': profile.genres,
          'bio': profile.bio,
          'photo_path': ?_pendingPhoto,
          'clip_path': ?_pendingClip,
        })
        .eq('id', userId);
    await profiles
        .update({'onboarded_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', userId)
        .isFilter('onboarded_at', null);

    // The files just replaced are no longer needed.
    await _discard(_avatars, before['photo_path'], replacedBy: _pendingPhoto);
    await _discard(_clips, before['clip_path'], replacedBy: _pendingClip);
    _pendingPhoto = null;
    _pendingClip = null;
  }

  Future<void> _discard(
    String bucket,
    Object? oldPath, {
    required String? replacedBy,
  }) async {
    if (replacedBy == null || oldPath is! String || oldPath == replacedBy) {
      return;
    }
    try {
      await _core.client.storage.from(bucket).remove([oldPath]);
    } on StorageException {
      // A leftover file is harmless; the profile is already saved.
    }
  }

  static const _contentTypes = {
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.webp': 'image/webp',
    '.heic': 'image/heic',
    '.mp4': 'video/mp4',
    '.mov': 'video/quicktime',
  };
}

class _SupabaseDiscover implements DiscoverRepository {
  _SupabaseDiscover(this._core);

  final _Core _core;

  @override
  Future<List<Person>> loadDeck() async {
    final rows = await _core.client.rpc<List<dynamic>>('discover_deck');
    return _core.people(rows.cast<_Row>());
  }

  @override
  Future<void> swipe(String personId, SwipeDirection direction) async {
    final swipes = _core.client.from('swipes');
    if (direction == SwipeDirection.right) {
      // Connecting with someone skipped earlier replaces the skip.
      await swipes
          .delete()
          .eq('swiper_id', _core.userId)
          .eq('target_id', personId)
          .eq('direction', 'left');
    }
    await swipes.upsert({
      'target_id': personId,
      'direction': direction.name,
    }, ignoreDuplicates: true);
  }

  @override
  Future<void> undoSkips() => _core.client
      .from('swipes')
      .delete()
      .eq('swiper_id', _core.userId)
      .eq('direction', 'left');
}

class _SupabaseCollabs implements CollabRepository {
  _SupabaseCollabs(this._core);

  final _Core _core;

  @override
  Future<List<Collab>> loadBrowse() async {
    final userId = _core.userId;
    final (posts, applications) = await (
      _core.client
          .from('collab_posts')
          .select()
          .neq('owner_id', userId)
          .order('created_at', ascending: false),
      _core.client
          .from('collab_applications')
          .select('post_id')
          .eq('applicant_id', userId),
    ).wait;
    final owners = await _core.peopleById(
      posts.map((p) => p['owner_id'] as String),
    );
    final applied = {for (final a in applications) a['post_id']};
    return [
      for (final post in posts)
        if (owners[post['owner_id']] case final owner?)
          Collab(
            id: post['id'] as String,
            owner: owner,
            title: post['title'] as String,
            skill: post['skill'] as String,
            desc: post['description'] as String,
            media: switch (post['media_type']) {
              'audio' => CollabMedia.audio,
              'clip' => CollabMedia.clip,
              _ => null,
            },
            createdAt: _time(post['created_at']),
            applied: applied.contains(post['id']),
          ),
    ];
  }

  static MyPost _post(_Row row) => MyPost(
    id: row['id'] as String,
    title: row['title'] as String,
    skill: row['skill'] as String,
    desc: row['description'] as String,
    createdAt: _time(row['created_at']),
  );

  static _Row _fields(PostDraft draft) => {
    'title': draft.title.trim(),
    'skill': draft.skill,
    'description': draft.desc,
  };

  @override
  Future<List<MyPost>> loadMine() async {
    final rows = await _core.client
        .from('collab_posts')
        .select()
        .eq('owner_id', _core.userId)
        .order('created_at', ascending: false);
    return rows.map(_post).toList();
  }

  @override
  Future<void> apply(String collabId) => _core.client
      .from('collab_applications')
      .upsert(
        {'post_id': collabId},
        onConflict: 'post_id,applicant_id',
        ignoreDuplicates: true,
      );

  @override
  Future<MyPost> createPost(PostDraft draft) async => _post(
    await _core.client
        .from('collab_posts')
        .insert(_fields(draft))
        .select()
        .single(),
  );

  @override
  Future<MyPost> updatePost(String postId, PostDraft draft) async => _post(
    await _core.client
        .from('collab_posts')
        .update(_fields(draft))
        .eq('id', postId)
        .select()
        .single(),
  );

  @override
  Future<void> deletePost(String postId) =>
      _core.client.from('collab_posts').delete().eq('id', postId);
}

class _SupabaseRequests implements RequestRepository {
  _SupabaseRequests(this._core);

  final _Core _core;

  @override
  Future<List<ConnectionRequest>> loadConnectionRequests() async {
    final rows = await _core.client
        .from('connections')
        .select('id, requester_id')
        .eq('addressee_id', _core.userId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    final people = await _core.peopleById(
      rows.map((r) => r['requester_id'] as String),
    );
    return [
      for (final row in rows)
        if (people[row['requester_id']] case final person?)
          ConnectionRequest(id: row['id'] as String, person: person),
    ];
  }

  @override
  Future<List<ConnectionRequest>> loadCollabRequests() async {
    final userId = _core.userId;
    final rows = await _core.client
        .from('collab_applications')
        .select(
          'id, applicant_id, post:collab_posts!inner(id, title, owner_id)',
        )
        .eq('post.owner_id', userId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    final people = await _core.peopleById(
      rows.map((r) => r['applicant_id'] as String),
    );
    return [
      for (final row in rows)
        if (people[row['applicant_id']] case final person?)
          ConnectionRequest(
            id: row['id'] as String,
            person: person,
            postId: (row['post'] as _Row)['id'] as String,
            post: (row['post'] as _Row)['title'] as String,
          ),
    ];
  }

  @override
  Future<Chat?> respond(
    ConnectionRequest request, {
    required bool accept,
  }) async {
    final chatId = request.postId == null
        ? await _core.client.rpc<String?>(
            'respond_to_connection',
            params: {'p_connection_id': request.id, 'p_accept': accept},
          )
        : await _core.client.rpc<String?>(
            'respond_to_application',
            params: {'p_application_id': request.id, 'p_accept': accept},
          );
    if (chatId == null) return null;
    final row = await _core.client
        .from('chats')
        .select()
        .eq('id', chatId)
        .single();
    return Chat(
      id: chatId,
      person: request.person,
      lastActivity: _time(row['last_message_at']),
      unread: false,
      messages: const [],
    );
  }
}

class _SupabaseChats implements ChatRepository {
  _SupabaseChats(this._core);

  final _Core _core;

  RealtimeChannel? _channel;
  late final _events = StreamController<ChatEvent>.broadcast(
    onListen: _subscribe,
    onCancel: _unsubscribe,
  );

  @override
  Stream<ChatEvent> get events => _events.stream;

  /// Listens for new messages. The database only delivers messages from
  /// chats the signed-in user belongs to.
  void _subscribe() {
    _channel = _core.client
        .channel('creya-messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (change) {
            final row = change.newRecord;
            if (row['sender_id'] == _core.client.auth.currentUser?.id) return;
            _events.add(
              MessageReceived(
                row['chat_id'] as String,
                Message(me: false, body: row['body'] as String),
              ),
            );
          },
        )
        .subscribe();
  }

  Future<void> _unsubscribe() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) await _core.client.removeChannel(channel);
  }

  @override
  Future<List<Chat>> loadChats() async {
    final userId = _core.userId;
    final chats = await _core.client
        .from('chats')
        .select()
        .order('last_message_at', ascending: false);
    if (chats.isEmpty) return [];
    final chatIds = [for (final c in chats) c['id'] as String];

    String other(_Row chat) =>
        (chat['user_a'] == userId ? chat['user_b'] : chat['user_a']) as String;

    final (people, messages, reads) = await (
      _core.peopleById(chats.map(other)),
      _core.client
          .from('messages')
          .select()
          .inFilter('chat_id', chatIds)
          .order('created_at'),
      _core.client
          .from('chat_reads')
          .select()
          .eq('user_id', userId)
          .inFilter('chat_id', chatIds),
    ).wait;
    final readAt = {
      for (final r in reads) r['chat_id']: _time(r['last_read_at']),
    };

    return [
      for (final chat in chats)
        if (people[other(chat)] case final person?)
          () {
            final own = messages.where((m) => m['chat_id'] == chat['id']);
            final last = own.lastOrNull;
            final read = readAt[chat['id']];
            return Chat(
              id: chat['id'] as String,
              person: person,
              lastActivity: _time(chat['last_message_at']),
              unread:
                  last != null &&
                  last['sender_id'] != userId &&
                  (read == null || _time(last['created_at']).isAfter(read)),
              messages: [
                for (final m in own)
                  Message(
                    me: m['sender_id'] == userId,
                    body: m['body'] as String,
                  ),
              ],
            );
          }(),
    ];
  }

  @override
  Future<void> send(String chatId, String body) =>
      _core.client.from('messages').insert({'chat_id': chatId, 'body': body});

  @override
  Future<void> markRead(String chatId) =>
      _core.client.rpc<void>('mark_chat_read', params: {'p_chat_id': chatId});
}

class _SupabaseSafety implements SafetyRepository {
  _SupabaseSafety(this._core);

  final _Core _core;

  @override
  Future<void> block(String personId) => _core.client.from('blocks').upsert({
    'blocked_id': personId,
  }, ignoreDuplicates: true);

  // Reports can be written but never read back, so no row is requested.
  @override
  Future<void> report(String personId, {required String reason}) => _core.client
      .from('reports')
      .insert({'reported_user_id': personId, 'reason': reason});
}
