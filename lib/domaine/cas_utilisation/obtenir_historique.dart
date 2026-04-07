import '../depots/depot_analyse.dart';
import '../entites/entite_analyse_sauvegardee.dart';

/// Cas d'utilisation : Obtenir l'historique des analyses.
///
/// Couche domaine — retourne la liste triée par date décroissante.
class ObtenirHistorique {
  final DepotAnalyse _depot;

  const ObtenirHistorique(this._depot);

  /// Exécute la récupération de l'historique.
  Future<List<EntiteAnalyseSauvegardee>> executer() {
    return _depot.obtenirHistorique();
  }
}
