import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../models/task_model.dart';

/// Offline copy of a user's personal tasks, including the ones that still wait
/// to be pushed (`isSynced == false`) or deleted (`isDeleted == true`) on the
/// backend. Personal task lists are small, so the whole list is stored as one
/// JSON string per user; that works on every platform without a native database.
class LocalTaskStore {
  String _key(String uid) => '${AppStrings.prefTasksPrefix}$uid';

  Future<List<TaskModel>> load(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(uid));
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => TaskModel.fromLocal(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(String uid, List<TaskModel> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(uid),
      jsonEncode(tasks.map((t) => t.toLocal()).toList()),
    );
  }
}
