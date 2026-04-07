import '../entites/entite_analyse_sauvegardee.dart';

/// Interface abstraite du dépôt d'analyses sauvegardées.
///
/// Couche domaine — définit le contrat sans connaître l'implémentation
/// concrète (Hive, SQLite, etc.). Le principe d'inversion de dépendance
/// est respecté : la couche données implémente cette interface.
abstract class DepotAnalyse {
  /// Sauvegarde une analyse.
  Future<void> sauvegarder(EntiteAnalyseSauvegardee analyse);

  /// Retourne l'historique complet des analyses, triées par date décroissante.
  Future<List<EntiteAnalyseSauvegardee>> obtenirHistorique();

  /// Retourne une analyse par son identifiant, ou `null` si non trouvée.
  Future<EntiteAnalyseSauvegardee?> obtenirParId(String id);

  /// Supprime une analyse par son identifiant.
  Future<void> supprimer(String id);
}
