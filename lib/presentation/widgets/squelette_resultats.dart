import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Widget squelette avec effet shimmer pour la phase de chargement.
///
/// Mime la disposition de l'écran de résultats : un rectangle image,
/// des lignes de texte (risque, confiance, modèle, métriques) avec
/// un effet de scintillement pour indiquer le traitement en cours.
class SqueletteResultats extends StatelessWidget {
  const SqueletteResultats({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final estSombre = theme.brightness == Brightness.dark;

    final baseColor = estSombre ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor =
        estSombre ? Colors.grey.shade600 : Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre « Analyse en cours... »
            Center(
              child: Text(
                'Analyse en cours...',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Squelette carte de risque
            _construireBoiteSqelette(hauteur: 100, rayon: 16),
            const SizedBox(height: 20),

            // Squelette image de segmentation
            _construireBoiteSqelette(hauteur: 220, rayon: 12),
            const SizedBox(height: 20),

            // Squelette lignes de métriques
            _construireLigneSqelette(largeur: 200),
            const SizedBox(height: 12),
            _construireLigneSqelette(largeur: 260),
            const SizedBox(height: 12),
            _construireLigneSqelette(largeur: 180),
            const SizedBox(height: 12),
            _construireLigneSqelette(largeur: 240),
            const SizedBox(height: 20),

            // Squelette boutons
            _construireBoiteSqelette(hauteur: 48, rayon: 24),
          ],
        ),
      ),
    );
  }

  /// Construit un rectangle de squelette.
  Widget _construireBoiteSqelette({required double hauteur, double rayon = 8}) {
    return Container(
      width: double.infinity,
      height: hauteur,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(rayon),
      ),
    );
  }

  /// Construit une ligne de texte de squelette.
  Widget _construireLigneSqelette({required double largeur}) {
    return Container(
      width: largeur,
      height: 16,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
