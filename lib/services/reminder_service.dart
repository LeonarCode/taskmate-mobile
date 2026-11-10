import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../models/task_model.dart';

/// Schedules on-device reminders for task deadlines: 8 AM, 2 PM and 8 PM on
/// each of the 3 days before the deadline and on the day itself. Does nothing
/// on platforms where scheduled notifications aren't available.
class ReminderService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'taskmate_channel';
  static const _channelName = 'TaskMate Notifications';
  static const _channelDesc = 'Alerts for tasks, messages, and server activity';
  static const _reminderHours = [8, 14, 20];

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<void> init() async {
    if (_ready || !_supported) return;
    try {
      tz_data.initializeTimeZones();
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: darwin,
          macOS: darwin,
        ),
      );
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(
              const AndroidNotificationChannel(
                _channelId,
                _channelName,
                description: _channelDesc,
                importance: Importance.high,
                playSound: true,
              ),
            );
      }
      _ready = true;
    } catch (e) {
      debugPrint('Reminders unavailable: $e');
    }
  }

  /// Asks for permission to show notifications (Android 13+, iOS, macOS).
  Future<void> requestPermission() async {
    if (!_ready) return;
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission();
        case TargetPlatform.iOS:
          await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true);
        case TargetPlatform.macOS:
          await _plugin
              .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true);
        default:
          break;
      }
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  /// Schedules reminders for [task] if it still needs them, otherwise makes
  /// sure none are left. Safe to call repeatedly.
  Future<void> syncTask(TaskModel task) async {
    await cancelTaskReminders(task.id);
    if (task.hasAlarm && !task.isCompleted && !task.isDeleted) {
      await scheduleTaskReminders(task);
    }
  }

  Future<void> scheduleTaskReminders(TaskModel task) async {
    if (!_ready || !task.hasAlarm) return;
    final now = DateTime.now();
    final deadline = task.deadline;

    for (var daysOffset = 3; daysOffset >= 0; daysOffset--) {
      final day = deadline.subtract(Duration(days: daysOffset));
      for (var hourIndex = 0; hourIndex < _reminderHours.length; hourIndex++) {
        final hour = _reminderHours[hourIndex];
        final when = DateTime(day.year, day.month, day.day, hour);
        // Past times are skipped, and so is anything after the deadline itself.
        if (!when.isAfter(now) || when.isAfter(deadline)) continue;

        final label = daysOffset == 0
            ? 'Today'
            : daysOffset == 1
            ? 'Tomorrow'
            : 'In $daysOffset days';
        await _schedule(
          id: _notificationId(task.id, daysOffset, hourIndex),
          title: '⏰ Task Reminder: ${task.title}',
          body:
              '$label at ${_formatHour(hour)} — Deadline: ${_formatDate(deadline)}',
          at: when,
        );
      }
    }
  }

  Future<void> cancelTaskReminders(String taskId) async {
    if (!_ready) return;
    try {
      for (var d = 0; d <= 3; d++) {
        for (var h = 0; h < _reminderHours.length; h++) {
          await _plugin.cancel(id: _notificationId(taskId, d, h));
        }
      }
    } catch (e) {
      debugPrint('Could not cancel reminders: $e');
    }
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Could not cancel reminders: $e');
    }
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(at, tz.UTC),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
          macOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        // Inexact is plenty for a morning/afternoon/evening reminder and avoids
        // needing the "exact alarms" permission on Android 12+.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Could not schedule reminder: $e');
    }
  }

  /// Stable across app launches (String.hashCode is not guaranteed to be).
  int _notificationId(String taskId, int daysOffset, int hourIndex) {
    var hash = 0x811C9DC5;
    for (final unit in taskId.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    return (hash % 100000) * 100 + daysOffset * 10 + hourIndex;
  }

  String _formatHour(int hour) {
    final period = hour < 12 ? 'AM' : 'PM';
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$h:00 $period';
  }

  String _formatDate(DateTime dt) => '${dt.month}/${dt.day}/${dt.year}';
}
