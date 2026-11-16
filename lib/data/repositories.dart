import '../models.dart';
import 'media.dart';

/// The app's data layer. `AppState` talks only to these interfaces, so the
/// in-memory backend used today can be swapped for a real one without
/// touching the screens.
///
/// Every call may fail by throwing; `AppState` reports the failure and
/// reloads to get back in step with the backend.

abstract interface class AuthRepository {
  Future<void> signInWithGoogle();

  Future<void> signOut();

  Future<void> deleteAccount();
}

abstract interface class ProfileRepository {
  /// The signed-in user's profile, or null when nobody is signed in.
  Future<MyProfile?> loadMine();

  /// Uploads only store the file. The profile starts using it when
  /// [saveProfile] is next called, so an abandoned edit changes nothing.
  Future<void> uploadPhoto(PickedMedia photo);

  /// Uploads the talent clip, reporting progress from 0 to 100. The stream
  /// closes when the upload finishes. A backend that can't measure progress
  /// reports 0 until it is done.
  Stream<int> uploadClip(PickedMedia clip);

  Future<void> saveProfile(Person profile);
}

abstract interface class DiscoverRepository {
  /// People the user has not swiped, is not connected to and has not blocked.
  Future<List<Person>> loadDeck();

  /// A right swipe sends a connection request.
  Future<void> swipe(String personId, SwipeDirection direction);

  /// Forgets the user's left swipes so those people can come round again.
  Future<void> undoSkips();
}

abstract interface class CollabRepository {
  Future<List<Collab>> loadBrowse();

  Future<List<MyPost>> loadMine();

  Future<void> apply(String collabId);

  Future<MyPost> createPost(PostDraft draft);

  Future<MyPost> updatePost(String postId, PostDraft draft);

  Future<void> deletePost(String postId);
}

abstract interface class RequestRepository {
  Future<List<ConnectionRequest>> loadConnectionRequests();

  /// Applications to the user's own collab posts.
  Future<List<ConnectionRequest>> loadCollabRequests();

  /// Answers a request. Returns the chat it opens when accepted, else null.
  Future<Chat?> respond(ConnectionRequest request, {required bool accept});
}

abstract interface class ChatRepository {
  /// The chat list. Each chat carries only its latest message.
  Future<List<Chat>> loadChats();

  /// A page of a chat's history, ending just before [before], or at the
  /// newest message when [before] is null.
  Future<MessagePage> loadMessages(
    String chatId, {
    DateTime? before,
    int limit = 30,
  });

  /// Live updates from the other person in any chat.
  Stream<ChatEvent> get events;

  Future<void> send(String chatId, String body);

  Future<void> markRead(String chatId);
}

sealed class ChatEvent {
  const ChatEvent(this.chatId);

  final String chatId;
}

class MessageReceived extends ChatEvent {
  const MessageReceived(super.chatId, this.message);

  final Message message;
}

class TypingChanged extends ChatEvent {
  const TypingChanged(super.chatId, {required this.typing});

  final bool typing;
}

abstract interface class SafetyRepository {
  Future<void> block(String personId);

  Future<void> report(String personId, {required String reason});
}

/// One of each repository, handed to `AppState` as a unit.
class Backend {
  const Backend({
    required this.auth,
    required this.profiles,
    required this.discover,
    required this.collabs,
    required this.requests,
    required this.chats,
    required this.safety,
  });

  final AuthRepository auth;
  final ProfileRepository profiles;
  final DiscoverRepository discover;
  final CollabRepository collabs;
  final RequestRepository requests;
  final ChatRepository chats;
  final SafetyRepository safety;
}
