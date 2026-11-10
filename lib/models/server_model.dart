import '../core/format.dart';
import 'user_model.dart';

class ServerModel {
  final int id;
  final String name;
  final String description;
  final int ownerId;
  final int iconColorValue;
  final String? iconEmoji;
  final int memberCount;
  final DateTime createdAt;

  const ServerModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.ownerId,
    this.iconColorValue = 0xFF7C3AED,
    this.iconEmoji,
    this.memberCount = 1,
    required this.createdAt,
  });

  factory ServerModel.fromJson(Map<String, dynamic> json) {
    return ServerModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      ownerId: json['owner_id'] as int? ?? 0,
      // The backend sends colors as text such as "0xFF7C3AED".
      iconColorValue: int.tryParse('${json['icon_color']}') ?? 0xFF7C3AED,
      iconEmoji: json['icon_emoji'] as String?,
      memberCount: json['member_count'] as int? ?? 1,
      createdAt: parseServerTimeOrNull(json['created_at']) ?? DateTime.now(),
    );
  }

  /// The color in the exact text form the backend accepts.
  static String colorToApi(int value) =>
      '0x${value.toRadixString(16).toUpperCase().padLeft(8, '0')}';
}

/// One row of a server's Members tab.
class MemberModel {
  final UserPublic user;
  final DateTime joinedAt;
  final bool isOwner;

  const MemberModel({
    required this.user,
    required this.joinedAt,
    required this.isOwner,
  });

  factory MemberModel.fromJson(Map<String, dynamic> json) {
    return MemberModel(
      user: UserPublic.fromJson(json['user'] as Map<String, dynamic>),
      joinedAt: parseServerTimeOrNull(json['joined_at']) ?? DateTime.now(),
      isOwner: json['is_owner'] as bool? ?? false,
    );
  }
}
