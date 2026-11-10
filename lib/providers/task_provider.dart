import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../models/task_model.dart';
import '../services/api_client.dart';
import '../services/local_task_store.dart';
import '../services/reminder_service.dart';
import '../services/task_service.dart';
import 'session_bound.dart';

/// Personal tasks. Offline-first: every change is saved on the device straight
/// away and pushed to the backend in the background. The backend addresses a
/// task by the UUID created here, so repeating a push or a delete is harmless.
class TaskProvider extends ChangeNotifier with SessionBound {
  TaskProvider(this._api, this._store, this._reminders);

  final TaskService _api;
  final LocalTaskStore _store;
  final ReminderService _reminders;

  /// Everything on the device, including tasks waiting to be deleted remotely.
  List<TaskModel> _all = [];
  List<TaskModel> _visible = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _syncAgain = false;
  String? _error;

  List<TaskModel> get tasks => List.unmodifiable(_visible);

  /// True until the tasks stored on the device have been read.
  bool get isLoading => _isLoading;

  /// True while talking to the backend.
  bool get isSyncing => _isSyncing;
  String? get error => _error;

  List<TaskModel> get pendingTasks =>
      _visible.where((t) => !t.isCompleted).toList();
  List<TaskModel> get completedTasks =>
      _visible.where((t) => t.isCompleted).toList();
  List<TaskModel> get overdueTasks =>
      _visible.where((t) => t.isOverdue).toList();
  List<TaskModel> get dueSoonTasks =>
      _visible.where((t) => t.isDueSoon && !t.isOverdue).toList();

  @override
  void onSessionReset() {
    _all = [];
    _visible = [];
    _isLoading = false;
    _isSyncing = false;
    _syncAgain = false;
    _error = null;
  }

  @override
  Future<void> onSessionStart() => loadTasks();

  // ── Load & sync ──────────────────────────────────────────────────────────────
  Future<void> loadTasks() async {
    final userId = sessionUserId;
    if (userId == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      final stored = await _store.load('$userId');
      if (sessionUserId != userId) return;
      _all = stored;
      _publish();
      for (final task in _visible) {
        unawaited(_reminders.syncTask(task));
      }
    } catch (_) {
      _error = 'Failed to load tasks';
    } finally {
      if (sessionUserId == userId) {
        _isLoading = false;
        notifyListeners();
      }
    }
    await sync();
  }

  /// Pushes local changes, then pulls what changed on the backend.
  Future<void> sync() async {
    final userId = sessionUserId;
    if (userId == null) return;
    if (_isSyncing) {
      _syncAgain = true;
      return;
    }
    _isSyncing = true;
    notifyListeners();
    try {
      do {
        _syncAgain = false;
        await _syncOnce(userId);
      } while (_syncAgain && sessionUserId == userId);
    } on ApiException {
      // Offline or rejected: keep the local copy and try again next time.
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _syncOnce(int userId) async {
    // 1. Deletions made while offline.
    for (final task in _all.where((t) => t.isDeleted).toList()) {
      await _api.deletePersonal(task.id);
      _all.removeWhere((t) => t.id == task.id && t.isDeleted);
    }
    await _persist(userId);

    // 2. Tasks created or changed on this device.
    for (final task
        in _all.where((t) => !t.isDeleted && !t.isSynced).toList()) {
      final pushed = jsonEncode(task.toUpsertBody());
      final TaskModel saved;
      try {
        saved = await _api.upsertPersonal(task);
      } on ApiException catch (e) {
        if (e.isNetwork || e.isUnauthorized) rethrow;
        continue; // the backend refused this one task; keep it and go on
      }
      final index = _all.indexWhere((t) => t.id == task.id);
      if (index == -1) continue;
      final current = _all[index];
      // If it was edited again while the request ran, it still needs pushing.
      final unchanged =
          !current.isDeleted && jsonEncode(current.toUpsertBody()) == pushed;
      _all[index] = current.copyWith(
        remoteId: saved.remoteId,
        isSynced: unchanged,
      );
    }
    await _persist(userId);

    // 3. What the backend has now (changes from other devices).
    final remote = await _api.fetchPersonal('$userId');
    if (sessionUserId != userId) return;
    final merged = <TaskModel>[];
    final changed = <TaskModel>[];
    final removed = <TaskModel>[];
    final localById = {for (final t in _all) t.id: t};
    final remoteIds = {for (final r in remote) r.id};

    for (final r in remote) {
      final local = localById[r.id];
      if (local != null && (local.isDeleted || !local.isSynced)) {
        merged.add(local); // a change not pushed yet wins
      } else {
        merged.add(r);
        if (local == null ||
            jsonEncode(local.toUpsertBody()) != jsonEncode(r.toUpsertBody())) {
          changed.add(r);
        }
      }
    }
    for (final local in _all) {
      if (remoteIds.contains(local.id)) continue;
      if (!local.isSynced && !local.isDeleted) {
        merged.add(local); // created after the push step; goes up next time
      } else if (!local.isDeleted) {
        removed.add(local); // synced before, now gone: deleted elsewhere
      }
    }

    _all = merged;
    _publish();
    await _persist(userId);
    for (final task in changed) {
      unawaited(_reminders.syncTask(task));
    }
    for (final task in removed) {
      unawaited(_reminders.cancelTaskReminders(task.id));
    }
  }

  // ── Changes ──────────────────────────────────────────────────────────────────
  Future<void> addTask({
    required String title,
    String description = '',
    required DateTime deadline,
    TaskPriority priority = TaskPriority.medium,
    bool hasAlarm = true,
  }) async {
    final userId = sessionUserId;
    if (userId == null) return;
    final task = TaskModel(
      id: const Uuid().v4(),
      uid: '$userId',
      title: title,
      description: description,
      deadline: deadline,
      priority: priority,
      hasAlarm: hasAlarm,
    );
    _all.add(task);
    _publish();
    notifyListeners();
    await _persist(userId);
    unawaited(_reminders.syncTask(task));
    unawaited(sync());
  }

  Future<void> updateTask(TaskModel updated) async {
    final userId = sessionUserId;
    final index = _all.indexWhere((t) => t.id == updated.id);
    if (userId == null || index == -1) return;
    final next = updated.copyWith(isSynced: false);
    _all[index] = next;
    _publish();
    notifyListeners();
    await _persist(userId);
    unawaited(_reminders.syncTask(next));
    unawaited(sync());
  }

  Future<void> toggleComplete(String taskId) async {
    final index = _all.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    final task = _all[index];
    await updateTask(
      task.isCompleted
          ? task.copyWith(isCompleted: false, clearCompletedAt: true)
          : task.copyWith(isCompleted: true, completedAt: DateTime.now()),
    );
  }

  Future<void> deleteTask(String taskId) async {
    final userId = sessionUserId;
    final index = _all.indexWhere((t) => t.id == taskId);
    if (userId == null || index == -1) return;
    // Kept (hidden) until the backend confirms, so an offline delete isn't lost.
    _all[index] = _all[index].copyWith(isDeleted: true, isSynced: false);
    _publish();
    notifyListeners();
    await _persist(userId);
    unawaited(_reminders.cancelTaskReminders(taskId));
    unawaited(sync());
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  void _publish() {
    _visible = _all.where((t) => !t.isDeleted).toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));
  }

  Future<void> _persist(int userId) async {
    if (sessionUserId != userId) return;
    try {
      await _store.save('$userId', _all);
    } catch (e) {
      debugPrint('Could not save tasks locally: $e');
    }
  }
}
