import 'package:hive_flutter/hive_flutter.dart';
import '../models/task_model.dart';
import '../models/task_hive_adapter.dart';

/// Gère le stockage local des tâches avec Hive.
/// Sert de "source de vérité hors ligne" : l'API alimente ce cache,
/// et l'écran de liste lit toujours depuis ce cache (jamais directement
/// depuis l'API), comme demandé dans le cahier des charges.
class TaskCacheService {
  static const String _boxName = 'tasksBox';

  /// À appeler une seule fois au démarrage de l'app, avant runApp().
  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(TaskPriorityAdapter());
    Hive.registerAdapter(TaskAdapter());
    await Hive.openBox<Task>(_boxName);
  }

  Box<Task> get _box => Hive.box<Task>(_boxName);

  /// Remplace tout le cache par la liste donnée (utilisé après un
  /// rafraîchissement réussi depuis l'API).
  Future<void> saveTasks(List<Task> tasks) async {
    await _box.clear();
    final Map<String, Task> entries = {for (final t in tasks) t.id: t};
    await _box.putAll(entries);
  }

  /// Ajoute ou met à jour une seule tâche dans le cache.
  Future<void> saveTask(Task task) async {
    await _box.put(task.id, task);
  }

  /// Supprime une tâche du cache.
  Future<void> deleteTask(String id) async {
    await _box.delete(id);
  }

  /// Lit toutes les tâches actuellement en cache (utilisé si hors ligne,
  /// ou juste après une synchronisation API réussie).
  List<Task> getTasks() {
    return _box.values.toList();
  }
}
