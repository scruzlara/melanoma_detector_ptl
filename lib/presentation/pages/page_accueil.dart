import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../donnees/config/config_modeles.dart';
import '../../services/theme_service.dart';
import '../providers/provider_melanome.dart';
import '../widgets/banniere_avertissement.dart';
import '../widgets/carte_selection_image.dart';
import '../widgets/formulaire_analyse.dart';
import '../widgets/squelette_resultats.dart';
import 'page_historique.dart';
import 'page_resultats.dart';
import 'page_analyse_faciale.dart';
import 'page_antigravity.dart';
import 'page_analyse_roboflow.dart';
import 'page_pipeline_offline.dart';

/// Page d'accueil de l'application Détecteur de Mélanome.
///
/// Gère le flux principal : sélection d'image → paramètres → analyse → résultats.
/// Toute la logique est déléguée au [ProviderMelanome].
class PageAccueil extends StatefulWidget {
  /// Gestionnaire d'état de l'application.
  final ProviderMelanome provider;

  /// Service de gestion du thème.
  final ThemeService themeService;

  const PageAccueil({
    super.key,
    required this.provider,
    required this.themeService,
  });

  @override
  State<PageAccueil> createState() => _PageAccueilState();
}

class _PageAccueilState extends State<PageAccueil> {
  /// Mode Online (Hybride) ou Offline (P5).
  bool _isOnlineMode = false;

