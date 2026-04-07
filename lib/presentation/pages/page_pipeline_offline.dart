import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../donnees/services/service_export_pdf.dart';
import '../../services/facial_analysis_service.dart';

import '../../donnees/config/config_modeles.dart';
import '../../models/facial_landmark.dart';
import '../../models/resultat_pipeline_offline.dart';
import '../../services/reconstruction_service.dart';
import '../../services/service_pipeline_offline.dart';
import '../../theme/app_theme.dart';
import 'page_antigravity.dart';
import 'page_editeur_segmentation.dart';

/// Page d'analyse offline complète : recadrage → classification →
/// segmentation → landmarks → décision de reconstruction.
///
/// Utilise un widget de recadrage interactif intégré (pas de dépendance
/// externe) pour obtenir les coordonnées exactes du rectangle de sélection.
class PagePipelineOffline extends StatefulWidget {
  const PagePipelineOffline({super.key});

  @override
  State<PagePipelineOffline> createState() => _PagePipelineOfflineState();
}

class _PagePipelineOfflineState extends State<PagePipelineOffline> {
  final ImagePicker _picker = ImagePicker();
  final ServicePipelineOffline _pipeline = ServicePipelineOffline();

  int _currentStep = 0; // 0=image, 1=crop, 2=analyse, 3=résultats
  File? _imageFile;
  ui.Image? _uiImage;
  Rect? _cropRect; // Coordonnées EXACTES dans l'image originale (pixels)
  ResultatPipelineOffline? _result;
  bool _isLoading = false;
  String? _errorMessage;

  // ── Multi-modèle ──────────────────────────────────────────────────────
  final Set<int> _selectedModelIndices = {1}; // défaut = Melanoma Mobile V2
  Map<String, ResultatPipelineOffline> _multiResults = {};
  String? _loadingModelName;
  Set<String> _enabledModelNames = {};

