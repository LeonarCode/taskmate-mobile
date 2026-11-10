import '../core/constants.dart';
import '../core/format.dart';

/// A task, either personal (synced by its client UUID) or belonging to a
/// server (group task, identified by the backend id).
class TaskModel {
  /// Personal task: the UUID created by the app (`client_id` on the backend).
  /// Group task: `g<backend id>`.
  final String id;

  /// Backend row id, once known.
  final int? remoteId;

  /// Set for group tasks only.
  final int? serverId;

  /// Owner's user id (as text) for personal tasks.
  final String uid;
  final String title;
  final String description;
  final DateTime deadline;
  final bool isCompleted;
  final TaskPriority priority;
  final bool hasAlarm;
  final bool isSynced;

  /// Personal tasks deleted offline stay here until the delete is synced.
  final bool isDeleted;
  final DateTime? completedAt;

  const TaskModel({
    required this.id,
    this.remoteId,
    this.serverId,
    this.uid = '',
    required this.title,
    this.description = '',
    required this.deadline,
    this.isCompleted = false,
    this.priority = TaskPriority.medium,
    this.hasAlarm = true,
    this.isSynced = false,
    this.isDeleted = false,
    this.completedAt,
  });

  bool get isGroup => serverId != null;

  static TaskPriority _priorityFrom(Object? value) => TaskPriority.values
      .firstWhere((p) => p.name == value, orElse: () => TaskPriority.medium);

  // ── Local cache ─────────────────────────────────────────────────────────────
  factory TaskModel.fromLocal(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] as String,
      remoteId: map['remoteId'] as int?,
      uid: map['uid'] as String? ?? '',
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      deadline: DateTime.fromMillisecondsSinceEpoch(map['deadline'] as int),
      isCompleted: map['isCompleted'] as bool? ?? false,
      priority: _priorityFrom(map['priority']),
      hasAlarm: map['hasAlarm'] as bool? ?? true,
      isSynced: map['isSynced'] as bool? ?? false,
      isDeleted: map['isDeleted'] as bool? ?? false,
      completedAt: map['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'] as int)
          : null,
    );
  }

  Map<String, dynamic> toLocal() => {
    'id': id,
    'remoteId': remoteId,
    'uid': uid,
    'title': title,
    'description': description,
    'deadline': deadline.millisecondsSinceEpoch,
    'isCompleted': isCompleted,
    'priority': priority.name,
    'hasAlarm': hasAlarm,
    'isSynced': isSynced,
    'isDeleted': isDeleted,
    'completedAt': completedAt?.millisecondsSinceEpoch,
  };

  // ── API ─────────────────────────────────────────────────────────────────────
  /// A personal task from `GET /task`. Returns null when the backend row has no
  /// `client_id`, because the app can only sync tasks it can address by UUID.
  static TaskModel? fromPersonalApi(Map<String, dynamic> json, String uid) {
    final clientId = json['client_id'] as String?;
    if (clientId == null) return null;
    return TaskModel(
      id: clientId,
      remoteId: json['id'] as int?,
      uid: uid,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      deadline: parseServerTime(json['deadline'] as String),
      isCompleted: json['is_complete'] as bool? ?? false,
      priority: _priorityFrom(json['priority']),
      hasAlarm: json['has_alarm'] as bool? ?? true,
      isSynced: true,
      completedAt: parseServerTimeOrNull(json['completed_at']),
    );
  }

  factory TaskModel.fromGroupApi(Map<String, dynamic> json) {
    final id = json['id'] as int;
    return TaskModel(
      id: 'g$id',
      remoteId: id,
      serverId: json['server_id'] as int?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      deadline: parseServerTime(json['deadline'] as String),
      isCompleted: json['is_complete'] as bool? ?? false,
      priority: _priorityFrom(json['priority']),
      hasAlarm: json['has_alarm'] as bool? ?? true,
      isSynced: true,
      completedAt: parseServerTimeOrNull(json['completed_at']),
    );
  }

  /// Body for `PUT /task/{client_id}`.
  Map<String, dynamic> toUpsertBody() => {
    'title': title,
    'description': description,
    'priority': priority.name,
    'deadline': toServerTime(deadline),
    'has_alarm': hasAlarm,
    'is_complete': isCompleted,
    'completed_at': completedAt != null ? toServerTime(completedAt!) : null,
  };

  TaskModel copyWith({
    int? remoteId,
    String? title,
    String? description,
    DateTime? deadline,
    bool? isCompleted,
    TaskPriority? priority,
    bool? hasAlarm,
    bool? isSynced,
    bool? isDeleted,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return TaskModel(
      id: id,
      remoteId: remoteId ?? this.remoteId,
      serverId: serverId,
      uid: uid,
      title: title ?? this.title,
      description: description ?? this.description,
      deadline: deadline ?? this.deadline,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      hasAlarm: hasAlarm ?? this.hasAlarm,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  int get daysUntilDeadline => deadline.difference(DateTime.now()).inDays;
  bool get isOverdue => !isCompleted && deadline.isBefore(DateTime.now());
  bool get isDueSoon =>
      !isCompleted && daysUntilDeadline <= 3 && daysUntilDeadline >= 0;
}
