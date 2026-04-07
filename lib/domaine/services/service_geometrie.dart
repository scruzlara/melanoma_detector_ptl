import 'dart:math';

import '../entites/niveau_risque.dart';

/// Service de calculs géométriques pour l'analyse de lésions.
///
/// Couche domaine — pure Dart, aucune dépendance Flutter.
///
/// Fournit des méthodes pour :
/// - Calculer l'aire et le diamètre d'un contour (formule du lacet).
/// - Évaluer le niveau de risque à partir d'une probabilité.
/// - Naviguer dans la structure JSON imbriquée des résultats de segmentation.
class ServiceGeometrie {
  /// Calcule l'aire et le diamètre équivalent d'un contour fermé.
  ///
  /// Utilise la **formule du lacet** (Shoelace formula) pour l'aire,
  /// puis calcule le diamètre d'un cercle de même aire.
  ///
  /// Retourne un Map avec les clés `area_px` (int) et `diam_px` (double).
  static Map<String, dynamic> calculerGeometrie(List<List<double>> contours) {
    if (contours.isEmpty) return {};

    double aire = 0.0;
    for (int i = 0; i < contours.length; i++) {
      final p1 = contours[i];
      final p2 = contours[(i + 1) % contours.length];
      aire += (p1[0] * p2[1]) - (p2[0] * p1[1]);
    }
    aire = (aire / 2.0).abs();

    final diametre = 2 * sqrt(aire / pi);
    return {'area_px': aire.round(), 'diam_px': diametre};
  }

  /// Évalue le niveau de risque en fonction de la probabilité de malignité.
  ///
  /// Seuils calibrés pour compenser le biais "bénin" du modèle MobileNetV3
  /// (entraîné sur dataset déséquilibré 67% bénins sans correction) :
  ///
  /// - < 0.15 → [NiveauRisque.faible]   (bénin quasi-certain)
  /// - 0.15–0.25 → [NiveauRisque.modere] (suspect, à surveiller)
  /// - > 0.25 → [NiveauRisque.eleve]    (mélanome probable)
  static DonneesRisque evaluerNiveauRisque(double probabilite) {
    if (probabilite < 0.15) {
      return const DonneesRisque(
        libelle: 'Risque Faible (Bénin)',
        niveau: NiveauRisque.faible,
      );
    } else if (probabilite < 0.25) {
      return const DonneesRisque(
        libelle: 'Risque Modéré (Suspect)',
        niveau: NiveauRisque.modere,
      );
    } else {
      return const DonneesRisque(
        libelle: 'Risque Élevé (Mélanome)',
        niveau: NiveauRisque.eleve,
      );
    }
  }

  /// Lit une valeur de segmentation depuis la structure JSON imbriquée.
  ///
  /// Priorité de lecture :
  /// 1. `segmentacion.unet.tamano.[key]` (si U-Net disponible)
  /// 2. `segmentacion.opencv.tamano.[key]` (fallback OpenCV)
  /// 3. `tamano.[key]` (structure legacy)
  static dynamic obtenirValeurSegmentation(
    Map<String, dynamic>? json,
    String cle,
  ) {
    if (json == null) return null;

    // 1. Nouvelle structure Ensemble
    if (json.containsKey('segmentacion')) {
      final seg = json['segmentacion'];
      if (seg is Map) {
        // Priorité U-Net
        if (seg['unet']?['disponible'] == true &&
            seg['unet']?['tamano']?[cle] != null) {
          return seg['unet']['tamano'][cle];
        }
        // Fallback OpenCV
        if (seg['opencv']?['tamano']?[cle] != null) {
          return seg['opencv']['tamano'][cle];
        }
      }
    }

    // 2. Structure legacy
    return json['tamano']?[cle];
  }

  /// Extrait le diagnostic à partir du JSON de résultat.
  ///
  /// Retourne un Map contenant `diagnostic`, `estMalin`, et `confiance`.
  static Map<String, dynamic> extraireDiagnostic(Map<String, dynamic>? json) {
    String diagnostic = 'Résultat inconnu';
    double confiance = 0.0;
    bool estMalin = false;

    if (json == null) {
      return {
        'diagnostic': diagnostic,
        'estMalin': estMalin,
        'confiance': confiance,
      };
    }

    // 1. Obtenir la probabilité de malignité
    final valConf =
        json['prob_malignidad'] ?? json['prob_promedio'] ?? json['confianza'];
    if (valConf != null) {
      double rawConf = double.tryParse(valConf.toString()) ?? 0.0;
      // Si > 1, format pourcentage → convertir en décimal
      confiance = rawConf > 1.0 ? rawConf / 100.0 : rawConf;
    }

    // 2. Utiliser prediccion_final
    final rawPred = json['prediccion_final'] ?? json['prediccion'] ?? '';
    final pred = rawPred.toString().toLowerCase().trim();

    if (pred.isNotEmpty && pred != 'null') {
      estMalin =
          pred.contains('malin') ||
          pred.contains('malignant') ||
          pred.contains('melanoma');
      diagnostic = estMalin ? 'Mélanome (Maligne)' : 'Bénin';
    } else {
      // Fallback : prob >= 0.5
      estMalin = confiance >= 0.5;
      diagnostic = estMalin ? 'Mélanome (Maligne)' : 'Bénin';
    }

    return {
      'diagnostic': diagnostic,
      'estMalin': estMalin,
      'confiance': confiance,
    };
  }
}
