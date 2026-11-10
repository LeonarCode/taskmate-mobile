import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';

/// An error returned by the backend, or [isNetwork] when it could not be
/// reached. The backend sends `{"detail": ..., "code": ...}`; [code] is a
/// stable machine-readable value such as `invalid_credentials`.
class ApiException implements Exception {
  /// HTTP status, or 0 when there was no response at all.
  final int status;
  final String code;
  final String message;

  const ApiException(this.status, this.code, this.message);

  bool get isNetwork => status == 0;
  bool get isUnauthorized => status == 401;
  bool get isNotFound => status == 404;

  @override
  String toString() => message;
}

const _friendlyByCode = <String, String>{
  'invalid_credentials': 'Incorrect email or password.',
  'email_taken': 'An account with this email already exists.',
  'username_taken': 'Username is already taken.',
  'invalid_code': 'That code is invalid or has expired.',
  'user_not_found': 'No account found.',
  'unauthorized': 'Please sign in again.',
  'forbidden': "You don't have permission to do that.",
  'not_found': 'Not found.',
  'bad_request': 'That request was not valid.',
};

class ApiClient {
  ApiClient({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;

  /// Bearer token of the signed-in user.
  String? token;

  /// Called when the backend rejects the saved token (expired or invalid).
  void Function()? onSessionExpired;

  static const _timeout = Duration(seconds: 20);
  static const _uploadTimeout = Duration(seconds: 60);

  /// Headers for requests the app makes itself (e.g. `Image.network`).
  Map<String, String> get authHeaders => {
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Uri uri(String path, [Map<String, Object?>? query]) {
    final base = Uri.parse(AppConfig.apiBaseUrl);
    final params = <String, String>{
      for (final e in (query ?? const <String, Object?>{}).entries)
        if (e.value != null) e.key: '${e.value}',
    };
    return base.replace(
      path: '${base.path}$path',
      queryParameters: params.isEmpty ? null : params,
    );
  }

  Future<dynamic> get(String path, {Map<String, Object?>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body, bool auth = true}) =>
      _send('POST', path, body: body, auth: auth);

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// Uploads a file as `multipart/form-data` (the backend reads the field
  /// named [field]). Slower than a JSON call, so it gets a longer timeout.
  Future<dynamic> putFile(
    String path, {
    required String field,
    required List<int> bytes,
    required String filename,
  }) {
    final request = http.MultipartRequest('PUT', uri(path))
      ..files.add(
        http.MultipartFile.fromBytes(field, bytes, filename: filename),
      );
    return _execute(request, timeout: _uploadTimeout);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    bool auth = true,
  }) {
    final request = http.Request(method, uri(path, query));
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    return _execute(request, auth: auth);
  }

  Future<dynamic> _execute(
    http.BaseRequest request, {
    bool auth = true,
    Duration timeout = _timeout,
  }) async {
    request.headers['Accept'] = 'application/json';
    if (auth && token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(request).timeout(timeout),
      );
    } catch (_) {
      throw const ApiException(
        0,
        'network',
        'Cannot reach the server. Check your connection and try again.',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.bodyBytes.isEmpty) return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    }

    final error = _errorFrom(response);
    // A rejected token on a request that carried one means the session is over.
    if (error.isUnauthorized && auth && token != null) {
      onSessionExpired?.call();
    }
    throw error;
  }

  ApiException _errorFrom(http.Response response) {
    var code = 'error';
    String? detail;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) {
        code = decoded['code'] as String? ?? code;
        final d = decoded['detail'];
        if (d is String) {
          detail = d;
        } else if (d is List && d.isNotEmpty && d.first is Map) {
          detail = _validationMessage(d.first as Map);
          code = 'validation_error';
        }
      }
    } catch (_) {
      // Non-JSON error body; fall through to the generic message.
    }
    final message = (detail == null || detail == code)
        ? (_friendlyByCode[code] ??
              detail ??
              'Something went wrong (${response.statusCode}).')
        : detail;
    return ApiException(response.statusCode, code, message);
  }

  /// Turns a FastAPI validation entry into "field: message".
  String _validationMessage(Map entry) {
    final loc = entry['loc'];
    final field = loc is List && loc.isNotEmpty && loc.last is String
        ? loc.last as String
        : null;
    final msg = ('${entry['msg'] ?? 'Invalid value'}').replaceFirst(
      'Value error, ',
      '',
    );
    return field == null ? msg : '$field: $msg';
  }

  void close() => _http.close();
}
