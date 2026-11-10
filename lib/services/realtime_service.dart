import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/app_config.dart';
import 'ws_connect.dart';

/// One event pushed by the backend: `{"type": ..., "data": ...}`.
/// The service also emits a synthetic [connected] event every time the socket
/// (re)opens, so listeners can reload anything they may have missed.
class RealtimeEvent {
  static const connected = 'connected';

  final String type;
  final Map<String, dynamic> data;

  const RealtimeEvent(this.type, [this.data = const {}]);
}

/// One socket per device for every kind of event (messages, group messages,
/// notifications). Reconnects automatically with backoff.
class RealtimeService {
  final _controller = StreamController<RealtimeEvent>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _pingTimer;
  Timer? _retryTimer;
  String? _token;
  bool _wantConnected = false;
  int _attempt = 0;

  Stream<RealtimeEvent> get events => _controller.stream;

  void connect(String token) {
    _token = token;
    _wantConnected = true;
    _attempt = 0;
    _open();
  }

  void disconnect() {
    _wantConnected = false;
    _token = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _close();
  }

  void dispose() {
    disconnect();
    _controller.close();
  }

  void _open() {
    final token = _token;
    if (!_wantConnected || token == null) return;
    _close();

    final WebSocketChannel channel;
    try {
      channel = connectWebSocket(AppConfig.webSocketUri, token);
    } catch (_) {
      _scheduleRetry();
      return;
    }
    _channel = channel;
    _subscription = channel.stream.listen(
      _onMessage,
      onError: (_) => _onClosed(channel),
      onDone: () => _onClosed(channel),
    );
    channel.ready.then((_) {
      if (_channel != channel) return;
      _attempt = 0;
      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        try {
          channel.sink.add('ping');
        } catch (_) {}
      });
      _emit(const RealtimeEvent(RealtimeEvent.connected));
    }, onError: (_) => _onClosed(channel));
  }

  void _onMessage(dynamic raw) {
    if (raw is! String || raw == 'pong') return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> && decoded['type'] is String) {
        final data = decoded['data'];
        _emit(
          RealtimeEvent(
            decoded['type'] as String,
            data is Map<String, dynamic> ? data : const {},
          ),
        );
      }
    } catch (e) {
      debugPrint('Ignoring malformed realtime message: $e');
    }
  }

  void _onClosed(WebSocketChannel channel) {
    if (_channel != channel) return; // an older socket; already replaced
    // 1008 = the backend refused the token. The REST layer handles an expired
    // session, so retrying here would only spam the server.
    final rejected = channel.closeCode == 1008;
    _close();
    if (!rejected) _scheduleRetry();
  }

  void _scheduleRetry() {
    if (!_wantConnected || _retryTimer != null) return;
    final seconds = min(30, 1 << min(_attempt, 5));
    _attempt++;
    _retryTimer = Timer(Duration(seconds: seconds), () {
      _retryTimer = null;
      _open();
    });
  }

  void _close() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _subscription?.cancel();
    _subscription = null;
    final channel = _channel;
    _channel = null;
    try {
      channel?.sink.close();
    } catch (_) {}
  }

  void _emit(RealtimeEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }
}
