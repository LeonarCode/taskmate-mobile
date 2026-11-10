import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskmate_ui/services/api_client.dart';

http.Response _json(int status, Object body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'API_BASE_URL=http://api.test:8000');
  });

  test('builds URLs from API_BASE_URL and skips null query values', () {
    final api = ApiClient(client: MockClient((_) async => _json(200, {})));
    final uri = api.uri('/messages/3', {'limit': 50, 'before_id': null});
    expect(uri.toString(), 'http://api.test:8000/messages/3?limit=50');
  });

  test('sends the bearer token and a JSON body', () async {
    late http.Request seen;
    final api = ApiClient(
      client: MockClient((request) async {
        seen = request;
        return _json(200, {'ok': true});
      }),
    )..token = 'abc';

    final result = await api.post('/x', body: {'a': 1});

    expect(result, {'ok': true});
    expect(seen.headers['Authorization'], 'Bearer abc');
    expect(seen.headers['Content-Type'], contains('application/json'));
    expect(jsonDecode(seen.body), {'a': 1});
  });

  test('does not send the token when auth is off', () async {
    late http.Request seen;
    final api = ApiClient(
      client: MockClient((request) async {
        seen = request;
        return _json(200, {});
      }),
    )..token = 'abc';

    await api.post('/auth/login', auth: false, body: {});

    expect(seen.headers.containsKey('Authorization'), isFalse);
  });

  test('uploads a file as multipart/form-data', () async {
    late http.Request seen;
    final api = ApiClient(
      client: MockClient((request) async {
        seen = request;
        return _json(200, {'id': 7});
      }),
    )..token = 'abc';

    final result = await api.putFile(
      '/users/me/photo',
      field: 'file',
      bytes: [1, 2, 3],
      filename: 'avatar.jpg',
    );

    expect(result, {'id': 7});
    expect(seen.method, 'PUT');
    expect(seen.url.path, '/users/me/photo');
    expect(seen.headers['Authorization'], 'Bearer abc');
    expect(
      seen.headers['content-type'],
      startsWith('multipart/form-data; boundary='),
    );
    expect(seen.body, contains('name="file"'));
    expect(seen.body, contains('filename="avatar.jpg"'));
  });

  test(
    'shows the backend message for an oversize or unreachable upload',
    () async {
      for (final (status, code, detail) in [
        (413, 'file_too_large', 'Photo is too large (max 5 MB)'),
        (503, 'storage_unavailable', 'Image storage is unavailable, try again'),
      ]) {
        final api = ApiClient(
          client: MockClient(
            (_) async => _json(status, {'detail': detail, 'code': code}),
          ),
        );
        await expectLater(
          api.putFile(
            '/users/me/photo',
            field: 'file',
            bytes: [1],
            filename: 'a.jpg',
          ),
          throwsA(
            isA<ApiException>()
                .having((e) => e.status, 'status', status)
                .having((e) => e.code, 'code', code)
                .having((e) => e.message, 'message', detail),
          ),
        );
      }
    },
  );

  test('an empty 204 response gives null', () async {
    final api = ApiClient(
      client: MockClient((_) async => http.Response('', 204)),
    );
    expect(await api.delete('/task/x'), isNull);
  });

  test('maps the backend error code to a friendly message', () async {
    final api = ApiClient(
      client: MockClient(
        (_) async => _json(401, {
          'detail': 'invalid_credentials',
          'code': 'invalid_credentials',
        }),
      ),
    );
    await expectLater(
      api.post('/auth/login', auth: false, body: {}),
      throwsA(
        isA<ApiException>()
            .having((e) => e.status, 'status', 401)
            .having((e) => e.code, 'code', 'invalid_credentials')
            .having(
              (e) => e.message,
              'message',
              'Incorrect email or password.',
            ),
      ),
    );
  });

  test('keeps a custom detail message from the backend', () async {
    final api = ApiClient(
      client: MockClient(
        (_) async => _json(409, {
          'detail': 'Email already in use',
          'code': 'email_taken',
        }),
      ),
    );
    await expectLater(
      api.get('/x'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Email already in use',
        ),
      ),
    );
  });

  test('reads a FastAPI validation error', () async {
    final api = ApiClient(
      client: MockClient(
        (_) async => _json(422, {
          'detail': [
            {
              'loc': ['body', 'password'],
              'msg': 'String should have at least 8 characters',
              'type': 'string_too_short',
            },
          ],
        }),
      ),
    );
    await expectLater(
      api.post('/auth/register', body: {}),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'password: String should have at least 8 characters',
        ),
      ),
    );
  });

  test('an unreachable server is reported as a network error', () async {
    final api = ApiClient(
      client: MockClient((_) async => throw http.ClientException('refused')),
    );
    await expectLater(
      api.get('/x'),
      throwsA(
        isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', true),
      ),
    );
  });

  test('a 401 on a signed-in request ends the session', () async {
    var expired = 0;
    final api =
        ApiClient(
            client: MockClient(
              (_) async => _json(401, {
                'detail': 'unauthorized',
                'code': 'unauthorized',
              }),
            ),
          )
          ..token = 'old'
          ..onSessionExpired = () => expired++;

    await expectLater(api.get('/auth/me'), throwsA(isA<ApiException>()));
    expect(expired, 1);
  });

  test('a failed login is not treated as an expired session', () async {
    var expired = 0;
    final api = ApiClient(
      client: MockClient(
        (_) async => _json(401, {
          'detail': 'invalid_credentials',
          'code': 'invalid_credentials',
        }),
      ),
    )..onSessionExpired = () => expired++;

    await expectLater(
      api.post('/auth/login', auth: false, body: {}),
      throwsA(isA<ApiException>()),
    );
    expect(expired, 0);
  });
}
