/// Définition d'un modèle de classification pour la détection de mélanome.
///
/// Entité du domaine — pure Dart, aucune dépendance Flutter.
/// Chaque modèle est identifié par son [cheminAsset] (chemin unique).
class DefinitionModele {
  /// Nom affiché du modèle (ex: « MobileNetV3 (Model D) »).
  final String nom;

  /// Chemin du fichier asset (.ptl) dans le bundle Flutter.
  final String cheminAsset;

  /// Taille d'entrée en pixels (largeur = hauteur).
  final int tailleEntree;

  const DefinitionModele({
    required this.nom,
    required this.cheminAsset,
    required this.tailleEntree,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DefinitionModele &&
          runtimeType == other.runtimeType &&
          cheminAsset == other.cheminAsset;

  @override
  int get hashCode => cheminAsset.hashCode;

  @override
  String toString() => 'DefinitionModele($nom, ${tailleEntree}px)';
}
