import 'dart:ui';
import 'dart:typed_data';
import '../../models/facial_landmark.dart';
import '../face_landmark_service.dart';
import '../antigravity_decision_service.dart';
import '../reconstruction_service.dart';

/// Résultat complet d'une analyse faciale combinant landmarks, région et reconstruction.
///
/// Agrège les données provenant de plusieurs services :
/// - [FaceLandmarkService] → points clés et région anatomique
/// - [ReconstructionService] → options de reconstruction chirurgicale
/// - [AntigravityDecisionService] → zone de l'arbre de décision
class FacialAnalysisResult {
  /// Points clés du visage détectés par ML Kit.
  final FacialKeyPoints keyPoints;

  /// Région anatomique identifiée pour la position de la lésion.
  final FacialRegion region;

  /// Distances en pixels entre la lésion et chaque point clé facial.
  final Map<String, double> distancesPx;

  /// Options de reconstruction chirurgicale proposées.
  final List<ReconstructionOption> reconstructionOptions;

  /// Zone de reconstruction correspondante dans l'arbre de décision.
  final ReconstructionZone? reconstructionZone;

  /// Diagnostic associé (optionnel, provenant de l'analyse Roboflow).
  final String? diagnosis;

  /// Confiance du diagnostic (optionnel).
  final double? confidence;

  FacialAnalysisResult({
    required this.keyPoints,
    required this.region,
    required this.distancesPx,
    required this.reconstructionOptions,
    this.reconstructionZone,
    this.diagnosis,
    this.confidence,
  });
}

/// Service d'analyse faciale complète (pipeline local).
///
/// Couche locale — orchestre le pipeline complet d'analyse faciale
/// en combinant la détection de landmarks, la détermination de région,
/// le calcul de distances et les recommandations de reconstruction.
///
/// Flux de données :
/// 1. Image → [FaceLandmarkService] → points clés du visage
/// 2. Position lésion + points clés → détermination de la région anatomique
/// 3. Position lésion + points clés → calcul des distances en pixels
/// 4. Région + taille → [ReconstructionService] → options chirurgicales
/// 5. Région → [AntigravityDecisionService] → zone de l'arbre de décision
/// 6. Agrégation → [FacialAnalysisResult]
class FacialAnalysisService {
  static final FacialAnalysisService _instance =
      FacialAnalysisService._internal();
  factory FacialAnalysisService() => _instance;
  FacialAnalysisService._internal();

  /// Service de détection des landmarks faciaux (Google ML Kit).
  final FaceLandmarkService _landmarkService = FaceLandmarkService();

  /// Service de recommandation de techniques de reconstruction.
  final ReconstructionService _reconstructionService = ReconstructionService();

  /// Service d'arbres de décision de reconstruction (thèse).
  final AntigravityDecisionService _decisionService =
      AntigravityDecisionService();

  /// Analyse une image faciale avec une position de lésion spécifique.
  ///
  /// Exécute le pipeline complet : landmarks → région → distances →
  /// reconstruction → arbre de décision.
  ///
  /// Paramètres :
  /// - [imageBytes] : octets bruts de l'image (BGRA)
  /// - [width] / [height] : dimensions de l'image
  /// - [lesionPosition] : position de la lésion sur l'image
  /// - [lesionSizeMm] : taille estimée de la lésion en mm
  /// - [marginMm] : marge de sécurité chirurgicale en mm
  /// - [imagePath] : chemin du fichier image (recommandé pour JPEG/PNG)
  ///
  /// Retourne `null` si aucun visage n'est détecté.
  Future<FacialAnalysisResult?> analyze({
    required Uint8List imageBytes,
    required int width,
    required int height,
    required Offset lesionPosition,
    double lesionSizeMm = 0,
    double marginMm = 5.0,
    String? diagnosis,
    double? confidence,
    String? imagePath,
  }) async {
    // 1. Détecter les landmarks (préférer le fichier pour JPEG/PNG)
    FacialKeyPoints? keyPoints;
    if (imagePath != null) {
      keyPoints = await _landmarkService.detectFacialLandmarksFromFile(
        imagePath,
      );
    } else {
      keyPoints = await _landmarkService.detectFacialLandmarks(
        imageBytes,
        width,
        height,
      );
    }
    if (keyPoints == null) {
      return null;
    }

    // 2. Déterminer la région anatomique
    final region = _landmarkService.determineRegion(lesionPosition, keyPoints);

    // 3. Calculer les distances en pixels
    final distances = _landmarkService.calculateDistancesToKeyPoints(
      lesionPosition,
      keyPoints,
    );

    // 4. Obtenir les options de reconstruction
    final options = _reconstructionService.getReconstructionOptions(
      region: region,
      lesionSizeMm: lesionSizeMm,
      marginMm: marginMm,
      distancesToKeyPoints: distances,
    );

    // 5. Déterminer la zone Antigravity (logique avancée)
    final zone = _decisionService.getZoneForRegion(region);

    return FacialAnalysisResult(
      keyPoints: keyPoints,
      region: region,
      distancesPx: distances,
      reconstructionOptions: options,
      reconstructionZone: zone,
      diagnosis: diagnosis,
      confidence: confidence,
    );
  }

  /// Indique si le service d'analyse faciale est disponible sur cette plateforme.
  bool get isAvailable => _landmarkService.isAvailable;
}
