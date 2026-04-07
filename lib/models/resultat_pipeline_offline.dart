import 'dart:ui';

import 'facial_landmark.dart';
import '../services/reconstruction_service.dart';
import '../services/antigravity_decision_service.dart';

/// Résultat complet du pipeline d'analyse offline.
///
/// Agrège tous les résultats des étapes du pipeline :
/// recadrage → classification → segmentation → re-mappage →
/// landmarks → distances → décision de reconstruction.
class ResultatPipelineOffline {
  // ── Étape 1 : Recadrage ──────────────────────────────────────────────────
  /// Coordonnées du rectangle de recadrage dans l'image originale (pixels).
  final Rect cropRect;

  // ── Étape 2 : Classification ─────────────────────────────────────────────
  /// Résultats de classification (label, confiance, prob_malignant, probabilites).
  final Map<String, dynamic> classification;

  // ── Étape 3-4 : Segmentation re-mappée ───────────────────────────────────
  /// Contours de la lésion en coordonnées de l'image originale (pixels).
  /// Chaque élément est [x, y].
  final List<List<double>>? contoursOriginal;

  /// Centre de la lésion dans l'image originale (pixels).
  final Offset lesionCenter;

  /// Taille estimée de la lésion (diamètre en pixels dans l'image originale).
  final double lesionDiameterPx;

  /// Taille estimée de la lésion en mm, calibrée via la distance interpupillaire.
  /// `null` si les yeux n'ont pas été détectés.
  final double? lesionSizeMm;

  /// Ratio px → mm, dérivé de la distance interpupillaire détectée.
  /// IPD moyenne adulte ≈ 63 mm.
  final double? pxToMmRatio;

  /// Distance interpupillaire mesurée en pixels.
  final double? ipdPx;

  // ── Étape 5 : Landmarks faciaux ──────────────────────────────────────────
  /// Points clés du visage détectés par ML Kit.
  final FacialKeyPoints? keyPoints;

  // ── Étape 6 : Analyse de localisation ────────────────────────────────────
  /// Région faciale déterminée automatiquement.
  final FacialRegion region;

  /// Distances (en pixels) entre le centre de la lésion et chaque landmark.
  final Map<String, double> distancesPx;

  /// Options de reconstruction chirurgicale proposées.
  final List<ReconstructionOption> reconstructionOptions;

  /// Zone Antigravity correspondante (pour l'arbre de décision avancé).
  final ReconstructionZone? antigravityZone;

  const ResultatPipelineOffline({
    required this.cropRect,
    required this.classification,
    this.contoursOriginal,
    required this.lesionCenter,
    required this.lesionDiameterPx,
    this.lesionSizeMm,
    this.pxToMmRatio,
    this.ipdPx,
    this.keyPoints,
    required this.region,
    required this.distancesPx,
    required this.reconstructionOptions,
    this.antigravityZone,
  });

  // ── Getters utilitaires ──────────────────────────────────────────────────

  /// Label de classification (ex. « Malignant », « Benign »).
  String get label => classification['label'] as String? ?? 'Inconnu';

  /// Confiance de la classification [0..1].
  double get confiance => (classification['confiance'] as double?) ?? 0.0;

  /// Probabilité de malignité [0..1].
  double get probMalignant =>
      (classification['prob_malignant'] as double?) ?? 0.0;

  /// Indique si la lésion est probablement maligne (> 50%).
  bool get estProbablementMaligne => probMalignant > 0.5;

  /// Taille estimée en cm (pour affichage).
  double? get lesionSizeCm =>
      lesionSizeMm != null ? lesionSizeMm! / 10.0 : null;
}
