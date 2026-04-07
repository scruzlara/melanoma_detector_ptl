import '../../domaine/entites/definition_modele.dart';

/// Configuration centralisée des modèles d'intelligence artificielle.
///
/// Couche données — définit les modèles disponibles et les chemins
/// vers les fichiers assets PyTorch Lite.
class ConfigModeles {
  ConfigModeles._();

  // ---------------------------------------------------------------------------
  // Liste des Modèles de Classification Disponibles
  // ---------------------------------------------------------------------------

  /// Modèles de classification disponibles pour l'inférence locale.
  ///
  /// Chaque modèle spécifie sa taille d'entrée (224 ou 384 pixels).
  static const List<DefinitionModele> modelesDisponibles = [
    DefinitionModele(
      nom: 'MobileNetV3 (Model D)',
      cheminAsset: 'assets/models/melanoma_mobilenet_v3.ptl',
      tailleEntree: 224,
    ),
    DefinitionModele(
      nom: 'Melanoma Mobile V2',
      cheminAsset: 'assets/models/melanoma_mobile_v2.ptl',
      tailleEntree: 384,
    ),
    DefinitionModele(
      nom: 'Melanoma Mobile (V1)',
      cheminAsset: 'assets/models/melanoma_mobile.ptl',
      tailleEntree: 384,
    ),
    DefinitionModele(
      nom: 'Melanoma Quantized',
      cheminAsset: 'assets/models/melanoma_mobile_quantized.ptl',
      tailleEntree: 384,
    ),
  ];

  /// Modèle par défaut (MobileNetV3 — compatible LibTorch 1.14, pas de SDPA requis).
  static DefinitionModele get modeleParDefaut => modelesDisponibles[0];

  /// Chemin du fichier de labels associé (commun à tous les modèles).
  static const String cheminLabels = 'assets/models/labels.txt';

  // ---------------------------------------------------------------------------
  // Segmentation (Extraction de forme)
  // ---------------------------------------------------------------------------

  /// Chemin du modèle de segmentation PyTorch Lite (U-Net).
  static const String cheminModeleSegmentation =
      'assets/models/segmentation.ptl';

  /// Taille d'entrée (256×256) pour le modèle de segmentation.
  static const int tailleEntreeSegmentation = 256;

  // ---------------------------------------------------------------------------
  // Normalisation ImageNet
  // ---------------------------------------------------------------------------

  /// Moyenne de normalisation ImageNet (RGB).
  static const List<double> moyenneNorm = [0.485, 0.456, 0.406];

  /// Écart-type de normalisation ImageNet (RGB).
  static const List<double> ecartTypeNorm = [0.229, 0.224, 0.225];

  // ---------------------------------------------------------------------------
  // Temperature Scaling (calibration des probabilités)
  // ---------------------------------------------------------------------------

  /// Température appliquée aux logits bruts avant le softmax.
  ///
  /// T < 1 → distributions plus tranchées (confiance amplifiée).
  /// T = 1 → comportement standard (softmax simple).
  /// T > 1 → distributions plus lisses (confiance atténuée).
  ///
  /// Valeur recommandée : 0.5 pour le modèle MobileNetV3 actuel,
  /// dont les logits sont faibles (~±0.3) car entraîné sans correction
  /// du déséquilibre de classes.
  static const double temperatureScaling = 0.5;

  // ---------------------------------------------------------------------------
  // Seuil de décision malignité
  // ---------------------------------------------------------------------------

  /// Seuil de probabilité à partir duquel une lésion est considérée maligne.
  ///
  /// Le modèle MobileNetV3 actuel est biaisé vers "bénin" (entraîné sur
  /// un dataset à 67% bénins sans correction du déséquilibre).
  /// Un seuil abaissé à 0.30 compense ce biais et améliore la sensibilité
  /// (détection des vrais mélanomes), au prix de quelques faux positifs
  /// supplémentaires — comportement cliniquement préférable.
  ///
  /// Valeurs indicatives :
  /// - 0.50 : seuil classique (trop de mélanomes manqués)
  /// - 0.35 : compromis sensibilité/spécificité
  /// - 0.25 : haute sensibilité (recommandé pour dépistage)
  static const double seuilDetectionMalin = 0.25;

  // ---------------------------------------------------------------------------
  // YOLO Detection (Localisation de lésions sur visage complet)
  // ---------------------------------------------------------------------------

  /// Chemin du modèle YOLO PyTorch Lite pour la détection de lésions.
  static const String cheminModeleDetection =
      'assets/models/yolo11n_lesion.ptl';

  /// Chemin du fichier de labels YOLO.
  static const String cheminLabelsDetection = 'assets/models/labels_yolo.txt';

  /// Taille d'entrée (640×640) pour le modèle YOLO.
  static const int tailleEntreeDetection = 640;

  /// Nombre de classes du modèle YOLO (1 = "Lesion").
  static const int nombreClassesDetection = 1;

  /// Score minimal pour conserver une détection.
  static const double seuilScoreDetection = 0.1; // Seuil réduit pour debug

  /// Seuil IoU pour le NMS (Non-Maximum Suppression).
  static const double seuilIouDetection = 0.5;

  /// Nombre maximal de détections retournées.
  static const int maxBoxesDetection = 20;
}
