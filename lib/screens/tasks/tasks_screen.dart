import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/task_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/task_card.dart';
import 'add_task_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _filterIndex = 0; // 0=All, 1=Today, 2=Upcoming, 3=Completed

  final List<String> _filters = ['All', 'Today', 'Upcoming', 'Done'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filters.length, vsync: this);
    _tabController.addListener(() {
      setState(() => _filterIndex = _tabController.index);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<TaskModel> _filteredTasks(List<TaskModel> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_filterIndex) {
      case 1: // Today
        return tasks.where((t) {
          final d = t.deadline;
          return !t.isCompleted && DateTime(d.year, d.month, d.day) == today;
        }).toList();
      case 2: // Upcoming
        return tasks
            .where((t) => !t.isCompleted && t.deadline.isAfter(now))
            .toList();
      case 3: // Done
        return tasks.where((t) => t.isCompleted).toList();
      default: // All
        return tasks.where((t) => !t.isCompleted).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final taskProv = context.watch<TaskProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.userModel;

    return Scaffold(
      backgroundColor: isDark ? AppColors.dark900 : AppColors.gray50,
      body: RefreshIndicator(
        color: AppColors.purple600,
        onRefresh: taskProv.sync,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(isDark, user?.fullName ?? 'User'),
            SliverToBoxAdapter(child: _buildSummaryRow(isDark, taskProv)),
            SliverToBoxAdapter(child: _buildFilterTabs(isDark)),
            if (taskProv.isLoading)
              const SliverFillRemaining(child: BrandSpinner())
            else
              _buildTaskList(isDark, taskProv),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTask(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New Task',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.purple600,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildAppBar(bool isDark, String name) {
    final greeting = _greeting();
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: false,
      backgroundColor: isDark ? AppColors.dark900 : AppColors.gray50,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting,',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.gray400 : AppColors.gray500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      name.split(' ').first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.gray900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(bool isDark, TaskProvider taskProv) {
    final stats = [
      _StatItem(
        label: 'Total',
        value: taskProv.tasks.length.toString(),
        color: AppColors.purple600,
        icon: Icons.list_alt_rounded,
      ),
      _StatItem(
        label: 'Pending',
        value: taskProv.pendingTasks.length.toString(),
        color: AppColors.amber500,
        icon: Icons.pending_actions_rounded,
      ),
      _StatItem(
        label: 'Overdue',
        value: taskProv.overdueTasks.length.toString(),
        color: AppColors.red500,
        icon: Icons.warning_rounded,
      ),
      _StatItem(
        label: 'Done',
        value: taskProv.completedTasks.length.toString(),
        color: AppColors.green500,
        icon: Icons.check_circle_rounded,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: stats
            .map((s) => Expanded(child: _buildStatCard(s, isDark)))
            .toList(),
      ),
    );
  }

  Widget _buildStatCard(_StatItem stat, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: stat.color.withAlpha(isDark ? 30 : 20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: stat.color.withAlpha(isDark ? 50 : 40),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(stat.icon, color: stat.color, size: 20),
          const SizedBox(height: 4),
          Text(
            stat.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: stat.color,
            ),
          ),
          Text(
            stat.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.gray400 : AppColors.gray500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_filters.length, (i) {
            final active = _filterIndex == i;
            return GestureDetector(
              onTap: () {
                _tabController.animateTo(i);
                setState(() => _filterIndex = i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  gradient: active ? AppColors.primaryGradient : null,
                  color: active
                      ? null
                      : isDark
                      ? AppColors.dark700
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active
                        ? AppColors.purple600
                        : (isDark ? AppColors.dark500 : AppColors.gray200),
                    width: 1.5,
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: AppColors.purple600.withAlpha(40),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  _filters[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? Colors.white
                        : (isDark ? AppColors.gray400 : AppColors.gray600),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTaskList(bool isDark, TaskProvider taskProv) {
    final filtered = _filteredTasks(taskProv.tasks);

    if (filtered.isEmpty) {
      return SliverFillRemaining(child: _buildEmptyState(isDark));
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TaskCard(
              task: filtered[i],
              onToggle: () => taskProv.toggleComplete(filtered[i].id),
              onDelete: () => _confirmDelete(filtered[i]),
            ),
          ),
          childCount: filtered.length,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.purple600.withAlpha(15),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.task_alt_rounded,
              size: 44,
              color: AppColors.purple600.withAlpha(150),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No tasks here!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.gray800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap + to add a new task',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.gray400 : AppColors.gray500,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTask(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddTaskSheet(),
    );
  }

  /// Asks first, then deletes. Returns true if the task was deleted.
  Future<bool> _confirmDelete(TaskModel task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
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
    if (confirmed != true || !mounted) return false;
    await context.read<TaskProvider>().deleteTask(task.id);
    return true;
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _StatItem {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
}
