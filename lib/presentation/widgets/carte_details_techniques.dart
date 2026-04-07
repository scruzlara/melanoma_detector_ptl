import 'package:flutter/material.dart';

import '../../domaine/services/service_geometrie.dart';

/// Carte des détails techniques de l'analyse.
///
/// Affiche les probabilités par classe, la surface en pixels,
/// le diamètre équivalent, et un avertissement sur la calibration.
class CarteDetailsTechniques extends StatelessWidget {
  /// JSON de résultat complet.
  final Map<String, dynamic>? resultJson;

  /// Nom du modèle utilisé.
  final String? nomModele;

  const CarteDetailsTechniques({
    super.key,
    required this.resultJson,
    this.nomModele,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Détails Techniques',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Probabilités par classe
                if (resultJson?['probabilites'] != null) ...[
                  Text(
                    'Probabilités (${nomModele ?? "Inconnu"}):',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._construireLignesProbabilites(context),
                  const Divider(height: 24),
                ],

                // Surface en pixels
                _construireLigneInfo(
                  context,
                  Icons.aspect_ratio,
                  'Surface (Pixels)',
                  '${ServiceGeometrie.obtenirValeurSegmentation(resultJson, 'area_px') ?? 'N/A'}',
                ),
                const SizedBox(height: 8),

                // Diamètre équivalent
                _construireLigneInfo(
                  context,
                  Icons.circle_outlined,
                  'Diamètre Équivalent',
                  '${ServiceGeometrie.obtenirValeurSegmentation(resultJson, 'diam_px')?.toStringAsFixed(1) ?? 'N/A'} px',
                ),
                const SizedBox(height: 12),

                // Avertissement calibration
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.straighten, size: 16, color: Colors.amber),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mesures en pixels (non calibrées).\n'
                          'Indiquent la forme, pas la taille réelle.',
                          style: TextStyle(fontSize: 11, color: Colors.amber),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Construit les lignes de probabilités par classe.
  List<Widget> _construireLignesProbabilites(BuildContext context) {
    final probs = resultJson!['probabilites'] as List;

    // Noms lisibles pour l'utilisateur (index 0 = bénin, index 1 = mélanome)
    const nomsClasses = ['Bénin (non-mélanome)', 'Mélanome'];

    return probs.asMap().entries.map((e) {
      final prob = (e.value as num).toDouble();
      final theme = Theme.of(context);
      final nom =
          e.key < nomsClasses.length ? nomsClasses[e.key] : 'Classe ${e.key}';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              nom,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '${(prob * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                // Index 0 = Bénin → vert si prob élevée
                // Index 1 = Mélanome → rouge si prob élevée
                color:
                    e.key == 0
                        ? (prob > 0.5 ? Colors.green : Colors.red)
                        : (prob > 0.5 ? Colors.red : Colors.green),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  /// Construit une ligne d'information (icône + label + valeur).
  Widget _construireLigneInfo(
    BuildContext context,
    IconData icone,
    String libelle,
    String valeur,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icone, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(
          libelle,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        const Spacer(),
        Text(valeur, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
