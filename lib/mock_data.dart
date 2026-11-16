import 'models.dart';

/// Sample content from the design. It feeds the in-memory backend in
/// `data/fake_backend.dart`; the app itself never reads it directly, apart
/// from the [creatives] list of crafts.
const creatives = [
  '3D Artist',
  'Bassist',
  'Content Creator',
  'Dancer',
  'DJ',
  'Drummer',
  'Filmmaker',
  'Graphic Designer',
  'Guitarist',
  'Merch Designer',
  'Music Producer',
  'Photographer',
  'Pianist',
  'Poet',
  'Rapper',
  'Sound Engineer',
  'Visual Artist',
  'VJ',
  'Vocalist',
  'Writer',
];

const people = <String, Person>{
  'amara': Person(
    id: 'amara',
    name: 'Amara Okafor',
    creative: 'Vocalist',
    city: 'London',
    genres: ['Neo-soul', 'R&B', 'Jazz'],
    bio:
        'Session vocalist and songwriter. Looking for producers who like warm, live-sounding records.',
    hue: 310,
    connections: 58,
  ),
  'kenji': Person(
    id: 'kenji',
    name: 'Kenji Watanabe',
    creative: 'Music Producer',
    city: 'Manchester',
    genres: ['Lo-fi', 'House'],
    bio:
        'Beats, sampling, late-night sessions. Always down to build a track from a voice memo.',
    hue: 250,
    connections: 112,
  ),
  'lucia': Person(
    id: 'lucia',
    name: 'Lucía Romero',
    creative: 'Filmmaker',
    city: 'Bristol',
    genres: ['Music video', 'Documentary'],
    bio:
        'Directing music videos on 16mm. Looking for artists with a story worth shooting.',
    hue: 25,
    connections: 41,
  ),
  'theo': Person(
    id: 'theo',
    name: 'Theo Adeyemi',
    creative: 'Rapper',
    city: 'Birmingham',
    genres: ['UK Rap', 'Grime'],
    bio:
        'Writing my debut EP. Need a producer and a cover artist who get the vision.',
    hue: 150,
    connections: 33,
  ),
  'maya': Person(
    id: 'maya',
    name: 'Maya Lindqvist',
    creative: 'Graphic Designer',
    city: 'Leeds',
    genres: ['Album art', 'Type'],
    bio: 'Cover art, merch and identities for independent musicians.',
    hue: 70,
    connections: 87,
  ),
  'sol': Person(
    id: 'sol',
    name: 'Sol Navarro',
    creative: 'Dancer',
    city: 'Glasgow',
    genres: ['Contemporary', 'Hip-hop'],
    bio: 'Choreographer for stage and video. Open to music video collabs.',
    hue: 350,
    connections: 64,
  ),
  'ines': Person(
    id: 'ines',
    name: 'Inès Dubois',
    creative: 'Photographer',
    city: 'London',
    genres: ['Portrait', 'Live'],
    bio:
        'Live and portrait photography for musicians. Shooting on film and digital.',
    hue: 205,
    connections: 95,
  ),
  'rafa': Person(
    id: 'rafa',
    name: 'Rafa Costa',
    creative: 'Guitarist',
    city: 'Brighton',
    genres: ['Indie', 'Funk'],
    bio: 'Touring guitarist with a home studio. Quick turnaround on parts.',
    hue: 115,
    connections: 29,
  ),
};

const discoverQueue = ['amara', 'lucia', 'theo', 'sol', 'rafa'];

DateTime _ago(Duration age) => DateTime.now().subtract(age);

List<Collab> seedBrowse() => [
  Collab(
    id: 'c1',
    owner: people['theo']!,
    title: 'Producer for my debut EP',
    skill: 'Music Producer',
    desc:
        'Four tracks, dark and melodic. I have demos and lyrics ready, need someone to shape the sound and co-produce through to mix.',
    media: CollabMedia.audio,
    createdAt: _ago(const Duration(hours: 2)),
  ),
  Collab(
    id: 'c2',
    owner: people['lucia']!,
    title: 'Dancers for a 16mm music video',
    skill: 'Dancer',
    desc:
        'One-day shoot in Bristol next month. Looking for two dancers comfortable with improvised movement on location.',
    media: CollabMedia.clip,
    createdAt: _ago(const Duration(hours: 5)),
  ),
  Collab(
    id: 'c3',
    owner: people['kenji']!,
    title: 'Vocalist for a lo-fi tape',
    skill: 'Vocalist',
    desc:
        'Six-track tape, soft hooks over dusty beats. Remote is fine, credit and split on every track.',
    media: CollabMedia.audio,
    createdAt: _ago(const Duration(days: 1)),
  ),
  Collab(
    id: 'c4',
    owner: people['ines']!,
    title: 'Musicians for a portrait series',
    skill: 'Guitarist',
    desc:
        'Shooting a series on players and their instruments. Free prints and full usage for your releases.',
    media: CollabMedia.clip,
    createdAt: _ago(const Duration(days: 2)),
  ),
];

List<MyPost> seedMine() => [
  MyPost(
    id: 'm1',
    title: 'Vocalist for a summer house single',
    skill: 'Vocalist',
    createdAt: _ago(const Duration(days: 3)),
  ),
  MyPost(
    id: 'm2',
    title: 'Dancer for a music video teaser',
    skill: 'Dancer',
    createdAt: _ago(const Duration(days: 7)),
  ),
];

List<ConnectionRequest> seedConnections() => [
  ConnectionRequest(id: 'r1', person: people['kenji']!),
  ConnectionRequest(id: 'r2', person: people['ines']!),
];

List<ConnectionRequest> seedCollabRequests() => [
  ConnectionRequest(
    id: 'r3',
    person: people['amara']!,
    postId: 'm1',
    post: 'Vocalist for a summer house single',
  ),
  ConnectionRequest(
    id: 'r4',
    person: people['sol']!,
    postId: 'm2',
    post: 'Dancer for a music video teaser',
  ),
];

List<Chat> seedChats() => [
  Chat(
    id: 'h1',
    person: people['maya']!,
    lastActivity: _ago(const Duration(minutes: 40)),
    unread: true,
    messages: [
      Message(
        me: false,
        body: 'Hey! Loved the clip.',
        sentAt: _ago(const Duration(minutes: 55)),
      ),
      Message(
        me: true,
        body: 'Thank you! Your cover work is great.',
        sentAt: _ago(const Duration(minutes: 48)),
      ),
      Message(
        me: false,
        body: 'Want me to mock up a cover for the single?',
        sentAt: _ago(const Duration(minutes: 40)),
      ),
    ],
  ),
  Chat(
    id: 'h2',
    person: people['rafa']!,
    lastActivity: _ago(const Duration(days: 2)),
    unread: false,
    messages: [
      Message(
        me: true,
        body: 'Can you lay down a guitar part this week?',
        sentAt: _ago(const Duration(days: 2, hours: 1)),
      ),
      Message(
        me: false,
        body: 'Send the stems over, will do it Thursday.',
        sentAt: _ago(const Duration(days: 2)),
      ),
    ],
  ),
];
