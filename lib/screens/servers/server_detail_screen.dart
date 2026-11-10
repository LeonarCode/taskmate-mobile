import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/ui_helpers.dart';
import '../../models/server_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/server_detail_provider.dart';
import '../../providers/server_provider.dart';
import '../../services/reminder_service.dart';
import '../../services/server_service.dart';
import '../../services/task_service.dart';
import '../tasks/add_task_screen.dart';
import 'server_chat_view.dart';
import 'server_members_view.dart';
import 'server_tasks_view.dart';
import 'servers_screen.dart' show ServerIcon;

class ServerDetailScreen extends StatelessWidget {
  final ServerModel server;

  const ServerDetailScreen({super.key, required this.server});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => ServerDetailProvider(
        server: server,
        myId: ctx.read<AuthProvider>().userModel!.id,
        servers: ctx.read<ServerService>(),
        tasks: ctx.read<TaskService>(),
        reminders: ctx.read<ReminderService>(),
      ),
      child: _ServerDetailView(server: server),
    );
  }
}

class _ServerDetailView extends StatefulWidget {
  final ServerModel server;

  const _ServerDetailView({required this.server});

  @override
  State<_ServerDetailView> createState() => _ServerDetailViewState();
}

class _ServerDetailViewState extends State<_ServerDetailView> {
  int _currentIndex = 0;

  ServerModel get server => widget.server;

  Future<void> _confirmLeaveServer(bool isOwner) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = isOwner ? 'Delete Server' : 'Leave Server';
    final content = isOwner
        ? 'Are you sure you want to permanently delete ${server.name}? '
              'Its members, tasks, messages and ratings will be deleted too.'
        : 'Are you sure you want to leave ${server.name}?';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.dark800 : Colors.white,
        title: Text(
          title,
          style: TextStyle(color: isDark ? Colors.white : AppColors.gray900),
        ),
        content: Text(
          content,
          style: TextStyle(
            color: isDark ? AppColors.gray400 : AppColors.gray600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? AppColors.gray400 : AppColors.gray600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red500),
            child: Text(
              isOwner ? 'Delete' : 'Leave',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final servers = context.read<ServerProvider>();
    final detail = context.read<ServerDetailProvider>();
    final navigator = Navigator.of(context);
    try {
      await detail.cancelAllReminders();
      if (isOwner) {
        await servers.deleteServer(server.id);
      } else {
        await servers.leave(server.id);
      }
      navigator.pop();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  void _showAddServerTask() {
    final detail = context.read<ServerDetailProvider>();
    showAppSheet<void>(
      context,
      (_) => AddTaskSheet(
        heading: 'New Server Task ✨',
        onCreate: (draft) => detail.addTask(
          title: draft.title,
          description: draft.description,
          deadline: draft.deadline,
          priority: draft.priority,
          hasAlarm: draft.hasAlarm,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOwner = context.select<ServerDetailProvider, bool>(
      (p) => p.isOwner,
    );

    return Scaffold(
      backgroundColor: isDark ? AppColors.dark900 : AppColors.gray50,
      appBar: AppBar(
        title: Text(server.name),
        backgroundColor: isDark ? AppColors.dark900 : AppColors.gray50,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              isOwner ? Icons.delete_rounded : Icons.exit_to_app_rounded,
              color: AppColors.red500,
            ),
            tooltip: isOwner ? 'Delete Server' : 'Leave Server',
            onPressed: () => _confirmLeaveServer(isOwner),
          ),
        ],
      ),
      // Kept alive so the chat and lists don't reload on every tab change.
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _Overview(server: server),
          ServerChatView(serverId: server.id),
          const ServerTasksView(),
          const ServerMembersView(),
        ],
      ),
      floatingActionButton: _currentIndex == 2 && isOwner
          ? FloatingActionButton(
              onPressed: _showAddServerTask,
              backgroundColor: AppColors.purple600,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: AppColors.purple600,
        unselectedItemColor: isDark ? AppColors.gray500 : AppColors.gray400,
        backgroundColor: isDark ? AppColors.dark800 : Colors.white,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.info_outline_rounded),
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.task_alt_rounded),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline_rounded),
            label: 'Members',
          ),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  final ServerModel server;

  const _Overview({required this.server});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final detail = context.watch<ServerDetailProvider>();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ServerIcon(server: server, size: 88),
            const SizedBox(height: 16),
            Text(
              'Welcome to ${server.name}!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.gray900,
              ),
            ),
            if (server.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                server.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.gray400 : AppColors.gray600,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '${detail.isOwner ? 'You own this server · ' : ''}'
              'Created ${DateFormat.yMMMd().format(server.createdAt)}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.gray500 : AppColors.gray400,
              ),
            ),
            const SizedBox(height: 32),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 32,
              runSpacing: 24,
              children: [
                _StatColumn('Members', detail.memberCount, isDark),
                _StatColumn('Open tasks', detail.openTaskCount, isDark),
                _StatColumn('Done', detail.doneTaskCount, isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final int count;
  final bool isDark;

  const _StatColumn(this.label, this.count, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.gray900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.gray400 : AppColors.gray500,
          ),
        ),
      ],
    );
  }
}
