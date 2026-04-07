import 'dart:ui';
import 'dart:typed_data';
import '../models/facial_landmark.dart';
import 'face_landmark_service.dart';
import 'antigravity_decision_service.dart';
import 'reconstruction_service.dart';

class FacialAnalysisResult {
  final FacialKeyPoints keyPoints;
  final FacialRegion region;
  final Map<String, double> distancesPx;
  final List<ReconstructionOption> reconstructionOptions;
  final ReconstructionZone? reconstructionZone;
  final String? diagnosis;
  final double? confidence;
  final double? pxToMmRatio;
  final List<List<double>>? contours;

  FacialAnalysisResult({
    required this.keyPoints,
    required this.region,
    required this.distancesPx,
    required this.reconstructionOptions,
    this.reconstructionZone,
    this.diagnosis,
    this.confidence,
    this.pxToMmRatio,
    this.contours,
  });
}

class FacialAnalysisService {
  static final FacialAnalysisService _instance =
      FacialAnalysisService._internal();
  factory FacialAnalysisService() => _instance;
  FacialAnalysisService._internal();

  final FaceLandmarkService _landmarkService = FaceLandmarkService();
  final ReconstructionService _reconstructionService = ReconstructionService();
  final AntigravityDecisionService _decisionService =
      AntigravityDecisionService();

  /// Analyze a facial image with a specific lesion position
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
    // 1. Detect landmarks (prefer file-based for JPEG/PNG)
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

    // 2. Determine region
    final region = _landmarkService.determineRegion(lesionPosition, keyPoints);

    // 3. Calculate distances (in pixels)
    final distances = _landmarkService.calculateDistancesToKeyPoints(
      lesionPosition,
      keyPoints,
    );

    // 4. Get reconstruction options
    final options = _reconstructionService.getReconstructionOptions(
      region: region,
      lesionSizeMm: lesionSizeMm,
      marginMm: marginMm,
      distancesToKeyPoints: distances,
    );

    // 5. Determine Antigravity Zone (for advanced logic)
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

  bool get isAvailable => _landmarkService.isAvailable;
}
