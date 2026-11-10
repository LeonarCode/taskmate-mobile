import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/user_model.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/realtime_service.dart';
import '../services/reminder_service.dart';

enum AuthStatus { loading, authenticated, unauthenticated, profileIncomplete }

/// A sign-up that passed the first step and waits for the profile details
/// ("Complete Profile"). Nothing is created on the backend until then.
class PendingSignup {
  final String? email;
  final String? password;
  final String? googleIdToken;
  final String? suggestedName;

  const PendingSignup.email({
    required String this.email,
    required String this.password,
  }) : googleIdToken = null,
       suggestedName = null;

  const PendingSignup.google({
    required String this.googleIdToken,
    this.suggestedName,
  }) : email = null,
       password = null;

  bool get isGoogle => googleIdToken != null;
}

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._auth, this._api, this._realtime, this._reminders) {
    _api.onSessionExpired = _handleSessionExpired;
    _boot();
  }

  final AuthService _auth;
  final ApiClient _api;
  final RealtimeService _realtime;
  final ReminderService _reminders;

  AuthStatus _status = AuthStatus.loading;
  UserModel? _userModel;
  PendingSignup? _pending;
  String? _error;
  bool _busy = false;

  AuthStatus get status => _status;
  UserModel? get userModel => _userModel;
  PendingSignup? get pendingSignup => _pending;
  String? get error => _error;

  /// A request is running (shown as an overlay; the screen stays put).
  bool get isLoading => _busy;

  // ── Startup ──────────────────────────────────────────────────────────────────
  Future<void> _boot() async {
    final token = await _auth.readToken();
    if (token == null) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    _api.token = token;
    try {
      await _enterSession(token, await _auth.me());
    } on ApiException catch (e) {
      if (e.isNetwork) {
        // Offline: open with the profile from the last session.
        final cached = await _auth.readCachedUser();
        if (cached != null) {
          await _enterSession(token, cached);
          return;
        }
      }
      await _leaveSession();
      if (e.isNetwork) _error = e.message;
      notifyListeners();
    } catch (_) {
      // Unreadable response: start from the sign-in screen rather than hang.
      await _leaveSession();
      notifyListeners();
    }
  }

  // ── Sign in / sign up ────────────────────────────────────────────────────────
  Future<void> signInWithEmail(String email, String password) => _run(() async {
    final token = await _auth.login(email, password);
    await _finishSignIn(token);
  });

  /// First step of registering with email: checks the email is free, then asks
  /// for the profile details.
  Future<void> startEmailSignup(String email, String password) =>
      _run(() async {
        if (!await _auth.isEmailAvailable(email)) {
          throw const ApiException(
            409,
            'email_taken',
            'An account with this email already exists.',
          );
        }
        _pending = PendingSignup.email(email: email.trim(), password: password);
        _status = AuthStatus.profileIncomplete;
      });

  Future<void> signInWithGoogle() => _run(() async {
    final credential = await _auth.pickGoogleAccount();
    if (credential == null) return; // dismissed the picker
    try {
      await _finishSignIn(await _auth.googleLogin(credential.idToken));
    } on ApiException catch (e) {
      if (e.code != 'user_not_found') rethrow;
      // New Google user: collect the profile details first.
      _pending = PendingSignup.google(
        googleIdToken: credential.idToken,
        suggestedName: credential.displayName,
      );
      _status = AuthStatus.profileIncomplete;
    }
  });

  /// Final step of signing up (email or Google).
  Future<void> completeProfile({
    required String fullName,
    required String username,
    required int age,
    required UserType userType,
    String? organization,
  }) => _run(() async {
    final pending = _pending;
    if (pending == null) return;
    final String token;
    if (pending.isGoogle) {
      token = await _auth.googleRegister(
        idToken: pending.googleIdToken!,
        fullName: fullName,
        username: username,
        age: age,
        userType: userType,
        organization: organization,
      );
    } else {
      token = await _auth.register(
        email: pending.email!,
        password: pending.password!,
        fullName: fullName,
        username: username,
        age: age,
        userType: userType,
        organization: organization,
      );
    }
    await _finishSignIn(token);
  });

  /// Back from "Complete Profile" to the sign-in screen.
  void cancelSignup() {
    _pending = null;
    _error = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> isUsernameAvailable(String username) =>
      _auth.isUsernameAvailable(username);

  Future<void> sendPasswordResetCode(String email) =>
      _auth.forgotPassword(email);

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) => _auth.resetPassword(email: email, code: code, newPassword: newPassword);

  // ── Session ──────────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _leaveSession();
    notifyListeners();
  }

  /// Reloads the profile from the backend.
  Future<void> refreshUser() async {
    if (_userModel == null) return;
    try {
      await updateUser(await _auth.me());
    } on ApiException {
      // Keep showing what we have.
    }
  }

  /// Replaces the profile after the user edited it.
  Future<void> updateUser(UserModel user) async {
    _userModel = user;
    await _auth.cacheUser(user);
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  // ── Internals ────────────────────────────────────────────────────────────────
  Future<void> _finishSignIn(String token) async {
    await _auth.saveToken(token);
    _api.token = token;
    await _enterSession(token, await _auth.me());
  }

  Future<void> _enterSession(String token, UserModel user) async {
    _api.token = token;
    _userModel = user;
    _pending = null;
    _error = null;
    _status = AuthStatus.authenticated;
    await _auth.cacheUser(user);
    _realtime.connect(token);
    await _reminders.requestPermission();
    notifyListeners();
  }

  Future<void> _leaveSession() async {
    _realtime.disconnect();
    await _reminders.cancelAll();
    await _auth.signOutGoogle();
    await _auth.clearSession();
    _api.token = null;
    _userModel = null;
    _pending = null;
    _status = AuthStatus.unauthenticated;
  }

  void _handleSessionExpired() {
    if (_status != AuthStatus.authenticated) return;
    _leaveSession().then((_) {
      _error = 'Your session expired. Please sign in again.';
      notifyListeners();
    });
  }

  /// Runs [action] with the busy overlay and turns failures into [error].
  Future<void> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
