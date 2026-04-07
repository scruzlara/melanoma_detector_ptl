/// Suppression des Non-Maxima (NMS) pour le post-traitement de détection.
///
/// Couche algorithmique pure Dart — aucune dépendance Flutter ni IA.
///
/// Le NMS filtre les détections redondantes en supprimant celles
/// qui se chevauchent significativement avec une détection de score
/// plus élevé, mesurée par l'IoU (Intersection over Union).
///
/// **Complexité :**
/// - Temporelle : O(n² · log n) — tri + comparaison par paires.
/// - Spatiale : O(n) — liste de flags de suppression.
class Nms {
  Nms._();

  /// Calcule l'IoU (Intersection over Union) entre deux boîtes englobantes.
  ///
  /// Les boîtes sont définies par `(left, top, width, height)` normalisés [0..1].
  ///
  /// L'IoU mesure le rapport entre la surface d'intersection et la surface
  /// d'union des deux boîtes :
  /// ```
  /// IoU = Aire(A ∩ B) / Aire(A ∪ B)
  /// ```
  ///
  /// Retourne une valeur dans [0..1] : 0 = pas de chevauchement, 1 = identique.
  ///
  /// Complexité temporelle : O(1).
  static double calculerIou({
    required double leftA,
    required double topA,
    required double widthA,
    required double heightA,
    required double leftB,
    required double topB,
    required double widthB,
    required double heightB,
  }) {
    final x1 = leftA > leftB ? leftA : leftB;
    final y1 = topA > topB ? topA : topB;
    final x2 =
        (leftA + widthA) < (leftB + widthB)
            ? (leftA + widthA)
            : (leftB + widthB);
    final y2 =
        (topA + heightA) < (topB + heightB)
            ? (topA + heightA)
            : (topB + heightB);

    final intersection =
        (x2 - x1).clamp(0.0, double.infinity) *
        (y2 - y1).clamp(0.0, double.infinity);
    final union = widthA * heightA + widthB * heightB - intersection;

    return union > 0 ? intersection / union : 0.0;
  }

  /// Applique le NMS sur une liste de détections triées par score décroissant.
  ///
  /// [candidats] — Liste de détections brutes (pré-triées par score).
  /// [seuilIou] — Seuil d'IoU au-dessus duquel une détection est supprimée.
  /// [maxDetections] — Nombre maximal de détections à conserver.
  /// [obtenirBoite] — Fonction extractant les coordonnées d'une détection.
  ///
  /// Retourne une sous-liste filtrée de détections non redondantes.
  ///
  /// L'algorithme itère les candidats du plus confiant au moins confiant.
  /// Pour chaque candidat retenu, il supprime tous les candidats suivants
  /// dont l'IoU avec lui dépasse le seuil.
  static List<T> appliquer<T>({
    required List<T> candidats,
    required double seuilIou,
    required int maxDetections,
    required ({double left, double top, double width, double height}) Function(
      T,
    )
    obtenirBoite,
  }) {
    final resultats = <T>[];
    final supprime = List<bool>.filled(candidats.length, false);

    for (int i = 0; i < candidats.length; i++) {
      if (supprime[i]) continue;
      resultats.add(candidats[i]);
      if (resultats.length >= maxDetections) break;

      final boiteA = obtenirBoite(candidats[i]);
      for (int k = i + 1; k < candidats.length; k++) {
        if (supprime[k]) continue;
        final boiteB = obtenirBoite(candidats[k]);

        final iou = calculerIou(
          leftA: boiteA.left,
          topA: boiteA.top,
          widthA: boiteA.width,
          heightA: boiteA.height,
          leftB: boiteB.left,
          topB: boiteB.top,
          widthB: boiteB.width,
          heightB: boiteB.height,
        );

        if (iou > seuilIou) {
          supprime[k] = true;
        }
      }
    }

    return resultats;
  }
}
