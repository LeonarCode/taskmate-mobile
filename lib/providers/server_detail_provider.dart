import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/rating_model.dart';
import '../models/server_model.dart';
import '../models/task_model.dart';
import '../services/api_client.dart';
import '../services/reminder_service.dart';
import '../services/server_service.dart';
import '../services/task_service.dart';

/// Everything on a server's detail screen except the chat: members, the
/// server's tasks, and the ratings the signed-in user gave its members.
/// The owner can manage tasks; members can only mark them complete.
class ServerDetailProvider extends ChangeNotifier {
  ServerDetailProvider({
    required this.server,
    required this.myId,
    required ServerService servers,
    required TaskService tasks,
    required ReminderService reminders,
  }) : _servers = servers,
       _tasks = tasks,
       _reminders = reminders {
    unawaited(loadAll());
  }

  final ServerModel server;
  final int myId;
  final ServerService _servers;
  final TaskService _tasks;
  final ReminderService _reminders;
  bool _disposed = false;

  List<MemberModel> _members = [];
  List<TaskModel> _taskList = [];
  Map<int, RatingModel> _myRatings = {};
  bool _membersLoading = true;
  bool _tasksLoading = true;
  String? _membersError;
  String? _tasksError;

  bool get isOwner => server.ownerId == myId;
  List<MemberModel> get members => _members;
  List<TaskModel> get tasks => _taskList;
  bool get membersLoading => _membersLoading;
  bool get tasksLoading => _tasksLoading;
  String? get membersError => _membersError;
  String? get tasksError => _tasksError;

  /// Number shown on the Overview tab; the loaded list is more current than
  /// the count the server had when the screen was opened.
  int get memberCount => _membersLoading ? server.memberCount : _members.length;
  int get openTaskCount => _taskList.where((t) => !t.isCompleted).length;
  int get doneTaskCount => _taskList.where((t) => t.isCompleted).length;

  /// The rating I gave [userId] in this server, if any.
  RatingModel? myRatingFor(int userId) => _myRatings[userId];

  Future<void> loadAll() => Future.wait([loadMembers(), loadTasks()]);

  Future<void> loadMembers() async {
    try {
      final results = await Future.wait([
        _servers.members(server.id),
        _servers.given(serverId: server.id),
      ]);
      _members = results[0] as List<MemberModel>;
      _myRatings = {
        for (final r in results[1] as List<RatingModel>) r.rated.id: r,
      };
      _membersError = null;
    } on ApiException catch (e) {
      _membersError = e.message;
    } finally {
      _membersLoading = false;
      _notify();
    }
  }

  Future<void> loadTasks() async {
    try {
      _taskList = _byDeadline(await _tasks.fetchGroup(server.id));
      _tasksError = null;
      for (final task in _taskList) {
        unawaited(_reminders.syncTask(task));
      }
    } on ApiException catch (e) {
      _tasksError = e.message;
    } finally {
      _tasksLoading = false;
      _notify();
    }
  }

  // ── Tasks ────────────────────────────────────────────────────────────────────
  /// Owner only. Throws [ApiException] when refused.
  Future<void> addTask({
    required String title,
    required String description,
    required DateTime deadline,
    required TaskPriority priority,
    required bool hasAlarm,
  }) async {
    final task = await _tasks.createGroup(
      server.id,
      title: title,
      description: description,
      deadline: deadline,
      priority: priority.name,
      hasAlarm: hasAlarm,
    );
    _taskList = _byDeadline([..._taskList, task]);
    _notify();
    unawaited(_reminders.syncTask(task));
  }

  /// Members can only complete a task; undoing it is up to the owner.
  /// Throws [ApiException] when refused.
  Future<void> toggleTask(TaskModel task) async {
    final id = task.remoteId;
    if (id == null) return;
    final updated = task.isCompleted
        ? await _tasks.incompleteGroup(server.id, id)
        : await _tasks.completeGroup(server.id, id);
    _taskList = _byDeadline([
      for (final t in _taskList) t.id == task.id ? updated : t,
    ]);
    _notify();
    unawaited(_reminders.syncTask(updated));
  }

  /// Owner only. Throws [ApiException] when refused.
  Future<void> deleteTask(TaskModel task) async {
    final id = task.remoteId;
    if (id == null) return;
    await _tasks.deleteGroup(server.id, id);
    _taskList = _taskList.where((t) => t.id != task.id).toList();
    _notify();
    unawaited(_reminders.cancelTaskReminders(task.id));
  }

  /// Used when leaving or deleting the server: its deadlines no longer apply.
  Future<void> cancelAllReminders() async {
    for (final task in _taskList) {
      await _reminders.cancelTaskReminders(task.id);
    }
  }

  // ── Ratings ──────────────────────────────────────────────────────────────────
  /// Throws [ApiException] when refused.
  Future<void> rate(int userId, double score, String? comment) async {
    final rating = await _servers.rate(
      serverId: server.id,
      ratedId: userId,
      score: score,
      comment: comment,
    );
    _myRatings = {..._myRatings, userId: rating};
    _notify();
  }

  Future<void> removeRating(int userId) async {
    await _servers.removeRating(serverId: server.id, ratedId: userId);
    _myRatings = {..._myRatings}..remove(userId);
    _notify();
  }

  List<TaskModel> _byDeadline(List<TaskModel> list) =>
      list..sort((a, b) => a.deadline.compareTo(b.deadline));

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
