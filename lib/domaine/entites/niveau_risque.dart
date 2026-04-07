/// Niveaux de risque pour le diagnostic de mélanome.
///
/// Entité du domaine — pure Dart, aucune dépendance Flutter.
/// Le mapping vers des couleurs et icônes est effectué dans la couche
/// présentation (voir `couleurs_risque.dart`).
enum NiveauRisque {
  /// Risque faible (< 30 % de probabilité de malignité).
  faible,

  /// Risque modéré (30–60 % de probabilité de malignité).
  modere,

  /// Risque élevé (> 60 % de probabilité de malignité).
  eleve,
}

/// Données associées à un niveau de risque (sans dépendance UI).
///
/// Contient le libellé textuel et le niveau calculé.
/// Pour obtenir la couleur ou l'icône, utiliser [CouleursRisque] dans
/// la couche présentation.
class DonneesRisque {
  /// Libellé du risque (ex: « Risque Faible (Bénin) »).
  final String libelle;

  /// Niveau de risque calculé.
  final NiveauRisque niveau;

  const DonneesRisque({required this.libelle, required this.niveau});
}
