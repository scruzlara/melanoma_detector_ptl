import 'package:flutter/material.dart';

import '../../domaine/entites/definition_modele.dart';

/// Formulaire des paramètres d'analyse (Version simplifiée locale).
///
/// Contient le sélecteur de modèle IA, un champ de notes,
/// et le bouton de lancement d'analyse.
class FormulaireAnalyse extends StatelessWidget {
  /// Contrôleur du champ de notes.
  final TextEditingController controleurNotes;

  /// Indique si le formulaire est désactivé (chargement en cours).
  final bool enChargement;

  /// Indique si une image est sélectionnée.
  final bool imagePresente;

  /// Callback du bouton « Lancer l'analyse ».
  final VoidCallback? surAnalyser;

  /// Modèle sélectionné.
  final DefinitionModele modeleSelectionne;

  /// Liste des modèles disponibles.
  final List<DefinitionModele> modelesDisponibles;

  /// Callback de changement de modèle.
  final ValueChanged<DefinitionModele?>? surChangementModele;

  const FormulaireAnalyse({
    super.key,
    required this.controleurNotes,
    required this.enChargement,
    required this.imagePresente,
    required this.surAnalyser,
    required this.modeleSelectionne,
    required this.modelesDisponibles,
    required this.surChangementModele,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre de section
        Text(
          'Paramètres',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // Sélecteur de Modèle
        DropdownButtonFormField<DefinitionModele>(
          initialValue: modeleSelectionne,
          decoration: const InputDecoration(
            labelText: 'Modèle IA',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.psychology),
          ),
          items:
              modelesDisponibles.map((modele) {
                return DropdownMenuItem(
                  value: modele,
                  child: Text(
                    modele.nom,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
          onChanged: enChargement ? null : surChangementModele,
        ),
        const SizedBox(height: 16),

        // Notes
        TextField(
          controller: controleurNotes,
          enabled: !enChargement,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Notes (optionnel)',
            prefixIcon: Icon(Icons.note_outlined),
            border: OutlineInputBorder(),
          ),
        ),

        // Bouton d'analyse
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: (!imagePresente || enChargement) ? null : surAnalyser,
            icon: const Icon(Icons.analytics_outlined),
            label: const Text("LANCER L'ANALYSE LOCAL"),
            style: FilledButton.styleFrom(elevation: 2),
          ),
        ),
      ],
    );
  }
}
