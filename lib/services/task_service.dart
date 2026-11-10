import '../core/format.dart';
import '../models/task_model.dart';
import 'api_client.dart';

/// REST calls for personal tasks (`/task`) and server tasks (`/server/task`).
class TaskService {
  TaskService(this._api);

  final ApiClient _api;

  // ── Personal ────────────────────────────────────────────────────────────────
  Future<List<TaskModel>> fetchPersonal(String uid) async {
    final json = await _api.get('/task');
    return (json as List)
        .map((e) => TaskModel.fromPersonalApi(e as Map<String, dynamic>, uid))
        .whereType<TaskModel>()
        .toList();
  }

  /// Creates or updates the task addressed by its UUID. Safe to repeat.
  Future<TaskModel> upsertPersonal(TaskModel task) async {
    final json = await _api.put('/task/${task.id}', body: task.toUpsertBody());
    return TaskModel.fromPersonalApi(json as Map<String, dynamic>, task.uid) ??
        task.copyWith(isSynced: true);
  }

  /// Safe to repeat: the backend answers 204 even if the task is already gone.
  Future<void> deletePersonal(String clientId) =>
      _api.delete('/task/$clientId');

  // ── Server (group) tasks ────────────────────────────────────────────────────
  Future<List<TaskModel>> fetchGroup(int serverId) async {
    final json = await _api.get('/server/task/$serverId');
    return (json as List)
        .map((e) => TaskModel.fromGroupApi(e as Map<String, dynamic>))
        .toList();
  }

  /// Owner only.
  Future<TaskModel> createGroup(
    int serverId, {
    required String title,
    required String description,
    required DateTime deadline,
    required String priority,
    required bool hasAlarm,
  }) async {
    final json = await _api.post(
      '/server/task/$serverId',
      body: {
        'title': title,
        'description': description,
        'priority': priority,
        'deadline': toServerTime(deadline),
        'has_alarm': hasAlarm,
      },
    );
    return TaskModel.fromGroupApi(json as Map<String, dynamic>);
  }

  /// Any member can complete a task.
  Future<TaskModel> completeGroup(int serverId, int taskId) async {
    final json = await _api.post('/server/task/$serverId/$taskId/complete');
    return TaskModel.fromGroupApi(json as Map<String, dynamic>);
  }

  /// Owner only.
  Future<TaskModel> incompleteGroup(int serverId, int taskId) async {
    final json = await _api.post('/server/task/$serverId/$taskId/incomplete');
    return TaskModel.fromGroupApi(json as Map<String, dynamic>);
  }

  /// Owner only.
  Future<void> deleteGroup(int serverId, int taskId) =>
      _api.delete('/server/task/$serverId/$taskId');
}
