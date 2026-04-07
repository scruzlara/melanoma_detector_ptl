import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:pytorch_lite/pytorch_lite.dart';

import '../../domaine/entites/definition_modele.dart';
import '../config/config_modeles.dart';

/// Service d'inférence PyTorch Lite pour la détection de mélanome.
///
/// Couche données — gère le chargement et l'exécution de deux modèles :
/// - **Classification** : prédit Bénin/Malignant.
/// - **Segmentation** (U-Net) : génère un masque de la lésion
///   et en extrait les contours via l'algorithme de Moore-Neighbor.
///
/// Singleton pour éviter le rechargement inutile des modèles.
class ServicePyTorch {
  static final ServicePyTorch _instance = ServicePyTorch._interne();
  factory ServicePyTorch() => _instance;
  ServicePyTorch._interne();

  // ---------------------------------------------------------------------------
  // Modèles chargés
  // ---------------------------------------------------------------------------

  /// Modèle de classification actuellement chargé.
  ClassificationModel? _modeleClassification;

  /// Définition du modèle de classification en cours.
  DefinitionModele? _definitionCourante;

  /// Modèle de segmentation U-Net.
  ClassificationModel? _modeleSegmentation;

  /// Indique si le modèle de segmentation est chargé.
  bool _segmentationChargee = false;

  // ---------------------------------------------------------------------------
  // Chargement des modèles
  // ---------------------------------------------------------------------------

