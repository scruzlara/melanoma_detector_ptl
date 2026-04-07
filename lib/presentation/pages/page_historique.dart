import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domaine/cas_utilisation/obtenir_historique.dart';
import '../../domaine/entites/entite_analyse_sauvegardee.dart';
import '../../domaine/depots/depot_analyse.dart';

/// Page d'historique des analyses sauvegardées.
///
/// Affiche la liste des analyses précédentes avec miniature, date,
/// résultat et niveau de risque. Permet de recharger une analyse
/// pour la ré-éditer.
class PageHistorique extends StatefulWidget {
  /// Dépôt pour accéder aux analyses sauvegardées.
  final DepotAnalyse depot;

  /// Callback appelé lorsqu'une analyse est sélectionnée pour ré-édition.
  final void Function(EntiteAnalyseSauvegardee analyse) surSelection;

  const PageHistorique({
    super.key,
    required this.depot,
    required this.surSelection,
  });

  @override
  State<PageHistorique> createState() => _PageHistoriqueState();
}

class _PageHistoriqueState extends State<PageHistorique> {
  late final ObtenirHistorique _obtenirHistorique;
  List<EntiteAnalyseSauvegardee> _analyses = [];
  bool _enChargement = true;

  @override
  void initState() {
    super.initState();
    _obtenirHistorique = ObtenirHistorique(widget.depot);
    _chargerHistorique();
  }

  Future<void> _chargerHistorique() async {
    setState(() => _enChargement = true);
    try {
      final resultats = await _obtenirHistorique.executer();
      if (mounted) {
        setState(() {
          _analyses = resultats;
          _enChargement = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _enChargement = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur chargement: $e')));
      }
    }
  }

  Future<void> _supprimerAnalyse(String id) async {
    try {
      await widget.depot.supprimer(id);
      await _chargerHistorique();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Analyse supprimée')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur suppression: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Historique des Analyses')),
      body:
          _enChargement
              ? const Center(child: CircularProgressIndicator())
              : _analyses.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_outlined,
                      size: 64,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aucune analyse sauvegardée',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Les analyses sauvegardées apparaîtront ici',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _analyses.length,
                itemBuilder: (context, index) {
                  final analyse = _analyses[index];
                  return _construireCarteAnalyse(
                    context,
                    analyse,
                    dateFormat,
                    theme,
                  );
                },
              ),
    );
  }

  Widget _construireCarteAnalyse(
    BuildContext context,
    EntiteAnalyseSauvegardee analyse,
    DateFormat dateFormat,
    ThemeData theme,
  ) {
    // Déterminer couleur de risque
    Color couleurRisque;
    String libelle;
    if (analyse.probMalignant < 0.30) {
      couleurRisque = Colors.green;
      libelle = 'Faible';
    } else if (analyse.probMalignant < 0.60) {
      couleurRisque = Colors.orange;
      libelle = 'Modéré';
    } else {
      couleurRisque = Colors.red;
      libelle = 'Élevé';
    }

    // Vérifier si l'image existe
    final fichierImage = File(analyse.cheminImageOriginale);

    return Dismissible(
      key: Key(analyse.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Supprimer'),
                content: const Text('Voulez-vous supprimer cette analyse ?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('ANNULER'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('SUPPRIMER'),
                  ),
                ],
              ),
        );
      },
      onDismissed: (_) => _supprimerAnalyse(analyse.id),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            widget.surSelection(analyse);
            Navigator.of(context).pop();
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Miniature
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: FutureBuilder<bool>(
                      future: fichierImage.exists(),
                      builder: (_, snapshot) {
                        if (snapshot.data == true) {
                          return Image.file(fichierImage, fit: BoxFit.cover);
                        }
                        return Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Informations
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        analyse.resultatClassification,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${analyse.nomModele} • ${dateFormat.format(analyse.horodatage)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Badge risque
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: couleurRisque.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: couleurRisque.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    libelle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: couleurRisque,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
