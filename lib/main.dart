import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'providers/alert_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/home_tab_provider.dart';
import 'providers/server_provider.dart';
import 'providers/task_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/app_root.dart';
import 'services/alert_service.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/local_task_store.dart';
import 'services/message_service.dart';
import 'services/realtime_service.dart';
import 'services/reminder_service.dart';
import 'services/server_service.dart';
import 'services/task_service.dart';
import 'services/user_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // API address and Google client ID live in `.env`.
  await dotenv.load(isOptional: true);

  // On-device task reminders.
  final reminders = ReminderService();
  await reminders.init();

  runApp(TaskMateApp(reminders: reminders));
}

class TaskMateApp extends StatelessWidget {
  /// [api] and [realtime] can be replaced, which lets tests run the whole app
  /// against a fake backend.
  const TaskMateApp({
    super.key,
    required this.reminders,
    this.api,
    this.realtime,
  });

  final ReminderService reminders;
  final ApiClient? api;
  final RealtimeService? realtime;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Networking
        Provider<ApiClient>(
          create: (_) => api ?? ApiClient(),
          dispose: (_, client) => client.close(),
        ),
        Provider<RealtimeService>(
          create: (_) => realtime ?? RealtimeService(),
          dispose: (_, service) => service.dispose(),
        ),

        // Services (stateless wrappers around the REST API)
        Provider<ReminderService>.value(value: reminders),
        Provider<LocalTaskStore>(create: (_) => LocalTaskStore()),
        Provider<AuthService>(create: (c) => AuthService(c.read<ApiClient>())),
        Provider<UserService>(create: (c) => UserService(c.read<ApiClient>())),
        Provider<TaskService>(create: (c) => TaskService(c.read<ApiClient>())),
        Provider<ServerService>(
          create: (c) => ServerService(c.read<ApiClient>()),
        ),
        Provider<MessageService>(
          create: (c) => MessageService(c.read<ApiClient>()),
        ),
        Provider<AlertService>(
          create: (c) => AlertService(c.read<ApiClient>()),
        ),

        // App state
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => HomeTabProvider()),
        ChangeNotifierProvider<AuthProvider>(
          create: (c) => AuthProvider(
            c.read<AuthService>(),
            c.read<ApiClient>(),
            c.read<RealtimeService>(),
            c.read<ReminderService>(),
          ),
        ),

        // Data of the signed-in user: dropped and reloaded when the user changes.
        ChangeNotifierProxyProvider<AuthProvider, TaskProvider>(
          create: (c) => TaskProvider(
            c.read<TaskService>(),
            c.read<LocalTaskStore>(),
            c.read<ReminderService>(),
          ),
          update: (_, auth, tasks) => tasks!..bindUser(auth.userModel?.id),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (c) =>
              ChatProvider(c.read<MessageService>(), c.read<RealtimeService>()),
          update: (_, auth, chats) => chats!..bindUser(auth.userModel?.id),
        ),
        ChangeNotifierProxyProvider<AuthProvider, AlertProvider>(
          create: (c) =>
              AlertProvider(c.read<AlertService>(), c.read<RealtimeService>()),
          update: (_, auth, alerts) => alerts!..bindUser(auth.userModel?.id),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ServerProvider>(
          create: (c) => ServerProvider(c.read<ServerService>()),
          update: (_, auth, servers) => servers!..bindUser(auth.userModel?.id),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (_, themeProv, _) {
          return MaterialApp(
            title: 'TaskMate',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeProv.themeMode,
            home: const AppRoot(),
          );
        },
      ),
    );
  }
}
