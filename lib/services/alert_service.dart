import '../models/notification_model.dart';
import 'api_client.dart';

/// In-app notifications from the backend (`/notifications`), shown in the
/// Alerts tab. Not to be confused with `ReminderService`, which schedules
/// on-device task reminders.
class AlertService {
  AlertService(this._api);

  final ApiClient _api;

  Future<List<NotificationModel>> list({int limit = 50, int? beforeId}) async {
    final json = await _api.get(
      '/notifications',
      query: {'limit': limit, 'before_id': beforeId},
    );
    return (json as List)
        .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> unreadCount() async {
    final json = await _api.get('/notifications/unread-count');
    return (json as Map<String, dynamic>)['unread_count'] as int;
  }

  Future<void> markRead(int id) => _api.post('/notifications/$id/read');

  Future<void> markAllRead() => _api.post('/notifications/read-all');

  Future<void> delete(int id) => _api.delete('/notifications/$id');

  Future<void> clearAll() => _api.delete('/notifications');
}
