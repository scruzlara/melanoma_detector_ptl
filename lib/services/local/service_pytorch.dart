import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../domaine/entites/definition_modele.dart';
import '../../services/inference/service_classification.dart';
import '../../services/inference/service_detection_yolo.dart';
import '../../services/inference/service_segmentation.dart';

export '../../services/inference/service_detection_yolo.dart'
    show DetectionYolo;

/// Façade d'inférence PyTorch Lite pour la détection de mélanome.
///
/// Couche données — orchestre les trois services d'inférence spécialisés :
/// - [ServiceClassification] : classification bénin/maligne (MobileNetV3).
/// - [ServiceSegmentation] : segmentation U-Net (masque + contours).
/// - [ServiceDetectionYolo] : détection de lésions (YOLO v8/v11).
///
/// Cette façade maintient la compatibilité ascendante avec le code existant
/// (notamment [ProviderMelanome]) tout en déléguant la logique à des services
/// mono-responsabilité.
///
/// **Pattern Singleton** pour éviter le rechargement inutile des modèles.
///
/// Aucune donnée ne quitte la mémoire de l'appareil.
class ServicePyTorch {
  static final ServicePyTorch _instance = ServicePyTorch._interne();
  factory ServicePyTorch() => _instance;
  ServicePyTorch._interne();

  // ---------------------------------------------------------------------------
  // Services spécialisés (délégation)
  // ---------------------------------------------------------------------------

  /// Service de classification (MobileNetV3 / MobileNetV2).
  final ServiceClassification _classification = ServiceClassification();

  /// Service de segmentation (U-Net).
  final ServiceSegmentation _segmentation = ServiceSegmentation();

  /// Service de détection (YOLO v8/v11).
  final ServiceDetectionYolo _detection = ServiceDetectionYolo();

  // ---------------------------------------------------------------------------
  // Classification
  // ---------------------------------------------------------------------------

  /// Charge un modèle de classification spécifique.
  ///
  /// Délègue à [ServiceClassification.chargerModele].
  Future<void> chargerModele(DefinitionModele definition) =>
      _classification.chargerModele(definition);

  /// Exécute la classification sur un fichier image.
  ///
  /// Délègue à [ServiceClassification.predire].
  /// Retourne un `Map` contenant `label`, `confiance`,
  /// `prob_malignant`, et `probabilites`.
  Future<Map<String, dynamic>> predire(
    File fichierImage,
    DefinitionModele definition,
  ) => _classification.predire(fichierImage, definition);

  /// Exécute la classification sur des octets bruts (image recadrée).
  ///
  /// Délègue à [ServiceClassification.predireDepuisBytes].
  Future<Map<String, dynamic>> predireDepuisBytes(
    Uint8List octetsImage,
    DefinitionModele definition,
  ) => _classification.predireDepuisBytes(octetsImage, definition);

  // ---------------------------------------------------------------------------
  // Segmentation
  // ---------------------------------------------------------------------------

  /// Charge le modèle de segmentation U-Net.
  ///
  /// Délègue à [ServiceSegmentation.chargerModele].
  Future<void> chargerModeleSegmentation() => _segmentation.chargerModele();

  /// Exécute la segmentation et retourne les contours normalisés.
  ///
  /// Délègue à [ServiceSegmentation.predire].
  /// Retourne `null` si le modèle n'est pas disponible.
  Future<List<List<double>>?> predireSegmentation(File fichierImage) =>
      _segmentation.predire(fichierImage);

  /// Exécute la segmentation sur des octets bruts.
  ///
  /// Délègue à [ServiceSegmentation.predireDepuisBytes].
  Future<List<List<double>>?> predireSegmentationDepuisBytes(
    Uint8List octetsImage,
  ) => _segmentation.predireDepuisBytes(octetsImage);

  // ---------------------------------------------------------------------------
  // Détection YOLO
  // ---------------------------------------------------------------------------

  /// Charge le modèle de détection YOLO.
  ///
  /// Délègue à [ServiceDetectionYolo.chargerModele].
  Future<void> chargerModeleDetection() => _detection.chargerModele();

  /// Détecte les lésions sur une image de visage complet.
  ///
  /// Délègue à [ServiceDetectionYolo.detecter].
  /// Retourne une liste de [DetectionYolo] avec bboxes normalisées [0..1].
  Future<List<DetectionYolo>> detecterLesions(File fichierImage) =>
      _detection.detecter(fichierImage);

  // ---------------------------------------------------------------------------
  // Libération des ressources
  // ---------------------------------------------------------------------------

  /// Libère tous les modèles chargés.
  ///
  /// Doit être appelé lors de la destruction de l'application
  /// pour éviter les fuites de mémoire native PyTorch.
  void dispose() {
    _classification.dispose();
    _segmentation.dispose();
    _detection.dispose();
    if (kDebugMode) {
      debugPrint('[ServicePyTorch] Tous les modèles libérés.');
    }
  }
}
