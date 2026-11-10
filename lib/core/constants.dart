// App-wide constants
class AppStrings {
  AppStrings._();

  static const appName = 'TaskMate';
  static const tagline = 'Your smart productivity mate 🚀';

  // Shared prefs keys
  static const prefThemeMode = 'theme_mode';
  static const prefAuthToken = 'auth_token';
  static const prefAuthUser = 'auth_user';
  static const prefTasksPrefix = 'tasks_v1_';
}

class AppDurations {
  AppDurations._();
  static const fast = Duration(milliseconds: 200);
  static const medium = Duration(milliseconds: 350);
  static const slow = Duration(milliseconds: 600);
  static const splash = Duration(seconds: 2);
}

/// The `.name` of each value matches what the backend sends.
enum UserType { student, employee }

/// The `.name` of each value matches what the backend sends.
enum TaskPriority { low, medium, high }

enum NotifType {
  message('message'),
  taskDeadline('task_deadline'),
  serverActivity('server_activity'),
  taskReminder('task_reminder');

  const NotifType(this.apiValue);
  final String apiValue;

  static NotifType fromApi(String? value) => NotifType.values.firstWhere(
    (t) => t.apiValue == value,
    orElse: () => NotifType.message,
  );
}

/// Colors the backend accepts for a server icon (`icon_color`).
const kServerColors = <int>[
  0xFF7C3AED,
  0xFFEC4899,
  0xFF22C55E,
  0xFFF59E0B,
  0xFFEF4444,
  0xFF3B82F6,
];
