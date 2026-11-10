import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../models/task_model.dart';
import 'package:intl/intl.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onToggle;

  /// Confirms and deletes the task; true if it was deleted. Null hides delete.
  final Future<bool> Function()? onDelete;

  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    this.onDelete,
  });

  Color get _priorityColor {
    switch (task.priority) {
      case TaskPriority.high:
        return AppColors.red500;
      case TaskPriority.medium:
        return AppColors.amber500;
      case TaskPriority.low:
        return AppColors.green500;
    }
  }

  String get _priorityLabel {
    switch (task.priority) {
      case TaskPriority.high:
        return 'High';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.low:
        return 'Low';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOverdue = task.isOverdue;
    final isDueSoon = task.isDueSoon;

    return Dismissible(
      key: Key(task.id),
      direction: onDelete == null
          ? DismissDirection.none
          : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
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
      // The task is removed from the list inside onDelete, so the card only
      // slides away when the delete really happened.
      confirmDismiss: (_) => onDelete!(),
      child: GestureDetector(
        onLongPress: () => _showOptions(context),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.dark800 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOverdue
                  ? AppColors.red500.withAlpha(60)
                  : isDueSoon
                  ? AppColors.amber500.withAlpha(60)
                  : (isDark ? AppColors.dark600 : AppColors.gray200),
              width: (isOverdue || isDueSoon) ? 1.5 : 1,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // Left colored bar
              Container(
                width: 5,
                height: 80,
                decoration: BoxDecoration(
                  color: task.isCompleted ? AppColors.green500 : _priorityColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Checkbox
              GestureDetector(
                onTap: onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: task.isCompleted
                        ? AppColors.green500
                        : Colors.transparent,
                    border: Border.all(
                      color: task.isCompleted
                          ? AppColors.green500
                          : (isDark ? AppColors.gray500 : AppColors.gray300),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: task.isCompleted
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 16,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: task.isCompleted
                              ? (isDark ? AppColors.gray500 : AppColors.gray400)
                              : (isDark ? Colors.white : AppColors.gray900),
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: isDark
                              ? AppColors.gray500
                              : AppColors.gray400,
                        ),
                      ),
                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          task.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.gray500
                                : AppColors.gray400,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // Deadline chip
                          _chip(
                            icon: isOverdue
                                ? Icons.warning_rounded
                                : Icons.calendar_today_rounded,
                            label: _deadlineLabel(),
                            color: isOverdue
                                ? AppColors.red500
                                : isDueSoon
                                ? AppColors.amber500
                                : (isDark
                                      ? AppColors.gray400
                                      : AppColors.gray500),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          // Priority chip
                          _chip(
                            icon: Icons.flag_rounded,
                            label: _priorityLabel,
                            color: _priorityColor,
                            isDark: isDark,
                          ),
                          if (task.hasAlarm) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.alarm_rounded,
                              size: 13,
                              color: AppColors.purple600.withAlpha(150),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  String _deadlineLabel() {
    final now = DateTime.now();
    final diff = task.deadline.difference(now);

    if (task.isCompleted) {
      return 'Done ✓';
    }
    if (task.isOverdue) {
      final days = now.difference(task.deadline).inDays;
      return days == 0 ? 'Due today!' : '$days days overdue';
    }
    if (diff.inHours < 24) {
      return 'Due today!';
    }
    if (diff.inDays == 1) {
      return 'Due tomorrow';
    }
    if (diff.inDays <= 7) {
      return 'In ${diff.inDays} days';
    }
    return DateFormat('MMM d').format(task.deadline);
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.dark800 : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.dark500 : AppColors.gray200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.green500,
                ),
                title: Text(
                  task.isCompleted ? 'Mark Incomplete' : 'Mark Complete',
                ),
                onTap: () {
                  Navigator.pop(context);
                  onToggle();
                },
              ),
              if (onDelete != null)
                ListTile(
                  leading: const Icon(
                    Icons.delete_rounded,
                    color: AppColors.red500,
                  ),
                  title: const Text(
                    'Delete Task',
                    style: TextStyle(color: AppColors.red500),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    onDelete!();
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
