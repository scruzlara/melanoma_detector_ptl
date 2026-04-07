import 'package:flutter/material.dart';

/// Thème de l'application Détecteur de Mélanome.
///
/// Fournit un thème clair et un thème sombre basés sur Material 3,
/// avec des couleurs sémantiques médicales optimisées pour chaque mode.
///
/// Les couleurs de risque sont soigneusement choisies pour garantir
/// un contraste élevé et une lisibilité optimale sur fond clair ET sombre.
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Couleurs de risque médical — Mode Clair
  // ---------------------------------------------------------------------------

  /// Vert foncé — Bénin (mode clair).
  static const Color riskLowLight = Color(0xFF2E7D32);

  /// Ambre foncé — Suspect (mode clair).
  static const Color riskModerateLight = Color(0xFFE65100);

  /// Rouge foncé — Mélanome (mode clair).
  static const Color riskHighLight = Color(0xFFB71C1C);

  // ---------------------------------------------------------------------------
  // Couleurs de risque médical — Mode Sombre
  // ---------------------------------------------------------------------------

  /// Vert lumineux — Bénin (mode sombre). Choisi pour contraster
  /// suffisamment sur surfaces sombres (ratio ≥ 4.5:1).
  static const Color riskLowDark = Color(0xFF66BB6A);

  /// Ambre lumineux — Suspect (mode sombre). Plus vif que le mode clair
  /// pour rester lisible sur fond foncé.
  static const Color riskModerateDark = Color(0xFFFFB74D);

  /// Rouge corail — Mélanome (mode sombre). Tons plus clairs pour
  /// maintenir la lisibilité sans éblouir.
  static const Color riskHighDark = Color(0xFFEF5350);

  // ---------------------------------------------------------------------------
  // Couleurs Hybrides (P6/P7)
  // ---------------------------------------------------------------------------

  static const Color accentCyan = Color(0xFF00BCD4);

  // P7 Online mode colors (used by AnalysisScreen)
  static const Color primaryDark = Color(0xFF0D1B2A);
  static const Color primaryMedium = Color(0xFF1B263B);
  static const Color primaryLight = Color(0xFF415A77);
  static const Color accentTeal = Color(0xFF26A69A);
  static const Color riskHighConst = Color(0xFFEF5350);
  static const Color riskMediumConst = Color(0xFFFFB74D);
  static const Color riskLowConst = Color(0xFF66BB6A);
  static const Color riskUnknown = Color(0xFF9E9E9E);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color textMuted = Color(0xFF78909C);
  static const Color surfaceCard = Color(0xFF1E3A5F);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D47A1), Color(0xFF00BCD4)],
  );

  static const LinearGradient lightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF5F7FA), Color(0xFFC3CFE2)],
  );

  static LinearGradient get cardGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withValues(alpha: 0.1),
      Colors.white.withValues(alpha: 0.05),
    ],
  );

  static LinearGradient get lightCardGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withValues(alpha: 0.9),
      Colors.white.withValues(alpha: 0.8),
    ],
  );

  // ---------------------------------------------------------------------------
  // Accesseurs adaptatifs (selon la luminosité du contexte)
  // ---------------------------------------------------------------------------

  /// Retourne la couleur de risque faible adaptée à la [brightness].
  static Color riskLow(Brightness brightness) =>
      brightness == Brightness.dark ? riskLowDark : riskLowLight;

  /// Retourne la couleur de risque modéré adaptée à la [brightness].
  static Color riskModerate(Brightness brightness) =>
      brightness == Brightness.dark ? riskModerateDark : riskModerateLight;

  /// Retourne la couleur de risque élevé adaptée à la [brightness].
  static Color riskHigh(Brightness brightness) =>
      brightness == Brightness.dark ? riskHighDark : riskHighLight;

  /// Couleur graine pour la palette Material 3.
  static const Color _seedColor = Color(0xFF1565C0);

  // ---------------------------------------------------------------------------
  // Thème clair
  // ---------------------------------------------------------------------------

  /// Thème clair de l'application, adapté pour la lisibilité médicale.
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Thème sombre
  // ---------------------------------------------------------------------------

  /// Thème sombre de l'application, adapté pour le confort visuel.
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
      surface: const Color(0xFF121218),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        color: colorScheme.surfaceContainerHigh,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Glassmorphism card decoration (P7 style)
class GlassmorphismDecoration extends BoxDecoration {
  GlassmorphismDecoration({
    double opacity = 0.1,
    double blur = 10,
    double borderRadius = 20,
    bool isDark = true,
  }) : super(
         gradient:
             isDark
                 ? LinearGradient(
                   begin: Alignment.topLeft,
                   end: Alignment.bottomRight,
                   colors: [
                     Colors.white.withValues(alpha: opacity + 0.05),
                     Colors.white.withValues(alpha: opacity),
                   ],
                 )
                 : LinearGradient(
                   begin: Alignment.topLeft,
                   end: Alignment.bottomRight,
                   colors: [
                     const Color(0xFF2D4A6A).withValues(alpha: 0.95),
                     const Color(0xFF1B3A5F).withValues(alpha: 0.9),
                   ],
                 ),
         borderRadius: BorderRadius.circular(borderRadius),
         border: Border.all(
           color:
               isDark
                   ? Colors.white.withValues(alpha: 0.2)
                   : const Color(0xFF415A77).withValues(alpha: 0.3),
           width: 1.5,
         ),
         boxShadow: [
           BoxShadow(
             color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.15),
             blurRadius: blur,
             spreadRadius: 0,
           ),
         ],
       );
}
