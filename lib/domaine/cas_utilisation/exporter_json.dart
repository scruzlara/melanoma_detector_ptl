import 'dart:io';

import '../entites/entite_analyse_sauvegardee.dart';

/// Cas d'utilisation : Exporter une analyse en JSON.
///
/// Couche domaine — définit le contrat d'export JSON.
/// L'implémentation concrète est dans la couche données.
class ExporterJson {
  final Future<File> Function(EntiteAnalyseSauvegardee analyse) _generer;

  const ExporterJson(this._generer);

  /// Génère le fichier JSON et retourne son chemin.
  Future<File> executer(EntiteAnalyseSauvegardee analyse) {
    return _generer(analyse);
  }
}
