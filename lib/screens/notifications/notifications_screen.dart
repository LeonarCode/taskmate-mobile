import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui_helpers.dart';
import '../../models/notification_model.dart';
import '../../providers/alert_provider.dart';
import '../../providers/home_tab_provider.dart';
import '../../services/server_service.dart';
import '../../widgets/common.dart';
import '../servers/servers_screen.dart' show openServer;

/// The Alerts tab: notifications from the backend. Tap one to mark it read and
/// jump to what it is about; swipe to delete.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Future<void> _clearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear all notifications'),
        content: const Text('This removes every notification.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red500),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AlertProvider>().clearAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final alerts = context.watch<AlertProvider>();

    return Scaffold(
      backgroundColor: isDark ? AppColors.dark900 : AppColors.gray50,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: isDark ? AppColors.dark900 : AppColors.gray50,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded),
            tooltip: 'Mark all as read',
            onPressed: alerts.unreadCount > 0 ? alerts.markAllRead : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear all',
            onPressed: alerts.items.isEmpty ? null : () => _clearAll(context),
          ),
        ],
      ),
      body: _buildBody(context, alerts, isDark),
    );
  }

  Widget _buildBody(BuildContext context, AlertProvider alerts, bool isDark) {
    if (alerts.isLoading && alerts.items.isEmpty) return const BrandSpinner();

    return RefreshIndicator(
      color: AppColors.purple600,
      onRefresh: alerts.refresh,
      child: alerts.items.isEmpty
          ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: alerts.error != null
                      ? EmptyState(
                          icon: Icons.cloud_off_rounded,
                          message: alerts.error!,
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.notifications_off_outlined,
                                size: 64,
                                color: isDark
                                    ? AppColors.gray600
                                    : AppColors.gray400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No new notifications',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark
                                      ? AppColors.gray400
                                      : AppColors.gray500,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: alerts.items.length,
              itemBuilder: (_, i) => _AlertTile(
                key: ValueKey(alerts.items[i].id),
                item: alerts.items[i],
              ),
            ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final NotificationModel item;

  const _AlertTile({super.key, required this.item});

  (IconData, Color) get _look {
    switch (item.type) {
      case NotifType.message:
        return (Icons.chat_bubble_rounded, AppColors.purple600);
      case NotifType.taskDeadline:
        return (Icons.warning_rounded, AppColors.red500);
      case NotifType.serverActivity:
        return (Icons.dns_rounded, AppColors.pink500);
      case NotifType.taskReminder:
        return (Icons.alarm_rounded, AppColors.amber500);
    }
  }

  Future<void> _open(BuildContext context) async {
    final tabs = context.read<HomeTabProvider>();
    final servers = context.read<ServerService>();
    context.read<AlertProvider>().markRead(item.id);

    if (item.serverId != null) {
      try {
        final server = await servers.get(item.serverId!);
        if (context.mounted) openServer(context, server);
      } catch (_) {
        if (context.mounted) {
          showInfoSnack(context, 'This server is no longer available.');
        }
      }
    } else if (item.taskId != null) {
      tabs.go(HomeTabProvider.tasks);
    } else if (item.dmId != null) {
      tabs.go(HomeTabProvider.chats);
    } else {
      switch (item.type) {
        case NotifType.message:
          tabs.go(HomeTabProvider.chats);
        case NotifType.taskDeadline:
        case NotifType.taskReminder:
          tabs.go(HomeTabProvider.tasks);
        case NotifType.serverActivity:
          tabs.go(HomeTabProvider.servers);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (icon, color) = _look;

    return Dismissible(
      key: ValueKey('dismiss-${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.red500.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_rounded,
          color: AppColors.red500,
          size: 28,
        ),
      ),
      onDismissed: (_) => context.read<AlertProvider>().delete(item.id),
      child: GestureDetector(
        onTap: () => _open(context),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: item.isRead
                ? (isDark ? AppColors.dark800 : Colors.white)
                : (isDark
                      ? AppColors.purple600.withAlpha(30)
                      : AppColors.purple50),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.isRead
                  ? (isDark ? AppColors.dark600 : AppColors.gray200)
                  : AppColors.purple600.withAlpha(60),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: item.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.gray900,
                            ),
                          ),
                        ),
                        Text(
                          shortTimeLabel(item.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.gray500
                                : AppColors.gray400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.content,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: isDark ? AppColors.gray300 : AppColors.gray600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!item.isRead) ...[
                const SizedBox(width: 8),
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: const BoxDecoration(
                    color: AppColors.pink500,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
