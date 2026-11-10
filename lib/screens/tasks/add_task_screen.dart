import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/ui_helpers.dart';
import '../../providers/task_provider.dart';
import '../../widgets/gradient_button.dart';

/// What the user typed into the New Task sheet.
typedef TaskDraft = ({
  String title,
  String description,
  DateTime deadline,
  TaskPriority priority,
  bool hasAlarm,
});

/// Bottom sheet for creating a task. Creates a personal task unless
/// [onCreate] is given (used for server tasks, which the owner creates through
/// the server screen). Throwing from [onCreate] keeps the sheet open and shows
/// the error.
class AddTaskSheet extends StatefulWidget {
  final Future<void> Function(TaskDraft draft)? onCreate;
  final String heading;
  const AddTaskSheet({super.key, this.onCreate, this.heading = 'New Task ✨'});

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  DateTime _deadline = DateTime.now().add(const Duration(days: 1));
  TaskPriority _priority = TaskPriority.medium;
  bool _hasAlarm = true;
  bool _isSaving = false;

  static const _priorityLabels = ['Low', 'Medium', 'High'];
  static const _priorityColors = [
    AppColors.green500,
    AppColors.amber500,
    AppColors.red500,
  ];
  static const _priorityIcons = [
    Icons.keyboard_arrow_down_rounded,
    Icons.remove_rounded,
    Icons.keyboard_arrow_up_rounded,
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.purple600,
            onPrimary: Colors.white,
            surface: Theme.of(ctx).brightness == Brightness.dark
                ? AppColors.dark800
                : Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      if (!mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_deadline),
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.purple600,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        ),
      );
      if (mounted) {
        setState(() {
          _deadline = DateTime(
            picked.year,
            picked.month,
            picked.day,
            pickedTime?.hour ?? _deadline.hour,
            pickedTime?.minute ?? _deadline.minute,
          );
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final draft = (
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      deadline: _deadline,
      priority: _priority,
      hasAlarm: _hasAlarm,
    );

    try {
      final onCreate = widget.onCreate;
      if (onCreate != null) {
        await onCreate(draft);
      } else {
        await context.read<TaskProvider>().addTask(
          title: draft.title,
          description: draft.description,
          deadline: draft.deadline,
          priority: draft.priority,
          hasAlarm: draft.hasAlarm,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.dark800 : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.dark500 : AppColors.gray200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                widget.heading,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.gray900,
                ),
              ),
              const SizedBox(height: 20),
              // Title
              _label('Task Title', isDark),
              const SizedBox(height: 7),
              TextFormField(
                controller: _titleCtrl,
                inputFormatters: [LengthLimitingTextInputFormatter(255)],
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Title is required'
                    : null,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.gray900,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                decoration: const InputDecoration(
                  hintText: 'What needs to be done?',
                  prefixIcon: Icon(
                    Icons.edit_note_rounded,
                    color: AppColors.purple600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Description
              _label('Description (optional)', isDark),
              const SizedBox(height: 7),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.gray900,
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  hintText: 'Add details about this task...',
                  prefixIcon: Icon(
                    Icons.notes_rounded,
                    color: AppColors.gray400,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Deadline
              _label('Deadline', isDark),
              const SizedBox(height: 7),
              GestureDetector(
                onTap: _pickDeadline,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.dark700 : AppColors.gray50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppColors.dark500 : AppColors.gray200,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        color: AppColors.purple600,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatDeadline(_deadline),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.gray800,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: isDark ? AppColors.gray500 : AppColors.gray400,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Priority
              _label('Priority', isDark),
              const SizedBox(height: 10),
              Row(
                children: List.generate(3, (i) {
                  final prio = TaskPriority.values[i];
                  final active = _priority == prio;
                  final color = _priorityColors[i];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _priority = prio),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: EdgeInsets.only(right: i < 2 ? 10 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: active
                              ? color.withAlpha(30)
                              : (isDark ? AppColors.dark700 : AppColors.gray50),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: active
                                ? color
                                : (isDark
                                      ? AppColors.dark500
                                      : AppColors.gray200),
                            width: active ? 2 : 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(_priorityIcons[i], color: color, size: 20),
                            const SizedBox(height: 4),
                            Text(
                              _priorityLabels[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: active
                                    ? color
                                    : (isDark
                                          ? AppColors.gray400
                                          : AppColors.gray500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              // Alarm toggle
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.dark700 : AppColors.purple50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.dark500 : AppColors.purple200,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.alarm_rounded,
                      color: AppColors.purple600,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enable Reminders',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.gray800,
                            ),
                          ),
                          Text(
                            '3 daily reminders, 3 days before deadline',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.gray400
                                  : AppColors.gray500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _hasAlarm,
                      onChanged: (v) => setState(() => _hasAlarm = v),
                      activeTrackColor: AppColors.purple600,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              GradientButton(
                label: _isSaving ? 'Saving...' : 'Add Task',
                icon: Icons.add_task_rounded,
                onTap: _isSaving ? null : _save,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.gray200 : AppColors.gray700,
      ),
    );
  }

  String _formatDeadline(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour < 12 ? 'AM' : 'PM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $hour:$min $period';
  }
}
