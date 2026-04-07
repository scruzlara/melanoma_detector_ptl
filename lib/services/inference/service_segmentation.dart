import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:pytorch_lite/pytorch_lite.dart';

import '../../core/math/traceur_contour.dart';
import '../../donnees/config/config_modeles.dart';

/// Service d'inférence de segmentation (U-Net).
///
/// Couche infrastructure — encapsule le chargement et l'exécution
/// du modèle U-Net PyTorch Lite pour la segmentation de lésion.
///
/// **Pipeline de traitement :**
/// 1. Inférence U-Net → masque de probabilités (256×256).
/// 2. Extraction de contour via l'algorithme de Moore-Neighbor
///    (délégué à [TraceurContour]).
/// 3. Mise à l'échelle des contours normalisés vers les dimensions
///    de l'image originale.
///
/// **Gestion mémoire :**
/// - Le modèle est chargé une seule fois (singleton pattern).
/// - Les codecs d'image sont libérés immédiatement après lecture
///   des dimensions (`frame.image.dispose()`).
///
/// Aucune donnée ne quitte la mémoire de l'appareil.
class ServiceSegmentation {
  /// Modèle de segmentation U-Net chargé.
  ClassificationModel? _modele;

  /// Indique si le modèle est chargé et prêt.
  bool _estCharge = false;

  /// Indique si le modèle de segmentation est disponible.
  bool get estCharge => _estCharge;

  // ---------------------------------------------------------------------------
  // Chargement du modèle
  // ---------------------------------------------------------------------------

  /// Charge le modèle de segmentation U-Net depuis les assets.
  ///
  /// Ne fait rien si le modèle est déjà chargé (optimisation).
  /// Les erreurs sont capturées et journalisées en mode debug.
  Future<void> chargerModele() async {
    if (_estCharge) return;

    try {
      if (kDebugMode) {
        debugPrint('[ServiceSegmentation] Chargement modèle U-Net...');
      }

      _modele = await PytorchLite.loadClassificationModel(
        ConfigModeles.cheminModeleSegmentation,
        ConfigModeles.tailleEntreeSegmentation,
        ConfigModeles.tailleEntreeSegmentation,
        labelPath: null,
      );
      _estCharge = true;

      if (kDebugMode) {
        debugPrint('[ServiceSegmentation] Modèle U-Net chargé.');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ServiceSegmentation] Erreur chargement : $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Prédiction de segmentation
  // ---------------------------------------------------------------------------

  /// Exécute la segmentation et retourne les contours en pixels originaux.
  ///
  /// **Étapes du pipeline :**
  /// 1. Lecture des octets de l'image.
  /// 2. Inférence U-Net → masque plat de probabilités.
  /// 3. Extraction du contour via [TraceurContour.extraireContour]
  ///    (algorithme de Moore-Neighbor avec table de lookup O(1)).
  /// 4. Obtention des dimensions originales de l'image
  ///    (sans décoder l'image entière — optimisation mémoire).
  /// 5. Mise à l'échelle des points normalisés vers les pixels originaux.
  ///
  /// Retourne `null` si :
  /// - Le modèle n'est pas disponible.
  /// - Aucun pixel de premier plan n'est détecté dans le masque.
  /// - Une erreur survient pendant l'inférence.
  /// Exécute la segmentation sur un fichier image.
  Future<List<List<double>>?> predire(File fichierImage) async {
    if (!_estCharge) await chargerModele();
    if (_modele == null) return null;

    try {
      final octetsImage = await fichierImage.readAsBytes();
      return _predireDepuistOctets(octetsImage);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ServiceSegmentation] Erreur lecture fichier : $e');
      }
      return null;
    }
  }

  /// Exécute la segmentation sur des octets d'image (ex. lesion recadrée).
  Future<List<List<double>>?> predireDepuisBytes(Uint8List octetsImage) async {
    if (!_estCharge) await chargerModele();
    if (_modele == null) return null;

    return _predireDepuistOctets(octetsImage);
  }

  /// Logique commune d'inférence depuis des octets.
  Future<List<List<double>>?> _predireDepuistOctets(
    Uint8List octetsImage,
  ) async {
    try {
      // Inférence U-Net → masque plat (256×256 valeurs)
      final sortie = await _modele!.getImagePredictionList(octetsImage);
      if (sortie == null || sortie.isEmpty) return null;

      // Obtenir les dimensions originales sans décoder l'image entière
      final dimensions = await _obtenirDimensionsImage(octetsImage);

      // Extraction du contour via l'algorithme de Moore-Neighbor
      final pointsNormalises = TraceurContour.extraireContour(
        sortie,
        ConfigModeles.tailleEntreeSegmentation,
        ConfigModeles.tailleEntreeSegmentation,
      );
      if (pointsNormalises == null) return null;

      // Mise à l'échelle vers les dimensions de l'image originale
      return pointsNormalises
          .map((p) => [p[0] * dimensions.largeur, p[1] * dimensions.hauteur])
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ServiceSegmentation] Erreur segmentation : $e');
      }
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Libération des ressources
  // ---------------------------------------------------------------------------

  /// Libère le modèle de segmentation.
  ///
  /// Doit être appelé lors de la destruction du service parent
  /// pour éviter les fuites de mémoire native.
  void dispose() {
    _modele = null;
    _estCharge = false;
  }

  // ---------------------------------------------------------------------------
  // Méthodes privées
  // ---------------------------------------------------------------------------

  /// Obtient les dimensions d'une image sans la décoder entièrement.
  ///
  /// Utilise `ui.instantiateImageCodec` qui ne décode que les
  /// métadonnées (dimensions, format). Le codec et le frame sont
  /// libérés immédiatement après lecture.
  ///
  /// En cas d'échec, retourne les dimensions par défaut du modèle
  /// de segmentation (256×256).
  Future<_DimensionsImage> _obtenirDimensionsImage(
    Uint8List octetsImage,
  ) async {
    try {
      final codec = await ui.instantiateImageCodec(octetsImage);
      final frame = await codec.getNextFrame();
      final largeur = frame.image.width;
      final hauteur = frame.image.height;
      frame.image.dispose(); // Libération immédiate
      return _DimensionsImage(largeur: largeur, hauteur: hauteur);
    } catch (_) {
      // Fallback : dimensions par défaut du modèle
      return _DimensionsImage(
        largeur: ConfigModeles.tailleEntreeSegmentation,
        hauteur: ConfigModeles.tailleEntreeSegmentation,
      );
    }
  }
}

/// Dimensions d'une image (largeur × hauteur).
///
/// Classe interne utilisée pour transporter les dimensions
/// sans créer de dépendance vers `dart:ui`.
class _DimensionsImage {
  final int largeur;
  final int hauteur;
  const _DimensionsImage({required this.largeur, required this.hauteur});
}
