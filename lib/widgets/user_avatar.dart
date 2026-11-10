import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/format.dart';
import '../core/image_utils.dart';
import '../core/theme.dart';
import '../models/user_model.dart';
import '../services/api_client.dart';

/// Round profile picture with the person's initial as a placeholder.
///
/// The signed-in user's own photo arrives with the profile ([photoUrl]);
/// everybody else's is fetched from `GET /users/{id}/photo`, which needs the
/// auth header, when [hasPhoto] is true.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.userId,
    this.hasPhoto = false,
    this.photoUrl,
    this.radius = 20,
    this.backgroundColor,
    this.textColor,
  });

  UserAvatar.me(UserModel user, {super.key, this.radius = 20})
    : name = user.fullName,
      userId = user.id,
      hasPhoto = user.photoUrl != null,
      photoUrl = user.photoUrl,
      backgroundColor = null,
      textColor = null;

  UserAvatar.of(UserPublic user, {super.key, this.radius = 20})
    : name = user.fullName,
      userId = user.id,
      hasPhoto = user.hasPhoto,
      photoUrl = null,
      backgroundColor = null,
      textColor = null;

  final String name;
  final int? userId;
  final bool hasPhoto;
  final String? photoUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    ImageProvider? image;
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      image = resolvePhoto(photoUrl);
    } else if (hasPhoto && userId != null) {
      final api = context.read<ApiClient>();
      image = NetworkImage(
        api.uri('/users/$userId/photo').toString(),
        headers: api.authHeaders,
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? AppColors.purple600.withAlpha(25),
      // Drawn over the initial, which stays visible while loading or on error.
      foregroundImage: image,
      onForegroundImageError: image == null ? null : (_, _) {},
      child: Text(
        initialOf(name),
        style: TextStyle(
          color: textColor ?? AppColors.purple600,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}
