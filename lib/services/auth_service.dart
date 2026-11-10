import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_config.dart';
import '../core/constants.dart';
import '../models/user_model.dart';
import 'api_client.dart';

/// What the app needs from a Google account to talk to the backend.
class GoogleCredential {
  final String idToken;
  final String? displayName;

  const GoogleCredential({required this.idToken, this.displayName});
}

/// Auth endpoints plus the saved session (token and cached profile).
class AuthService {
  AuthService(this._api);

  final ApiClient _api;
  Future<void>? _googleReady;

  // ── Saved session ───────────────────────────────────────────────────────────
  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppStrings.prefAuthToken);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppStrings.prefAuthToken, token);
  }

  /// Profile cached from the last successful sign-in, so the app can open
  /// while offline.
  Future<UserModel?> readCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppStrings.prefAuthUser);
    if (raw == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppStrings.prefAuthUser, jsonEncode(user.toJson()));
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppStrings.prefAuthToken);
    await prefs.remove(AppStrings.prefAuthUser);
  }

  // ── Availability checks (Register / Complete Profile) ───────────────────────
  Future<bool> isEmailAvailable(String email) async {
    final json = await _api.get(
      '/auth/check-email',
      query: {'email': email.trim()},
    );
    return (json as Map<String, dynamic>)['available'] as bool;
  }

  Future<bool> isUsernameAvailable(String username) async {
    final json = await _api.get(
      '/auth/check-username',
      query: {'username': username.trim().toLowerCase()},
    );
    return (json as Map<String, dynamic>)['available'] as bool;
  }

  // ── Email / password ────────────────────────────────────────────────────────
  Future<String> login(String email, String password) async {
    final json = await _api.post(
      '/auth/login',
      auth: false,
      body: {'email': email.trim(), 'password': password},
    );
    return _tokenFrom(json);
  }

  Future<String> register({
    required String email,
    required String password,
    required String fullName,
    required String username,
    required int age,
    required UserType userType,
    String? organization,
  }) async {
    final json = await _api.post(
      '/auth/register',
      auth: false,
      body: {
        'email': email.trim(),
        'password': password,
        'fullname': fullName.trim(),
        'username': username.trim().toLowerCase(),
        'age': age,
        'user_type': userType.name,
        'organization': organization?.trim(),
      },
    );
    return _tokenFrom(json);
  }

  Future<void> forgotPassword(String email) async {
    await _api.post(
      '/auth/forgot-password',
      auth: false,
      body: {'email': email.trim()},
    );
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _api.post(
      '/auth/reset-password',
      auth: false,
      body: {
        'email': email.trim(),
        'code': code.trim(),
        'new_password': newPassword,
      },
    );
  }

  // ── Google ──────────────────────────────────────────────────────────────────
  /// Shows the Google account picker. Returns null if the user dismissed it.
  Future<GoogleCredential?> pickGoogleAccount() async {
    final google = GoogleSignIn.instance;
    if (!google.supportsAuthenticate()) {
      throw Exception('Google Sign-In is not available on this platform.');
    }
    if (AppConfig.googleServerClientId.isEmpty) {
      throw Exception(
        'Google Sign-In is not configured. Set GOOGLE_SERVER_CLIENT_ID in .env.',
      );
    }
    _googleReady ??= google.initialize(
      serverClientId: AppConfig.googleServerClientId,
    );
    await _googleReady;

    try {
      // Always show the picker so a previously used account isn't reused silently.
      await google.signOut();
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw Exception(
          'Google did not return an ID token. Check GOOGLE_SERVER_CLIENT_ID and '
          'that this app\'s SHA-1 is registered for the OAuth client.',
        );
      }
      return GoogleCredential(
        idToken: idToken,
        displayName: account.displayName,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      throw Exception('Google Sign-In failed: ${e.description ?? e.code.name}');
    }
  }

  /// Signs in an existing Google user. Throws [ApiException] with code
  /// `user_not_found` for a new user, who must finish [googleRegister].
  Future<String> googleLogin(String idToken) async {
    final json = await _api.post(
      '/auth/google',
      auth: false,
      body: {'id_token': idToken},
    );
    return _tokenFrom(json);
  }

  Future<String> googleRegister({
    required String idToken,
    required String fullName,
    required String username,
    required int age,
    required UserType userType,
    String? organization,
  }) async {
    final json = await _api.post(
      '/auth/google/register',
      auth: false,
      body: {
        'id_token': idToken,
        'fullname': fullName.trim(),
        'username': username.trim().toLowerCase(),
        'age': age,
        'user_type': userType.name,
        'organization': organization?.trim(),
      },
    );
    return _tokenFrom(json);
  }

  Future<void> signOutGoogle() async {
    try {
      if (_googleReady != null) await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Nothing to sign out of.
    }
  }

  // ── Profile ─────────────────────────────────────────────────────────────────
  Future<UserModel> me() async {
    final json = await _api.get('/auth/me');
    return UserModel.fromJson(json as Map<String, dynamic>);
  }

  String _tokenFrom(dynamic json) =>
      (json as Map<String, dynamic>)['access_token'] as String;
}
