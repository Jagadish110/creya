// Runs the Supabase repositories against a real Supabase stack: real
// sign-ins, uploads, row-level security and live messages.
//
// Skipped unless a stack is named. To run it locally:
//
//   supabase start
//   SUPABASE_TEST_URL=http://127.0.0.1:54321 \
//   SUPABASE_TEST_KEY=<publishable key printed by `supabase start`> \
//   flutter test test/backend
//
// It creates throwaway anonymous accounts, so never point it at production.
import 'dart:async';
import 'dart:io';

import 'package:creya/app_state.dart';
import 'package:creya/data/media.dart';
import 'package:creya/data/repositories.dart';
import 'package:creya/data/supabase_backend.dart';
import 'package:creya/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';

final _url = Platform.environment['SUPABASE_TEST_URL'];
final _key = Platform.environment['SUPABASE_TEST_KEY'];

late Directory _temp;

/// A signed-in, onboarded user with their own client and repositories.
class _User {
  _User(this.name, this.client)
    : backend = supabaseBackend(client, anonymousSignIn: true);

  final String name;
  final SupabaseClient client;
  final Backend backend;

  String get id => client.auth.currentUser!.id;

  Person get draft => Person(
    id: 'me',
    name: name,
    creative: 'Vocalist',
    city: 'London',
    genres: const ['Soul'],
    bio: 'Test account',
    hue: 0,
    connections: 0,
  );

  static Future<_User> create(String name) async {
    final user = _User(
      name,
      SupabaseClient(
        _url!,
        _key!,
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      ),
    );
    await user.backend.auth.signInWithGoogle();
    return user;
  }

  Future<void> onboard() async {
    await backend.profiles.uploadPhoto(_file('photo.jpg'));
    await backend.profiles.uploadClip(_file('clip.mp4')).drain<void>();
    await backend.profiles.saveProfile(draft);
  }
}

PickedMedia _file(String name) {
  final file = File('${_temp.path}/$name')
    ..writeAsBytesSync(List.filled(64, 7));
  return PickedMedia(name: name, path: file.path);
}

/// Hands the app real files, as the photo library would.
class _FilePicker implements MediaPicker {
  @override
  Future<PickedMedia?> pickPhoto() async => _file('me.jpg');

  @override
  Future<PickedMedia?> pickClip() async => _file('me.mp4');
}

