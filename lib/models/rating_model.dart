import '../core/format.dart';
import 'user_model.dart';

class RatingModel {
  final int id;

  /// 1.0 – 5.0 in steps of 0.5.
  final double score;
  final String? comment;
  final DateTime createdAt;
  final int serverId;
  final String serverName;
  final UserPublic rater;
  final UserPublic rated;

  const RatingModel({
    required this.id,
    required this.score,
    this.comment,
    required this.createdAt,
    required this.serverId,
    required this.serverName,
    required this.rater,
    required this.rated,
  });

  factory RatingModel.fromJson(Map<String, dynamic> json) {
    final server = json['server'] as Map<String, dynamic>;
    return RatingModel(
      id: json['id'] as int,
      score: (json['score'] as num).toDouble(),
      comment: json['comment'] as String?,
      createdAt: parseServerTimeOrNull(json['created_at']) ?? DateTime.now(),
      serverId: server['id'] as int,
      serverName: server['name'] as String? ?? '',
      rater: UserPublic.fromJson(json['rater'] as Map<String, dynamic>),
      rated: UserPublic.fromJson(json['rated'] as Map<String, dynamic>),
    );
  }
}
