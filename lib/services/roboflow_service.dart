import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/skin_analysis_result.dart';

/// Service for communicating with Roboflow API for skin lesion detection
class RoboflowService {
  static final RoboflowService _instance = RoboflowService._internal();
  factory RoboflowService() => _instance;
  RoboflowService._internal();

  String get _apiKey => dotenv.env['ROBOFLOW_API_KEY'] ?? '';

  // Using Roboflow Inference API endpoint (detect.roboflow.com or serverless)
  String get _baseUrl =>
      dotenv.env['ROBOFLOW_MODEL_ENDPOINT'] ?? 'https://detect.roboflow.com';

  // Public skin lesion detection model
  String get _modelId =>
      dotenv.env['ROBOFLOW_MODEL_ID'] ?? 'skin-cancer-classification-kjic2/1';

  /// Analyze an image from bytes
  Future<SkinAnalysisResult> analyzeImageBytes(
    Uint8List imageBytes,
    String imagePath, {
    String? modelId,
  }) async {
    try {
      final String base64Image = base64Encode(imageBytes);

      // Use provided modelId, or fallback to env variable, or default
      final String effectiveModelId = modelId ?? _modelId;

      // Build API URL with the serverless endpoint
      final String apiUrl = '$_baseUrl/$effectiveModelId?api_key=$_apiKey';

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: base64Image,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw RoboflowException(
                'Timeout',
                'La requête a expiré. Vérifiez votre connexion internet.',
              );
            },
          );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        debugPrint(
          '[Roboflow] Response JSON: ${response.body.substring(0, response.body.length.clamp(0, 500))}',
        );
        return _parseResponse(jsonResponse, imagePath);
      } else if (response.statusCode == 403) {
        throw RoboflowException(
          'Accès refusé (403)',
          'Vérifiez votre clé API.',
        );
      } else if (response.statusCode == 404 || response.statusCode == 405) {
        throw RoboflowException(
          'Modèle incompatible (${response.statusCode})',
          'Ce modèle n\'est pas accessible via l\'API serverless.',
        );
      } else {
        throw RoboflowException('Échec: ${response.statusCode}', response.body);
      }
    } on RoboflowException {
      rethrow;
    } catch (e) {
      throw RoboflowException('Erreur de connexion', e.toString());
    }
  }

  /// Parse Roboflow API response (handles both classification and detection models)
  SkinAnalysisResult _parseResponse(
    Map<String, dynamic> json,
    String imagePath,
  ) {
    List<Detection> detections = [];
    String lesionClass = 'UNKNOWN';
    double maxConfidence = 0.0;

    if (json.containsKey('predictions')) {
      final predictions = json['predictions'];

      if (predictions is Map<String, dynamic>) {
        // Classification model response: {"predictions": {"class1": {"confidence": 0.8}, ...}}
        predictions.forEach((className, value) {
          double conf = 0.0;
          if (value is Map<String, dynamic>) {
            conf = (value['confidence'] as num?)?.toDouble() ?? 0.0;
          } else if (value is num) {
            conf = value.toDouble();
          }
          detections.add(
            Detection(
              className: className.toUpperCase(),
              confidence: conf,
              x: 0,
              y: 0,
              width: 0,
              height: 0,
            ),
          );
          if (conf > maxConfidence) {
            maxConfidence = conf;
            lesionClass = className.toUpperCase();
          }
        });
      } else if (predictions is List) {
        // Object detection model response: {"predictions": [{...}, ...]}
        for (final p in predictions) {
          if (p is Map<String, dynamic>) {
            final det = Detection(
              className: (p['class'] as String? ?? '').toUpperCase(),
              confidence: (p['confidence'] as num?)?.toDouble() ?? 0.0,
              x: (p['x'] as num?)?.toDouble() ?? 0.0,
              y: (p['y'] as num?)?.toDouble() ?? 0.0,
              width: (p['width'] as num?)?.toDouble() ?? 0.0,
              height: (p['height'] as num?)?.toDouble() ?? 0.0,
            );
            detections.add(det);
            if (det.confidence > maxConfidence) {
              maxConfidence = det.confidence;
              lesionClass = det.className;
            }
          }
        }
      }
    }

    // Handle alternative classification format: {"top": "class", "confidence": 0.8}
    if (detections.isEmpty && json.containsKey('top')) {
      final topClass = (json['top'] as String? ?? '').toUpperCase();
      final topConf = (json['confidence'] as num?)?.toDouble() ?? 0.0;
      lesionClass = topClass;
      maxConfidence = topConf;
      detections.add(
        Detection(
          className: topClass,
          confidence: topConf,
          x: 0,
          y: 0,
          width: 0,
          height: 0,
        ),
      );
    }

    // Handle yet another format: {"predicted_classes": ["class1"]}
    if (detections.isEmpty && json.containsKey('predicted_classes')) {
      final classes = json['predicted_classes'];
      if (classes is List && classes.isNotEmpty) {
        lesionClass = (classes.first as String).toUpperCase();
        maxConfidence = (json['confidence'] as num?)?.toDouble() ?? 0.5;
        detections.add(
          Detection(
            className: lesionClass,
            confidence: maxConfidence,
            x: 0,
            y: 0,
            width: 0,
            height: 0,
          ),
        );
      }
    }

    if (detections.isEmpty) {
      return SkinAnalysisResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        imagePath: imagePath,
        lesionClass: 'NONE',
        lesionName: 'Aucune lésion détectée',
        confidence: 0.0,
        riskLevel: RiskLevel.unknown,
        timestamp: DateTime.now(),
        detections: [],
      );
    }

    return SkinAnalysisResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      imagePath: imagePath,
      lesionClass: lesionClass,
      lesionName: LesionClassInfo.getName(lesionClass),
      confidence: maxConfidence,
      riskLevel: LesionClassInfo.getRiskLevel(lesionClass),
      timestamp: DateTime.now(),
      detections: detections,
    );
  }
}

class RoboflowException implements Exception {
  final String message;
  final String details;

  RoboflowException(this.message, this.details);

  @override
  String toString() => '$message: $details';
}
