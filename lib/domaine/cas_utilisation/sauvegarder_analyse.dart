import '../depots/depot_analyse.dart';
import '../entites/entite_analyse_sauvegardee.dart';

/// Cas d'utilisation : Sauvegarder une analyse.
///
/// Couche domaine — orchestre la sauvegarde via le [DepotAnalyse].
/// Aucune connaissance de l'implémentation concrète (Hive, etc.).
class SauvegarderAnalyse {
  final DepotAnalyse _depot;

  const SauvegarderAnalyse(this._depot);

  /// Exécute la sauvegarde de l'analyse.
  Future<void> executer(EntiteAnalyseSauvegardee analyse) {
    return _depot.sauvegarder(analyse);
  }
}
