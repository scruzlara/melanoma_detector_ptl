import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../../domaine/cas_utilisation/exporter_json.dart';
import '../../domaine/cas_utilisation/exporter_pdf.dart';
import '../../domaine/cas_utilisation/sauvegarder_analyse.dart';
import '../../domaine/depots/depot_analyse.dart';
import '../../domaine/entites/definition_modele.dart';
import '../../domaine/entites/entite_analyse_sauvegardee.dart';
import '../../domaine/entites/resultat_analyse.dart';
import '../../domaine/services/service_geometrie.dart';
import '../../donnees/config/config_modeles.dart';
import '../../donnees/services/service_export_json.dart';
import '../../donnees/services/service_export_pdf.dart';
import '../../donnees/services/service_pytorch.dart';

/// Gestionnaire d'état principal de l'application de détection de mélanome.
///
/// Couche présentation — état réactif pur.
/// La logique métier est déléguée aux services (couche données/domaine).
///
/// Responsabilités :
/// - Sélection d'image (caméra ou galerie)
/// - Gestion de l'état UI (chargement, erreur, résultat)
/// - Déclenchement de l'analyse (délégué à [ServicePyTorch])
/// - Sélection du modèle
/// - Sauvegarde, export et chargement d'analyses
class ProviderMelanome extends ChangeNotifier {
  // ---------------------------------------------------------------------------
  // Dépendances injectées
  // ---------------------------------------------------------------------------

  /// Dépôt d'analyses (injecté pour respecter l'inversion de dépendance).
  final DepotAnalyse depot;

  /// Cas d'utilisation : sauvegarde.
  late final SauvegarderAnalyse _sauvegarderAnalyse;

  /// Cas d'utilisation : export PDF.
  late final ExporterPdf _exporterPdf;

  /// Cas d'utilisation : export JSON.
  late final ExporterJson _exporterJson;

  ProviderMelanome({required this.depot}) {
    _sauvegarderAnalyse = SauvegarderAnalyse(depot);
    _exporterPdf = ExporterPdf(ServiceExportPdf.generer);
    _exporterJson = ExporterJson(ServiceExportJson.generer);
  }

  // ---------------------------------------------------------------------------
  // État de l'image
  // ---------------------------------------------------------------------------

  /// Image sélectionnée par l'utilisateur.
  File? _imageSelectionnee;
  File? get imageSelectionnee => _imageSelectionnee;

  // ---------------------------------------------------------------------------
  // État du chargement
  // ---------------------------------------------------------------------------

  /// Indique si une analyse est en cours.
  bool _enChargement = false;
  bool get enChargement => _enChargement;

  // ---------------------------------------------------------------------------
  // Résultat et erreur
  // ---------------------------------------------------------------------------

  /// Résultat de la dernière analyse.
  ResultatAnalyse? _resultat;
  ResultatAnalyse? get resultat => _resultat;

  /// Message d'erreur (null si pas d'erreur).
  String? _messageErreur;
  String? get messageErreur => _messageErreur;

  // ---------------------------------------------------------------------------
  // Paramètres d'analyse
  // ---------------------------------------------------------------------------

  /// Modèle de classification sélectionné.
  DefinitionModele _modeleSelectionne = ConfigModeles.modeleParDefaut;
  DefinitionModele get modeleSelectionne => _modeleSelectionne;

  /// Notes de l'utilisateur.
  String _notes = '';
  String get notes => _notes;

  // ---------------------------------------------------------------------------
  // Méthodes publiques — Flux principal
  // ---------------------------------------------------------------------------

  /// Demande les permissions nécessaires (caméra et galerie).
  Future<void> demanderPermissions() async {
    await Permission.camera.request();
    if (Platform.isAndroid) {
      if (await Permission.photos.status.isDenied) {
        await Permission.photos.request();
      }
    }
  }

