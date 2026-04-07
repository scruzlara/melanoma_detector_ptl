import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../domaine/entites/definition_modele.dart';
import '../models/facial_landmark.dart';
import '../models/resultat_pipeline_offline.dart';
import 'antigravity_decision_service.dart';
import 'face_landmark_service.dart' hide debugPrint;
import 'local/service_pytorch.dart';
import 'reconstruction_service.dart';

/// Orquestador del pipeline offline de análisis de melanoma facial.
///
/// Pipeline completo en 6 pasos:
/// 1. Recorte (crop) de la zona de la lesión
/// 2. Clasificación local (MobileNetV3) del recorte
/// 3. Segmentación local (U-Net) del recorte
/// 4. Re-mapeo de los contornos del recorte a la imagen original
/// 5. Detección de landmarks faciales (Google ML Kit) en imagen completa
/// 6. Cálculo de distancias + decisión de reconstrucción
///
/// Todas las operaciones se ejecutan en el dispositivo (offline).
/// Aucune donnée ne quitte la mémoire de l'appareil.
class ServicePipelineOffline {
  static final ServicePipelineOffline _instance =
      ServicePipelineOffline._internal();
  factory ServicePipelineOffline() => _instance;
  ServicePipelineOffline._internal();

  final ServicePyTorch _pytorch = ServicePyTorch();
  final FaceLandmarkService _landmarkService = FaceLandmarkService();
  final ReconstructionService _reconstructionService = ReconstructionService();
  final AntigravityDecisionService _decisionService =
      AntigravityDecisionService();

