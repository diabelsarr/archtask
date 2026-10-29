import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../utils/app_colors.dart';

/// Écran unique pour Ajouter ET Modifier une tâche.
/// Si [taskToEdit] est null -> mode création.
/// Si [taskToEdit] est fourni -> mode modification (champs pré-remplis,
/// titre de la page adapté).
class AddEditTaskScreen extends StatefulWidget {
  final Task? taskToEdit;

  const AddEditTaskScreen({super.key, this.taskToEdit});

  bool get isEditing => taskToEdit != null;

  @override
  State<AddEditTaskScreen> createState() => _AddEditTaskScreenState();
}

class _AddEditTaskScreenState extends State<AddEditTaskScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late TaskPriority _selectedPriority;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    final task = widget.taskToEdit;
    _titleController = TextEditingController(text: task?.title ?? '');
    _notesController = TextEditingController(text: task?.content ?? '');
    _selectedPriority = task?.priority ?? TaskPriority.medium;
    _selectedDate = task?.dueDate;
    _selectedTime = task != null
        ? TimeOfDay(hour: task.dueDate.hour, minute: task.dueDate.minute)
        : null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _handleSubmit() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un titre')),
      );
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir une date')),
      );
      return;
    }
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir une heure')),
      );
      return;
    }

    final combinedDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final result = Task(
      id: widget.taskToEdit?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      content: _notesController.text.trim(),
      dueDate: combinedDateTime,
      priority: _selectedPriority,
      isDone: widget.taskToEdit?.isDone ?? false,
    );

    Navigator.pop(context, result);
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre de la tâche
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Titre de votre Tache',
                        hintStyle: TextStyle(
                          fontSize: 20,
                          color: AppColors.textPlaceholder,
                        ),
                        border: InputBorder.none,
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.inputBorder),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    Text('Priorité', style: AppTextStyles.label),
                    const SizedBox(height: 10),
                    _buildPrioritySelector(),
                    const SizedBox(height: 24),

                    Text('Date', style: AppTextStyles.label),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(flex: 3, child: _buildDateField()),
                        const SizedBox(width: 10),
                        Expanded(flex: 2, child: _buildTimeField()),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Text('NOTES (OPTIONAL)', style: AppTextStyles.label),
                    const SizedBox(height: 10),
                    _buildNotesField(),
                  ],
                ),
              ),
            ),
            _buildSubmitButton(),
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
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: const Icon(Icons.close, size: 18),
            ),
          ),
          Expanded(
            child: Text(
              widget.isEditing ? 'Modifier ' : 'Nouvele Tache',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 30), // équilibre visuel avec le bouton close
        ],
      ),
    );
  }

  Widget _buildPrioritySelector() {
    Widget priorityButton(TaskPriority priority, Color color) {
      final isSelected = _selectedPriority == priority;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _selectedPriority = priority),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.15) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? color : AppColors.inputBorder,
              ),
            ),
            child: Text(
              priority.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : AppColors.textLabel,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        priorityButton(TaskPriority.high, AppColors.priorityHigh),
        priorityButton(TaskPriority.medium, AppColors.priorityMedium),
        priorityButton(TaskPriority.low, AppColors.priorityLow),
      ],
    );
  }

  Widget _buildDateField() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedDate == null
                  ? 'dd/mm/yyyy'
                  : '${_selectedDate!.day.toString().padLeft(2, '0')}/'
                      '${_selectedDate!.month.toString().padLeft(2, '0')}/'
                      '${_selectedDate!.year}',
              style: TextStyle(
                color: _selectedDate == null
                    ? AppColors.textPlaceholder
                    : AppColors.textPrimary,
              ),
            ),
            Icon(Icons.calendar_today, size: 18, color: AppColors.textLabel),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeField() {
    return GestureDetector(
      onTap: _pickTime,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedTime == null
                  ? '--:--'
                  : _selectedTime!.format(context),
              style: TextStyle(
                color: _selectedTime == null
                    ? AppColors.textPlaceholder
                    : AppColors.textPrimary,
              ),
            ),
            Icon(Icons.access_time, size: 18, color: AppColors.textLabel),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: TextField(
        controller: _notesController,
        maxLines: 4,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Ajouter des details...',
          hintStyle: TextStyle(color: AppColors.textPlaceholder),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _handleSubmit,
          icon: Icon(
            widget.isEditing ? Icons.check : Icons.add_task,
            color: Colors.white,
            size: 20,
          ),
          label: Text(
            widget.isEditing ? 'Sauvegarder ' : 'Créer une Tache',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }
}
