import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Values read from the bundled `.env` file (see `.env` in the project root).
class AppConfig {
  AppConfig._();

  /// Base URL of the TaskMate FastAPI backend, without a trailing slash.
  static String get apiBaseUrl {
    final configured = (dotenv.maybeGet('API_BASE_URL') ?? '').trim();
    final url = configured.isNotEmpty ? configured : _platformDefault;
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  // The Android emulator reaches the host machine through 10.0.2.2.
  static String get _platformDefault =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:8000'
      : 'http://localhost:8000';

  /// Web OAuth client ID; must match GOOGLE_CLIENT_ID on the backend.
  static String get googleServerClientId =>
      (dotenv.maybeGet('GOOGLE_SERVER_CLIENT_ID') ?? '').trim();

  /// `ws://host:port/ws` (or `wss://` when the API is served over https).
  static Uri get webSocketUri {
    final base = Uri.parse(apiBaseUrl);
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '${base.path}/ws',
    );
  }
}
