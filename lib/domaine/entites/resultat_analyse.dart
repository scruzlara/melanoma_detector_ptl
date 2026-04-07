/// Résultat d'une analyse de lésion (classification + segmentation).
///
/// Entité du domaine — pure Dart, aucune dépendance Flutter.
/// Remplace l'ancien `PredictResult` en supprimant le code mort
/// lié à l'API Gradio et en simplifiant la structure.
class ResultatAnalyse {
  /// Résultats JSON complets de l'analyse.
  final Map<String, dynamic>? resultJson;

  /// Rapport au format Markdown.
  final String? rapportMd;

  /// Contours de la lésion (liste de points [x, y]).
  final List<List<double>>? contours;

  /// Largeur de l'image originale (si disponible dans le JSON).
  int? get largeurImage => resultJson?['original_size']?['width'];

  /// Hauteur de l'image originale (si disponible dans le JSON).
  int? get hauteurImage => resultJson?['original_size']?['height'];

  /// Constructeur principal.
  const ResultatAnalyse({this.resultJson, this.rapportMd, this.contours});

  /// Crée une copie avec des contours mis à jour.
  ///
  /// Utilisé par l'éditeur de contours pour recalculer la géométrie
  /// après modification manuelle des points.
  ResultatAnalyse copierAvecContours({
    required List<List<double>> nouveauxContours,
    Map<String, dynamic>? jsonMisAJour,
  }) {
    return ResultatAnalyse(
      resultJson: jsonMisAJour ?? resultJson,
      contours: nouveauxContours,
      rapportMd: rapportMd,
    );
  }
}
