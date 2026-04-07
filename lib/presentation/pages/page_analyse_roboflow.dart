import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/skin_analysis_result.dart';
import '../../services/roboflow_service.dart';
import '../../theme/app_theme.dart';
import 'page_analyse_faciale.dart';

/// Écran d'analyse Roboflow (Mode Online).
///
/// Reçoit une image, l'envoie à l'API Roboflow, et affiche les résultats
/// avec niveau de risque, barres de confiance, et recommandations.
class PageAnalyseRoboflow extends StatefulWidget {
  final Uint8List imageBytes;
  final String imagePath;

  const PageAnalyseRoboflow({
    super.key,
    required this.imageBytes,
    required this.imagePath,
  });

  @override
  State<PageAnalyseRoboflow> createState() => _PageAnalyseRoboflowState();
}

class _PageAnalyseRoboflowState extends State<PageAnalyseRoboflow> {
  final RoboflowService _roboflowService = RoboflowService();

  SkinAnalysisResult? _result;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _analyzeImage();
  }

  Future<void> _analyzeImage() async {
    try {
      final result = await _roboflowService.analyzeImageBytes(
        widget.imageBytes,
        widget.imagePath,
      );

      if (mounted) {
        setState(() {
          _result = result;
          _isLoading = false;
        });
      }
    } on RoboflowException catch (e) {
      if (mounted) {
        setState(() {
          _error = '${e.message}\n${e.details}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur inattendue: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Analyse IA'),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        child: SafeArea(
          child:
              _isLoading
                  ? _buildLoadingView()
                  : _error != null
                  ? _buildErrorView()
                  : _buildResultView(),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentCyan.withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.memory(widget.imageBytes, fit: BoxFit.cover),
              )
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(duration: 1500.ms)
              .animate()
              .scale(duration: 600.ms),

          const SizedBox(height: 40),

          const CircularProgressIndicator(color: AppTheme.accentCyan),

          const SizedBox(height: 24),

          Text(
            'Analyse en cours...',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: AppTheme.textPrimary),
          ).animate().fadeIn().slideY(begin: 0.3),

          const SizedBox(height: 8),

          Text(
            'L\'IA analyse votre image',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ).animate(delay: 200.ms).fadeIn(),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.riskHighConst.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 50,
                color: AppTheme.riskHighConst,
              ),
            ).animate().scale(),

            const SizedBox(height: 24),

            Text(
              'Erreur d\'analyse',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.riskHighConst,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              _error!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _analyzeImage();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultView() {
    if (_result == null) return const SizedBox();

    final riskColor = _getRiskColor(_result!.riskLevel);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildImageCard(),
          const SizedBox(height: 16),
          _buildFacialAnalysisButton(),
          const SizedBox(height: 24),
          _buildMainResultCard(riskColor),
          const SizedBox(height: 16),
          _buildConfidenceCard(),
          const SizedBox(height: 16),
          _buildRecommendationCard(riskColor),
          const SizedBox(height: 24),
          _buildDisclaimerCard(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFacialAnalysisButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentCyan.withValues(alpha: 0.2),
            AppTheme.accentCyan.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PageAnalyseFaciale(isOnline: true),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.accentCyan.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.face_retouching_natural,
                    color: AppTheme.accentCyan,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Analyse Faciale Complète',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppTheme.accentCyan),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mesures, distances et localisation',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: AppTheme.accentCyan,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 350.ms).slideX(begin: 0.1);
  }

  Widget _buildImageCard() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(widget.imageBytes, fit: BoxFit.cover),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.6),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _getRiskColor(_result!.riskLevel),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getRiskIcon(_result!.riskLevel),
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getRiskLabel(_result!.riskLevel),
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.3),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildMainResultCard(Color riskColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: riskColor.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: riskColor.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _getResultIcon(_result!.lesionClass),
                  color: riskColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Résultat de l\'analyse',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _result!.lesionName,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(color: riskColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            LesionClassInfo.getDescription(_result!.lesionClass),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2);
  }

  Widget _buildConfidenceCard() {
    final sortedDetections = List<Detection>.from(_result!.detections)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: GlassmorphismDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analyse détaillée',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 16),
          ...sortedDetections.map((detection) {
            final confidence = detection.confidence * 100;
            final isHighest = detection == sortedDetections.first;
            final color = _getClassColor(detection.className);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            LesionClassInfo.getName(detection.className),
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              fontWeight:
                                  isHighest
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                              color:
                                  isHighest
                                      ? Colors.white
                                      : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${confidence.toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              isHighest ? FontWeight.bold : FontWeight.normal,
                          color: isHighest ? color : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: detection.confidence,
                      minHeight: 6,
                      backgroundColor: AppTheme.primaryLight,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isHighest ? color : color.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2);
  }

  Color _getClassColor(String className) {
    switch (className.toUpperCase()) {
      case 'MEL':
      case 'MELANOMA':
      case 'MALIGNANT':
        return AppTheme.riskHighConst;
      case 'BCC':
        return Colors.orange;
      case 'AKIEC':
      case 'ACTINIC KERATOSIS':
        return Colors.orangeAccent;
      case 'NV':
      case 'BENIGN':
        return AppTheme.riskLowConst;
      case 'BKL':
      case 'BENIGN KERATOSIS':
        return AppTheme.accentCyan;
      case 'DF':
      case 'DERMATOFIBROMA':
        return Colors.teal;
      case 'VASC':
      case 'VASCULAR LESION':
        return Colors.purple;
      default:
        return AppTheme.textMuted;
    }
  }

  Widget _buildRecommendationCard(Color riskColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: riskColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: riskColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _result!.riskLevel == RiskLevel.high
                ? Icons.error
                : _result!.riskLevel == RiskLevel.medium
                ? Icons.warning
                : Icons.check_circle,
            color: riskColor,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recommandation',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: riskColor),
                ),
                const SizedBox(height: 8),
                Text(
                  LesionClassInfo.getRecommendation(_result!.lesionClass),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2);
  }

  Widget _buildDisclaimerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppTheme.textMuted, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Ce résultat est fourni à titre informatif uniquement et ne constitue pas un diagnostic médical. '
              'Consultez toujours un dermatologue pour une évaluation professionnelle.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textMuted,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 700.ms);
  }

  Color _getRiskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.high:
        return AppTheme.riskHighConst;
      case RiskLevel.medium:
        return AppTheme.riskMediumConst;
      case RiskLevel.low:
        return AppTheme.riskLowConst;
      default:
        return AppTheme.riskUnknown;
    }
  }

  IconData _getRiskIcon(RiskLevel level) {
    switch (level) {
      case RiskLevel.high:
        return Icons.warning;
      case RiskLevel.medium:
        return Icons.remove_circle_outline;
      case RiskLevel.low:
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  String _getRiskLabel(RiskLevel level) {
    switch (level) {
      case RiskLevel.high:
        return 'Risque élevé';
      case RiskLevel.medium:
        return 'Risque modéré';
      case RiskLevel.low:
        return 'Risque faible';
      default:
        return 'Risque inconnu';
    }
  }

  IconData _getResultIcon(String lesionClass) {
    switch (lesionClass.toUpperCase()) {
      case 'MEL':
      case 'BCC':
      case 'MELANOMA':
      case 'MALIGNANT':
        return Icons.warning_amber;
      case 'AKIEC':
      case 'ACTINIC KERATOSIS':
      case 'NON-MELANOMA':
        return Icons.remove_circle_outline;
      case 'NV':
      case 'BENIGN':
        return Icons.circle_outlined;
      default:
        return Icons.help_outline;
    }
  }
}
