import 'dart:io';

import '../entites/entite_analyse_sauvegardee.dart';

/// Cas d'utilisation : Exporter une analyse en PDF.
///
/// Couche domaine — définit le contrat d'export.
/// L'implémentation concrète est dans la couche données.
class ExporterPdf {
  final Future<File> Function(EntiteAnalyseSauvegardee analyse) _generer;

  const ExporterPdf(this._generer);

  /// Génère le fichier PDF et retourne son chemin.
  Future<File> executer(EntiteAnalyseSauvegardee analyse) {
    return _generer(analyse);
  }
}
