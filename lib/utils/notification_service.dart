import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../models/task_model.dart';

/// Gère les notifications locales liées aux tâches : demande de
/// permission, programmation d'un rappel à la date d'échéance, et
/// annulation quand une tâche est terminée/modifiée/supprimée.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// À appeler une fois au démarrage de l'app.
  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    //await _plugin.initialize(settings);
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  /// Demande la permission de notifier (obligatoire sur Android 13+).
  /// Retourne true si accordée.
  static Future<bool> requestPermission() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await androidImpl?.requestNotificationsPermission();
    return granted ?? false;
  }

  /// Programme un rappel pour une tâche, à sa date d'échéance exacte.
  /// N'a d'effet que si la date est dans le futur.
  static Future<void> scheduleTaskReminder(Task task) async {
    if (task.dueDate.isBefore(DateTime.now())) return;

    final scheduledDate = tz.TZDateTime.from(task.dueDate, tz.local);

    await _plugin.zonedSchedule(
      id: task.id.hashCode,
      title: 'Tâche à échéance : ${task.title}',
      body: task.content.isEmpty ? 'Il est temps de t\'en occuper !' : task.content,
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Rappels de tâches',
          channelDescription: 'Notifications de rappel pour vos tâches',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Annule le rappel programmé pour une tâche (ex: supprimée ou faite).
  static Future<void> cancelTaskReminder(Task task) async {
    await _plugin.cancel(id: task.id.hashCode);
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
