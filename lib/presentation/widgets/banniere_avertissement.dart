import 'package:flutter/material.dart';

/// Bannière d'avertissement médical.
///
/// Informe l'utilisateur que l'outil est un support de triage
/// statistique et ne remplace pas l'avis d'un dermatologue.
class BanniereAvertissement extends StatelessWidget {
  const BanniereAvertissement({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.amber.shade900.withValues(alpha: 0.3)
                : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.amber.shade700 : Colors.amber.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.medical_information,
            color: isDark ? Colors.amber.shade200 : Colors.amber.shade800,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Outil de TRIAGE statistique pour la recherche.\n'
              "Ne remplace pas l'avis d'un dermatologue.",
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
