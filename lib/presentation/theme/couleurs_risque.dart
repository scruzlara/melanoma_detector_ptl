import 'package:flutter/material.dart';

import '../../domaine/entites/niveau_risque.dart';
import '../../theme/app_theme.dart';

/// Mapping des niveaux de risque vers les couleurs et icônes Material.
///
/// Couche présentation uniquement — sépare la logique de risque (domaine)
/// de sa représentation visuelle (Flutter).
class CouleursRisque {
  CouleursRisque._();

  /// Retourne la couleur associée à un [niveau] de risque,
  /// adaptée à la [brightness] du thème courant.
  static Color couleur(NiveauRisque niveau, Brightness brightness) {
    switch (niveau) {
      case NiveauRisque.faible:
        return AppTheme.riskLow(brightness);
      case NiveauRisque.modere:
        return AppTheme.riskModerate(brightness);
      case NiveauRisque.eleve:
        return AppTheme.riskHigh(brightness);
    }
  }

  /// Retourne l'icône Material associée à un [niveau] de risque.
  static IconData icone(NiveauRisque niveau) {
    switch (niveau) {
      case NiveauRisque.faible:
        return Icons.check_circle_outline;
      case NiveauRisque.modere:
        return Icons.warning_amber_rounded;
      case NiveauRisque.eleve:
        return Icons.health_and_safety;
    }
  }
}
