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
  });

  final String id;
  final String name;
  final String creative;
  final String city;
  final List<String> genres;
  final String bio;
  final int hue;
  final int connections;

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

enum CollabMedia { audio, clip }

class Collab {
  const Collab({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.skill,
    required this.desc,
    required this.media,
    required this.time,
    this.applied = false,
  });

  final String id;
  final String ownerId;
  final String title;
  final String skill;
  final String desc;
  final CollabMedia media;
  final String time;
  final bool applied;

  Collab markApplied() => Collab(
    id: id,
    ownerId: ownerId,
    title: title,
    skill: skill,
    desc: desc,
    media: media,
    time: time,
    applied: true,
  );
}

class MyPost {
  const MyPost({
    required this.id,
    required this.title,
    required this.skill,
    required this.time,
    this.desc = '',
  });

  final String id;
  final String title;
  final String skill;
  final String time;
  final String desc;
}

class ConnectionRequest {
  const ConnectionRequest({
    required this.id,
    required this.personId,
    this.post,
  });

  final String id;
  final String personId;

  /// The title of the post applied to. Null for a plain connection request.
  final String? post;
}

class Message {
  const Message({required this.me, required this.body});

  final bool me;
  final String body;
}

class Chat {
  Chat({
    required this.id,
    required this.personId,
    required this.time,
    required this.unread,
    required List<Message> messages,
  }) : messages = List.of(messages);

  final String id;
  final String personId;
  String time;
  bool unread;

  /// Always a growable copy, since seed data passes const lists.
  final List<Message> messages;
}
