import '../core/constants.dart';
import '../core/format.dart';

class NotificationModel {
  final int id;
  final String content;
  final NotifType type;
  final bool isRead;
  final DateTime createdAt;

  /// What the notification points to; at most one is set.
  final int? taskId;
  final int? serverId;

  /// Id of a message (not of the other person).
  final int? dmId;

  const NotificationModel({
    required this.id,
    required this.content,
    required this.type,
    this.isRead = false,
    required this.createdAt,
    this.taskId,
    this.serverId,
    this.dmId,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final ref = json['reference'];
    final refMap = ref is Map<String, dynamic> ? ref : const {};
    return NotificationModel(
      id: json['id'] as int,
      content: json['content'] as String? ?? '',
      type: NotifType.fromApi(json['notification_type'] as String?),
      isRead: json['is_read'] as bool? ?? false,
      createdAt: parseServerTimeOrNull(json['created_at']) ?? DateTime.now(),
      taskId: refMap['task_id'] as int?,
      serverId: refMap['server_id'] as int?,
      dmId: refMap['dm_id'] as int?,
    );
  }

  String get title {
    switch (type) {
      case NotifType.message:
        return 'New message';
      case NotifType.taskDeadline:
        return 'Task deadline';
      case NotifType.serverActivity:
        return 'Server activity';
      case NotifType.taskReminder:
        return 'Task reminder';
    }
  }

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
    id: id,
    content: content,
    type: type,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
    taskId: taskId,
    serverId: serverId,
    dmId: dmId,
  );
}
