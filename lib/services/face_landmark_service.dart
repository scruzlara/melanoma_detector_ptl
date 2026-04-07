import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/facial_landmark.dart';

/// Service de détection des landmarks faciaux via Google ML Kit
/// Note: Ce service ne fonctionne que sur iOS/Android, pas sur le web
class FaceLandmarkService {
  static final FaceLandmarkService _instance = FaceLandmarkService._internal();
  factory FaceLandmarkService() => _instance;
  FaceLandmarkService._internal();

  FaceDetector? _faceDetector;

  /// Initialise le détecteur de visage
  FaceDetector get faceDetector {
    _faceDetector ??= FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableLandmarks: true,
        enableClassification: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
    return _faceDetector!;
  }

  /// Vérifie si le service est disponible sur la plateforme actuelle
  bool get isAvailable => !kIsWeb;

  /// Détecte les landmarks faciaux depuis un fichier image (JPEG/PNG)
  /// C'est la méthode recommandée car InputImage.fromFilePath gère
  /// automatiquement le décodage du format d'image.
  Future<FacialKeyPoints?> detectFacialLandmarksFromFile(
    String filePath,
  ) async {
    if (kIsWeb) {
      return null;
    }

    try {
      final inputImage = InputImage.fromFilePath(filePath);
      final faces = await faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        return null;
      }

      final face = faces.first;
      return _extractKeyPoints(face);
    } catch (e) {
      debugPrint('Erreur lors de la détection faciale: $e');
      return null;
    }
  }

  /// Détecte les landmarks faciaux dans une image depuis des bytes bruts (BGRA)
  /// Retourne null si aucun visage n'est détecté ou si la plateforme n'est pas supportée
  Future<FacialKeyPoints?> detectFacialLandmarks(
    Uint8List imageBytes,
    int imageWidth,
    int imageHeight,
  ) async {
    if (kIsWeb) {
      return null;
    }

    try {
      final inputImage = InputImage.fromBytes(
        bytes: imageBytes,
        metadata: InputImageMetadata(
          size: Size(imageWidth.toDouble(), imageHeight.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.bgra8888,
          bytesPerRow: imageWidth * 4,
        ),
      );

      final faces = await faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        return null;
      }

      final face = faces.first;
      return _extractKeyPoints(face);
    } catch (e) {
      debugPrint('Erreur lors de la détection faciale: $e');
      return null;
    }
  }

  /// Extrait les points clés d'un visage détecté
  FacialKeyPoints _extractKeyPoints(Face face) {
    Offset? landmarkToOffset(FaceLandmark? landmark) {
      if (landmark == null) return null;
      return Offset(
        landmark.position.x.toDouble(),
        landmark.position.y.toDouble(),
      );
    }

    // Extraire les contours du visage
    List<Offset> faceContour = [];
    final contour = face.contours[FaceContourType.face];
    if (contour != null) {
      faceContour =
          contour.points
              .map((p) => Offset(p.x.toDouble(), p.y.toDouble()))
              .toList();
    }

    // Calculer le centre de la bouche à partir des coins
    Offset? mouthCenter;
    final leftMouth = landmarkToOffset(
      face.landmarks[FaceLandmarkType.leftMouth],
    );
    final rightMouth = landmarkToOffset(
      face.landmarks[FaceLandmarkType.rightMouth],
    );
    if (leftMouth != null && rightMouth != null) {
      mouthCenter = Offset(
        (leftMouth.dx + rightMouth.dx) / 2,
        (leftMouth.dy + rightMouth.dy) / 2,
      );
    }

    // Estimer le front (au-dessus des yeux)
    Offset? forehead;
    final leftEye = landmarkToOffset(face.landmarks[FaceLandmarkType.leftEye]);
    final rightEye = landmarkToOffset(
      face.landmarks[FaceLandmarkType.rightEye],
    );
    if (leftEye != null && rightEye != null) {
      final eyeCenter = Offset(
        (leftEye.dx + rightEye.dx) / 2,
        (leftEye.dy + rightEye.dy) / 2,
      );
      // Le front est environ 30% de la hauteur du visage au-dessus des yeux
      final faceHeight = face.boundingBox.height;
      forehead = Offset(eyeCenter.dx, eyeCenter.dy - faceHeight * 0.2);
    }

    return FacialKeyPoints(
      leftEye: leftEye,
      rightEye: rightEye,
      noseTip: landmarkToOffset(face.landmarks[FaceLandmarkType.noseBase]),
      noseBase: landmarkToOffset(face.landmarks[FaceLandmarkType.noseBase]),
      leftMouth: leftMouth,
      rightMouth: rightMouth,
      mouthCenter: mouthCenter,
      leftCheek: landmarkToOffset(face.landmarks[FaceLandmarkType.leftCheek]),
      rightCheek: landmarkToOffset(face.landmarks[FaceLandmarkType.rightCheek]),
      chin: landmarkToOffset(face.landmarks[FaceLandmarkType.bottomMouth]),
      forehead: forehead,
      faceContour: faceContour,
    );
  }

  /// Calcule les distances entre un point de lésion et les points clés faciaux
  /// Retourne les distances en pixels
  Map<String, double> calculateDistancesToKeyPoints(
    Offset lesionCenter,
    FacialKeyPoints keyPoints,
  ) {
    final distances = <String, double>{};

    for (final entry in keyPoints.allPoints.entries) {
      if (entry.value != null) {
        distances[entry.key] = FacialKeyPoints.distanceBetween(
          lesionCenter,
          entry.value!,
        );
      }
    }

    return distances;
  }

  /// Détermine la région faciale d'un point
  FacialRegion determineRegion(Offset point, FacialKeyPoints keyPoints) {
    // Si on n'a pas assez de points, retourner inconnu
    if (keyPoints.leftEye == null || keyPoints.rightEye == null) {
      return FacialRegion.unknown;
    }

    final leftEye = keyPoints.leftEye!;
    final rightEye = keyPoints.rightEye!;
    final faceCenter =
        keyPoints.faceCenter ??
        Offset((leftEye.dx + rightEye.dx) / 2, (leftEye.dy + rightEye.dy) / 2);

    // Distance entre les yeux pour estimer les proportions
    final eyeDistance = (rightEye - leftEye).distance;

    // Vérifier la zone péri-orbitaire
    if ((point - leftEye).distance < eyeDistance * 0.4) {
      return FacialRegion.leftPeriorbital;
    }
    if ((point - rightEye).distance < eyeDistance * 0.4) {
      return FacialRegion.rightPeriorbital;
    }

    // Vérifier le nez
    if (keyPoints.noseTip != null) {
      if ((point - keyPoints.noseTip!).distance < eyeDistance * 0.3) {
        return FacialRegion.nose;
      }
    }

    // Vérifier les lèvres
    if (keyPoints.mouthCenter != null) {
      final distToMouth = (point - keyPoints.mouthCenter!).distance;
      if (distToMouth < eyeDistance * 0.3) {
        if (point.dy < keyPoints.mouthCenter!.dy) {
          return FacialRegion.upperLip;
        }
        return FacialRegion.lowerLip;
      }
    }

    // Vérifier le menton
    if (keyPoints.chin != null) {
      if ((point - keyPoints.chin!).distance < eyeDistance * 0.4) {
        return FacialRegion.chin;
      }
    }

    // Vérifier le front
    if (keyPoints.forehead != null) {
      if ((point - keyPoints.forehead!).distance < eyeDistance * 0.5) {
        return FacialRegion.forehead;
      }
    }

    // Déterminer les joues (gauche ou droite du centre)
    if (point.dx < faceCenter.dx) {
      return FacialRegion.leftCheek;
    } else {
      return FacialRegion.rightCheek;
    }
  }

  /// Libère les ressources
  void dispose() {
    _faceDetector?.close();
    _faceDetector = null;
  }
}

/// Fonction de debug print compatible web
void debugPrint(String message) {
  if (kIsWeb) {
    // ignore: avoid_print
    print('[FaceLandmarkService] $message');
  }
}
