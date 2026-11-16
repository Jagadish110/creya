import 'theme.dart';

class Person {
  const Person({
    required this.id,
    required this.name,
    required this.creative,
    required this.city,
    required this.genres,
    required this.bio,
    required this.hue,
    required this.connections,
    this.photo,
    this.clip,
  });

  final String id;
  final String name;
  final String creative;
  final String city;
  final List<String> genres;
  final String bio;
  final int hue;
  final int connections;

  /// Where the profile photo and talent clip are: a file on this device or a
  /// web address. Null shows the placeholder artwork instead.
  final String? photo;
  final String? clip;

  CssGradient get bg => CssGradient.fromHue(hue);

  String get firstName => name.split(' ').first;

  String get initials {
    final letters = name
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => word.characters.first)
        .join();
    return letters.length > 2 ? letters.substring(0, 2) : letters;
  }
}

extension on String {
  Iterable<String> get characters => runes.map(String.fromCharCode);
}

/// The signed-in user's own profile, and whether they finished onboarding.
class MyProfile {
  const MyProfile({required this.person, required this.onboarded});

  final Person person;
  final bool onboarded;
}

enum SwipeDirection { left, right }

enum CollabMedia { audio, clip }

/// A short age label such as `now`, `5m`, `2h`, `3d` or `1w`.
String timeAgo(DateTime time, {DateTime? now}) {
  final age = (now ?? DateTime.now()).difference(time);
  if (age.inMinutes < 1) return 'now';
  if (age.inHours < 1) return '${age.inMinutes}m';
  if (age.inDays < 1) return '${age.inHours}h';
  if (age.inDays < 7) return '${age.inDays}d';
  return '${age.inDays ~/ 7}w';
}

/// When a chat was last active: `now`, a time today, a weekday this week,
/// or a date.
String chatTimeLabel(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final age = current.difference(time);
  if (age.inMinutes < 1) return 'now';
  final sameDay =
      time.year == current.year &&
      time.month == current.month &&
      time.day == current.day;
  if (sameDay) {
    final minute = time.minute.toString().padLeft(2, '0');
    return '${time.hour}:$minute';
  }
  if (age.inDays < 7) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[time.weekday - 1];
  }
  return '${time.day}/${time.month}';
}

class Collab {
  const Collab({
    required this.id,
    required this.owner,
    required this.title,
    required this.skill,
    required this.desc,
    required this.createdAt,
    this.media,
    this.applied = false,
  });

  final String id;
  final Person owner;
  final String title;
  final String skill;
  final String desc;

  /// The kind of preview attached to the post, if any.
  final CollabMedia? media;
  final DateTime createdAt;
  final bool applied;

  String get ownerId => owner.id;

  String get time => timeAgo(createdAt);

  Collab markApplied() => Collab(
    id: id,
    owner: owner,
    title: title,
    skill: skill,
    desc: desc,
    media: media,
    createdAt: createdAt,
    applied: true,
  );
}

/// The editable fields of a collab post.
class PostDraft {
  const PostDraft({required this.title, required this.skill, this.desc = ''});

  final String title;
  final String skill;
  final String desc;
}

class MyPost {
  const MyPost({
    required this.id,
    required this.title,
    required this.skill,
    required this.createdAt,
    this.desc = '',
  });

  final String id;
  final String title;
  final String skill;
  final DateTime createdAt;
  final String desc;

  String get time => timeAgo(createdAt);

  MyPost withDraft(PostDraft draft) => MyPost(
    id: id,
    title: draft.title,
    skill: draft.skill,
    desc: draft.desc,
    createdAt: createdAt,
  );
}

/// A request waiting for the user's answer: either someone asking to connect,
/// or someone applying to one of the user's collab posts.
class ConnectionRequest {
  const ConnectionRequest({
    required this.id,
    required this.person,
    this.postId,
    this.post,
  });

  final String id;
  final Person person;

  /// The post applied to. Null for a plain connection request.
  final String? postId;

  /// That post's title, for display.
  final String? post;

  String get personId => person.id;

  ConnectionRequest withPostTitle(String title) =>
      ConnectionRequest(id: id, person: person, postId: postId, post: title);
}

class Message {
  const Message({
    required this.me,
    required this.body,
    required this.sentAt,
    this.id,
  });

  final bool me;
  final String body;
  final DateTime sentAt;

  /// The backend's id. Null for a message shown before it has been saved.
  final String? id;
}

/// One screenful of a chat's history, oldest first.
class MessagePage {
  const MessagePage({required this.messages, required this.hasOlder});

  final List<Message> messages;

  /// Whether earlier messages exist beyond this page.
  final bool hasOlder;
}

class Chat {
  Chat({
    required this.id,
    required this.person,
    required this.lastActivity,
    required this.unread,
    required List<Message> messages,
    this.historyLoaded = false,
    this.hasOlder = false,
  }) : messages = List.of(messages);

  final String id;
  final Person person;
  DateTime lastActivity;
  bool unread;

  /// The chat list only carries each chat's latest message. Once the chat
  /// has been opened, [historyLoaded] is true and this holds the pages
  /// loaded so far, oldest first.
  final List<Message> messages;
  bool historyLoaded;

  /// Whether messages earlier than the loaded ones exist.
  bool hasOlder;

  String get personId => person.id;

  String get time => chatTimeLabel(lastActivity);

  Chat copy() => Chat(
    id: id,
    person: person,
    lastActivity: lastActivity,
    unread: unread,
    messages: messages,
    historyLoaded: historyLoaded,
    hasOlder: hasOlder,
  );

  /// This chat as the chat list sees it: just the latest message.
  Chat preview() => Chat(
    id: id,
    person: person,
    lastActivity: lastActivity,
    unread: unread,
    messages: [?messages.lastOrNull],
  );
}