  /// Charge un modèle de classification spécifique via [definition].
  ///
  /// Si le modèle demandé est déjà chargé, ne fait rien.
  /// Sinon, libère l'ancien modèle et charge le nouveau.
  Future<void> chargerModele(DefinitionModele definition) async {
    if (_modeleClassification != null && _definitionCourante == definition) {
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('[ServicePyTorch] Chargement: ${definition.nom}...');
      }
      _modeleClassification = null;
      _definitionCourante = null;

      _modeleClassification = await PytorchLite.loadClassificationModel(
        definition.cheminAsset,
        definition.tailleEntree,
        definition.tailleEntree,
        labelPath: ConfigModeles.cheminLabels,
      );
      _definitionCourante = definition;

      if (kDebugMode) {
        debugPrint('[ServicePyTorch] Chargé: ${definition.nom}');
      }
    } catch (e) {
      _definitionCourante = null;
      _modeleClassification = null;
      rethrow;
    }
  }

  /// Charge le modèle de segmentation U-Net.
  ///
  /// Ne fait rien si le modèle est déjà chargé.
  Future<void> chargerModeleSegmentation() async {
    if (_segmentationChargee) return;
    try {
      if (kDebugMode) {
        debugPrint('[ServicePyTorch] Chargement modèle segmentation...');
      }
      _modeleSegmentation = await PytorchLite.loadClassificationModel(
        ConfigModeles.cheminModeleSegmentation,
        ConfigModeles.tailleEntreeSegmentation,
        ConfigModeles.tailleEntreeSegmentation,
        labelPath: null,
      );
      _segmentationChargee = true;
      if (kDebugMode) {
        debugPrint('[ServicePyTorch] Segmentation chargée.');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ServicePyTorch] Erreur segmentation: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Prédiction de classification
  // ---------------------------------------------------------------------------

  /// Exécute la classification sur une image.
  ///
  /// Optimisations par rapport à l'ancien code :
  /// - Lecture unique des octets (au lieu de double).
  /// - Déduction du label depuis les probabilités (un seul appel modèle).
  ///
  /// Retourne un Map contenant :
  /// - `label` (String) : étiquette prédite.
  /// - `confiance` (double) : confiance de la prédiction.
  /// - `prob_malignant` (double) : probabilité de malignité.
  /// - `probabilites` (`List<double>`) : probabilités par classe.
  Future<Map<String, dynamic>> predire(
    File fichierImage,
    DefinitionModele definition,
  ) async {
    // S'assurer que le bon modèle est chargé
    if (_modeleClassification == null || _definitionCourante != definition) {
      await chargerModele(definition);
    }

    if (_modeleClassification == null) {
      throw Exception('Impossible de charger le modèle de classification.');
    }

    final chrono = Stopwatch()..start();

    // Lecture unique des octets
    final octetsImage = await fichierImage.readAsBytes();

    // Obtenir les logits bruts (sans softmax) pour pouvoir appliquer le temperature scaling
    final listeLogits = await _modeleClassification!
        .getImagePredictionList(octetsImage);
    final probs = _softmaxAvecTemperature(listeLogits);

    chrono.stop();
    if (kDebugMode) {
      debugPrint(
        '[ServicePyTorch] Prédiction en ${chrono.elapsedMilliseconds}ms',
      );
    }

    // Déduire le label depuis les probabilités (évite un 2ème appel modèle)
    String label = 'Inconnu';
    double probMalignant = 0.0;

    if (probs.isNotEmpty && _modeleClassification!.labels.isNotEmpty) {
      // Extraire la probabilité de malignité
      for (int i = 0; i < probs.length; i++) {
        if (i < _modeleClassification!.labels.length) {
          final l = _modeleClassification!.labels[i].toLowerCase();
          if (l.contains('malignant') || l.contains('melanoma')) {
            probMalignant = probs[i];
            break;
          }
        }
      }

      // Seuil abaissé pour compenser le biais "bénin" du modèle
      final estMalin = probMalignant >= ConfigModeles.seuilDetectionMalin;
      label = estMalin ? 'Malignant' : 'Benign';
    }

    // Confiance exprimée comme probabilité de malignité (pour les seuils de risque)
    final confiance = probMalignant;

    return {
      'label': label,
      'confiance': confiance,
      'prob_malignant': probMalignant,
      'probabilites': probs,
    };
  }

  // ---------------------------------------------------------------------------
  // Prédiction de segmentation
  // ---------------------------------------------------------------------------

  /// Exécute la segmentation et retourne les contours normalisés.
  ///
  /// Optimisations mémoire :
  /// - Utilise `ui.instantiateImageCodec` pour les dimensions (léger).
  /// - Dispose immédiatement le codec et le frame après lecture.
  ///
  /// Retourne `null` si le modèle n'est pas disponible.
  Future<List<List<double>>?> predireSegmentation(File fichierImage) async {
    if (!_segmentationChargee) await chargerModeleSegmentation();
    if (_modeleSegmentation == null) return null;

    try {
      final octetsImage = await fichierImage.readAsBytes();
      final sortie = await _modeleSegmentation!.getImagePredictionList(
        octetsImage,
      );

      if (sortie == null || sortie.isEmpty) return null;

      // Obtenir dimensions sans décoder l'image entière (optimisation mémoire)
      int origW = ConfigModeles.tailleEntreeSegmentation;
      int origH = ConfigModeles.tailleEntreeSegmentation;
      try {
        final codec = await ui.instantiateImageCodec(octetsImage);
        final frame = await codec.getNextFrame();
        origW = frame.image.width;
        origH = frame.image.height;
        frame.image.dispose(); // Libération immédiate
      } catch (_) {
        // Utiliser les dimensions par défaut si échec
      }

      final points = _extraireContour(
        sortie,
        ConfigModeles.tailleEntreeSegmentation,
        ConfigModeles.tailleEntreeSegmentation,
      );
      if (points == null) return null;

      // Mise à l'échelle vers les dimensions d'origine
      return points.map((p) => [p[0] * origW, p[1] * origH]).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ServicePyTorch] Erreur segmentation: $e');
      }
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Temperature scaling
  // ---------------------------------------------------------------------------

  /// Applique le softmax avec temperature scaling aux logits bruts du modèle.
  ///
  /// Divise chaque logit par [ConfigModeles.temperatureScaling] avant le
  /// softmax, ce qui amplifie les différences entre classes quand T < 1.
  List<double> _softmaxAvecTemperature(List<double?>? logits) {
    if (logits == null || logits.isEmpty) return [];
    final t = ConfigModeles.temperatureScaling;
    final scaled = logits.map((l) => (l ?? 0.0) / t).toList();
    final maxVal = scaled.reduce(max); // stabilisation numérique
    final expVals = scaled.map((l) => exp(l - maxVal)).toList();
    final sumExp = expVals.reduce((a, b) => a + b);
    return expVals.map((e) => e / sumExp).toList();
  }

  // ---------------------------------------------------------------------------
  // Extraction de contour — Algorithme de Moore-Neighbor (optimisé)
  // ---------------------------------------------------------------------------

  /// Décalages des 8 voisins (sens horaire depuis le haut) — constantes.
  static const _ox = [0, 1, 1, 1, 0, -1, -1, -1];
  static const _oy = [-1, -1, 0, 1, 1, 1, 0, -1];

  /// Table de lookup pour les directions — O(1) au lieu de 8 if-else.
  static int _obtenirDirection(int dX, int dY) {
    // Encodage : (dX + 1) * 3 + (dY + 1) → index dans la table
    const table = [7, 6, 5, 0, -1, 4, 1, 2, 3];
    final index = (dX + 1) * 3 + (dY + 1);
    return table[index];
  }

  /// Extrait le contour d'un masque binaire via l'algorithme de Moore-Neighbor.
  ///
  /// [masque] — Masque plat (hauteur × largeur) de valeurs flottantes.
  /// [largeur] / [hauteur] — Dimensions du masque.
  /// [seuil] — Seuil de binarisation (> seuil = premier plan).
  ///
  /// Retourne une liste de points normalisés [x/w, y/h], ou `null`
  /// si aucun pixel de premier plan n'est trouvé. Limité à ~300 points.
  List<List<double>>? _extraireContour(
    List<double?> masque,
    int largeur,
    int hauteur, {
    double seuil = 0.0,
  }) {
    /// Vérifie si un pixel appartient au premier plan.
    bool estPremierPlan(int x, int y) {
      if (x < 0 || x >= largeur || y < 0 || y >= hauteur) return false;
      final val = masque[y * largeur + x] ?? 0.0;
      return val > seuil;
    }

    // Recherche du premier pixel de premier plan
    int debutX = -1;
    int debutY = -1;
    for (int y = 0; y < hauteur; y++) {
      for (int x = 0; x < largeur; x++) {
        if (estPremierPlan(x, y)) {
          debutX = x;
          debutY = y;
          break;
        }
      }
      if (debutX != -1) break;
    }

    if (debutX == -1) return null;

    // Traçage de Moore-Neighbor
    final contour = <List<double>>[];
    contour.add([debutX / largeur, debutY / hauteur]);

    int px = debutX;
    int py = debutY;
    int bx = debutX - 1;
    int by = debutY;

    final maxPoints = largeur * hauteur;

    do {
      bool suivantTrouve = false;
      final dirDepart = _obtenirDirection(bx - px, by - py);

      for (int i = 0; i < 8; i++) {
        final dir = (dirDepart + i) % 8;
        final nx = px + _ox[dir];
        final ny = py + _oy[dir];

        if (estPremierPlan(nx, ny)) {
          final bDir = (dir - 1 + 8) % 8;
          bx = px + _ox[bDir];
          by = py + _oy[bDir];
          px = nx;
          py = ny;
          contour.add([px / largeur, py / hauteur]);
          suivantTrouve = true;
          break;
        }
      }

      if (!suivantTrouve) break;
      if (contour.length > maxPoints) break;
    } while (px != debutX || py != debutY);

    // Simplification à ~300 points maximum
    if (contour.length > 300) {
      final simple = <List<double>>[];
      final pas = (contour.length / 300).ceil();
      for (int i = 0; i < contour.length; i += pas) {
        simple.add(contour[i]);
      }
      return simple;
    }
    return contour;
  }
}
