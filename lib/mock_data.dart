import 'models.dart';

/// Sample content from the design. There is no backend yet, so this is what
/// the app shows; replace it with real API data when one exists.
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

const seedBrowse = [
  Collab(
    id: 'c1',
    ownerId: 'theo',
    title: 'Producer for my debut EP',
    skill: 'Music Producer',
    desc:
        'Four tracks, dark and melodic. I have demos and lyrics ready, need someone to shape the sound and co-produce through to mix.',
    media: CollabMedia.audio,
    time: '2h',
  ),
  Collab(
    id: 'c2',
    ownerId: 'lucia',
    title: 'Dancers for a 16mm music video',
    skill: 'Dancer',
    desc:
        'One-day shoot in Bristol next month. Looking for two dancers comfortable with improvised movement on location.',
    media: CollabMedia.clip,
    time: '5h',
  ),
  Collab(
    id: 'c3',
    ownerId: 'kenji',
    title: 'Vocalist for a lo-fi tape',
    skill: 'Vocalist',
    desc:
        'Six-track tape, soft hooks over dusty beats. Remote is fine, credit and split on every track.',
    media: CollabMedia.audio,
    time: '1d',
  ),
  Collab(
    id: 'c4',
    ownerId: 'ines',
    title: 'Musicians for a portrait series',
    skill: 'Guitarist',
    desc:
        'Shooting a series on players and their instruments. Free prints and full usage for your releases.',
    media: CollabMedia.clip,
    time: '2d',
  ),
];

const seedMine = [
  MyPost(
    id: 'm1',
    title: 'Vocalist for a summer house single',
    skill: 'Vocalist',
    time: '3d',
  ),
  MyPost(
    id: 'm2',
    title: 'Dancer for a music video teaser',
    skill: 'Dancer',
    time: '1w',
  ),
];

const seedConnections = [
  ConnectionRequest(id: 'r1', personId: 'kenji'),
  ConnectionRequest(id: 'r2', personId: 'ines'),
];

const seedCollabRequests = [
  ConnectionRequest(
    id: 'r3',
    personId: 'amara',
    post: 'Vocalist for a summer house single',
  ),
  ConnectionRequest(
    id: 'r4',
    personId: 'sol',
    post: 'Dancer for a music video teaser',
  ),
];

List<Chat> seedChats() => [
  Chat(
    id: 'h1',
    personId: 'maya',
    time: '10:24',
    unread: true,
    messages: const [
      Message(me: false, body: 'Hey! Loved the clip.'),
      Message(me: true, body: 'Thank you! Your cover work is great.'),
      Message(me: false, body: 'Want me to mock up a cover for the single?'),
    ],
  ),
  Chat(
    id: 'h2',
    personId: 'rafa',
    time: 'Mon',
    unread: false,
    messages: const [
      Message(me: true, body: 'Can you lay down a guitar part this week?'),
      Message(me: false, body: 'Send the stems over, will do it Thursday.'),
    ],
  ),
];