void main() {
  final skip = _url == null || _key == null
      ? 'Set SUPABASE_TEST_URL and SUPABASE_TEST_KEY to run'
      : null;

  late _User ann;
  late _User bob;
  late _User cee;

  setUpAll(() async {
    if (skip != null) return;
    _temp = Directory.systemTemp.createTempSync('creya-test');
    ann = await _User.create('Ann Archer');
    bob = await _User.create('Bob Baker');
    cee = await _User.create('Cee Cole');
  });

  tearDownAll(() async {
    if (skip != null) return;
    for (final user in [ann, bob, cee]) {
      if (user.client.auth.currentUser != null) {
        await user.backend.auth.deleteAccount();
      }
      await user.client.dispose();
    }
    _temp.deleteSync(recursive: true);
  });

  Future<List<String>> deckOf(_User user) async => [
    for (final p in await user.backend.discover.loadDeck()) p.id,
  ];

  group('against a real Supabase stack', skip: skip, () {
    test('onboarding saves the profile and its files', () async {
      final before = await ann.backend.profiles.loadMine();
      expect(before!.onboarded, isFalse);

      await ann.onboard();
      await bob.onboard();
      await cee.onboard();

      final after = await ann.backend.profiles.loadMine();
      expect(after!.onboarded, isTrue);
      expect(after.person.name, 'Ann Archer');
      expect(after.person.genres, ['Soul']);

      // The photo link really serves the uploaded file.
      final request = await HttpClient().getUrl(Uri.parse(after.person.photo!));
      final response = await request.close();
      expect(response.statusCode, 200);
      expect(await response.fold<int>(0, (n, chunk) => n + chunk.length), 64);
      expect(after.person.clip, startsWith('http'));
    });

    test('replacing the photo removes the old file', () async {
      await ann.backend.profiles.uploadPhoto(_file('new.png'));
      await ann.backend.profiles.saveProfile(ann.draft);
      final files = await ann.client.storage.from('avatars').list(path: ann.id);
      expect(files, hasLength(1));
      expect(files.single.name, endsWith('.png'));
    });

    test('a skip hides someone until skips are undone', () async {
      expect(await deckOf(ann), containsAll([bob.id, cee.id]));
      await ann.backend.discover.swipe(cee.id, SwipeDirection.left);
      expect(await deckOf(ann), isNot(contains(cee.id)));
      await ann.backend.discover.undoSkips();
      expect(await deckOf(ann), contains(cee.id));
    });

    late Chat chat;

    test(
      'a right swipe becomes a request, and accepting opens a chat',
      () async {
        await ann.backend.discover.swipe(bob.id, SwipeDirection.right);
        expect(await deckOf(ann), isNot(contains(bob.id)));
        expect(await deckOf(bob), isNot(contains(ann.id)));
        expect(await cee.backend.requests.loadConnectionRequests(), isEmpty);

        final requests = await bob.backend.requests.loadConnectionRequests();
        expect(requests.single.person.name, 'Ann Archer');

        chat = (await bob.backend.requests.respond(
          requests.single,
          accept: true,
        ))!;
        expect(chat.person.id, ann.id);
        expect(await bob.backend.requests.loadConnectionRequests(), isEmpty);
        expect((await ann.backend.chats.loadChats()).single.person.id, bob.id);
        expect((await cee.backend.chats.loadChats()), isEmpty);

        final me = await ann.backend.profiles.loadMine();
        expect(me!.person.connections, 1);
      },
    );

    test(
      'connecting with someone skipped earlier still sends a request',
      () async {
        await cee.backend.discover.swipe(ann.id, SwipeDirection.left);
        await cee.backend.discover.swipe(ann.id, SwipeDirection.right);
        final requests = await ann.backend.requests.loadConnectionRequests();
        expect(requests.single.person.id, cee.id);
        expect(
          await ann.backend.requests.respond(requests.single, accept: false),
          isNull,
        );
        expect(await ann.backend.chats.loadChats(), hasLength(1));
      },
    );

    test('a message arrives live and marks the chat unread', () async {
      final incoming = Completer<MessageReceived>();
      final listening = ann.backend.chats.events.listen((event) {
        if (event is MessageReceived && !incoming.isCompleted) {
          incoming.complete(event);
        }
      });
      // Give the live channel a moment to connect before sending.
      await Future<void>.delayed(const Duration(seconds: 2));

      await bob.backend.chats.send(chat.id, 'Hello Ann');
      final event = await incoming.future.timeout(const Duration(seconds: 10));
      expect(event.chatId, chat.id);
      expect(event.message.body, 'Hello Ann');
      expect(event.message.me, isFalse);
      await listening.cancel();

      final unread = (await ann.backend.chats.loadChats()).single;
      expect(unread.unread, isTrue);
      expect(unread.messages.single.body, 'Hello Ann');
      expect((await bob.backend.chats.loadChats()).single.unread, isFalse);

      await ann.backend.chats.markRead(chat.id);
      expect((await ann.backend.chats.loadChats()).single.unread, isFalse);
    });

    test('chat history loads a page at a time', () async {
      for (var i = 1; i <= 34; i++) {
        await bob.backend.chats.send(chat.id, 'Line $i');
      }
      // The chat list carries only the latest message.
      final listed = (await ann.backend.chats.loadChats()).single;
      expect(listed.messages.single.body, 'Line 34');
      expect(listed.unread, isTrue);

      final newest = await ann.backend.chats.loadMessages(chat.id);
      expect(newest.messages, hasLength(30));
      expect(newest.messages.last.body, 'Line 34');
      expect(newest.messages.first.body, 'Line 5');
      expect(newest.hasOlder, isTrue);

      final older = await ann.backend.chats.loadMessages(
        chat.id,
        before: newest.messages.first.sentAt,
      );
      expect(older.messages.map((m) => m.body), [
        'Hello Ann',
        for (var i = 1; i <= 4; i++) 'Line $i',
      ]);
      expect(older.hasOlder, isFalse);
      expect(older.messages.every((m) => !m.me), isTrue);
      expect(
        (await bob.backend.chats.loadMessages(chat.id)).messages.last.me,
        isTrue,
      );
    });

    test('collab posts can be applied to, renamed and answered', () async {
      final post = await ann.backend.collabs.createPost(
        const PostDraft(title: 'Vocalist wanted', skill: 'Vocalist'),
      );
      expect((await ann.backend.collabs.loadMine()).single.id, post.id);
      expect(await ann.backend.collabs.loadBrowse(), isEmpty);

      final seen = (await bob.backend.collabs.loadBrowse()).single;
      expect(seen.owner.id, ann.id);
      expect(seen.applied, isFalse);
      expect(seen.media, isNull);

      await bob.backend.collabs.apply(post.id);
      await bob.backend.collabs.apply(post.id);
      expect((await bob.backend.collabs.loadBrowse()).single.applied, isTrue);

      await ann.backend.collabs.updatePost(
        post.id,
        const PostDraft(title: 'Singer wanted', skill: 'Vocalist'),
      );
      final application =
          (await ann.backend.requests.loadCollabRequests()).single;
      expect(application.person.id, bob.id);
      expect(application.postId, post.id);
      expect(application.post, 'Singer wanted');
      expect(await bob.backend.requests.loadCollabRequests(), isEmpty);

      final opened = await ann.backend.requests.respond(
        application,
        accept: true,
      );
      expect(opened!.id, chat.id);
      expect(await ann.backend.requests.loadCollabRequests(), isEmpty);
    });

    test("one user can't change another's data", () async {
      final post = (await ann.backend.collabs.loadMine()).single;
      await expectLater(
        bob.backend.collabs.updatePost(
          post.id,
          const PostDraft(title: 'Hijacked', skill: 'DJ'),
        ),
        throwsA(isA<PostgrestException>()),
      );
      await bob.backend.collabs.deletePost(post.id);
      expect(
        (await ann.backend.collabs.loadMine()).single.title,
        'Singer wanted',
      );

      await expectLater(
        cee.backend.chats.send(chat.id, 'Let me in'),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        bob.client.storage
            .from('avatars')
            .upload('${ann.id}/evil.jpg', File(_file('evil.jpg').path!)),
        throwsA(isA<StorageException>()),
      );
    });

    test('blocking hides both people from each other', () async {
      await bob.backend.safety.report(ann.id, reason: 'Test report');
      await bob.backend.safety.block(ann.id);

      expect(await bob.backend.chats.loadChats(), isEmpty);
      expect(await ann.backend.chats.loadChats(), isEmpty);
      expect(await bob.backend.collabs.loadBrowse(), isEmpty);
      await expectLater(
        ann.backend.chats.send(chat.id, 'Still there?'),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('the app signs up, then resumes the session on next launch', () async {
      final dee = await _User.create('Dee Diaz');
      await dee.client.auth.signOut();
      final picker = _FilePicker();

      final first = AppState(backend: dee.backend, picker: picker);
      await pumpEventQueue();
      expect(first.launching, isFalse);
      expect(first.stage, AppStage.welcome);

      await first.signIn();
      expect(first.stage, AppStage.craft);
      expect(first.name, isEmpty);
      first.updateProfile(name: 'Dee Diaz', city: 'Leeds');
      await first.addPhoto();
      final uploaded = Completer<void>();
      first.addListener(() {
        if (first.clip == ClipStatus.done && !uploaded.isCompleted) {
          uploaded.complete();
        }
      });
      await first.uploadClip();
      await uploaded.future.timeout(const Duration(seconds: 10));
      await first.finishOnboarding();
      expect(first.stage, AppStage.app);
      expect(first.listState, ListState.data);
      expect(first.visibleDeck.map((p) => p.id), contains(cee.id));
      first.dispose();

      // A second launch on the same signed-in client.
      final second = AppState(backend: dee.backend, picker: picker);
      expect(second.launching, isTrue);
      for (var i = 0; i < 50 && second.listState != ListState.data; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(second.launching, isFalse);
      expect(second.stage, AppStage.app);
      expect(second.name, 'Dee Diaz');
      expect(second.city, 'Leeds');
      expect(second.me.photo, startsWith('http'));
      expect(second.clip, ClipStatus.done);

      await second.deleteAccount();
      expect(second.stage, AppStage.welcome);
      second.dispose();
      await dee.client.dispose();
    });

    test(
      'deleting an account removes the user, their data and files',
      () async {
        final annId = ann.id;
        await ann.backend.auth.deleteAccount();
        expect(ann.client.auth.currentUser, isNull);
        expect(await ann.backend.profiles.loadMine(), isNull);

        expect(await deckOf(cee), isNot(contains(annId)));
        final left = await cee.client.storage.from('avatars').list(path: annId);
        expect(left, isEmpty);
      },
    );
  });
}
