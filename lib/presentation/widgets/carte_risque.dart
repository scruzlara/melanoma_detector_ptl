import 'package:flutter/material.dart';

import '../../domaine/entites/niveau_risque.dart';
import '../../presentation/theme/couleurs_risque.dart';

/// Carte de diagnostic affichant le niveau de risque.
///
/// Grande carte colorée avec icône et pourcentage de confiance.
/// La couleur varie selon le risque : vert (faible), ambre (modéré), rouge (élevé).
class CarteRisque extends StatelessWidget {
  /// Données du niveau de risque (libellé + niveau).
  final DonneesRisque donneesRisque;

  /// Probabilité de malignité (0.0 à 1.0).
  final double confiance;

  /// Nom du modèle utilisé (ex: « MobileNetV3 »).
  final String? nomModele;

  const CarteRisque({
    super.key,
    required this.donneesRisque,
    required this.confiance,
    this.nomModele,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final couleur = CouleursRisque.couleur(donneesRisque.niveau, brightness);
    final icone = CouleursRisque.icone(donneesRisque.niveau);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Modèle: ${nomModele ?? "Inconnu"}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            color: couleur,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: couleur.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icone, size: 56, color: Colors.white),
              const SizedBox(height: 14),
              Text(
                donneesRisque.libelle.toUpperCase(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Confiance IA: ${(confiance * 100).toStringAsFixed(1)}%',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
