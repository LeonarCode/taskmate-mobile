import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/ui_helpers.dart';
import '../../models/task_model.dart';
import '../../providers/server_detail_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/task_card.dart';

/// The tasks tab of a server. Anyone in the server can mark a task complete;
/// only the owner can reopen, add or delete tasks.
class ServerTasksView extends StatelessWidget {
  const ServerTasksView({super.key});

  Future<void> _toggle(BuildContext context, TaskModel task) async {
    final detail = context.read<ServerDetailProvider>();
    if (task.isCompleted && !detail.isOwner) {
      showInfoSnack(context, 'Only the server owner can reopen a task.');
      return;
    }
    try {
      await detail.toggleTask(task);
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }

  Future<bool> _delete(BuildContext context, TaskModel task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Delete "${task.title}" for everyone in this server?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red500),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return false;
    try {
      await context.read<ServerDetailProvider>().deleteTask(task);
      return true;
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final detail = context.watch<ServerDetailProvider>();

    if (detail.tasksLoading) return const BrandSpinner();

    final tasks = detail.tasks;
    return RefreshIndicator(
      color: AppColors.purple600,
      onRefresh: detail.loadTasks,
      child: tasks.isEmpty
          ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: detail.tasksError != null
                      ? EmptyState(
                          icon: Icons.cloud_off_rounded,
                          message: detail.tasksError!,
                        )
                      : Center(
                          child: Text(
                            detail.isOwner
                                ? 'No tasks yet. Tap + to add one!'
                                : 'No tasks for this server yet!',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.gray400
                                  : AppColors.gray500,
                              fontSize: 16,
                            ),
                          ),
                        ),
                ),
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              itemBuilder: (context, i) {
                final task = tasks[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TaskCard(
                    task: task,
                    onToggle: () => _toggle(context, task),
                    onDelete: detail.isOwner
                        ? () => _delete(context, task)
                        : null,
                  ),
                );
              },
            ),
    );
  }
}
