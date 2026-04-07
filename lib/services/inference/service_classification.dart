import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:pytorch_lite/pytorch_lite.dart';

import '../../donnees/config/config_modeles.dart';
import '../../domaine/entites/definition_modele.dart';

/// Service d'inférence de classification (MobileNetV3 / MobileNetV2).
///
/// Couche infrastructure — encapsule le chargement et l'exécution
/// d'un modèle de classification PyTorch Lite pour la détection
/// de mélanome.
///
/// **Responsabilité unique :** classifier une image de lésion
/// et retourner les probabilités par classe (bénin / maligne).
///
/// **Gestion mémoire :** le modèle est chargé une seule fois
/// et réutilisé tant que la même définition est demandée.
/// Un changement de modèle libère automatiquement l'ancien.
///
/// Aucune donnée ne quitte la mémoire de l'appareil.
class ServiceClassification {
  /// Modèle de classification actuellement chargé.
  ClassificationModel? _modele;

  /// Définition du modèle en cours d'utilisation.
  DefinitionModele? _definitionCourante;

  /// Indique si un modèle est actuellement chargé.
  bool get estCharge => _modele != null;

  // ---------------------------------------------------------------------------
  // Chargement du modèle
  // ---------------------------------------------------------------------------

  /// Charge un modèle de classification à partir de sa [definition].
  ///
  /// Si le modèle demandé est identique au modèle déjà chargé,
  /// cette méthode ne fait rien (optimisation de rechargement).
  ///
  /// En cas d'erreur, l'ancien modèle est libéré et l'exception
  /// est propagée à l'appelant.
  Future<void> chargerModele(DefinitionModele definition) async {
    if (_modele != null && _definitionCourante == definition) {
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('[ServiceClassification] Chargement : ${definition.nom}...');
      }

      // Libérer l'ancien modèle avant de charger le nouveau
      _modele = null;
      _definitionCourante = null;

      _modele = await PytorchLite.loadClassificationModel(
        definition.cheminAsset,
        definition.tailleEntree,
        definition.tailleEntree,
        labelPath: ConfigModeles.cheminLabels,
      );
      _definitionCourante = definition;

      if (kDebugMode) {
        debugPrint('[ServiceClassification] Chargé : ${definition.nom}');
      }
    } catch (e) {
      _definitionCourante = null;
      _modele = null;
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Prédiction
  // ---------------------------------------------------------------------------

  /// Exécute la classification sur un fichier image.
  ///
  /// Charge le modèle si nécessaire, puis effectue l'inférence
  /// en un seul appel (optimisation : pas de double lecture des octets).
  ///
  /// Retourne un `Map` contenant :
  /// - `label` (String) — étiquette prédite (ex. « Benign »).
  /// - `confiance` (double) — confiance de la prédiction [0..1].
  /// - `prob_malignant` (double) — probabilité de malignité [0..1].
  /// - `probabilites` (`List<double>`) — probabilités par classe.
  ///
  /// Lance une exception si le modèle ne peut pas être chargé.
  Future<Map<String, dynamic>> predire(
    File fichierImage,
    DefinitionModele definition,
  ) async {
    await _assurerModeleCharge(definition);

    final chrono = Stopwatch()..start();
    final octetsImage = await fichierImage.readAsBytes();
    final resultat = await _extraireProbabilites(octetsImage);

    chrono.stop();
    if (kDebugMode) {
      debugPrint(
        '[ServiceClassification] Prédiction en ${chrono.elapsedMilliseconds}ms',
      );
    }

    return resultat;
  }

  /// Exécute la classification sur des octets bruts (image recadrée).
  ///
  /// Utilisé pour classifier chaque lésion recadrée individuellement
  /// lors de l'analyse en mode « visage complet ».
  ///
  /// Mêmes valeurs de retour que [predire].
  Future<Map<String, dynamic>> predireDepuisBytes(
    Uint8List octetsImage,
    DefinitionModele definition,
  ) async {
    await _assurerModeleCharge(definition);
    return _extraireProbabilites(octetsImage);
  }

  // ---------------------------------------------------------------------------
  // Libération des ressources
  // ---------------------------------------------------------------------------

  /// Libère le modèle de classification chargé.
  ///
  /// Doit être appelé lors de la destruction du service parent
  /// pour éviter les fuites de mémoire native.
  void dispose() {
    _modele = null;
    _definitionCourante = null;
  }

  // ---------------------------------------------------------------------------
  // Méthodes privées
  // ---------------------------------------------------------------------------

  /// S'assure que le modèle correspondant à [definition] est chargé.
  Future<void> _assurerModeleCharge(DefinitionModele definition) async {
    if (_modele == null || _definitionCourante != definition) {
      await chargerModele(definition);
    }
    if (_modele == null) {
      throw Exception('Impossible de charger le modèle de classification.');
    }
  }

  /// Extrait les probabilités et le label depuis les octets d'image.
  ///
  /// Méthode commune à [predire] et [predireDepuisBytes] pour éviter
  /// la duplication de la logique de post-traitement.
  /// Applique le softmax avec temperature scaling aux logits bruts du modèle.
  List<double> _softmaxAvecTemperature(List<double?>? logits) {
    if (logits == null || logits.isEmpty) return [];
    final t = ConfigModeles.temperatureScaling;
    final scaled = logits.map((l) => (l ?? 0.0) / t).toList();
    final maxVal = scaled.reduce(max);
    final expVals = scaled.map((l) => exp(l - maxVal)).toList();
    final sumExp = expVals.reduce((a, b) => a + b);
    return expVals.map((e) => e / sumExp).toList();
  }

  Future<Map<String, dynamic>> _extraireProbabilites(
    Uint8List octetsImage,
  ) async {
    final listeLogits = await _modele!.getImagePredictionList(octetsImage);
    final probs = _softmaxAvecTemperature(listeLogits);

    String label = 'Inconnu';
    double probMalignant = 0.0;

    if (probs.isNotEmpty && _modele!.labels.isNotEmpty) {
      // Extraire la probabilité de malignité
      for (int i = 0; i < probs.length; i++) {
        if (i < _modele!.labels.length) {
          final l = _modele!.labels[i].toLowerCase();
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
}
