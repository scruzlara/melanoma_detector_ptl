import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pytorch_lite/pytorch_lite.dart';

import '../../core/math/nms.dart';
import '../../donnees/config/config_modeles.dart';

/// Service de détection de lésions par YOLO (v8/v11).
///
/// Couche infrastructure — encapsule le chargement et l'exécution
/// du modèle YOLO PyTorch Lite pour la localisation de lésions
/// sur un visage complet.
///
/// **Pipeline de traitement :**
/// 1. Inférence YOLO → tenseur brut de forme (4+C) × 8400.
/// 2. Décodage des bounding boxes (cx, cy, w, h → left, top, w, h).
/// 3. Seuillage par score de confiance.
/// 4. Suppression des non-maxima (NMS) via [Nms.appliquer].
///
/// **Note technique :** le modèle YOLO est chargé comme
/// `ClassificationModel` car YOLO retourne un tenseur brut
/// (et non un tuple comme les modèles SSD).
///
/// Aucune donnée ne quitte la mémoire de l'appareil.
class ServiceDetectionYolo {
  /// Modèle YOLO chargé.
  ClassificationModel? _modele;

  /// Indique si le modèle est chargé et prêt.
  bool _estCharge = false;

  /// Indique si le modèle de détection est disponible.
  bool get estCharge => _estCharge;

  // ---------------------------------------------------------------------------
  // Chargement du modèle
  // ---------------------------------------------------------------------------

