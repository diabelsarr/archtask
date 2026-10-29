import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/task_model.dart';
import '../utils/app_colors.dart';
import 'add_edit_task_screen.dart';

/// Écran de détails d'une tâche.
/// Retourne à l'écran précédent :
/// - la tâche mise à jour si modifiée ou marquée comme faite
/// - la chaîne 'deleted' si l'utilisateur a supprimé la tâche
class TaskDetailScreen extends StatefulWidget {
  final Task task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late Task _task;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
  }

  Color get _priorityColor {
    switch (_task.priority) {
      case TaskPriority.high:
        return AppColors.priorityHigh;
      case TaskPriority.medium:
        return AppColors.priorityMedium;
      case TaskPriority.low:
        return AppColors.priorityLow;
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${months[date.month - 1]} ${date.day}, ${date.year} à $hour:$minute';
  }

  Future<void> _goToEdit() async {
    final updatedTask = await Navigator.push<Task>(
      context,
      MaterialPageRoute(builder: (_) => AddEditTaskScreen(taskToEdit: _task)),
    );
    if (updatedTask != null) {
      setState(() => _task = updatedTask);
    }
  }

  void _toggleDone() {
    setState(() => _task = _task.copyWith(isDone: !_task.isDone));
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer une Tache'),
        content: const Text(
            'Vous etes sure de vouloir supprimer cette tache?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.pop(context, 'deleted');
    }
  }

  void _shareTask() {
    final buffer = StringBuffer()
      ..writeln('📋 ${_task.title}')
      ..writeln()
      ..writeln('Priorité : ${_task.priority.label}')
      ..writeln('Échéance : ${_formatDate(_task.dueDate)}');

    if (_task.content.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(_task.content);
    }

    buffer
      ..writeln()
      ..write('Partagé depuis ArchTask');

    Share.share(buffer.toString(), subject: _task.title);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 4, right: 10),
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _priorityColor,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _task.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Text('Description', style: AppTextStyles.label),
                      const SizedBox(height: 6),
                      Text(
                        _task.content.isEmpty
                            ? 'Pas de notes additionelles.'
                            : _task.content,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: _infoBlock(
                              'A Faire avant',
                              _formatDate(_task.dueDate),
                            ),
                          ),
                          Expanded(
                            child: _infoBlock(
                              'Priorité',
                              null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _priorityColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _task.priority.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _priorityColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _infoBlock(
                        'STATUT',
                        _task.isDone ? 'Effectué' : 'En Cours',
                        valueColor:
                            _task.isDone ? AppColors.priorityLow : AppColors.primary,
                      ),
                      const SizedBox(height: 28),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _toggleDone,
                          icon: Icon(
                            _task.isDone
                                ? Icons.replay
                                : Icons.check_circle_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                          label: Text(
                            _task.isDone ? 'Marquer en Attente' : 'Valider',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _goToEdit,
                          icon: Icon(Icons.edit_outlined,
                              size: 18, color: AppColors.primary),
                          label: Text(
                            'Modifier une Tache',
                            style: TextStyle(color: AppColors.primary),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: _confirmDelete,
                          child: const Text(
                            'Supprimer une Tache',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context, _task),
            child: Row(
              children: [
                const Icon(Icons.arrow_back, size: 20, color: AppColors.primary),
                const SizedBox(width: 4),
                Text('Back', style: TextStyle(color: AppColors.primary)),
              ],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _shareTask,
            child: Icon(Icons.share_outlined, color: AppColors.textLabel),
          ),
        ],
      ),
    );
  }

  Widget _infoBlock(String label, String? value,
      {Widget? child, Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 6),
        child ??
            Text(
              value ?? '',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
      ],
    );
  }
}
