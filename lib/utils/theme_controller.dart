import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contrôleur global du thème (mode sombre/clair/auto).
/// Un seul ValueNotifier partagé par toute l'app : quand sa valeur change,
/// MaterialApp se reconstruit automatiquement avec le nouveau thème.
class ThemeController {
  static const _key = 'pref_theme_mode';

  static final ValueNotifier<ThemeMode> mode =
      ValueNotifier(ThemeMode.system);

  /// À appeler une fois au démarrage de l'app pour restaurer le choix
  /// précédent de l'utilisateur.
  static Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    switch (saved) {
      case 'light':
        mode.value = ThemeMode.light;
        break;
      case 'dark':
        mode.value = ThemeMode.dark;
        break;
      default:
        mode.value = ThemeMode.system; // "Auto"
    }
  }

  static Future<void> setMode(ThemeMode newMode) async {
    mode.value = newMode;
    final prefs = await SharedPreferences.getInstance();
    final value = switch (newMode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'auto',
    };
    await prefs.setString(_key, value);
  }
}