  /// Charge le modèle de détection YOLO depuis les assets.
  ///
  /// Le modèle est chargé en tant que `ClassificationModel`
  /// pour accéder au tenseur brut de sortie. Ne fait rien
  /// si le modèle est déjà chargé.
  Future<void> chargerModele() async {
    if (_estCharge) return;

    try {
      if (kDebugMode) {
        debugPrint('[ServiceDetectionYolo] Chargement modèle YOLO...');
      }

      _modele = await PytorchLite.loadClassificationModel(
        ConfigModeles.cheminModeleDetection,
        ConfigModeles.tailleEntreeDetection,
        ConfigModeles.tailleEntreeDetection,
        labelPath: null,
      );
      _estCharge = true;

      if (kDebugMode) {
        debugPrint('[ServiceDetectionYolo] Modèle YOLO chargé.');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ServiceDetectionYolo] Erreur chargement : $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Détection de lésions
  // ---------------------------------------------------------------------------

  /// Détecte les lésions sur une image de visage complet.
  ///
  /// **Pipeline :**
  /// 1. Normalisation de l'image [0..1] (division par 255).
  /// 2. Inférence YOLO → tenseur brut aplati.
  /// 3. Post-traitement : décodage + seuillage + NMS.
  ///
  /// Retourne une liste de [DetectionYolo] avec des bounding boxes
  /// normalisées [0..1]. Liste vide si aucune lésion n'est détectée.
  Future<List<DetectionYolo>> detecter(File fichierImage) async {
    if (!_estCharge) await chargerModele();
    if (_modele == null) return [];

    try {
      final chrono = Stopwatch()..start();
      final octetsImage = await fichierImage.readAsBytes();

      // Inférence avec normalisation [0..1] (YOLO attend des floats 0..1)
      // NOTE : TensorImageUtils.bitmapToFloat32Tensor divise déjà par 255
      // en interne avant d'appliquer (pixel/255 - mean) / std.
      // Donc mean=[0,0,0] et std=[1,1,1] donne pixel/255 → [0..1].
      final sortie = await _modele!.getImagePredictionList(
        octetsImage,
        mean: [0.0, 0.0, 0.0],
        std: [1.0, 1.0, 1.0],
      );

      if (sortie == null || sortie.isEmpty) return [];

      // Journalisation du tenseur brut en mode debug
      if (kDebugMode) {
        _journaliserStatsTenseur(sortie);
      }

      // Post-traitement YOLO (décodage + NMS)
      final detections = _postTraiter(
        sortie,
        seuilConfiance: ConfigModeles.seuilScoreDetection,
        seuilIou: ConfigModeles.seuilIouDetection,
        maxDetections: ConfigModeles.maxBoxesDetection,
      );

      chrono.stop();
      if (kDebugMode) {
        debugPrint(
          '[ServiceDetectionYolo] ${detections.length} lésions '
          'en ${chrono.elapsedMilliseconds}ms '
          '(sortie brute : ${sortie.length} valeurs)',
        );
      }

      return detections;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ServiceDetectionYolo] Erreur détection : $e');
      }
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Libération des ressources
  // ---------------------------------------------------------------------------

  /// Libère le modèle de détection.
  void dispose() {
    _modele = null;
    _estCharge = false;
  }

  // ---------------------------------------------------------------------------
  // Post-traitement YOLO
  // ---------------------------------------------------------------------------

  /// Post-traitement du tenseur brut YOLO v8/v11.
  ///
  /// **Format du tenseur d'entrée :**
  /// Tenseur aplati de forme (4+C) × 8400 (row-major) :
  /// - Indices [0..3] × 8400 : cx, cy, w, h (en pixels 640).
  /// - Indices [4..4+C-1] × 8400 : scores par classe.
  ///
  /// **Étapes :**
  /// 1. Décodage de chaque prédiction (8400 ancres).
  /// 2. Sélection de la classe avec le score maximal.
  /// 3. Filtrage par seuil de confiance.
  /// 4. Conversion centre → coin supérieur gauche, normalisation [0..1].
  /// 5. NMS via [Nms.appliquer] (délégation à la couche algorithmique).
  List<DetectionYolo> _postTraiter(
    List<double?> sortieBrute, {
    required double seuilConfiance,
    required double seuilIou,
    required int maxDetections,
  }) {
    const int numPredictions = 8400;
    final int totalValues = sortieBrute.length;
    final int numFeatures = totalValues ~/ numPredictions;

    if (numFeatures < 5) {
      if (kDebugMode) {
        debugPrint(
          '[YOLO] Sortie inattendue : $totalValues valeurs, '
          '$numFeatures features (attendu >= 5)',
        );
      }
      return [];
    }

    final int numClasses = numFeatures - 4;
    final double inputSize = ConfigModeles.tailleEntreeDetection.toDouble();

    if (kDebugMode) {
      debugPrint(
        '[YOLO] Post-traitement : $numFeatures features, '
        '$numClasses classes, $numPredictions prédictions',
      );
    }

    // Décodage : extraire les détections au-dessus du seuil
    final candidats = <DetectionYolo>[];
    double maxScoreTrouve = 0.0;

    for (int j = 0; j < numPredictions; j++) {
      // Trouver la classe avec le score max
      double maxScore = -1;
      int maxClassIdx = 0;
      for (int c = 0; c < numClasses; c++) {
        final score = sortieBrute[(4 + c) * numPredictions + j] ?? 0.0;
        if (score > maxScore) {
          maxScore = score;
          maxClassIdx = c;
        }
      }

      if (maxScore > maxScoreTrouve) {
        maxScoreTrouve = maxScore;
      }

      if (maxScore < seuilConfiance) continue;

      // Décoder cx, cy, w, h (pixels 640) → normalisé [0..1]
      final cx = (sortieBrute[0 * numPredictions + j] ?? 0.0) / inputSize;
      final cy = (sortieBrute[1 * numPredictions + j] ?? 0.0) / inputSize;
      final w = (sortieBrute[2 * numPredictions + j] ?? 0.0) / inputSize;
      final h = (sortieBrute[3 * numPredictions + j] ?? 0.0) / inputSize;

      // Convertir centre → coin supérieur gauche
      final left = (cx - w / 2).clamp(0.0, 1.0);
      final top = (cy - h / 2).clamp(0.0, 1.0);
      final bw = w.clamp(0.0, 1.0 - left);
      final bh = h.clamp(0.0, 1.0 - top);

      if (bw <= 0 || bh <= 0) continue;

      candidats.add(
        DetectionYolo(
          left: left,
          top: top,
          width: bw,
          height: bh,
          score: maxScore,
          classIndex: maxClassIdx,
        ),
      );
    }

    if (kDebugMode) {
      debugPrint('[YOLO] Score max trouvé : $maxScoreTrouve');
    }

    // Trier par score décroissant avant NMS
    candidats.sort((a, b) => b.score.compareTo(a.score));

    // NMS via la couche algorithmique pure Dart
    return Nms.appliquer(
      candidats: candidats,
      seuilIou: seuilIou,
      maxDetections: maxDetections,
      obtenirBoite:
          (det) => (
            left: det.left,
            top: det.top,
            width: det.width,
            height: det.height,
          ),
    );
  }

  /// Journalise les statistiques du tenseur brut (uniquement en mode debug).
  void _journaliserStatsTenseur(List<double?> sortie) {
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;
    double sumVal = 0;
    int count = 0;
    for (var v in sortie) {
      if (v != null) {
        if (v < minVal) minVal = v;
        if (v > maxVal) maxVal = v;
        sumVal += v;
        count++;
      }
    }
    debugPrint(
      '[YOLO-DEBUG] Min: $minVal, Max: $maxVal, '
      'Mean: ${count > 0 ? sumVal / count : 0}',
    );
    debugPrint('[YOLO-DEBUG] First 20: ${sortie.take(20).toList()}');
  }
}

/// Résultat d'une détection YOLO avec bounding box normalisée [0..1].
///
/// Représente une lésion détectée sur l'image, avec ses coordonnées
/// spatiales et son score de confiance.
class DetectionYolo {
  /// Coordonnée X du coin supérieur gauche (normalisée 0..1).
  final double left;

  /// Coordonnée Y du coin supérieur gauche (normalisée 0..1).
  final double top;

  /// Largeur de la bounding box (normalisée 0..1).
  final double width;

  /// Hauteur de la bounding box (normalisée 0..1).
  final double height;

  /// Score de confiance de la détection [0..1].
  final double score;

  /// Index de la classe détectée (0 = lésion).
  final int classIndex;

  const DetectionYolo({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.score,
    required this.classIndex,
  });

  @override
  String toString() =>
      'DetectionYolo(class=$classIndex, score=${score.toStringAsFixed(3)}, '
      'bbox=[$left, $top, $width, $height])';
}
