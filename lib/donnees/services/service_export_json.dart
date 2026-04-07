import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domaine/entites/entite_analyse_sauvegardee.dart';

/// Service d'export JSON pour les analyses sauvegardées.
///
/// Couche données — sérialise une [EntiteAnalyseSauvegardee] en fichier
/// JSON lisible. L'image est référencée par son chemin (pas de base64
/// pour limiter la taille du fichier).
class ServiceExportJson {
  ServiceExportJson._();

  /// Génère un fichier JSON et retourne le [File] résultant.
  static Future<File> generer(EntiteAnalyseSauvegardee analyse) async {
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fichier = File('${dir.path}/analyse_melanome_$timestamp.json');
    await fichier.writeAsString(analyse.versJsonString());
    return fichier;
  }
}
