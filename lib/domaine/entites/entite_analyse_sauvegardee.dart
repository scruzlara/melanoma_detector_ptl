import 'dart:convert';

/// Entité du domaine représentant une analyse sauvegardée.
///
/// Pure Dart — aucune dépendance Flutter ni base de données.
/// Contient toutes les données nécessaires pour restaurer un résultat
/// d'analyse complet, y compris les contours de segmentation.
class EntiteAnalyseSauvegardee {
  /// Identifiant unique de l'analyse.
  final String id;

  /// Chemin absolu de l'image originale analysée.
  final String cheminImageOriginale;

  /// Contours de segmentation (liste de points [x, y]).
  final List<List<double>>? contours;

  /// Résultat textuel de la classification (ex: « Bénin », « Mélanome »).
  final String resultatClassification;

  /// Probabilité de malignité (0.0 à 1.0).
  final double probMalignant;

  /// Confiance de la prédiction (0.0 à 1.0).
  final double confiance;

  /// Métriques géométriques (aire, diamètre, etc.).
  final Map<String, dynamic> metriquesGeometriques;

  /// Nom du modèle utilisé pour la classification.
  final String nomModele;

  /// Notes optionnelles de l'utilisateur.
  final String? notes;

  /// Horodatage de l'analyse.
  final DateTime horodatage;

  /// JSON complet du résultat (pour restauration fidèle).
  final Map<String, dynamic> resultJsonComplet;

  const EntiteAnalyseSauvegardee({
    required this.id,
    required this.cheminImageOriginale,
    this.contours,
    required this.resultatClassification,
    required this.probMalignant,
    required this.confiance,
    required this.metriquesGeometriques,
    required this.nomModele,
    this.notes,
    required this.horodatage,
    required this.resultJsonComplet,
  });

  /// Sérialise l'entité en Map JSON.
  Map<String, dynamic> versJson() {
    return {
      'id': id,
      'cheminImageOriginale': cheminImageOriginale,
      'contours': contours?.map((p) => [p[0], p[1]]).toList(),
      'resultatClassification': resultatClassification,
      'probMalignant': probMalignant,
      'confiance': confiance,
      'metriquesGeometriques': metriquesGeometriques,
      'nomModele': nomModele,
      'notes': notes,
      'horodatage': horodatage.toIso8601String(),
      'resultJsonComplet': resultJsonComplet,
    };
  }

  /// Sérialise l'entité en chaîne JSON formatée.
  String versJsonString() {
    return const JsonEncoder.withIndent('  ').convert(versJson());
  }

  /// Désérialise une entité depuis un Map JSON.
  factory EntiteAnalyseSauvegardee.depuisJson(Map<String, dynamic> json) {
    return EntiteAnalyseSauvegardee(
      id: json['id'] as String,
      cheminImageOriginale: json['cheminImageOriginale'] as String,
      contours:
          (json['contours'] as List<dynamic>?)
              ?.map(
                (p) =>
                    (p as List<dynamic>)
                        .map((v) => (v as num).toDouble())
                        .toList(),
              )
              .toList(),
      resultatClassification: json['resultatClassification'] as String,
      probMalignant: (json['probMalignant'] as num).toDouble(),
      confiance: (json['confiance'] as num).toDouble(),
      metriquesGeometriques: Map<String, dynamic>.from(
        json['metriquesGeometriques'] as Map,
      ),
      nomModele: json['nomModele'] as String,
      notes: json['notes'] as String?,
      horodatage: DateTime.parse(json['horodatage'] as String),
      resultJsonComplet: Map<String, dynamic>.from(
        json['resultJsonComplet'] as Map,
      ),
    );
  }
}