  /// Sélectionne une image depuis la [source] (caméra ou galerie).
  Future<void> choisirImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (photo != null) {
        _imageSelectionnee = File(photo.path);
        _resultat = null;
        _messageErreur = null;
        notifyListeners();
      }
    } catch (e) {
      _definirErreur('Erreur sélection image: $e');
    }
  }

  /// Met à jour le modèle sélectionné.
  void definirModele(DefinitionModele modele) {
    if (_modeleSelectionne != modele) {
      _modeleSelectionne = modele;
      notifyListeners();
    }
  }

  /// Met à jour les notes de l'utilisateur.
  void definirNotes(String valeur) {
    _notes = valeur;
  }

  /// Lance l'analyse de l'image sélectionnée.
  ///
  /// Délègue l'inférence au [ServicePyTorch] et la géométrie
  /// au [ServiceGeometrie]. Le Provider ne contient aucune logique métier.
  Future<void> analyser() async {
    if (_imageSelectionnee == null) return;

    _enChargement = true;
    _messageErreur = null;
    _resultat = null;
    notifyListeners();

    try {
      await _executerAnalyseLocale();
    } catch (e) {
      _definirErreur('Erreur analyse: $e');
    } finally {
      _enChargement = false;
      notifyListeners();
    }
  }

  /// Met à jour les contours après édition manuelle.
  void mettreAJourContours(List<List<double>> nouveauxContours) {
    if (_resultat == null) return;

    final nouvelleGeo = ServiceGeometrie.calculerGeometrie(nouveauxContours);
    final nouveauJson = Map<String, dynamic>.from(_resultat!.resultJson ?? {});
    nouveauJson['tamano'] = nouvelleGeo;

    _resultat = _resultat!.copierAvecContours(
      nouveauxContours: nouveauxContours,
      jsonMisAJour: nouveauJson,
    );
    notifyListeners();
  }

  /// Remet la vue en mode formulaire et réinitialise l'état.
  void afficherFormulaire() {
    _imageSelectionnee = null;
    _resultat = null;
    _messageErreur = null;
    _notes = '';
    notifyListeners();
  }

  /// Réinitialise complètement l'état de l'application.
  void reinitialiser() {
    _imageSelectionnee = null;
    _resultat = null;
    _messageErreur = null;
    _notes = '';
    _modeleSelectionne = ConfigModeles.modeleParDefaut;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Méthodes publiques — Persistance & Export
  // ---------------------------------------------------------------------------

  /// Sauvegarde l'analyse courante dans le dépôt local.
  ///
  /// Construit une [EntiteAnalyseSauvegardee] à partir de l'état actuel
  /// et la persiste via le cas d'utilisation [SauvegarderAnalyse].
  Future<bool> sauvegarderAnalyse() async {
    if (_resultat == null || _imageSelectionnee == null) return false;

    try {
      final entite = _construireEntiteSauvegarde();
      await _sauvegarderAnalyse.executer(entite);
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erreur sauvegarde: $e');
      }
      return false;
    }
  }

  /// Exporte l'analyse courante en PDF et ouvre le dialogue de partage.
  Future<bool> exporterPdf() async {
    if (_resultat == null || _imageSelectionnee == null) return false;

    try {
      final entite = _construireEntiteSauvegarde();
      final fichier = await _exporterPdf.executer(entite);
      await Share.shareXFiles([XFile(fichier.path)]);
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erreur export PDF: $e');
      }
      return false;
    }
  }

  /// Exporte l'analyse courante en JSON et ouvre le dialogue de partage.
  Future<bool> exporterJson() async {
    if (_resultat == null || _imageSelectionnee == null) return false;

    try {
      final entite = _construireEntiteSauvegarde();
      final fichier = await _exporterJson.executer(entite);
      await Share.shareXFiles([XFile(fichier.path)]);
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erreur export JSON: $e');
      }
      return false;
    }
  }

  /// Charge une analyse sauvegardée et restaure l'état pour ré-édition.
  ///
  /// Reconstruit un [ResultatAnalyse] à partir de l'entité persistée
  /// et recharge l'image si elle existe encore.
  void chargerAnalyseSauvegardee(EntiteAnalyseSauvegardee analyse) {
    final fichierImage = File(analyse.cheminImageOriginale);

    _imageSelectionnee = fichierImage;
    _notes = analyse.notes ?? '';

    // Trouver le modèle correspondant
    final modele = ConfigModeles.modelesDisponibles.where(
      (m) => m.nom == analyse.nomModele,
    );
    if (modele.isNotEmpty) {
      _modeleSelectionne = modele.first;
    }

    // Reconstruire le ResultatAnalyse
    _resultat = ResultatAnalyse(
      resultJson: analyse.resultJsonComplet,
      contours: analyse.contours,
      rapportMd:
          '## Analyse Chargée\n\n'
          "Résultat chargé depuis l'historique.\n\n"
          '**Résultat :** ${analyse.resultatClassification}\n'
          '**Confiance :** ${(analyse.confiance * 100).toStringAsFixed(1)}%\n'
          '**Probabilité Mélanome :** ${(analyse.probMalignant * 100).toStringAsFixed(1)}%\n\n'
          'Vous pouvez modifier les contours et recalculer les métriques.',
    );

    _messageErreur = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Méthodes privées
  // ---------------------------------------------------------------------------

  /// Construit une entité sauvegardée à partir de l'état actuel.
  EntiteAnalyseSauvegardee _construireEntiteSauvegarde() {
    final json = _resultat!.resultJson ?? {};

    // Extraire les données de diagnostic
    final diagData = ServiceGeometrie.extraireDiagnostic(json);

    return EntiteAnalyseSauvegardee(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      cheminImageOriginale: _imageSelectionnee!.path,
      contours: _resultat!.contours,
      resultatClassification: diagData['diagnostic'] as String,
      probMalignant: (json['prob_malignidad'] as num?)?.toDouble() ?? 0.0,
      confiance: (json['confianza'] as num?)?.toDouble() ?? 0.0,
      metriquesGeometriques: Map<String, dynamic>.from(
        json['tamano'] as Map? ?? {},
      ),
      nomModele: json['model_name'] as String? ?? _modeleSelectionne.nom,
      notes: _notes.isNotEmpty ? _notes : null,
      horodatage: DateTime.now(),
      resultJsonComplet: Map<String, dynamic>.from(json),
    );
  }

  /// Exécute l'analyse locale : classification + segmentation.
  ///
  /// Délègue au [ServicePyTorch] pour l'inférence et au
  /// [ServiceGeometrie] pour le calcul de géométrie.
  Future<void> _executerAnalyseLocale() async {
    final service = ServicePyTorch();
    final resultatClassification = await service.predire(
      _imageSelectionnee!,
      _modeleSelectionne,
    );

    final label = resultatClassification['label'] as String;
    final confiance = resultatClassification['confiance'] as double;
    final probMalignant = resultatClassification['prob_malignant'] as double;
    final probabilites = resultatClassification['probabilites'];

    final jsonResultat = <String, dynamic>{
      'model_name': _modeleSelectionne.nom,
      'prediccion_final': label,
      'prob_malignidad': probMalignant,
      'confianza': confiance,
      'probabilites': probabilites,
    };

    // Dimensions de l'image originale (pour la mise à l'échelle)
    try {
      final octets = await _imageSelectionnee!.readAsBytes();
      final codec = await ui.instantiateImageCodec(octets);
      final frame = await codec.getNextFrame();
      jsonResultat['original_size'] = {
        'width': frame.image.width,
        'height': frame.image.height,
      };
      frame.image.dispose();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erreur lecture dimensions image: $e');
      }
    }

    // Segmentation (optionnelle)
    List<List<double>>? contours;
    try {
      contours = await service.predireSegmentation(_imageSelectionnee!);
      if (contours != null && contours.isNotEmpty) {
        final geometrie = ServiceGeometrie.calculerGeometrie(contours);
        jsonResultat['tamano'] = geometrie;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erreur segmentation: $e');
      }
    }

    _resultat = ResultatAnalyse(
      resultJson: jsonResultat,
      contours: contours,
      rapportMd:
          '## Analyse Locale (PyTorch Lite)\n\n'
          "Modèle exécuté sur l'appareil (sans internet).\n\n"
          '**Résultat :** $label\n'
          '**Confiance :** ${(confiance * 100).toStringAsFixed(1)}%\n'
          '**Probabilité Mélanome :** ${(probMalignant * 100).toStringAsFixed(1)}%\n\n'
          'Note : La segmentation est générée localement.',
    );
  }

  /// Met à jour le message d'erreur et notifie les listeners.
  void _definirErreur(String message) {
    _messageErreur = message;
    notifyListeners();
  }
}