  /// Ejecuta el pipeline offline completo.
  ///
  /// [imagePath] — ruta del archivo de la imagen de cara completa.
  /// [cropRect] — rectángulo de recorte seleccionado por el usuario (en píxeles originales).
  /// [modele] — definición del modelo de clasificación a usar.
  /// [marginMm] — margen quirúrgico en mm (por defecto 5mm).
  Future<ResultatPipelineOffline> executerPipeline({
    required String imagePath,
    required ui.Rect cropRect,
    required DefinitionModele modele,
    double marginMm = 5.0,
  }) async {
    final chrono = Stopwatch()..start();

    // ── 1. Recorte de la imagen ────────────────────────────────────────────
    if (kDebugMode) {
      debugPrint('[Pipeline] Étape 1 : Recadrage...');
    }
    final cropBytes = await _recadrerImage(imagePath, cropRect);

    // ── 2. Clasificación del recorte ───────────────────────────────────────
    if (kDebugMode) {
      debugPrint('[Pipeline] Étape 2 : Classification...');
    }
    final classification = await _pytorch.predireDepuisBytes(cropBytes, modele);

    // ── 3. Segmentación del recorte ────────────────────────────────────────
    if (kDebugMode) {
      debugPrint('[Pipeline] Étape 3 : Segmentation...');
    }
    final contoursCrop = await _pytorch.predireSegmentationDepuisBytes(
      cropBytes,
    );

    // ── 4. Re-mapeo de los contornos al espacio de la imagen original ──────
    if (kDebugMode) {
      debugPrint('[Pipeline] Étape 4 : Re-mappage des contours...');
    }
    List<List<double>>? contoursOriginal;
    ui.Offset lesionCenter;
    double lesionDiameterPx;

    if (contoursCrop != null && contoursCrop.isNotEmpty) {
      contoursOriginal = _remapperContours(contoursCrop, cropRect);

      // Calcular el centro y diámetro de la lesión en coords originales
      final stats = _calculerStatistiquesContour(contoursOriginal);
      lesionCenter = stats.center;
      lesionDiameterPx = stats.diameter;
    } else {
      // Fallback: usar el centro del recorte como posición de la lesión
      lesionCenter = cropRect.center;
      lesionDiameterPx = cropRect.shortestSide;
    }

    // ── 5. Detección de landmarks faciales ─────────────────────────────────
    if (kDebugMode) {
      debugPrint('[Pipeline] Étape 5 : Landmarks faciaux...');
    }
    final keyPoints = await _landmarkService.detectFacialLandmarksFromFile(
      imagePath,
    );

    // ── 6. Cálculo de distancias + decisión ────────────────────────────────
    if (kDebugMode) {
      debugPrint('[Pipeline] Étape 6 : Distances + Décision...');
    }

    FacialRegion region = FacialRegion.unknown;
    Map<String, double> distancesPx = {};
    List<ReconstructionOption> options = [];
    ReconstructionZone? zone;

    // Calibration px → mm via la distance interpupillaire
    // Distance interpupillaire moyenne adulte ≈ 63 mm (Dodgson 2004).
    const double ipdMoyenneMm = 63.0;
    double? ipdPx;
    double? pxToMm;
    double? lesionSizeMm;

    if (keyPoints != null) {
      // Determinar la región facial
      region = _landmarkService.determineRegion(lesionCenter, keyPoints);

      // Calcular distancias a todos los landmarks
      distancesPx = _landmarkService.calculateDistancesToKeyPoints(
        lesionCenter,
        keyPoints,
      );

      // ── Calibration via IPD ──────────────────────────────────────────────
      if (keyPoints.leftEye != null && keyPoints.rightEye != null) {
        ipdPx = _distanceBetween(keyPoints.leftEye!, keyPoints.rightEye!);
        if (ipdPx > 0) {
          pxToMm = ipdMoyenneMm / ipdPx;
          lesionSizeMm = lesionDiameterPx * pxToMm;
          if (kDebugMode) {
            debugPrint(
              '[Pipeline] IPD: ${ipdPx.toStringAsFixed(1)} px → '
              '${ipdMoyenneMm.toStringAsFixed(0)} mm '
              '(ratio: ${pxToMm.toStringAsFixed(4)} mm/px). '
              'Lésion: ${lesionDiameterPx.toStringAsFixed(1)} px '
              '≈ ${lesionSizeMm.toStringAsFixed(1)} mm '
              '(${(lesionSizeMm / 10).toStringAsFixed(2)} cm)',
            );
          }
        }
      }

      // Fallback si IPD non disponible
      lesionSizeMm ??= lesionDiameterPx * 0.15;

      // Obtener opciones de reconstrucción
      options = _reconstructionService.getReconstructionOptions(
        region: region,
        lesionSizeMm: lesionSizeMm,
        marginMm: marginMm,
        distancesToKeyPoints: distancesPx,
      );

      // Obtener zona Antigravity
      zone = _decisionService.getZoneForRegion(region);
    }

    chrono.stop();
    if (kDebugMode) {
      debugPrint(
        '[Pipeline] Terminé en ${chrono.elapsedMilliseconds}ms. '
        'Région: ${region.displayName}',
      );
    }

    return ResultatPipelineOffline(
      cropRect: cropRect,
      classification: classification,
      contoursOriginal: contoursOriginal,
      lesionCenter: lesionCenter,
      lesionDiameterPx: lesionDiameterPx,
      lesionSizeMm: lesionSizeMm,
      pxToMmRatio: pxToMm,
      ipdPx: ipdPx,
      keyPoints: keyPoints,
      region: region,
      distancesPx: distancesPx,
      reconstructionOptions: options,
      antigravityZone: zone,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Métodos privados
  // ═══════════════════════════════════════════════════════════════════════════

  /// Recorta la imagen y devuelve los bytes PNG del recorte.
  Future<Uint8List> _recadrerImage(String imagePath, ui.Rect cropRect) async {
    final bytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Impossible de décoder l\'image.');
    }

    final cropped = img.copyCrop(
      decoded,
      x: cropRect.left.round(),
      y: cropRect.top.round(),
      width: cropRect.width.round(),
      height: cropRect.height.round(),
    );

    return Uint8List.fromList(img.encodePng(cropped));
  }

  /// Re-mapea los contornos desde las coordenadas del recorte
  /// hacia las coordenadas de la imagen original.
  ///
  /// Simplemente suma el offset (left, top) del rectángulo de recorte.
  List<List<double>> _remapperContours(
    List<List<double>> contoursCrop,
    ui.Rect cropRect,
  ) {
    return contoursCrop.map((point) {
      return [point[0] + cropRect.left, point[1] + cropRect.top];
    }).toList();
  }

  /// Calcula el centro y diámetro de un contorno.
  _ContourStats _calculerStatistiquesContour(List<List<double>> contours) {
    if (contours.isEmpty) {
      return _ContourStats(center: ui.Offset.zero, diameter: 0);
    }

    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    double sumX = 0, sumY = 0;

    for (final point in contours) {
      final x = point[0];
      final y = point[1];
      sumX += x;
      sumY += y;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }

    final center = ui.Offset(sumX / contours.length, sumY / contours.length);
    final diameter = ((maxX - minX) + (maxY - minY)) / 2; // promedio

    return _ContourStats(center: center, diameter: diameter);
  }

  /// Distance euclidienne entre deux points.
  double _distanceBetween(ui.Offset a, ui.Offset b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return math.sqrt(dx * dx + dy * dy);
  }
}

/// Estadísticas de un contorno (centro + diámetro).
class _ContourStats {
  final ui.Offset center;
  final double diameter;
  const _ContourStats({required this.center, required this.diameter});
}
