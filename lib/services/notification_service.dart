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

  /// Délai avant l'échéance auquel on prévient l'utilisateur.
  static const Duration leadTime = Duration(minutes: 10);

  /// Demande (si besoin) l'autorisation d'alarmes exactes (Android 12+).
  static Future<bool> _canUseExact() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return false;
    var ok = await androidImpl.canScheduleExactNotifications() ?? false;
    if (!ok) {
      await androidImpl.requestExactAlarmsPermission();
      ok = await androidImpl.canScheduleExactNotifications() ?? false;
    }
    return ok;
  }

  /// Programme un rappel [leadTime] avant l'échéance de la tâche.
  /// Si l'échéance est trop proche, le rappel part dans quelques secondes.
  static Future<void> scheduleTaskReminder(Task task) async {
    final now = DateTime.now();
    if (task.isDone || !task.dueDate.isAfter(now)) return;

    var remindAt = task.dueDate.subtract(leadTime);
    if (!remindAt.isAfter(now)) {
      remindAt = now.add(const Duration(seconds: 5));
    }
    final scheduledDate = tz.TZDateTime.from(remindAt, tz.local);
    final minutes = task.dueDate.difference(remindAt).inMinutes;

    final exact = await _canUseExact();

    await _plugin.zonedSchedule(
      id: task.id.hashCode,
      title: 'Bientôt : ${task.title}',
      body: minutes > 0
          ? 'Échéance dans environ $minutes min.'
          : 'C\'est l\'heure de t\'en occuper !',
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Rappels de tâches',
          channelDescription: 'Notifications de rappel pour vos tâches',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Reprogramme les rappels de toutes les tâches à venir (après un
  /// chargement de la liste, un redémarrage ou l'activation du switch).
  static Future<void> rescheduleAll(List<Task> tasks) async {
    await _plugin.cancelAll();
    for (final t in tasks) {
      await scheduleTaskReminder(t);
    }
  }

  /// Annule le rappel programmé pour une tâche (ex: supprimée ou faite).
  static Future<void> cancelTaskReminder(Task task) async {
    await _plugin.cancel(id: task.id.hashCode);
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
