import 'dart:typed_data';
import '../core/constants.dart';
import '../models/user_model.dart';
import 'api_client.dart';

class UserService {
  UserService(this._api);

  final ApiClient _api;

  /// Finds users by username (prefix match, "@" allowed). Excludes yourself.
  Future<List<UserPublic>> search(String query) async {
    final json = await _api.get('/users/search', query: {'q': query.trim()});
    return (json as List)
        .map((e) => UserPublic.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Only the fields you pass are changed. [organization] is the one field
  /// that can be cleared: pass an empty string to remove it.
  Future<UserModel> updateProfile({
    String? fullName,
    int? age,
    UserType? userType,
    String? organization,
  }) async {
    final json = await _api.patch(
      '/users/me',
      body: {
        'fullname': ?fullName,
        'age': ?age,
        'user_type': ?userType?.name,
        'organization': ?organization,
      },
    );
    return UserModel.fromJson(json as Map<String, dynamic>);
  }

  /// Uploads a new profile picture (jpeg, png, webp or gif, up to 5 MB) as a
  /// file. The backend keeps it on Cloudinary and the returned profile has the
  /// https URL as `photoUrl`. See `compressPhoto` for preparing [bytes].
  Future<UserModel> uploadPhoto(Uint8List bytes) async {
    final json = await _api.putFile(
      '/users/me/photo',
      field: 'file',
      bytes: bytes,
      filename: 'avatar.jpg',
    );
    return UserModel.fromJson(json as Map<String, dynamic>);
  }
}
