import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../domaine/depots/depot_analyse.dart';
import '../domaine/entites/entite_analyse_sauvegardee.dart';
import '../donnees/services/service_export_pdf.dart';

/// Service dédié à la génération et au partage de rapports PDF.
///
/// Couche services — combine la génération PDF avec la sauvegarde
/// optionnelle dans le dépôt local et le partage via le système.
///
/// Ce service centralise toute la logique liée au PDF :
/// - Génération du rapport à partir d'une entité d'analyse
/// - Sauvegarde optionnelle de l'analyse associée
/// - Partage du fichier PDF via le dialogue système
///
/// Flux de données :
/// 1. [EntiteAnalyseSauvegardee] → [ServiceExportPdf] → fichier PDF
/// 2. Fichier PDF → [Share.shareXFiles] → dialogue de partage
/// 3. (Optionnel) Entité → [DepotAnalyse] → sauvegarde Hive
class ServiceGenerationPdf {
  /// Dépôt d'analyses pour la sauvegarde optionnelle.
  final DepotAnalyse? _depot;

  /// Crée un service de génération PDF.
  ///
  /// Le [depot] est optionnel : s'il est fourni, la méthode
  /// [genererEtSauvegarder] sauvegardera également l'analyse.
  ServiceGenerationPdf({DepotAnalyse? depot}) : _depot = depot;

  /// Message d'état actuel (pour affichage dans l'UI).
  String _messageEtat = '';
  String get messageEtat => _messageEtat;

  /// Génère un rapport PDF à partir d'une analyse.
  ///
  /// Retourne le [File] du PDF généré.
  Future<File> generer(
    EntiteAnalyseSauvegardee analyse, {
    void Function(String)? onEtatChange,
  }) async {
    _messageEtat = 'Génération du PDF...';
    onEtatChange?.call(_messageEtat);

    final fichier = await ServiceExportPdf.generer(analyse);

    _messageEtat = 'PDF prêt.';
    onEtatChange?.call(_messageEtat);

    return fichier;
  }

  /// Génère le rapport PDF, sauvegarde l'analyse et partage le fichier.
  ///
  /// Opération combinée « tout-en-un » qui :
  /// 1. Génère le PDF
  /// 2. Sauvegarde l'analyse dans Hive (si le dépôt est disponible)
  /// 3. Ouvre le dialogue de partage système
  ///
  /// Retourne `true` si toutes les opérations ont réussi.
  Future<bool> genererEtSauvegarder(
    EntiteAnalyseSauvegardee analyse, {
    void Function(String)? onEtatChange,
  }) async {
    try {
      // 1. Générer le PDF
      _messageEtat = 'Génération du PDF...';
      onEtatChange?.call(_messageEtat);
      final fichier = await ServiceExportPdf.generer(analyse);

      // 2. Sauvegarder l'analyse dans Hive
      if (_depot != null) {
        _messageEtat = 'Sauvegarde de l\'analyse...';
        onEtatChange?.call(_messageEtat);
        await _depot.sauvegarder(analyse);
      }

      // 3. Partager le PDF
      _messageEtat = 'Ouverture du partage...';
      onEtatChange?.call(_messageEtat);
      await Share.shareXFiles([XFile(fichier.path)]);

      _messageEtat = 'Terminé.';
      onEtatChange?.call(_messageEtat);
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ServiceGenerationPdf] Erreur: $e');
      }
      _messageEtat = 'Erreur: $e';
      onEtatChange?.call(_messageEtat);
      return false;
    }
  }

  /// Génère un PDF et ouvre directement le dialogue de partage.
  ///
  /// Variante simplifiée sans sauvegarde.
  Future<bool> genererEtPartager(
    EntiteAnalyseSauvegardee analyse, {
    void Function(String)? onEtatChange,
  }) async {
    try {
      final fichier = await generer(analyse, onEtatChange: onEtatChange);

      _messageEtat = 'Ouverture du partage...';
      onEtatChange?.call(_messageEtat);

      await Share.shareXFiles([XFile(fichier.path)]);
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ServiceGenerationPdf] Erreur partage: $e');
      }
      return false;
    }
  }
}
