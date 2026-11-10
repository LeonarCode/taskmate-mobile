import 'dart:async';
import 'package:flutter/foundation.dart';

/// For providers that hold data of the signed-in user. They live for the whole
/// app, so they are told (through a `ChangeNotifierProxyProvider` on
/// `AuthProvider`) when the user changes: the old user's data is dropped and,
/// for a new user, loading starts.
mixin SessionBound on ChangeNotifier {
  int? _sessionUserId;
  bool _disposed = false;

  int? get sessionUserId => _sessionUserId;
  bool get isDisposed => _disposed;

  /// Safe to call on every auth change; only acts when the user id changes.
  void bindUser(int? userId) {
    if (userId == _sessionUserId) return;
    _sessionUserId = userId;
    // Runs while a widget tree is building, so it must not notify listeners.
    onSessionReset();
    if (userId != null) {
      scheduleMicrotask(() {
        if (!_disposed && _sessionUserId == userId) onSessionStart();
      });
    }
  }

  /// Drop everything that belongs to the previous user. Must not notify.
  @protected
  void onSessionReset();

  /// A user just signed in: load their data.
  @protected
  FutureOr<void> onSessionStart();

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
