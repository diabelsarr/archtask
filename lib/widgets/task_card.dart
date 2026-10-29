import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../utils/app_colors.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final ValueChanged<bool?> onToggleDone;
  final VoidCallback onTap;

  const TaskCard({
    super.key,
    required this.task,
    required this.onToggleDone,
    required this.onTap,
  });

  Color get _priorityColor {
    switch (task.priority) {
      case TaskPriority.high:
        return AppColors.priorityHigh;
      case TaskPriority.medium:
        return AppColors.priorityMedium;
      case TaskPriority.low:
        return AppColors.priorityLow;
    }
  }

  String get _timeLabel {
    final hour = task.dueDate.hour.toString().padLeft(2, '0');
    final minute = task.dueDate.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String get _dueLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
    final diff = due.difference(today).inDays;

    if (diff == 0) return 'Aujourd\'hui, $_timeLabel';
    if (diff == 1) return 'Demain, $_timeLabel';
    if (diff < 0) return 'En retard, $_timeLabel';
    return '${task.dueDate.day}/${task.dueDate.month}/${task.dueDate.year}, $_timeLabel';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: task.isDone ? AppColors.inputFill : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: task.isDone ? Colors.transparent : AppColors.inputBorder,
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: task.isDone,
              activeColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              onChanged: onToggleDone,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: task.isDone
                          ? AppColors.textPlaceholder
                          : AppColors.textPrimary,
                      decoration:
                          task.isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: task.isDone
                              ? AppColors.inputBorder
                              : _priorityColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          task.priority.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: task.isDone
                                ? AppColors.textPlaceholder
                                : _priorityColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.calendar_today,
                          size: 12, color: AppColors.textPlaceholder),
                      const SizedBox(width: 4),
                      Text(
                        _dueLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textPlaceholder,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
