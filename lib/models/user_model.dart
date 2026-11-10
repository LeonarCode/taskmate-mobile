import '../core/constants.dart';
import '../core/format.dart';

UserType _userTypeFrom(Object? value) =>
    value == 'employee' ? UserType.employee : UserType.student;

double _doubleFrom(Object? value) => (value as num?)?.toDouble() ?? 0.0;

/// The signed-in user (`GET /auth/me`, `PATCH /users/me`, ...).
class UserModel {
  final int id;
  final String email;
  final String fullName;
  final String username;
  final int age;
  final UserType userType;

  /// Base64 data URL or https URL. Only the signed-in user's own profile has it.
  final String? photoUrl;
  final String? organization;
  final double averageRating;
  final int ratingCount;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.username,
    required this.age,
    required this.userType,
    this.photoUrl,
    this.organization,
    this.averageRating = 0.0,
    this.ratingCount = 0,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      email: json['email'] as String? ?? '',
      fullName: json['fullname'] as String? ?? '',
      username: json['username'] as String? ?? '',
      age: json['age'] as int? ?? 0,
      userType: _userTypeFrom(json['user_type']),
      photoUrl: json['photo_url'] as String?,
      organization: json['organization'] as String?,
      averageRating: _doubleFrom(json['average_rating']),
      ratingCount: json['rating_count'] as int? ?? 0,
      createdAt: parseServerTimeOrNull(json['created_at']) ?? DateTime.now(),
    );
  }

  /// Written to the local cache so the app can open offline.
  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'fullname': fullName,
    'username': username,
    'age': age,
    'user_type': userType.name,
    'photo_url': photoUrl,
    'organization': organization,
    'average_rating': averageRating,
    'rating_count': ratingCount,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  UserPublic get asPublic => UserPublic(
    id: id,
    username: username,
    fullName: fullName,
    hasPhoto: photoUrl != null,
    averageRating: averageRating,
    ratingCount: ratingCount,
  );
}

/// Another user as seen in chats, members and search results. The backend
/// leaves out private fields (email, age) and the photo itself: fetch it from
/// `GET /users/{id}/photo` when [hasPhoto] is true.
class UserPublic {
  final int id;
  final String username;
  final String fullName;
  final bool hasPhoto;
  final double averageRating;
  final int ratingCount;

  const UserPublic({
    required this.id,
    required this.username,
    required this.fullName,
    this.hasPhoto = false,
    this.averageRating = 0.0,
    this.ratingCount = 0,
  });

  factory UserPublic.fromJson(Map<String, dynamic> json) {
    return UserPublic(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      fullName: json['fullname'] as String? ?? '',
      hasPhoto: json['has_photo'] as bool? ?? false,
      averageRating: _doubleFrom(json['average_rating']),
      ratingCount: json['rating_count'] as int? ?? 0,
    );
  }
}