  /// Contrôleur du champ de notes.
  final TextEditingController _controleurNotes = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.provider.addListener(_onProviderChanged);
    widget.provider.demanderPermissions();
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onProviderChanged);
    _controleurNotes.dispose();
    super.dispose();
  }

  void _onProviderChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isOnlineMode ? 'DermAI Hybrid' : 'DermAI Offline'),
        actions: [
          // Switch Online/Offline
          Row(
            children: [
              const Icon(Icons.wifi_off, size: 16),
              Switch(
                value: _isOnlineMode,
                onChanged: (val) => setState(() => _isOnlineMode = val),
                activeTrackColor: Colors.cyanAccent,
              ),
              const Icon(Icons.wifi, size: 16),
              const SizedBox(width: 8),
            ],
          ),
          // Bouton d'historique
          IconButton(
            icon: const Icon(Icons.history_outlined),
            tooltip: 'Historique des analyses',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => PageHistorique(
                        depot: widget.provider.depot,
                        surSelection: (analyse) {
                          widget.provider.chargerAnalyseSauvegardee(analyse);
                        },
                      ),
                ),
              );
            },
          ),
          // Bouton d'information
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Informations Modèles IA',
            onPressed: _afficherInfoModeles,
          ),
          // Bouton de thème
          ListenableBuilder(
            listenable: widget.themeService,
            builder: (context, _) {
              return IconButton(
                icon: Icon(widget.themeService.themeIcon),
                tooltip: widget.themeService.themeTooltip,
                onPressed: widget.themeService.toggleTheme,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avertissement médical
            const BanniereAvertissement(),
            const SizedBox(height: 20),

            // Pipeline Offline Complet (toujours visible)
            Card(
              elevation: 3,
              color: Theme.of(context).colorScheme.primaryContainer,
              child: ListTile(
                leading: const Icon(Icons.offline_bolt, size: 32),
                title: const Text('Pipeline Offline Complet'),
                subtitle: const Text(
                  'Recadrage → Classification → Segmentation → '
                  'Landmarks → Reconstruction',
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PagePipelineOffline(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Mode Online : Analyse Faciale + Arbre de Décision
            if (_isOnlineMode) ...[
              // Analyse IA Roboflow (P7 online models)
              Card(
                elevation: 2,
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.biotech, size: 32),
                  title: const Text('Analyse IA en Ligne'),
                  subtitle: const Text(
                    'Diagnostic par modèles Roboflow (HAM10000)',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _lancerAnalyseRoboflow(),
                ),
              ),
              const SizedBox(height: 10),

              // Analyse Faciale (P7 + Roboflow)
              Card(
                elevation: 2,
                color: Theme.of(context).colorScheme.primaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.face_retouching_natural, size: 32),
                  title: const Text('Mode Analyse Faciale'),
                  subtitle: const Text(
                    'Détection de landmarks & diagnostic Roboflow',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => const PageAnalyseFaciale(isOnline: true),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),

              // Arbre de Décision (P6)
              Card(
                elevation: 2,
                color: Theme.of(context).colorScheme.tertiaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.account_tree, size: 32),
                  title: const Text('Explorateur de Décision'),
                  subtitle: const Text(
                    'Visualisation interactive des arbres d\'Antigravity',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PageAntigravityZone(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            const SizedBox(height: 20),

            // Sélection d'image
            CarteSelectionImage(
              imageSelectionnee: provider.imageSelectionnee,
              desactive: provider.enChargement,
              surAppui: () => _afficherOptionsImage(context),
            ),
            const SizedBox(height: 20),

            // Erreur
            if (provider.messageErreur != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  provider.messageErreur!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Formulaire ou Résultats
            if (provider.resultat == null) ...[
              FormulaireAnalyse(
                controleurNotes: _controleurNotes,
                enChargement: provider.enChargement,
                imagePresente: provider.imageSelectionnee != null,
                surAnalyser: () {
                  provider.definirNotes(_controleurNotes.text);
                  provider.analyser();
                },
                modeleSelectionne: provider.modeleSelectionne,
                modelesDisponibles: ConfigModeles.modelesDisponibles,
                surChangementModele: (modele) {
                  if (modele != null) provider.definirModele(modele);
                },
              ),
            ] else ...[
              PageResultats(
                provider: provider,
                imageSelectionnee: provider.imageSelectionnee,
              ),
            ],

            // Squelette de chargement shimmer
            if (provider.enChargement) ...[
              const SizedBox(height: 20),
              const SqueletteResultats(),
            ],
          ],
        ),
      ),
    );
  }

  /// Lance l'analyse Roboflow : sélection d'image puis navigation.
  Future<void> _lancerAnalyseRoboflow() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Galerie'),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Caméra'),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
              ],
            ),
          ),
    );

    if (source == null || !mounted) return;

    final picked = await picker.pickImage(
      source: source,
      maxWidth: 640,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
                PageAnalyseRoboflow(imageBytes: bytes, imagePath: picked.path),
      ),
    );
  }

  /// Affiche les options de sélection d'image (galerie / caméra).
  void _afficherOptionsImage(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Galerie'),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.provider.choisirImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Caméra'),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.provider.choisirImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
    );
  }

  /// Affiche le dialogue d'information sur les modèles IA.
  void _afficherInfoModeles() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Informations Modèles IA'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _construireSectionInfo('🕵️‍♂️ Détection (Classification)', [
                    'Modèles: ViT (API) & MobileNetV3 (Local).',
                    'Performance (Test ISIC 2019): AUC 0.9053, Acc 89.0%, Sens 64.7%, Spec 93.7%.',
                    'Entraînement: ~25k images (ISIC 2019), Perte Pondérée.',
                    'Quantisation: Int8 (Mobile) pour rapidité.',
                  ]),
                  const Divider(),
                  _construireSectionInfo('✂️ Segmentation (Forme)', [
                    'Architecture: U-Net (Encodeur EfficientNet-B3).',
                    'Données: HAM10000 (10k masques experts).',
                    'Performance: Dice 0.93, IoU 0.88.',
                    'Résolution: 256×256 pixels.',
                  ]),
                  const Divider(),
                  _construireSectionInfo('⚠️ Limitations & Biais', [
                    'Usage: Outil d\'aide au triage statistique uniquement.',
                    'Biais: Entraîné majoritairement sur peaux claires (Types I-III).',
                    'Sensibilité: Pilosité dense, éclairage jaune/ombres.',
                  ]),
                  const SizedBox(height: 10),
                  Text(
                    'Note: Les dimensions sont en pixels relatifs, '
                    'utiles pour analyser la forme mais ne représentent pas '
                    'la taille réelle sans calibration.',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fermer'),
              ),
            ],
          ),
    );
  }

  /// Construit une section d'information (titre + puces).
  Widget _construireSectionInfo(String titre, List<String> elements) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titre,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 6),
        ...elements.map(
          (e) => Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Text('• $e', style: const TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }
}
