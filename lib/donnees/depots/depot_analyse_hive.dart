import 'package:hive/hive.dart';

import '../../domaine/depots/depot_analyse.dart';
import '../../domaine/entites/entite_analyse_sauvegardee.dart';
import '../modeles/modele_analyse_hive.dart';

/// Implémentation Hive du dépôt d'analyses.
///
/// Couche données — implémente le contrat [DepotAnalyse] du domaine.
/// Le nom de la boîte Hive est une constante interne à cette classe.
class DepotAnalyseHive implements DepotAnalyse {
  /// Nom de la boîte Hive utilisée pour le stockage.
  static const String _nomBoite = 'analyses_sauvegardees';

  /// Référence vers la boîte Hive ouverte.
  Box<ModeleAnalyseHive>? _boite;

  /// Ouvre la boîte Hive (appelé une seule fois au démarrage).
  Future<void> initialiser() async {
    if (_boite != null && _boite!.isOpen) return;
    _boite = await Hive.openBox<ModeleAnalyseHive>(_nomBoite);
  }

  /// Retourne la boîte ouverte, l'initialise si nécessaire.
  Future<Box<ModeleAnalyseHive>> _obtenirBoite() async {
    if (_boite == null || !_boite!.isOpen) {
      await initialiser();
    }
    return _boite!;
  }

  @override
  Future<void> sauvegarder(EntiteAnalyseSauvegardee analyse) async {
    final boite = await _obtenirBoite();
    final modele = ModeleAnalyseHive.depuisEntite(analyse);
    await boite.put(analyse.id, modele);
  }

  @override
  Future<List<EntiteAnalyseSauvegardee>> obtenirHistorique() async {
    final boite = await _obtenirBoite();
    final entites = boite.values.map((modele) => modele.versEntite()).toList();

    // Tri par date décroissante (plus récent en premier)
    entites.sort((a, b) => b.horodatage.compareTo(a.horodatage));
    return entites;
  }

  @override
  Future<EntiteAnalyseSauvegardee?> obtenirParId(String id) async {
    final boite = await _obtenirBoite();
    final modele = boite.get(id);
    return modele?.versEntite();
  }

  @override
  Future<void> supprimer(String id) async {
    final boite = await _obtenirBoite();
    await boite.delete(id);
  }
}
