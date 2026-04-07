import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domaine/entites/resultat_analyse.dart';
import '../../domaine/services/service_geometrie.dart';
import '../providers/provider_melanome.dart';
import '../widgets/carte_details_techniques.dart';
import '../widgets/carte_risque.dart';
import '../widgets/peintre_segmentation.dart';
import 'page_editeur_contours.dart';

/// Section d'affichage des résultats d'analyse.
///
/// Affiche la carte de risque, la segmentation locale (contours),
/// le bouton d'édition des contours et les détails techniques.
/// Conçu pour être intégré dans [PageAccueil] (pas une page autonome).
class PageResultats extends StatelessWidget {
  /// Gestionnaire d'état de l'application.
  final ProviderMelanome provider;

  /// Image sélectionnée (pour la segmentation locale).
  final File? imageSelectionnee;

  const PageResultats({
    super.key,
    required this.provider,
    this.imageSelectionnee,
  });

  @override
  Widget build(BuildContext context) {
    final res = provider.resultat!;
    final json = res.resultJson;
    final nomModele = json?['model_name'] as String?;

    // Extraire le diagnostic via le service domaine
    final diagData = ServiceGeometrie.extraireDiagnostic(json);
    final double confiance = diagData['confiance'];
    final donneesRisque = ServiceGeometrie.evaluerNiveauRisque(confiance);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        const SizedBox(height: 10),

        // 1. Carte de risque
        CarteRisque(
          donneesRisque: donneesRisque,
          confiance: confiance,
          nomModele: nomModele,
        ),

        const SizedBox(height: 24),

        // 2. Segmentation locale (contours sur l'image)
        _construireAnalyseVisuelle(context, res),

        // 3. Bouton d'édition des contours
        if (res.contours != null &&
            res.contours!.isNotEmpty &&
            imageSelectionnee != null) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.edit_location_alt_outlined),
              label: const Text('MODIFIER LA SEGMENTATION'),
              onPressed: () => _editerContours(context, res),
            ),
          ),
        ],

        const SizedBox(height: 24),

        // 4. Détails techniques
        CarteDetailsTechniques(resultJson: json, nomModele: nomModele),

        const SizedBox(height: 24),

        // 5. Actions : Sauvegarder, Exporter PDF, Exporter JSON
        _construireActionsExport(context),

        const SizedBox(height: 24),

        // 6. Bouton nouvelle analyse
        Center(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            icon: const Icon(Icons.refresh),
            onPressed: provider.afficherFormulaire,
            label: const Text('NOUVELLE ANALYSE'),
          ),
        ),
      ],
    );
  }

  /// Construit les boutons d'action (sauvegarder, exporter).
  Widget _construireActionsExport(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sauvegarder
        FilledButton.icon(
          icon: const Icon(Icons.save_outlined),
          label: const Text('SAUVEGARDER'),
          onPressed: () async {
            final succes = await provider.sauvegarderAnalyse();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    succes
                        ? 'Analyse sauvegardée avec succès'
                        : 'Erreur lors de la sauvegarde',
                  ),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 8),

        // Export PDF et JSON côte à côte
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF'),
                onPressed: () async {
                  final succes = await provider.exporterPdf();
                  if (context.mounted && !succes) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Erreur lors de l\'export PDF'),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.data_object_outlined),
                label: const Text('JSON'),
                onPressed: () async {
                  final succes = await provider.exporterJson();
                  if (context.mounted && !succes) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Erreur lors de l\'export JSON'),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Construit la section de segmentation locale.
  Widget _construireAnalyseVisuelle(BuildContext context, ResultatAnalyse res) {
    final theme = Theme.of(context);

    if (res.contours == null ||
        res.contours!.isEmpty ||
        imageSelectionnee == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Analyse Visuelle',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _construireSegmentationLocale(res),
      ],
    );
  }

  /// Construit l'affichage de la segmentation locale.
  Widget _construireSegmentationLocale(ResultatAnalyse res) {
    final imgWidth = res.largeurImage;
    final imgHeight = res.hauteurImage;

    Widget contenu;
    if (imgWidth != null &&
        imgHeight != null &&
        imgWidth > 0 &&
        imgHeight > 0) {
      final ratio = imgWidth / imgHeight;
      contenu = AspectRatio(
        aspectRatio: ratio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(imageSelectionnee!, fit: BoxFit.contain),
            CustomPaint(
              painter: PeintreSegmentation(
                contours: res.contours!,
                tailleOriginale: Size(
                  imgWidth.toDouble(),
                  imgHeight.toDouble(),
                ),
                couleur: Colors.redAccent,
              ),
            ),
          ],
        ),
      );
    } else {
      contenu = SizedBox(
        height: 300,
        child: Stack(
          fit: StackFit.expand,
          children: [Image.file(imageSelectionnee!, fit: BoxFit.contain)],
        ),
      );
    }

    return Column(
      children: [
        Text(
          'Segmentation Locale',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade400,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
            color: Colors.black12,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: contenu,
          ),
        ),
      ],
    );
  }

  /// Ouvre l'éditeur de contours et met à jour les données.
  Future<void> _editerContours(
    BuildContext context,
    ResultatAnalyse res,
  ) async {
    final nouveauxContours = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => PageEditeurContours(
              fichierImage: imageSelectionnee!,
              contoursInitiaux: res.contours!,
              mmParPixel: 0.0,
            ),
      ),
    );

    if (nouveauxContours != null) {
      try {
        final List<List<double>> contoursTypes =
            (nouveauxContours as List)
                .map((e) => (e as List).map((v) => v as double).toList())
                .toList();
        provider.mettreAJourContours(contoursTypes);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Erreur mise à jour contours: $e');
        }
      }
    }
  }
}
