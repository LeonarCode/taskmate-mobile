import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskmate_ui/models/task_model.dart';
import 'package:taskmate_ui/providers/task_provider.dart';
import 'package:taskmate_ui/services/api_client.dart';
import 'package:taskmate_ui/services/local_task_store.dart';
import 'package:taskmate_ui/services/reminder_service.dart';
import 'package:taskmate_ui/services/task_service.dart';

/// A tiny in-memory stand-in for the backend's `/task` endpoints.
class FakeBackend {
  final Map<String, Map<String, dynamic>> tasks = {};
  bool offline = false;

  /// A PUT with this title is answered with a validation error.
  String? rejectTitle;
  int requests = 0;
  int _nextId = 1;

  Future<http.Response> handle(http.Request request) async {
    requests++;
    if (offline) throw http.ClientException('offline');

    final path = request.url.path;
    if (request.method == 'GET' && path == '/task') {
      return _json(200, tasks.values.toList());
    }
    if (path.startsWith('/task/')) {
      final clientId = path.substring('/task/'.length);
      if (request.method == 'PUT') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['title'] == rejectTitle) {
          return _json(422, {
            'detail': [
              {
                'loc': ['body', 'title'],
                'msg': 'rejected',
              },
            ],
          });
        }
        final id = tasks[clientId]?['id'] ?? _nextId++;
        tasks[clientId] = {
          ...body,
          'id': id,
          'uid': 7,
          'client_id': clientId,
          'created_at': '2026-10-01T00:00:00Z',
          'updated_at': '2026-10-01T00:00:00Z',
        };
        return _json(200, tasks[clientId]);
      }
      if (request.method == 'DELETE') {
        tasks.remove(clientId);
        return http.Response('', 204);
      }
    }
    return http.Response('not found', 404);
  }

  http.Response _json(int status, Object? body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  late FakeBackend backend;
  late TaskProvider provider;

  TaskProvider makeProvider() {
    final api = ApiClient(client: MockClient(backend.handle))..token = 't';
    return TaskProvider(
      TaskService(api),
      LocalTaskStore(),
      ReminderService(), // never initialised, so reminders are no-ops
    );
  }

  /// Waits for loading and any running or queued sync to finish.
  Future<void> settle() async {
    for (var i = 0; i < 500; i++) {
      await Future<void>.delayed(Duration.zero);
      if (!provider.isLoading && !provider.isSyncing) return;
    }
    fail('provider never settled');
  }

  Future<void> signIn([int userId = 7]) async {
    provider.bindUser(userId);
    await settle();
  }

  final deadline = DateTime.utc(2030, 1, 1, 9);

  setUpAll(() {
    dotenv.loadFromString(envString: 'API_BASE_URL=http://api.test:8000');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    backend = FakeBackend();
    provider = makeProvider();
  });

  tearDown(() => provider.dispose());

  test('a task added online reaches the backend', () async {
    await signIn();
    await provider.addTask(title: 'Write tests', deadline: deadline);
    await settle();

    expect(provider.tasks.single.title, 'Write tests');
    expect(provider.tasks.single.isSynced, isTrue);
    expect(provider.tasks.single.remoteId, isNotNull);
    expect(backend.tasks.length, 1);
    final stored = backend.tasks.values.single;
    expect(stored['title'], 'Write tests');
    expect(stored['deadline'], '2030-01-01T09:00:00.000Z');
    expect(stored['priority'], 'medium');
  });

  test('a task added offline is kept and pushed when back online', () async {
    backend.offline = true;
    await signIn();
    await provider.addTask(title: 'Offline task', deadline: deadline);
    await settle();

    expect(provider.tasks.single.isSynced, isFalse);
    expect(backend.tasks, isEmpty);

    backend.offline = false;
    await provider.sync();
    await settle();

    expect(provider.tasks.single.isSynced, isTrue);
    expect(backend.tasks.length, 1);
  });

  test('tasks survive a restart', () async {
    backend.offline = true;
    await signIn();
    await provider.addTask(title: 'Remember me', deadline: deadline);
    await settle();
    provider.dispose();

    provider = makeProvider();
    await signIn();

    expect(provider.tasks.single.title, 'Remember me');
    expect(provider.tasks.single.isSynced, isFalse);
  });

  test('completing a task is sent with a completion time', () async {
    await signIn();
    await provider.addTask(title: 'Finish me', deadline: deadline);
    await settle();

    await provider.toggleComplete(provider.tasks.single.id);
    await settle();

    expect(provider.tasks.single.isCompleted, isTrue);
    final stored = backend.tasks.values.single;
    expect(stored['is_complete'], true);
    expect(stored['completed_at'], isNotNull);

    await provider.toggleComplete(provider.tasks.single.id);
    await settle();
    expect(backend.tasks.values.single['is_complete'], false);
    expect(backend.tasks.values.single['completed_at'], isNull);
  });

  test(
    'a task deleted offline disappears at once and is deleted later',
    () async {
      await signIn();
      await provider.addTask(title: 'Delete me', deadline: deadline);
      await settle();
      final id = provider.tasks.single.id;

      backend.offline = true;
      await provider.deleteTask(id);
      await settle();

      expect(provider.tasks, isEmpty);
      expect(backend.tasks, isNotEmpty); // not told yet

      backend.offline = false;
      await provider.sync();
      await settle();

      expect(backend.tasks, isEmpty);
      expect(provider.tasks, isEmpty);
      // Nothing is left behind in the offline copy either.
      final stored = await LocalTaskStore().load('7');
      expect(stored, isEmpty);
    },
  );

  test('changes made on another device are pulled in', () async {
    await signIn();
    await provider.addTask(title: 'Original', deadline: deadline);
    await settle();
    final id = provider.tasks.single.id;

    backend.tasks[id]!['title'] = 'Edited elsewhere';
    backend.tasks['11111111-1111-4111-8111-111111111111'] = {
      'id': 99,
      'uid': 7,
      'client_id': '11111111-1111-4111-8111-111111111111',
      'title': 'Made elsewhere',
      'description': '',
      'priority': 'low',
      'deadline': '2030-02-01T09:00:00Z',
      'has_alarm': false,
      'is_complete': false,
      'completed_at': null,
      'created_at': '2026-10-01T00:00:00Z',
      'updated_at': '2026-10-01T00:00:00Z',
    };

    await provider.sync();
    await settle();

    expect(
      provider.tasks.map((t) => t.title),
      unorderedEquals(['Edited elsewhere', 'Made elsewhere']),
    );
  });

  test('a task deleted on another device is removed here', () async {
    await signIn();
    await provider.addTask(title: 'Doomed', deadline: deadline);
    await settle();

    backend.tasks.clear();
    await provider.sync();
    await settle();

    expect(provider.tasks, isEmpty);
  });

  test('an unsynced local edit wins over the backend copy', () async {
    await signIn();
    await provider.addTask(title: 'Shared', deadline: deadline);
    await settle();
    final task = provider.tasks.single;

    backend.tasks[task.id]!['title'] = 'Backend title';
    backend.offline = true;
    await provider.updateTask(task.copyWith(title: 'My offline title'));
    await settle();
    backend.offline = false;

    await provider.sync();
    await settle();

    expect(provider.tasks.single.title, 'My offline title');
    expect(backend.tasks.values.single['title'], 'My offline title');
  });

  test('another user does not see these tasks', () async {
    await signIn(7);
    await provider.addTask(title: 'Private', deadline: deadline);
    await settle();

    provider.bindUser(null);
    expect(provider.tasks, isEmpty);

    backend.tasks.clear();
    await signIn(8);
    expect(provider.tasks, isEmpty);
  });

  test('a task the backend rejects does not block the others', () async {
    await signIn();
    backend.offline = true;
    await provider.addTask(title: 'Rejected', deadline: deadline);
    await provider.addTask(title: 'Fine', deadline: deadline);
    await settle();

    backend.offline = false;
    backend.rejectTitle = 'Rejected';
    await provider.sync();
    await settle();

    TaskModel byTitle(String title) =>
        provider.tasks.firstWhere((t) => t.title == title);
    expect(byTitle('Fine').isSynced, isTrue);
    expect(byTitle('Rejected').isSynced, isFalse); // kept for a later retry
    expect(backend.tasks.length, 1);
  });
}
