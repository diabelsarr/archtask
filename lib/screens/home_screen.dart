import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../utils/app_colors.dart';
import '../widgets/task_card.dart';
import 'add_edit_task_screen.dart';
import 'task_detail_screen.dart';
import 'profile_screen.dart';
import '../services/task_api_service.dart';
import '../services/task_cache_service.dart';
import '../services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _TaskFilter { all, pending, done }

class _HomeScreenState extends State<HomeScreen> {
  _TaskFilter _selectedFilter = _TaskFilter.all;
  TaskPriority? _priorityFilter; // null = toutes les priorités
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  int _currentNavIndex = 0;

  final TaskApiService _apiService = TaskApiService();
  final TaskCacheService _cacheService = TaskCacheService();

  List<Task> _tasks = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  /// Flux attendu par le cahier des charges :
  /// 1. On tente de récupérer les tâches depuis l'API
  /// 2. Si succès -> on les enregistre dans le cache local (Hive)
  /// 3. On relit ensuite depuis le cache local pour afficher la liste
  /// 4. Si hors ligne / API injoignable -> on lit directement le cache local
  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiTasks = await _apiService.getTasks();
      await _cacheService.saveTasks(apiTasks);
      setState(() {
        _tasks = _cacheService.getTasks();
        _isLoading = false;
        _isOffline = false;
      });
      if (await _notificationsEnabled()) {
        await NotificationService.rescheduleAll(_tasks);
      }
    } catch (e) {
      // API injoignable : on retombe sur ce qu'on a en cache local,
      // pour que l'utilisateur puisse quand même voir ses tâches hors ligne.
      final cached = _cacheService.getTasks();
      setState(() {
        _tasks = cached;
        _isLoading = false;
        _isOffline = true;
        _errorMessage = cached.isEmpty
            ? 'Impossible de charger les tâches et aucune donnée locale disponible.'
            : null;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<bool> _notificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('pref_push_notifications') ?? false;
  }

  List<Task> get _filteredTasks {
    Iterable<Task> result = _tasks;

    switch (_selectedFilter) {
      case _TaskFilter.pending:
        result = result.where((t) => !t.isDone);
        break;
      case _TaskFilter.done:
        result = result.where((t) => t.isDone);
        break;
      case _TaskFilter.all:
        break;
    }

    if (_priorityFilter != null) {
      result = result.where((t) => t.priority == _priorityFilter);
    }

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      result = result.where((t) => t.title.toLowerCase().contains(query));
    }

    return result.toList();
  }

  void _toggleTaskDone(Task task, bool? value) async {
    final updated = task.copyWith(isDone: value ?? false);
    // Mise à jour optimiste : on met à jour l'UI et le cache tout de suite,
    // puis on synchronise avec l'API en arrière-plan.
    setState(() {
      final index = _tasks.indexWhere((t) => t.id == task.id);
      _tasks[index] = updated;
    });
    await _cacheService.saveTask(updated);

    // Une tâche faite n'a plus besoin de rappel.
    if (updated.isDone) {
      await NotificationService.cancelTaskReminder(updated);
    } else if (await _notificationsEnabled()) {
      await NotificationService.scheduleTaskReminder(updated);
    }

    try {
      await _apiService.updateTask(task.id, updated);
    } catch (e) {
      // En cas d'échec, on annule le changement visuel/cache et on informe l'utilisateur.
      setState(() {
        final index = _tasks.indexWhere((t) => t.id == task.id);
        _tasks[index] = task;
      });
      await _cacheService.saveTask(task);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Échec de la mise à jour, réessaie.')),
        );
      }
    }
  }

  void _openTaskDetails(Task task) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)),
    );

    if (result == 'deleted') {
      try {
        await _apiService.deleteTask(task.id);
        await _cacheService.deleteTask(task.id);
        await NotificationService.cancelTaskReminder(task);
        setState(() => _tasks.removeWhere((t) => t.id == task.id));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Échec de la suppression, réessaie.')),
          );
        }
      }
    } else if (result is Task) {
      try {
        final updated = await _apiService.updateTask(task.id, result);
        await _cacheService.saveTask(updated);
        // Réajuste le rappel programmé (nouvelle date ou statut fait/pas fait).
        await NotificationService.cancelTaskReminder(task);
        if (!updated.isDone && await _notificationsEnabled()) {
          await NotificationService.scheduleTaskReminder(updated);
        }
        setState(() {
          final index = _tasks.indexWhere((t) => t.id == updated.id);
          _tasks[index] = updated;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Échec de la modification, réessaie.')),
          );
        }
      }
    }
  }

  void _openAddTask() async {
    final newTask = await Navigator.push<Task>(
      context,
      MaterialPageRoute(builder: (_) => const AddEditTaskScreen()),
    );
    if (newTask != null) {
      try {
        final created = await _apiService.createTask(newTask);
        await _cacheService.saveTask(created);
        if (!created.isDone && await _notificationsEnabled()) {
          await NotificationService.scheduleTaskReminder(created);
        }
        setState(() => _tasks.add(created));
      } catch (e) {
        print('ERREUR CREATION: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Échec de la création, réessaie.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHomeTab = _currentNavIndex == 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (isHomeTab) ...[
              if (_isSearching) _buildSearchBar(),
              if (_isOffline && !_isLoading) _buildOfflineBanner(),
              _buildFilterTabs(),
              _buildPriorityFilterChips(),
              Expanded(child: _buildBody()),
            ] else
              Expanded(child: _buildStatsView()),
          ],
        ),
      ),
      floatingActionButton: isHomeTab
          ? FloatingActionButton(
              onPressed: _openAddTask,
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  /// Calcule le nombre de tâches par jour de la semaine en cours
  /// (lundi à dimanche), basé sur leur date d'échéance.
  Map<int, int> _weeklyVolumeByWeekday() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeek = DateTime(monday.year, monday.month, monday.day);
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    final counts = <int, int>{for (var i = 1; i <= 7; i++) i: 0};
    for (final task in _tasks) {
      if (task.dueDate.isAfter(startOfWeek) &&
          task.dueDate.isBefore(endOfWeek)) {
        counts[task.dueDate.weekday] = (counts[task.dueDate.weekday] ?? 0) + 1;
      }
    }
    return counts;
  }

  Widget _buildStatsView() {
    final total = _tasks.length;
    final completed = _tasks.where((t) => t.isDone).length;
    final percentage = total == 0 ? 0.0 : completed / total;
    final weeklyVolume = _weeklyVolumeByWeekday();
    final maxVolume = weeklyVolume.values.isEmpty
        ? 1
        : weeklyVolume.values.reduce((a, b) => a > b ? a : b).clamp(1, 999);
    final weekdayLabels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Overview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // Carte "Tasks Completed" avec cercle de progression
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.inputBorder),
            ),
            child: Column(
              children: [
                const Text(
                  'Tasks Completed',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: CircularProgressIndicator(
                          value: percentage,
                          strokeWidth: 12,
                          backgroundColor: AppColors.inputFill,
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(percentage * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            total == 0 ? 'Aucune Tache' : '$completed / $total',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textLabel),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Carte "Weekly Volume"
          Container(
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Votre programme de la semaine',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Total: $total',
                      style: TextStyle(fontSize: 12, color: AppColors.textLabel),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 120,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(7, (index) {
                      final weekday = index + 1;
                      final count = weeklyVolume[weekday] ?? 0;
                      final barHeight =
                          count == 0 ? 4.0 : (count / maxVolume) * 90;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (count > 0)
                            Text('$count',
                                style: TextStyle(
                                    fontSize: 10, color: AppColors.textLabel)),
                          const SizedBox(height: 4),
                          Container(
                            width: 20,
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: count > 0
                                  ? AppColors.primary
                                  : AppColors.inputFill,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            weekdayLabels[index],
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textLabel),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, size: 40, color: AppColors.textPlaceholder),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textLabel),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadTasks,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredTasks.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredTasks.length,
        itemBuilder: (context, index) {
          final task = _filteredTasks[index];
          return TaskCard(
            task: task,
            onToggleDone: (value) => _toggleTaskDone(task, value),
            onTap: () => _openTaskDetails(task),
          );
        },
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      color: AppColors.priorityMedium.withOpacity(0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.wifi_off, size: 14, color: AppColors.priorityMedium),
          const SizedBox(width: 6),
          Text(
            'Hors ligne — données locales affichées',
            style: TextStyle(fontSize: 12, color: AppColors.priorityMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(Icons.menu, color: AppColors.textPrimary),
          Text(
            'ArchTask',
            style: AppTextStyles.title.copyWith(
              fontSize: 18,
              color: AppColors.primary,
            ),
          ),
          Row(
            children: [
              if (_currentNavIndex == 0) ...[
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isSearching = !_isSearching;
                      if (!_isSearching) {
                        _searchController.clear();
                        _searchQuery = '';
                      }
                    });
                  },
                  child: Icon(
                    _isSearching ? Icons.close : Icons.search,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
                child: const CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.inputFill,
                  child:
                      Icon(Icons.person, size: 18, color: AppColors.textLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Rechercher une tâche par titre...',
          hintStyle: TextStyle(color: AppColors.textPlaceholder),
          prefixIcon: Icon(Icons.search, color: AppColors.textLabel),
          filled: true,
          fillColor: AppColors.inputFill,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityFilterChips() {
    Widget chip(String label, TaskPriority? priority, Color? dotColor) {
      final isSelected = _priorityFilter == priority;
      return GestureDetector(
        onTap: () => setState(() => _priorityFilter = priority),
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.inputFill,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: dotColor),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textLabel,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            chip('Toutes priorités', null, null),
            chip('Élevée', TaskPriority.high, AppColors.priorityHigh),
            chip('Moyenne', TaskPriority.medium, AppColors.priorityMedium),
            chip('Basse', TaskPriority.low, AppColors.priorityLow),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    Widget tab(String label, _TaskFilter filter) {
      final isSelected = _selectedFilter == filter;
      return GestureDetector(
        onTap: () => setState(() => _selectedFilter = filter),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          margin: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.primary : AppColors.textLabel,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          tab('Tout', _TaskFilter.all),
          tab('En attente', _TaskFilter.pending),
          tab('Effectué', _TaskFilter.done),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline,
              size: 48, color: AppColors.textPlaceholder),
          const SizedBox(height: 12),
          Text(
            'Pas de tache ici',
            style: TextStyle(color: AppColors.textPlaceholder),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    Widget navItem(IconData icon, String label, int index) {
      final isSelected = _currentNavIndex == index;
      return GestureDetector(
        onTap: () => setState(() => _currentNavIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: isSelected
                ? null
                : Border.all(color: AppColors.inputBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 18,
                  color: isSelected ? Colors.white : AppColors.textLabel),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? Colors.white : AppColors.textLabel,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.inputBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          navItem(Icons.home, 'Home', 0),
          navItem(Icons.bar_chart, 'Stats', 1),
        ],
      ),
    );
  }
}
