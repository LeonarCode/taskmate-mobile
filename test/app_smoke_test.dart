import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskmate_ui/main.dart';
import 'package:taskmate_ui/services/api_client.dart';
import 'package:taskmate_ui/services/realtime_service.dart';
import 'package:taskmate_ui/services/reminder_service.dart';

/// Runs the whole app against a fake backend and walks through every screen.
/// Any layout overflow or exception fails the test. Set SHOT_DIR to also save
/// a screenshot of each step.
void main() {
  final shotDir = Platform.environment['SHOT_DIR'];
  final shotKey = GlobalKey();

  setUpAll(() async {
    dotenv.loadFromString(envString: 'API_BASE_URL=http://api.test:8000');
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader('Poppins');
    for (final weight in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
    ]) {
      loader.addFont(rootBundle.load('assets/fonts/Poppins-$weight.ttf'));
    }
    await loader.load();

    // Tests don't ship the icon font; load it so screenshots show real icons.
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null) {
      final icons = File(
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      if (icons.existsSync()) {
        final bytes = icons.readAsBytesSync();
        final iconLoader = FontLoader('MaterialIcons')
          ..addFont(Future.value(ByteData.view(bytes.buffer)));
        await iconLoader.load();
      }
    }
  });

  late FakeServer server;

  Future<void> boot(
    WidgetTester tester, {
    bool signedIn = true,
    String? theme,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (signedIn) 'auth_token': 'test-token',
      'theme_mode': ?theme,
    });
    server = FakeServer();
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      RepaintBoundary(
        key: shotKey,
        child: TaskMateApp(
          reminders: ReminderService(),
          api: ApiClient(client: MockClient(server.handle)),
          realtime: _OfflineRealtime(),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> shot(WidgetTester tester, String name) async {
    if (shotDir == null) return;
    await tester.runAsync(() async {
      final boundary =
          shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$shotDir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).first);
    await settle(tester);
  }

  testWidgets('signed in: every tab and server screen renders', (tester) async {
    await boot(tester);

    // ── Tasks ──
    expect(
      find.text('Good morning,').evaluate().length +
          find.text('Good afternoon,').evaluate().length +
          find.text('Good evening,').evaluate().length,
      1,
    );
    expect(find.text('Leonard'), findsOneWidget);
    expect(find.text('Write report'), findsOneWidget);
    expect(find.text('Buy groceries'), findsOneWidget);
    await shot(tester, '01_tasks');

    // 'Done' is both a stat card and a filter chip; the chip comes last.
    await tester.tap(find.text('Done').last);
    await settle(tester);
    expect(find.text('Old finished task'), findsOneWidget);
    await shot(tester, '02_tasks_done');

    // ── Servers ──
    await tester.tap(find.text('Servers').last);
    await settle(tester);
    expect(find.text('Study Group'), findsOneWidget);
    expect(find.text('Dev Team'), findsOneWidget);
    await shot(tester, '03_servers');

    await tapText(tester, 'Discover');
    expect(find.text('Photography Club'), findsOneWidget);
    await shot(tester, '04_discover');

    // ── Chats ──
    await tester.tap(find.text('Chats').last);
    await settle(tester);
    expect(find.text('Sam Santos'), findsOneWidget);
    expect(find.text('See you tomorrow!'), findsOneWidget);
    await shot(tester, '05_chats');

    await tester.tap(find.text('Sam Santos'));
    await settle(tester);
    expect(find.text('Hey Leonard'), findsOneWidget);
    expect(find.text('Seen'), findsNothing); // the last message is Sam's
    await shot(tester, '06_chat_detail');
    expect(server.markedRead, contains(3));

    // Send a message.
    await tester.enterText(find.byType(TextField), 'On my way');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await settle(tester);
    expect(find.text('On my way'), findsOneWidget);
    expect(server.sentDirect, ['On my way']);
    await shot(tester, '07_chat_sent');
    await tester.pageBack();
    await settle(tester);

    // ── Alerts ──
    await tester.tap(find.text('Alerts').last);
    await settle(tester);
    expect(find.text('Sam joined Study Group'), findsOneWidget);
    await shot(tester, '08_alerts');

    // ── Profile ──
    await tester.tap(find.text('Profile').last);
    await settle(tester);
    expect(find.text('Leonard Balaba'), findsWidgets);
    await shot(tester, '09_profile');
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -600),
    );
    await settle(tester);
    expect(find.text('"Great teammate"'), findsOneWidget);
    await shot(tester, '10_profile_ratings');

    // ── Server detail ──
    await tester.tap(find.text('Servers').last);
    await settle(tester);
    await tapText(tester, 'My Servers'); // the tab stayed on Discover
    await tester.tap(find.text('Study Group'));
    await settle(tester);
    expect(find.text('Welcome to Study Group!'), findsOneWidget);
    await shot(tester, '11_server_overview');

    await tester.tap(find.text('Chat').last);
    await settle(tester);
    expect(find.text('Welcome everyone'), findsOneWidget);
    await shot(tester, '12_server_chat');

    await tester.tap(find.text('Tasks').last);
    await settle(tester);
    expect(find.text('Prepare slides'), findsOneWidget);
    await shot(tester, '13_server_tasks');

    await tester.tap(find.text('Members').last);
    await settle(tester);
    expect(find.text('Ana Reyes'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
    await shot(tester, '14_server_members');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('completing a task updates the backend', (tester) async {
    await boot(tester);
    await tester.longPress(find.text('Write report'));
    await settle(tester);
    await tapText(tester, 'Mark Complete');

    final put = server.taskPuts['a0000000-0000-4000-8000-000000000001'];
    expect(put, isNotNull);
    expect(put!['is_complete'], true);
    expect(put['completed_at'], isNotNull);
    expect(put['priority'], 'high');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('signed out: sign in and register screens render', (
    tester,
  ) async {
    await boot(tester, signedIn: false);
    expect(find.text('Welcome back! 👋'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    await shot(tester, '20_auth_signin');

    await tester.tap(find.text('Register').first);
    await settle(tester);
    expect(find.text("Let's get started! 🚀"), findsOneWidget);
    await shot(tester, '21_auth_register');

    await tester.enterText(find.byType(TextFormField).at(0), 'new@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.enterText(find.byType(TextFormField).at(2), 'secret123');
    await tester.tap(find.text('Create Account'));
    await settle(tester);
    expect(find.text('Complete Profile'), findsOneWidget);
    await shot(tester, '22_profile_setup');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('wrong password shows the backend message', (tester) async {
    await boot(tester, signedIn: false);
    await tester.enterText(find.byType(TextFormField).at(0), 'leo@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrongpass');
    await tester.tap(find.text('Sign In').last);
    await settle(tester);
    expect(find.text('Incorrect email or password.'), findsOneWidget);
    await shot(tester, '23_auth_error');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('dark mode', (tester) async {
    await boot(tester, theme: 'dark');
    await shot(tester, '30_dark_tasks');
    await tester.tap(find.text('Chats').last);
    await settle(tester);
    await shot(tester, '31_dark_chats');
    await tester.tap(find.text('Servers').last);
    await settle(tester);
    await tester.tap(find.text('Study Group'));
    await settle(tester);
    await tester.tap(find.text('Members').last);
    await settle(tester);
    await shot(tester, '32_dark_members');
    await tester.pumpWidget(const SizedBox());
  });
}

/// Lets the app load: pumps a few frames without waiting for animations to end
/// (progress spinners animate forever).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _OfflineRealtime extends RealtimeService {
  @override
  void connect(String token) {}

  @override
  void disconnect() {}
}

String _iso(Duration fromNow) =>
    DateTime.now().toUtc().add(fromNow).toIso8601String();

Map<String, Object?> _user(
  int id,
  String name,
  String username, {
  bool photo = false,
  double rating = 0,
  int count = 0,
}) => {
  'id': id,
  'username': username,
  'fullname': name,
  'has_photo': photo,
  'average_rating': rating,
  'rating_count': count,
};

class FakeServer {
  final markedRead = <int>[];
  final sentDirect = <String>[];
  final taskPuts = <String, Map<String, Object?>>{};
  int _nextMessageId = 1000;

  static final me = {
    'id': 7,
    'username': 'leo',
    'email': 'leo@example.com',
    'fullname': 'Leonard Balaba',
    'age': 21,
    'organization': 'Cebu Institute of Technology',
    'user_type': 'student',
    'photo_url': null,
    'average_rating': 4.5,
    'rating_count': 2,
    'created_at': '2026-09-01T00:00:00Z',
  };

  final sam = _user(3, 'Sam Santos', 'sam', rating: 4.0, count: 3);
  final ana = _user(4, 'Ana Reyes', 'ana');

  http.Response _json(int status, Object? body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Map<String, Object?> _server(
    int id,
    String name,
    String emoji,
    String color,
    int owner,
    int members, [
    String description = '',
  ]) => {
    'name': name,
    'description': description,
    'icon_color': color,
    'icon_emoji': emoji,
    'id': id,
    'owner_id': owner,
    'member_count': members,
    'created_at': '2026-09-15T00:00:00Z',
  };

  Map<String, Object?> _dm(
    int id,
    int from,
    int to,
    String text, {
    bool read = true,
    Duration ago = const Duration(minutes: 5),
  }) => {
    'content': text,
    'task_ref_id': null,
    'image_url': null,
    'message_type': 'text',
    'id': id,
    'sender_id': from,
    'receiver_id': to,
    'is_read': read,
    'edited_at': null,
    'created_at': _iso(-ago),
  };

  Map<String, Object?> _task(
    String clientId,
    String title,
    String desc,
    Duration due,
    String priority, {
    bool done = false,
    bool alarm = true,
    int id = 1,
  }) => {
    'id': id,
    'uid': 7,
    'client_id': clientId,
    'title': title,
    'description': desc,
    'priority': priority,
    'deadline': _iso(due),
    'has_alarm': alarm,
    'is_complete': done,
    'completed_at': done ? _iso(due) : null,
    'created_at': '2026-10-01T00:00:00Z',
    'updated_at': '2026-10-01T00:00:00Z',
  };

  Future<http.Response> handle(http.Request r) async {
    final path = r.url.path;
    final method = r.method;

    // ── Auth ──
    if (path == '/auth/me') return _json(200, me);
    if (path == '/auth/check-email') return _json(200, {'available': true});
    if (path == '/auth/check-username') return _json(200, {'available': true});
    if (path == '/auth/login') {
      return _json(401, {
        'detail': 'invalid_credentials',
        'code': 'invalid_credentials',
      });
    }

    // ── Tasks ──
    if (method == 'GET' && path == '/task') {
      return _json(200, [
        _task(
          'a0000000-0000-4000-8000-000000000001',
          'Write report',
          'Quarterly numbers',
          const Duration(hours: 5),
          'high',
          id: 1,
        ),
        _task(
          'a0000000-0000-4000-8000-000000000002',
          'Buy groceries',
          '',
          const Duration(days: 2),
          'low',
          id: 2,
        ),
        _task(
          'a0000000-0000-4000-8000-000000000003',
          'Submit assignment',
          'Chapter 4 problem set',
          const Duration(days: -2),
          'medium',
          id: 3,
        ),
        _task(
          'a0000000-0000-4000-8000-000000000004',
          'Old finished task',
          '',
          const Duration(days: -5),
          'medium',
          done: true,
          id: 4,
        ),
      ]);
    }
    if (method == 'PUT' && path.startsWith('/task/')) {
      final body = jsonDecode(r.body) as Map<String, Object?>;
      final id = path.substring('/task/'.length);
      taskPuts[id] = body;
      return _json(200, {
        ...body,
        'id': 50,
        'uid': 7,
        'client_id': id,
        'created_at': '2026-10-01T00:00:00Z',
        'updated_at': '2026-10-01T00:00:00Z',
      });
    }

    // ── Servers ──
    if (path == '/server' && method == 'GET') {
      return _json(200, [
        _server(
          2,
          'Study Group',
          '📚',
          '0xFFEC4899',
          7,
          3,
          'CS 101 study buddies',
        ),
        _server(5, 'Dev Team', '💻', '0xFF3B82F6', 3, 8, 'Ship it'),
      ]);
    }
    if (path == '/server/discover') {
      return _json(200, [
        _server(
          9,
          'Photography Club',
          '🎨',
          '0xFFF59E0B',
          4,
          24,
          'Weekly photo walks',
        ),
      ]);
    }
    if (path == '/server/2/members') {
      return _json(200, [
        {
          'user': _user(7, 'Leonard Balaba', 'leo', rating: 4.5, count: 2),
          'joined_at': '2026-09-15T00:00:00Z',
          'is_owner': true,
        },
        {'user': sam, 'joined_at': '2026-09-16T00:00:00Z', 'is_owner': false},
        {'user': ana, 'joined_at': '2026-09-17T00:00:00Z', 'is_owner': false},
      ]);
    }
    if (path == '/server/task/2' && method == 'GET') {
      return _json(200, [
        {
          'id': 21,
          'server_id': 2,
          'title': 'Prepare slides',
          'description': 'Intro deck',
          'priority': 'high',
          'deadline': _iso(const Duration(days: 1)),
          'has_alarm': true,
          'is_complete': false,
          'completed_at': null,
          'created_at': '2026-10-01T00:00:00Z',
          'updated_at': '2026-10-01T00:00:00Z',
        },
        {
          'id': 22,
          'server_id': 2,
          'title': 'Book the room',
          'description': '',
          'priority': 'low',
          'deadline': _iso(const Duration(days: 6)),
          'has_alarm': false,
          'is_complete': true,
          'completed_at': _iso(const Duration(days: -1)),
          'created_at': '2026-10-01T00:00:00Z',
          'updated_at': '2026-10-01T00:00:00Z',
        },
      ]);
    }
    if (path == '/server/messages/2' && method == 'GET') {
      Map<String, Object?> g(
        int id,
        Map<String, Object?> who,
        String text,
        int mins,
      ) => {
        'content': text,
        'task_ref_id': null,
        'image_url': null,
        'message_type': 'text',
        'id': id,
        'sender_id': who['id'],
        'sender': who,
        'server_id': 2,
        'edited_at': null,
        'created_at': _iso(Duration(minutes: -mins)),
      };
      return _json(200, [
        g(3, _user(7, 'Leonard Balaba', 'leo'), 'Who is bringing snacks?', 5),
        g(2, ana, 'Count me in', 20),
        g(1, sam, 'Welcome everyone', 60),
      ]);
    }
    if (path == '/ratings/given') return _json(200, []);
    if (path == '/ratings/received') {
      return _json(200, [
        {
          'id': 1,
          'score': 4.5,
          'comment': 'Great teammate',
          'created_at': '2026-10-05T00:00:00Z',
          'server': {'id': 2, 'name': 'Study Group'},
          'rater': sam,
          'rated': _user(7, 'Leonard Balaba', 'leo'),
        },
        {
          'id': 2,
          'score': 4.0,
          'comment': null,
          'created_at': '2026-10-06T00:00:00Z',
          'server': {'id': 5, 'name': 'Dev Team'},
          'rater': ana,
          'rated': _user(7, 'Leonard Balaba', 'leo'),
        },
      ]);
    }

    // ── Messages ──
    if (path == '/messages' && method == 'GET') {
      return _json(200, [
        {
          'partner': sam,
          'last_message': _dm(
            14,
            3,
            7,
            'See you tomorrow!',
            read: false,
            ago: const Duration(minutes: 3),
          ),
          'unread_count': 2,
        },
        {
          'partner': ana,
          'last_message': _dm(
            9,
            7,
            4,
            'Thanks!',
            ago: const Duration(hours: 5),
          ),
          'unread_count': 0,
        },
      ]);
    }
    if (path == '/messages/3' && method == 'GET') {
      return _json(200, [
        _dm(
          14,
          3,
          7,
          'See you tomorrow!',
          read: false,
          ago: const Duration(minutes: 3),
        ),
        _dm(13, 7, 3, 'Sure, 9am works', ago: const Duration(minutes: 10)),
        _dm(12, 3, 7, 'Hey Leonard', ago: const Duration(minutes: 30)),
      ]);
    }
    if (path == '/messages/3/read') {
      markedRead.add(3);
      return _json(200, {'marked_read': 2});
    }
    if (path == '/messages/3' && method == 'POST') {
      final text = (jsonDecode(r.body) as Map)['content'] as String;
      sentDirect.add(text);
      return _json(
        201,
        _dm(_nextMessageId++, 7, 3, text, read: false, ago: Duration.zero),
      );
    }
    if (path == '/users/search') return _json(200, [sam, ana]);

    // ── Notifications ──
    if (path == '/notifications' && method == 'GET') {
      Map<String, Object?> n(
        int id,
        String content,
        String type,
        bool read,
        Map<String, Object?>? ref,
        int mins,
      ) => {
        'id': id,
        'content': content,
        'notification_type': type,
        'is_read': read,
        'created_at': _iso(Duration(minutes: -mins)),
        'reference': ref,
      };
      return _json(200, [
        n(4, 'Sam joined Study Group', 'server_activity', false, {
          'task_id': null,
          'server_id': 2,
          'dm_id': null,
        }, 4),
        n(3, 'Sam: See you tomorrow!', 'message', false, {
          'task_id': null,
          'server_id': null,
          'dm_id': 14,
        }, 3),
        n(2, '"Submit assignment" is overdue', 'task_deadline', true, {
          'task_id': 3,
          'server_id': null,
          'dm_id': null,
        }, 600),
        n(1, 'Reminder: "Write report" is due today', 'task_reminder', true, {
          'task_id': 1,
          'server_id': null,
          'dm_id': null,
        }, 900),
      ]);
    }
    if (path == '/notifications/unread-count') {
      return _json(200, {'unread_count': 2});
    }
    if (path.startsWith('/notifications/')) {
      return _json(200, {'marked_read': 0});
    }

    if (path == '/auth/forgot-password') {
      return _json(200, {
        'message': 'If that email is registered, we sent a 6-digit code.',
      });
    }

    return http.Response('unhandled in test: $method $path', 404);
  }
}
