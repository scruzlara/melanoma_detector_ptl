import 'dart:convert';

import 'package:hive/hive.dart';

import '../../domaine/entites/entite_analyse_sauvegardee.dart';

part 'modele_analyse_hive.g.dart';

/// DTO Hive pour la persistance d'une analyse sauvegardée.
///
/// Couche données — convertit entre [EntiteAnalyseSauvegardee] (domaine)
/// et le stockage Hive. Les structures imbriquées (contours, JSON)
/// sont sérialisées en chaînes JSON car Hive ne supporte pas
/// nativement les listes de listes.
@HiveType(typeId: 0)
class ModeleAnalyseHive extends HiveObject {
  /// Identifiant unique.
  @HiveField(0)
  final String id;

  /// Chemin de l'image originale.
  @HiveField(1)
  final String cheminImageOriginale;

  /// Contours sérialisés en JSON (nullable).
  @HiveField(2)
  final String? contoursJson;

  /// Résultat de classification.
  @HiveField(3)
  final String resultatClassification;

  /// Probabilité de malignité.
  @HiveField(4)
  final double probMalignant;

  /// Confiance de la prédiction.
  @HiveField(5)
  final double confiance;

  /// Métriques géométriques sérialisées en JSON.
  @HiveField(6)
  final String metriquesGeometriquesJson;

  /// Nom du modèle.
  @HiveField(7)
  final String nomModele;

  /// Notes de l'utilisateur.
  @HiveField(8)
  final String? notes;

  /// Horodatage (millisecondes depuis epoch).
  @HiveField(9)
  final int horodatageMs;

  /// JSON complet du résultat sérialisé.
  @HiveField(10)
  final String resultJsonCompletStr;

  ModeleAnalyseHive({
    required this.id,
    required this.cheminImageOriginale,
    this.contoursJson,
    required this.resultatClassification,
    required this.probMalignant,
    required this.confiance,
    required this.metriquesGeometriquesJson,
    required this.nomModele,
    this.notes,
    required this.horodatageMs,
    required this.resultJsonCompletStr,
  });

  // ---------------------------------------------------------------------------
  // Conversions Domaine ↔ Hive
  // ---------------------------------------------------------------------------

  /// Crée un DTO Hive à partir d'une entité du domaine.
  factory ModeleAnalyseHive.depuisEntite(EntiteAnalyseSauvegardee entite) {
    return ModeleAnalyseHive(
      id: entite.id,
      cheminImageOriginale: entite.cheminImageOriginale,
      contoursJson:
          entite.contours != null ? jsonEncode(entite.contours) : null,
      resultatClassification: entite.resultatClassification,
      probMalignant: entite.probMalignant,
      confiance: entite.confiance,
      metriquesGeometriquesJson: jsonEncode(entite.metriquesGeometriques),
      nomModele: entite.nomModele,
      notes: entite.notes,
      horodatageMs: entite.horodatage.millisecondsSinceEpoch,
      resultJsonCompletStr: jsonEncode(entite.resultJsonComplet),
    );
  }

  /// Convertit ce DTO en entité du domaine.
  EntiteAnalyseSauvegardee versEntite() {
    List<List<double>>? contours;
    if (contoursJson != null) {
      final decoded = jsonDecode(contoursJson!) as List<dynamic>;
      contours =
          decoded
              .map(
                (p) =>
                    (p as List<dynamic>)
                        .map((v) => (v as num).toDouble())
                        .toList(),
              )
              .toList();
    }

    return EntiteAnalyseSauvegardee(
      id: id,
      cheminImageOriginale: cheminImageOriginale,
      contours: contours,
      resultatClassification: resultatClassification,
      probMalignant: probMalignant,
      confiance: confiance,
      metriquesGeometriques: Map<String, dynamic>.from(
        jsonDecode(metriquesGeometriquesJson) as Map,
      ),
      nomModele: nomModele,
      notes: notes,
      horodatage: DateTime.fromMillisecondsSinceEpoch(horodatageMs),
      resultJsonComplet: Map<String, dynamic>.from(
        jsonDecode(resultJsonCompletStr) as Map,
      ),
    );
  }
}
