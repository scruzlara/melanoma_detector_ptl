import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service de gestion du thème (clair / sombre / système).
///
/// Étend [ChangeNotifier] pour permettre aux widgets de réagir
/// à chaque changement de mode. La préférence utilisateur est
/// persistée via [SharedPreferences] et restaurée au démarrage.
///
/// Utilisation :
/// ```dart
/// final themeService = ThemeService();
/// await themeService.init(); // charger la préférence enregistrée
/// ```
class ThemeService extends ChangeNotifier {
  /// Clé de persistance dans SharedPreferences.
  static const String _prefKey = 'theme_mode';

  /// Mode de thème actuel (système par défaut).
  ThemeMode _themeMode = ThemeMode.system;

  /// Retourne le mode de thème actuel.
  ThemeMode get themeMode => _themeMode;

  /// Indique si le thème sombre est explicitement actif.
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Indique si le thème suit les préférences du système.
  bool get isSystemMode => _themeMode == ThemeMode.system;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Charge la préférence de thème enregistrée.
  ///
  /// Doit être appelé au démarrage de l'application, avant le premier
  /// rendu, pour éviter un flash de thème incorrect.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKey);

    if (stored != null) {
      _themeMode = _fromString(stored);
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Basculement du thème
  // ---------------------------------------------------------------------------

  /// Bascule entre les trois modes dans l'ordre : système → clair → sombre.
  ///
  /// Persiste automatiquement la préférence.
  Future<void> toggleTheme() async {
    switch (_themeMode) {
      case ThemeMode.system:
        await setThemeMode(ThemeMode.light);
      case ThemeMode.light:
        await setThemeMode(ThemeMode.dark);
      case ThemeMode.dark:
        await setThemeMode(ThemeMode.system);
    }
  }

  /// Définit un mode de thème spécifique et persiste la préférence.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _toString(mode));
  }

  // ---------------------------------------------------------------------------
  // Icône contextuelle pour le bouton de basculement
  // ---------------------------------------------------------------------------

  /// Retourne l'icône correspondant au mode actuel.
  ///
  /// - Système → icône « luminosité automatique »
  /// - Clair   → icône « soleil »
  /// - Sombre  → icône « lune »
  IconData get themeIcon {
    switch (_themeMode) {
      case ThemeMode.system:
        return Icons.brightness_auto_outlined;
      case ThemeMode.light:
        return Icons.light_mode_outlined;
      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
    }
  }

  /// Retourne le libellé (tooltip) décrivant le mode actuel.
  String get themeTooltip {
    switch (_themeMode) {
      case ThemeMode.system:
        return 'Thème : Système';
      case ThemeMode.light:
        return 'Thème : Clair';
      case ThemeMode.dark:
        return 'Thème : Sombre';
    }
  }

  // ---------------------------------------------------------------------------
  // Sérialisation
  // ---------------------------------------------------------------------------

  /// Convertit un [ThemeMode] en chaîne pour la persistance.
  static String _toString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
    }
  }

  /// Convertit une chaîne persistée en [ThemeMode].
  static ThemeMode _fromString(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