  // ── Sélection d'image ─────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 90,
      );
      if (picked == null) return;

      final file = File(picked.path);
      final data = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(data);
      final frame = await codec.getNextFrame();

      setState(() {
        _imageFile = file;
        _uiImage = frame.image;
        _cropRect = null;
        _result = null;
        _errorMessage = null;
        _currentStep = 1;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Erreur sélection image : $e');
    }
  }

  // ── Análisis Pipeline ─────────────────────────────────────────────────

  Future<void> _runAnalysis() async {
    if (_imageFile == null || _cropRect == null) return;
    if (_selectedModelIndices.isEmpty) {
      setState(() => _errorMessage = 'Sélectionnez au moins un modèle.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _multiResults = {};
      _loadingModelName = null;
    });

    try {
      final models =
          _selectedModelIndices
              .map((i) => ConfigModeles.modelesDisponibles[i])
              .toList();

      for (final modele in models) {
        setState(() => _loadingModelName = modele.nom);

        final result = await _pipeline.executerPipeline(
          imagePath: _imageFile!.path,
          cropRect: _cropRect!,
          modele: modele,
        );
        _multiResults[modele.nom] = result;
      }

      // Le résultat actif = premier modèle
      final firstName = models.first.nom;
      setState(() {
        _result = _multiResults[firstName];
        _enabledModelNames = _multiResults.keys.toSet();
        _currentStep = 3;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Erreur analyse : $e');
    } finally {
      setState(() {
        _isLoading = false;
        _loadingModelName = null;
      });
    }
  }

  Future<void> _exporterPDF() async {
    if (_result == null || _imageFile == null) return;
    if (_result!.keyPoints == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible de générer le rapport : aucun point de repère facial détecté.',
          ),
        ),
      );
      return;
    }

    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Génération du rapport PDF...')),
      );

      // Convertir ResultatPipelineOffline en FacialAnalysisResult
      final facialResult = FacialAnalysisResult(
        keyPoints: _result!.keyPoints!,
        region: _result!.region,
        distancesPx: _result!.distancesPx,
        reconstructionOptions: _result!.reconstructionOptions,
        reconstructionZone: _result!.antigravityZone,
        diagnosis: _result!.classification['prediccion_final'] as String?,
        confidence: (_result!.classification['confianza'] as double?) ?? 0.0,
        pxToMmRatio: _result!.pxToMmRatio,
        contours: _result!.contoursOriginal,
      );

      final cropBytes = await _generateCropImage();

      final fichier = await ServiceExportPdf.genererRapportFacial(
        result: facialResult,
        imageFile: _imageFile!,
        lesionPosition: _result!.lesionCenter,
        patientName: "Patient (Anonyme)",
        lesionCropBytes: cropBytes,
        cropRect: _result!.cropRect,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      await Share.shareXFiles([
        XFile(fichier.path),
      ], subject: 'Rapport Analyse Offline - DermAI');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur export PDF: $e')));
    }
  }

  Future<Uint8List?> _generateCropImage() async {
    if (_uiImage == null || _result?.cropRect == null) return null;
    try {
      final rect = _result!.cropRect;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Décaler l'image pour que le crop commence à (0,0)
      canvas.translate(-rect.left, -rect.top);
      canvas.drawImage(_uiImage!, Offset.zero, Paint());

      final picture = recorder.endRecording();
      final img = await picture.toImage(
        rect.width.toInt(),
        rect.height.toInt(),
      );
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("Erreur crop image: $e");
      return null;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Analyse Offline',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (_currentStep == 3 &&
              _result != null &&
              _result!.keyPoints != null)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.picture_as_pdf, color: Colors.white),
              ),
              tooltip: 'Exporter PDF',
              onPressed: _exporterPDF,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.primaryGradient : AppTheme.lightGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStepIndicator(isDark),
                const SizedBox(height: 24),
                if (_errorMessage != null) _buildErrorCard(isDark),
                _buildCurrentStepContent(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Widgets de cada paso
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildStepIndicator(bool isDark) {
    const steps = ['📸 Image', '✂️ Recadrer', '🧠 Analyser', '📊 Résultats'];
    return Row(
      children: List.generate(steps.length, (i) {
        final isActive = i == _currentStep;
        final isDone = i < _currentStep;
        return Expanded(
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      isDone
                          ? AppTheme.accentCyan
                          : isActive
                          ? AppTheme.accentCyan.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.1),
                ),
                child: Center(
                  child:
                      isDone
                          ? const Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.white,
                          )
                          : Text(
                            '${i + 1}',
                            style: TextStyle(
                              color:
                                  isActive
                                      ? AppTheme.accentCyan
                                      : Colors.white54,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                steps[i],
                style: TextStyle(
                  fontSize: 10,
                  color:
                      isActive || isDone
                          ? (isDark ? Colors.white : Colors.black87)
                          : Colors.white38,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }),
    ).animate().fadeIn();
  }

  Widget _buildErrorCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepContent(bool isDark) {
    switch (_currentStep) {
      case 0:
        return _buildStep0Image(isDark);
      case 1:
        return _buildStep1Crop(isDark);
      case 2:
        return _buildStep2Analyze(isDark);
      case 3:
        return _buildStep3Results(isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Step 0 : Selección de imagen ──────────────────────────────────────

  Widget _buildStep0Image(bool isDark) {
    return _buildCard(
      isDark: isDark,
      icon: Icons.add_photo_alternate_outlined,
      title: 'Sélectionnez une image du visage',
      subtitle:
          'Prenez une photo ou choisissez depuis la galerie.\n'
          'L\'image doit montrer le visage entier avec la lésion visible.',
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: Icons.camera_alt,
              label: 'Caméra',
              onPressed: () => _pickImage(ImageSource.camera),
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              icon: Icons.photo_library,
              label: 'Galerie',
              onPressed: () => _pickImage(ImageSource.gallery),
              isDark: isDark,
              outlined: true,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  // ── Step 1 : Recorte interactivo (coordenadas exactas) ────────────────

  Widget _buildStep1Crop(bool isDark) {
    if (_imageFile == null || _uiImage == null) return const SizedBox.shrink();

    return Column(
      children: [
        _buildCard(
          isDark: isDark,
          icon: Icons.crop,
          title: 'Sélectionnez la lésion',
          subtitle:
              'Déplacez et redimensionnez le rectangle cyan pour '
              'encadrer précisément le mélanome.',
          child: const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
        _CropSelectionWidget(
          imageFile: _imageFile!,
          uiImage: _uiImage!,
          onCropConfirmed: (cropRectInImageCoords) {
            setState(() {
              _cropRect = cropRectInImageCoords;
              _currentStep = 2;
            });
          },
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _imageFile = null;
              _uiImage = null;
              _currentStep = 0;
            });
          },
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Changer d\'image'),
        ),
      ],
    );
  }

  // ── Step 2 : Análisis ────────────────────────────────────────────────

  Widget _buildStep2Analyze(bool isDark) {
    return Column(
      children: [
        if (_uiImage != null && _cropRect != null)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.accentCyan.withValues(alpha: 0.3),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final ratio = _uiImage!.width / _uiImage!.height;
                  final displayW = constraints.maxWidth;
                  final displayH = displayW / ratio;
                  return CustomPaint(
                    size: Size(displayW, displayH),
                    painter: _CropPreviewPainter(
                      image: _uiImage!,
                      cropRect: _cropRect!,
                    ),
                  );
                },
              ),
            ),
          ).animate().fadeIn(),
        const SizedBox(height: 16),

        // ── Sélection de modèles ──────────────────────────────────────────
        _buildCard(
          isDark: isDark,
          icon: Icons.model_training,
          title: 'Modèles de classification',
          subtitle: 'Sélectionnez un ou plusieurs modèles à exécuter.',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(ConfigModeles.modelesDisponibles.length, (
              i,
            ) {
              final m = ConfigModeles.modelesDisponibles[i];
              final selected = _selectedModelIndices.contains(i);
              return FilterChip(
                label: Text(
                  m.nom,
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        selected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
                selected: selected,
                selectedColor: AppTheme.accentCyan.withValues(alpha: 0.7),
                checkmarkColor: Colors.white,
                backgroundColor:
                    isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.withValues(alpha: 0.15),
                onSelected:
                    _isLoading
                        ? null
                        : (val) {
                          setState(() {
                            if (val) {
                              _selectedModelIndices.add(i);
                            } else {
                              _selectedModelIndices.remove(i);
                            }
                          });
                        },
              );
            }),
          ),
        ),
        const SizedBox(height: 12),

        // ── Lancement ─────────────────────────────────────────────────────
        _buildCard(
          isDark: isDark,
          icon: Icons.psychology,
          title: 'Lancer l\'analyse',
          subtitle:
              'Classification, segmentation et analyse faciale '
              'seront exécutées localement sur la zone sélectionnée.',
          child: Column(
            children: [
              if (_isLoading) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(color: AppTheme.accentCyan),
                const SizedBox(height: 8),
                Text(
                  _loadingModelName != null
                      ? 'Analyse avec $_loadingModelName...'
                      : 'Analyse en cours...',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (_multiResults.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${_multiResults.length}/${_selectedModelIndices.length} terminé(s)',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: _buildActionButton(
                    icon: Icons.play_arrow,
                    label:
                        _selectedModelIndices.length > 1
                            ? 'LANCER (${_selectedModelIndices.length} MODÈLES)'
                            : 'LANCER L\'ANALYSE',
                    onPressed: _runAnalysis,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _cropRect = null;
                      _currentStep = 1;
                    });
                  },
                  icon: const Icon(Icons.crop, size: 16),
                  label: const Text('Recadrer à nouveau'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Panneau de classification interactif multi-modèle ─────────────────

  Widget _buildClassificationPanel(bool isDark) {
    // Résultats des modèles activés
    final enabledResults =
        _multiResults.entries
            .where((e) => _enabledModelNames.contains(e.key))
            .map((e) => e.value)
            .toList();

    // Calcul de la moyenne
    double avgProb = 0;
    double avgConf = 0;
    if (enabledResults.isNotEmpty) {
      avgProb =
          enabledResults.map((r) => r.probMalignant).reduce((a, b) => a + b) /
          enabledResults.length;
      avgConf =
          enabledResults.map((r) => r.confiance).reduce((a, b) => a + b) /
          enabledResults.length;
    }
    final avgMalignant = avgProb >= 0.5;

    // Si un seul modèle dans _multiResults
    if (_multiResults.length <= 1) {
      final r = _result!;
      return _buildResultCard(
        isDark: isDark,
        icon:
            r.estProbablementMaligne ? Icons.warning_amber : Icons.check_circle,
        iconColor: r.estProbablementMaligne ? Colors.red : Colors.green,
        title: r.label,
        subtitle:
            'Confiance : ${(r.confiance * 100).toStringAsFixed(1)}%\n'
            'Probabilité maligne : ${(r.probMalignant * 100).toStringAsFixed(1)}%',
      ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1);
    }

    // Multi-modèle : consensus + détail par modèle
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: isDark ? AppTheme.cardGradient : AppTheme.lightCardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (avgMalignant ? Colors.red : Colors.green).withValues(
            alpha: 0.3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Consensus ──────────────────────────────────────────────
          Row(
            children: [
              Icon(
                avgMalignant ? Icons.warning_amber : Icons.check_circle,
                color: avgMalignant ? Colors.red : Colors.green,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      enabledResults.isEmpty
                          ? 'Aucun modèle sélectionné'
                          : (avgMalignant ? 'MELANOMA' : 'BÉNIN'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: avgMalignant ? Colors.red : Colors.green,
                      ),
                    ),
                    if (enabledResults.isNotEmpty)
                      Text(
                        'Consensus ${enabledResults.length} modèle${enabledResults.length > 1 ? 's' : ''} — '
                        'Prob. maligne moy. : ${(avgProb * 100).toStringAsFixed(1)}% — '
                        'Confiance moy. : ${(avgConf * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),
          const SizedBox(height: 10),

          // ── Détail par modèle (avec toggle) ───────────────────────
          Text(
            'Résultats par modèle :',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          ..._multiResults.entries.map((entry) {
            final name = entry.key;
            final res = entry.value;
            final enabled = _enabledModelNames.contains(name);
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  setState(() {
                    if (enabled) {
                      _enabledModelNames.remove(name);
                    } else {
                      _enabledModelNames.add(name);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color:
                        enabled
                            ? (res.estProbablementMaligne
                                    ? Colors.red
                                    : Colors.green)
                                .withValues(alpha: 0.08)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.02)
                                : Colors.grey.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          enabled
                              ? (res.estProbablementMaligne
                                      ? Colors.red
                                      : Colors.green)
                                  .withValues(alpha: 0.3)
                              : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Checkbox
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: enabled,
                          onChanged: (_) {
                            setState(() {
                              if (enabled) {
                                _enabledModelNames.remove(name);
                              } else {
                                _enabledModelNames.add(name);
                              }
                            });
                          },
                          activeColor: AppTheme.accentCyan,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Icône résultat
                      Icon(
                        res.estProbablementMaligne
                            ? Icons.warning_amber
                            : Icons.check_circle,
                        size: 16,
                        color:
                            enabled
                                ? (res.estProbablementMaligne
                                    ? Colors.red
                                    : Colors.green)
                                : (isDark ? Colors.white24 : Colors.black26),
                      ),
                      const SizedBox(width: 8),
                      // Nom + détails
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color:
                                    enabled
                                        ? (isDark
                                            ? Colors.white
                                            : Colors.black87)
                                        : (isDark
                                            ? Colors.white30
                                            : Colors.black26),
                              ),
                            ),
                            Text(
                              '${res.label} — '
                              'Conf. ${(res.confiance * 100).toStringAsFixed(1)}% — '
                              'Prob. mal. ${(res.probMalignant * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 9,
                                color:
                                    enabled
                                        ? (isDark
                                            ? Colors.white54
                                            : Colors.black45)
                                        : (isDark
                                            ? Colors.white.withValues(
                                              alpha: 0.2,
                                            )
                                            : Colors.black12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1);
  }

  // ── Step 3 : Resultados ──────────────────────────────────────────────

  Widget _buildStep3Results(bool isDark) {
    if (_result == null) return const SizedBox.shrink();
    final r = _result!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Image avec résultats superposés (interactive)
        if (_uiImage != null)
          _InteractiveResultImage(
            uiImage: _uiImage!,
            result: r,
            imageFile: _imageFile,
          ).animate().fadeIn(),

        const SizedBox(height: 20),

        // ── Classification — panneau interactif multi-modèle ─────────────
        _buildClassificationPanel(isDark),

        const SizedBox(height: 12),

        // Taille estimée de la lésion (calibrée via IPD)
        _buildResultCard(
          isDark: isDark,
          icon: Icons.straighten,
          iconColor: Colors.orangeAccent,
          title:
              r.lesionSizeCm != null
                  ? 'Taille estimée : ${r.lesionSizeCm!.toStringAsFixed(2)} cm '
                      '(${r.lesionSizeMm!.toStringAsFixed(1)} mm)'
                  : 'Taille : ${r.lesionDiameterPx.toStringAsFixed(0)} px',
          subtitle:
              r.pxToMmRatio != null
                  ? 'Calibré via distance interpupillaire '
                      '(${r.ipdPx!.toStringAsFixed(0)} px → 63 mm).\n'
                      'Ratio : ${r.pxToMmRatio!.toStringAsFixed(4)} mm/px'
                  : 'Calibration interpupillaire non disponible '
                      '(yeux non détectés). Valeur en pixels uniquement.',
        ).animate().fadeIn(delay: 150.ms).slideX(begin: 0.1),

        const SizedBox(height: 12),

        // Región facial
        _buildResultCard(
          isDark: isDark,
          icon: Icons.location_on,
          iconColor: AppTheme.accentCyan,
          title: 'Zone : ${r.region.displayName}',
          subtitle:
              r.region != FacialRegion.unknown
                  ? r.region.surgicalConsiderations
                  : 'Aucun visage détecté — l\'analyse de reconstruction '
                      'n\'est pas disponible.',
        ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1),

        const SizedBox(height: 12),

        // Distancias
        if (r.distancesPx.isNotEmpty) ...[
          _buildDistancesCard(isDark, r.distancesPx, r.pxToMmRatio),
          const SizedBox(height: 12),
        ],

        // Opciones de reconstrucción
        if (r.reconstructionOptions.isNotEmpty) ...[
          _buildSectionTitle('Options de Reconstruction', isDark),
          const SizedBox(height: 8),
          ...r.reconstructionOptions.asMap().entries.map((entry) {
            return _buildReconstructionCard(entry.value, isDark, entry.key);
          }),
        ],

        // Botón Antigravity
        if (r.antigravityZone != null) ...[
          const SizedBox(height: 16),
          _buildActionButton(
            icon: Icons.account_tree,
            label: 'EXPLORER L\'ARBRE DE DÉCISION',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => PageAntigravityTreeView(zone: r.antigravityZone!),
                ),
              );
            },
            isDark: isDark,
          ),
        ],

        const SizedBox(height: 16),

        // Nueva análisis
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _currentStep = 0;
              _imageFile = null;
              _uiImage = null;
              _cropRect = null;
              _result = null;
              _multiResults = {};
              _errorMessage = null;
            });
          },
          icon: const Icon(Icons.refresh),
          label: const Text('NOUVELLE ANALYSE'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Widgets utilitaires
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildCard({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isDark ? AppTheme.cardGradient : AppTheme.lightCardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppTheme.accentCyan),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (child is! SizedBox) ...[const SizedBox(height: 16), child],
        ],
      ),
    );
  }

  Widget _buildResultCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isDark ? AppTheme.cardGradient : AppTheme.lightCardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistancesCard(
    bool isDark,
    Map<String, double> distances,
    double? pxToMmRatio,
  ) {
    final sorted =
        distances.entries.toList()..sort((a, b) => a.value.compareTo(b.value));

    String formatDist(double px) {
      if (pxToMmRatio != null) {
        final cm = px * pxToMmRatio / 10.0;
        return '${cm.toStringAsFixed(1)} cm';
      }
      return '${px.toStringAsFixed(0)} px';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isDark ? AppTheme.cardGradient : AppTheme.lightCardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pxToMmRatio != null
                ? 'Distances aux points clés (≈ cm, calibré via IPD)'
                : 'Distances aux points clés (pixels)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                sorted.map((e) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accentCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.accentCyan.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '${e.key}: ${formatDist(e.value)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildReconstructionCard(
    ReconstructionOption option,
    bool isDark,
    int index,
  ) {
    Color complexityColor;
    switch (option.complexity) {
      case ReconstructionComplexity.simple:
        complexityColor = Colors.green;
        break;
      case ReconstructionComplexity.moderate:
        complexityColor = Colors.orange;
        break;
      case ReconstructionComplexity.complex:
        complexityColor = Colors.red;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: isDark ? AppTheme.cardGradient : AppTheme.lightCardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: complexityColor.withValues(alpha: 0.3)),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: complexityColor.withValues(alpha: 0.15),
          child: Icon(Icons.medical_services, color: complexityColor, size: 16),
        ),
        title: Text(
          option.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (option.subRegion != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  option.subRegion!,
                  style: TextStyle(
                    color: AppTheme.accentCyan,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            Text(
              '${option.complexity.displayName} • '
              'Succès ~${option.successRate.toInt()}%',
              style: TextStyle(
                color: complexityColor,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                if (option.considerations.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Points clés :',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  ...option.considerations.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '• $c',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 100 * index));
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isDark,
    bool outlined = false,
  }) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: AppTheme.accentCyan.withValues(alpha: 0.5)),
        ),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.accentCyan,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Widget de recadrage interactif — renvoie le Rect exact en pixels image
// ═══════════════════════════════════════════════════════════════════════════════

enum _DragHandle { topLeft, topRight, bottomLeft, bottomRight, move }

class _CropSelectionWidget extends StatefulWidget {
  final File imageFile;
  final ui.Image uiImage;
  final ValueChanged<Rect> onCropConfirmed;

  const _CropSelectionWidget({
    required this.imageFile,
    required this.uiImage,
    required this.onCropConfirmed,
  });

  @override
  State<_CropSelectionWidget> createState() => _CropSelectionWidgetState();
}

class _CropSelectionWidgetState extends State<_CropSelectionWidget> {
  Rect _displayCropRect = Rect.zero;
  double _displayWidth = 0;
  double _displayHeight = 0;
  bool _initialized = false;
  _DragHandle? _activeHandle;
  final TransformationController _zoomController = TransformationController();

  @override
  void dispose() {
    _zoomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isZoomed = _zoomController.value.getMaxScaleOnAxis() > 1.05;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.accentCyan.withValues(alpha: 0.3),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final ratio =
                    widget.uiImage.width.toDouble() /
                    widget.uiImage.height.toDouble();
                _displayWidth = constraints.maxWidth;
                _displayHeight = _displayWidth / ratio;

                if (!_initialized) {
                  final w = _displayWidth * 0.3;
                  final h = _displayHeight * 0.3;
                  _displayCropRect = Rect.fromCenter(
                    center: Offset(_displayWidth / 2, _displayHeight / 2),
                    width: w,
                    height: h,
                  );
                  _initialized = true;
                }

                return SizedBox(
                  width: _displayWidth,
                  height: _displayHeight,
                  child: InteractiveViewer(
                    transformationController: _zoomController,
                    minScale: 1.0,
                    maxScale: 5.0,
                    panEnabled: true,
                    scaleEnabled: true,
                    onInteractionEnd: (_) => setState(() {}),
                    child: GestureDetector(
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      child: CustomPaint(
                        size: Size(_displayWidth, _displayHeight),
                        painter: _CropOverlayPainter(
                          image: widget.uiImage,
                          cropRect: _displayCropRect,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        // ── Barre d'actions ──────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pinch,
              size: 14,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            const SizedBox(width: 4),
            Text(
              'Pincez pour zoomer',
              style: TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            if (isZoomed) ...[
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  _zoomController.value = Matrix4.identity();
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.accentCyan.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'Réinitialiser zoom',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.accentCyan,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () {
            widget.onCropConfirmed(_toImageCoords(_displayCropRect));
          },
          icon: const Icon(Icons.check),
          label: const Text('CONFIRMER LA SÉLECTION'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.accentCyan,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ],
    );
  }

  void _onPanStart(DragStartDetails details) {
    _activeHandle = _hitTestHandle(details.localPosition);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      final delta = details.delta;
      const minSize = 30.0;

      if (_activeHandle == _DragHandle.move) {
        var newRect = _displayCropRect.shift(delta);
        if (newRect.left < 0) {
          newRect = newRect.shift(Offset(-newRect.left, 0));
        }
        if (newRect.top < 0) {
          newRect = newRect.shift(Offset(0, -newRect.top));
        }
        if (newRect.right > _displayWidth) {
          newRect = newRect.shift(Offset(_displayWidth - newRect.right, 0));
        }
        if (newRect.bottom > _displayHeight) {
          newRect = newRect.shift(Offset(0, _displayHeight - newRect.bottom));
        }
        _displayCropRect = newRect;
      } else if (_activeHandle != null) {
        double l = _displayCropRect.left;
        double t = _displayCropRect.top;
        double r = _displayCropRect.right;
        double b = _displayCropRect.bottom;

        switch (_activeHandle!) {
          case _DragHandle.topLeft:
            l = (l + delta.dx).clamp(0.0, r - minSize);
            t = (t + delta.dy).clamp(0.0, b - minSize);
          case _DragHandle.topRight:
            r = (r + delta.dx).clamp(l + minSize, _displayWidth);
            t = (t + delta.dy).clamp(0.0, b - minSize);
          case _DragHandle.bottomLeft:
            l = (l + delta.dx).clamp(0.0, r - minSize);
            b = (b + delta.dy).clamp(t + minSize, _displayHeight);
          case _DragHandle.bottomRight:
            r = (r + delta.dx).clamp(l + minSize, _displayWidth);
            b = (b + delta.dy).clamp(t + minSize, _displayHeight);
          case _DragHandle.move:
            break;
        }
        _displayCropRect = Rect.fromLTRB(l, t, r, b);
      }
    });
  }

  _DragHandle _hitTestHandle(Offset pos) {
    const threshold = 28.0;
    final r = _displayCropRect;

    if ((pos - r.topLeft).distance < threshold) return _DragHandle.topLeft;
    if ((pos - r.topRight).distance < threshold) return _DragHandle.topRight;
    if ((pos - r.bottomLeft).distance < threshold) {
      return _DragHandle.bottomLeft;
    }
    if ((pos - r.bottomRight).distance < threshold) {
      return _DragHandle.bottomRight;
    }
    if (r.contains(pos)) return _DragHandle.move;
    return _DragHandle.move;
  }

  /// Convertit le rect d'affichage en coordonnées pixels de l'image réelle.
  Rect _toImageCoords(Rect displayRect) {
    final scaleX = widget.uiImage.width.toDouble() / _displayWidth;
    final scaleY = widget.uiImage.height.toDouble() / _displayHeight;
    return Rect.fromLTRB(
      displayRect.left * scaleX,
      displayRect.top * scaleY,
      displayRect.right * scaleX,
      displayRect.bottom * scaleY,
    );
  }

  @override
  void didUpdateWidget(covariant _CropSelectionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageFile != widget.imageFile) {
      _initialized = false;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Painters
// ═══════════════════════════════════════════════════════════════════════════════

/// Overlay de recadrage : image + zone assombrie + rectangle cyan + poignées.
class _CropOverlayPainter extends CustomPainter {
  final ui.Image image;
  final Rect cropRect;

  _CropOverlayPainter({required this.image, required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    // Image
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, src, dst, Paint());

    // Zone assombrie autour du crop
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, cropRect.top), dimPaint);
    canvas.drawRect(
      Rect.fromLTRB(0, cropRect.bottom, size.width, size.height),
      dimPaint,
    );
    canvas.drawRect(
      Rect.fromLTRB(0, cropRect.top, cropRect.left, cropRect.bottom),
      dimPaint,
    );
    canvas.drawRect(
      Rect.fromLTRB(cropRect.right, cropRect.top, size.width, cropRect.bottom),
      dimPaint,
    );

    // Bordure du rectangle
    canvas.drawRect(
      cropRect,
      Paint()
        ..color = AppTheme.accentCyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Poignées aux coins
    const handleRadius = 8.0;
    final handleFill =
        Paint()
          ..color = AppTheme.accentCyan
          ..style = PaintingStyle.fill;
    final handleStroke =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    for (final corner in [
      cropRect.topLeft,
      cropRect.topRight,
      cropRect.bottomLeft,
      cropRect.bottomRight,
    ]) {
      canvas.drawCircle(corner, handleRadius, handleFill);
      canvas.drawCircle(corner, handleRadius, handleStroke);
    }

    // Taille du rectangle
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${cropRect.width.toInt()} × ${cropRect.height.toInt()}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          backgroundColor: Colors.black54,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        cropRect.left + (cropRect.width - textPainter.width) / 2,
        cropRect.bottom + 4,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter old) =>
      old.cropRect != cropRect || old.image != image;
}

/// Aperçu de la zone sélectionnée sur l'image (step 2).
class _CropPreviewPainter extends CustomPainter {
  final ui.Image image;
  final Rect cropRect;

  _CropPreviewPainter({required this.image, required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, src, dst, Paint());

    final scaleX = size.width / image.width;
    final scaleY = size.height / image.height;
    final scaledCrop = Rect.fromLTRB(
      cropRect.left * scaleX,
      cropRect.top * scaleY,
      cropRect.right * scaleX,
      cropRect.bottom * scaleY,
    );

    // Zone assombrie extérieure
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.4);
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, scaledCrop.top), dimPaint);
    canvas.drawRect(
      Rect.fromLTRB(0, scaledCrop.bottom, size.width, size.height),
      dimPaint,
    );
    canvas.drawRect(
      Rect.fromLTRB(0, scaledCrop.top, scaledCrop.left, scaledCrop.bottom),
      dimPaint,
    );
    canvas.drawRect(
      Rect.fromLTRB(
        scaledCrop.right,
        scaledCrop.top,
        size.width,
        scaledCrop.bottom,
      ),
      dimPaint,
    );

    canvas.drawRect(
      scaledCrop,
      Paint()
        ..color = AppTheme.accentCyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _CropPreviewPainter old) =>
      old.cropRect != cropRect;
}

/// Résultats du pipeline superposés sur l'image — avec lignes de distance
/// étiquetées et noms de landmarks.
class _PipelineResultPainter extends CustomPainter {
  final ui.Image image;
  final ResultatPipelineOffline result;
  final Set<String> dimmedLines;
  final double? pxToMmRatio;
  final List<List<double>>? editedContours;

  _PipelineResultPainter({
    required this.image,
    required this.result,
    this.dimmedLines = const {},
    this.pxToMmRatio,
    this.editedContours,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Image
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, src, dst, Paint());

    final scaleX = size.width / image.width;
    final scaleY = size.height / image.height;
    Offset scalePoint(Offset p) => Offset(p.dx * scaleX, p.dy * scaleY);

    // 2. Contornos de segmentación (editados o originales)
    final contours = editedContours ?? result.contoursOriginal;
    if (contours != null && contours.isNotEmpty) {
      final path = Path();
      final points =
          contours.map((p) => scalePoint(Offset(p[0], p[1]))).toList();
      if (points.isNotEmpty) {
        path.moveTo(points.first.dx, points.first.dy);
        for (var i = 1; i < points.length; i++) {
          path.lineTo(points[i].dx, points[i].dy);
        }
        path.close();
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.red.withValues(alpha: 0.15)
            ..style = PaintingStyle.fill,
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.redAccent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );

        // Puntos de control editables (petits cercles)
        if (editedContours != null) {
          for (final pt in points) {
            canvas.drawCircle(
              pt,
              3.5,
              Paint()..color = Colors.orangeAccent.withValues(alpha: 0.9),
            );
            canvas.drawCircle(
              pt,
              3.5,
              Paint()
                ..color = Colors.white.withValues(alpha: 0.6)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 0.8,
            );
          }
        }
      }
    }

    // 3. Rectángulo de recorte
    final scaledCrop = Rect.fromLTRB(
      result.cropRect.left * scaleX,
      result.cropRect.top * scaleY,
      result.cropRect.right * scaleX,
      result.cropRect.bottom * scaleY,
    );
    canvas.drawRect(
      scaledCrop,
      Paint()
        ..color = AppTheme.accentCyan.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // 4. Landmarks
    if (result.keyPoints != null) {
      final paintLandmark =
          Paint()
            ..color = Colors.greenAccent.withValues(alpha: 0.7)
            ..style = PaintingStyle.fill;
      final paintLandmarkStroke =
          Paint()
            ..color = Colors.green
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1;

      for (final entry in result.keyPoints!.allPoints.entries) {
        if (entry.value != null) {
          final sp = scalePoint(entry.value!);
          canvas.drawCircle(sp, 4, paintLandmark);
          canvas.drawCircle(sp, 4, paintLandmarkStroke);
        }
      }

      // Contorno facial
      if (result.keyPoints!.faceContour.isNotEmpty) {
        final facePath = Path();
        final facePoints =
            result.keyPoints!.faceContour.map(scalePoint).toList();
        facePath.moveTo(facePoints.first.dx, facePoints.first.dy);
        for (var i = 1; i < facePoints.length; i++) {
          facePath.lineTo(facePoints[i].dx, facePoints[i].dy);
        }
        facePath.close();
        canvas.drawPath(
          facePath,
          Paint()
            ..color = Colors.green.withValues(alpha: 0.25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }

    // 5. Centro de la lesión (target)
    final centerDisplay = scalePoint(result.lesionCenter);
    canvas.drawCircle(
      centerDisplay,
      10,
      Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawCircle(
      centerDisplay,
      4,
      Paint()
        ..color = Colors.red.withValues(alpha: 0.8)
        ..style = PaintingStyle.fill,
    );

    // 6. Líneas de distancia CON etiquetas
    if (result.keyPoints != null && result.distancesPx.isNotEmpty) {
      final sorted =
          result.distancesPx.entries.toList()
            ..sort((a, b) => a.value.compareTo(b.value));

      final lineColors = [
        Colors.yellow,
        Colors.orange,
        Colors.amber,
        Colors.lime,
        Colors.cyanAccent,
        Colors.pinkAccent,
        Colors.lightGreenAccent,
        Colors.tealAccent,
      ];

      for (var i = 0; i < sorted.length; i++) {
        final entry = sorted[i];
        final point = result.keyPoints!.allPoints[entry.key];
        if (point == null) continue;

        final targetDisplay = scalePoint(point);
        final color = lineColors[i % lineColors.length];
        final isDimmed = dimmedLines.contains(entry.key);
        final lineAlpha = isDimmed ? 0.1 : 0.7;
        final labelAlpha = isDimmed ? 0.12 : 0.85;
        final textAlpha = isDimmed ? 0.25 : 1.0;

        // Format distance
        String distLabel;
        if (pxToMmRatio != null) {
          final cm = entry.value * pxToMmRatio! / 10.0;
          distLabel = '${cm.toStringAsFixed(1)} cm';
        } else {
          distLabel = '${entry.value.toStringAsFixed(0)} px';
        }

        // Línea
        canvas.drawLine(
          centerDisplay,
          targetDisplay,
          Paint()
            ..color = color.withValues(alpha: lineAlpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = isDimmed ? 0.8 : 1.5,
        );

        // Etiqueta con distancia en el punto medio
        final midPoint = Offset(
          (centerDisplay.dx + targetDisplay.dx) / 2,
          (centerDisplay.dy + targetDisplay.dy) / 2,
        );

        _drawLabel(
          canvas,
          distLabel,
          midPoint,
          color.withValues(alpha: labelAlpha),
          Colors.white.withValues(alpha: textAlpha),
          9,
        );

        // Nombre del landmark al lado del punto
        _drawLabel(
          canvas,
          entry.key,
          Offset(targetDisplay.dx + 6, targetDisplay.dy - 6),
          Colors.black.withValues(alpha: isDimmed ? 0.1 : 0.6),
          Colors.white.withValues(alpha: textAlpha),
          7,
          centered: false,
        );
      }
    }
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset position,
    Color bgColor,
    Color textColor,
    double fontSize, {
    bool centered = true,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final labelRect =
        centered
            ? Rect.fromCenter(
              center: position,
              width: textPainter.width + 8,
              height: textPainter.height + 4,
            )
            : Rect.fromLTWH(
              position.dx,
              position.dy,
              textPainter.width + 8,
              textPainter.height + 4,
            );

    final rrect = RRect.fromRectAndRadius(labelRect, const Radius.circular(3));
    canvas.drawRRect(rrect, Paint()..color = bgColor);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );

    textPainter.paint(canvas, Offset(labelRect.left + 4, labelRect.top + 2));
  }

  @override
  bool shouldRepaint(covariant _PipelineResultPainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.result != result ||
        oldDelegate.dimmedLines != dimmedLines ||
        oldDelegate.editedContours != editedContours;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Widget interactif pour l'image de résultats — tap pour masquer des lignes
// ═══════════════════════════════════════════════════════════════════════════════

class _InteractiveResultImage extends StatefulWidget {
  final ui.Image uiImage;
  final ResultatPipelineOffline result;
  final File? imageFile;

  const _InteractiveResultImage({
    required this.uiImage,
    required this.result,
    this.imageFile,
  });

  @override
  State<_InteractiveResultImage> createState() =>
      _InteractiveResultImageState();
}

class _InteractiveResultImageState extends State<_InteractiveResultImage> {
  final Set<String> _dimmedLines = {};
  bool _allDimmed = false;
  List<List<double>>? _editedContours;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.accentCyan.withValues(alpha: 0.3),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final ratio = widget.uiImage.width / widget.uiImage.height;
                final displayW = constraints.maxWidth;
                final displayH = displayW / ratio;
                return GestureDetector(
                  onTapUp: (details) => _onTap(details, displayW, displayH),
                  child: CustomPaint(
                    size: Size(displayW, displayH),
                    painter: _PipelineResultPainter(
                      image: widget.uiImage,
                      result: widget.result,
                      dimmedLines: _dimmedLines,
                      pxToMmRatio: widget.result.pxToMmRatio,
                      editedContours: _editedContours,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
        // ── Barre de contrôle ──────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.touch_app,
              size: 14,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 4),
            Text(
              'Tap ligne → masquer',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(width: 8),
            _miniButton(
              label: _allDimmed ? 'Tout afficher' : 'Tout masquer',
              onTap: _toggleAll,
            ),
            const SizedBox(width: 8),
            if (widget.result.contoursOriginal != null &&
                widget.result.contoursOriginal!.isNotEmpty &&
                widget.imageFile != null)
              _miniButton(
                label:
                    _editedContours != null
                        ? '✎ Re-éditer contour'
                        : '✎ Éditer contour',
                onTap: _openContourEditor,
                color: Colors.orangeAccent,
              ),
          ],
        ),
      ],
    );
  }

  Widget _miniButton({
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? AppTheme.accentCyan;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  // ── Distance lines toggle ──────────────────────────────────────────────

  void _toggleAll() {
    setState(() {
      if (_allDimmed) {
        _dimmedLines.clear();
      } else {
        _dimmedLines.addAll(widget.result.distancesPx.keys);
      }
      _allDimmed = !_allDimmed;
    });
  }

  void _onTap(TapUpDetails details, double displayW, double displayH) {
    final tapPos = details.localPosition;
    final r = widget.result;
    if (r.keyPoints == null || r.distancesPx.isEmpty) return;

    final scaleX = displayW / widget.uiImage.width;
    final scaleY = displayH / widget.uiImage.height;
    Offset scalePoint(Offset p) => Offset(p.dx * scaleX, p.dy * scaleY);

    final centerDisplay = scalePoint(r.lesionCenter);

    String? closestKey;
    double closestDist = double.infinity;

    for (final entry in r.distancesPx.entries) {
      final point = r.keyPoints!.allPoints[entry.key];
      if (point == null) continue;

      final targetDisplay = scalePoint(point);
      final dist = _distToSeg(tapPos, centerDisplay, targetDisplay);

      if (dist < closestDist) {
        closestDist = dist;
        closestKey = entry.key;
      }
    }

    if (closestKey != null && closestDist < 20.0) {
      setState(() {
        if (_dimmedLines.contains(closestKey)) {
          _dimmedLines.remove(closestKey);
        } else {
          _dimmedLines.add(closestKey!);
        }
        _allDimmed = _dimmedLines.length == r.distancesPx.length;
      });
    }
  }

  // ── Segmentation editor navigation ─────────────────────────────────────

  Future<void> _openContourEditor() async {
    final contours = _editedContours ?? widget.result.contoursOriginal;
    if (contours == null || contours.isEmpty || widget.imageFile == null)
      return;

    final result = await Navigator.push<List<List<double>>>(
      context,
      MaterialPageRoute(
        builder:
            (_) => PageEditeurSegmentation(
              fichierImage: widget.imageFile!,
              contoursInitiaux: contours,
              pxToMmRatio: widget.result.pxToMmRatio,
              cropRect: widget.result.cropRect,
            ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _editedContours = result;
      });
    }
  }

  // ── Utils ──────────────────────────────────────────────────────────────

  double _distToSeg(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final abLenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abLenSq == 0) return (p - a).distance;
    var t = (ap.dx * ab.dx + ap.dy * ab.dy) / abLenSq;
    t = t.clamp(0.0, 1.0);
    final proj = Offset(a.dx + t * ab.dx, a.dy + t * ab.dy);
    return (p - proj).distance;
  }
}
