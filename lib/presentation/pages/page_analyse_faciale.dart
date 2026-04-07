import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/facial_landmark.dart';
import '../../services/facial_analysis_service.dart';
import '../../services/reconstruction_service.dart';
import 'package:share_plus/share_plus.dart';

import '../../donnees/services/service_export_pdf.dart';
import '../../services/roboflow_service.dart';

class PageAnalyseFaciale extends StatefulWidget {
  final bool isOnline;
  const PageAnalyseFaciale({super.key, this.isOnline = false});

  @override
  State<PageAnalyseFaciale> createState() => _PageAnalyseFacialeState();
}

class _PageAnalyseFacialeState extends State<PageAnalyseFaciale> {
  final FacialAnalysisService _analysisService = FacialAnalysisService();
  final ImagePicker _picker = ImagePicker();

  File? _imageFile;
  ui.Image? _uiImage;
  FacialAnalysisResult? _result;
  bool _isAnalyzing = false;
  String? _errorMessage;
  Offset? _lesionPosition; // In display coordinates

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 640,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        final file = File(pickedFile.path);

        // Load ui.Image for painting
        final data = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(data);
        final frame = await codec.getNextFrame();

        setState(() {
          _imageFile = file;
          _uiImage = frame.image;
          _result = null;
          _lesionPosition = null;
          _errorMessage = null;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de la sélection de l\'image: $e';
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _analyze(Offset tapPosition, Size displaySize) async {
    if (_imageFile == null || _uiImage == null) return;

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _lesionPosition = tapPosition;
    });

    try {
      // Convert display tap position to actual image coordinates
      final double scaleX = _uiImage!.width / displaySize.width;
      final double scaleY = _uiImage!.height / displaySize.height;

      final imagePosition = Offset(
        tapPosition.dx * scaleX,
        tapPosition.dy * scaleY,
      );

      final bytes = await _imageFile!.readAsBytes();

      String? diagnosis;
      double? confidence;

      if (widget.isOnline) {
        try {
          final roboflowService = RoboflowService();
          final skinResult = await roboflowService.analyzeImageBytes(
            bytes,
            _imageFile!.path,
          );
          diagnosis = skinResult.lesionName;
          confidence = skinResult.confidence;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Erreur Roboflow: $e')));
          }
        }
      }

      final result = await _analysisService.analyze(
        imageBytes: bytes,
        width: _uiImage!.width,
        height: _uiImage!.height,
        lesionPosition: imagePosition,
        lesionSizeMm: 10.0,
        diagnosis: diagnosis,
        confidence: confidence,
        imagePath: _imageFile!.path,
      );

      setState(() {
        _result = result;
        if (result == null) {
          _errorMessage = "Aucun visage détecté.";
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de l\'analyse: $e';
      });
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _exporterPDF() async {
    if (_result == null || _imageFile == null || _lesionPosition == null)
      return;

    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Génération du rapport PDF...')),
      );

      final fichier = await ServiceExportPdf.genererRapportFacial(
        result: _result!,
        imageFile: _imageFile!,
        lesionPosition: _lesionPosition!,
        patientName: "Patient (Anonyme)",
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      await Share.shareXFiles([
        XFile(fichier.path),
      ], subject: 'Rapport Analyse Faciale - DermAI');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur export PDF: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyse Faciale & Reconstruction'),
        actions: [
          if (_result != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Exporter PDF',
              onPressed: _exporterPDF,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions
            if (_imageFile == null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.face_retouching_natural,
                        size: 48,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Instruction',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '1. Prenez une photo du visage.\n'
                        '2. Touchez l\'endroit exact de la lésion.\n'
                        '3. Obtenez une analyse et des suggestions de reconstruction.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Caméra'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galerie'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Image Display & Interaction
            if (_imageFile != null && _uiImage != null)
              LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate display size preserving aspect ratio
                  final double aspectRatio = _uiImage!.width / _uiImage!.height;
                  final double displayWidth = constraints.maxWidth;
                  final double displayHeight = displayWidth / aspectRatio;

                  return GestureDetector(
                    onTapUp:
                        (details) => _analyze(
                          details.localPosition,
                          Size(displayWidth, displayHeight),
                        ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: Size(displayWidth, displayHeight),
                          painter: ImagePainter(
                            image: _uiImage!,
                            result: _result,
                            lesionPosition: _lesionPosition,
                          ),
                        ),
                        if (_isAnalyzing)
                          Container(
                            width: displayWidth,
                            height: displayHeight,
                            color: Colors.black45,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),

            // Error Message
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),

            // Results
            if (_result != null) ...[
              const SizedBox(height: 24),
              _buildResultsSection(_result!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSection(FacialAnalysisResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.diagnosis != null) ...[
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: ListTile(
              leading: const Icon(Icons.analytics, size: 32),
              title: Text(
                result.diagnosis!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Confiance IA: ${(result.confidence! * 100).toStringAsFixed(1)}%',
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            const Icon(Icons.location_on, color: Colors.red),
            const SizedBox(width: 8),
            Text(
              'Zone détectée : ${result.region.displayName}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        if (result.region != FacialRegion.unknown)
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 4, bottom: 16),
            child: Text(
              result.region.surgicalConsiderations,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ),

        if (result.distancesPx.isNotEmpty) ...[
          const Divider(),
          const Text(
            'Distances aux points clés',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children:
                result.distancesPx.entries
                    .take(4)
                    .map(
                      (e) => Chip(
                        label: Text(
                          '${e.key}: ${e.value.toStringAsFixed(0)} px',
                        ),
                        backgroundColor:
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      ),
                    )
                    .toList(),
          ),
        ],

        const Divider(height: 32),
        const Text(
          'Options de Reconstruction',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 16),

        if (result.reconstructionOptions.isEmpty)
          const Text(
            'Aucune option spécifique trouvée pour cette configuration.',
          )
        else
          ...result.reconstructionOptions.map(
            (option) => _buildOptionCard(option),
          ),
      ],
    );
  }

  Widget _buildOptionCard(ReconstructionOption option) {
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: complexityColor.withValues(alpha: 0.1),
          child: Icon(Icons.medical_services, color: complexityColor, size: 20),
        ),
        title: Text(
          option.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${option.complexity.displayName} • Succès ~${option.successRate.toInt()}%',
          style: TextStyle(color: complexityColor, fontWeight: FontWeight.w500),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(option.description),
                const SizedBox(height: 12),
                if (option.considerations.isNotEmpty) ...[
                  const Text(
                    'Points clés :',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...option.considerations.map((c) => Text('• $c')),
                ],
                if (option.contraindications.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Contre-indications :',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  ...option.contraindications.map(
                    (c) =>
                        Text('• $c', style: const TextStyle(color: Colors.red)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ImagePainter extends CustomPainter {
  final ui.Image image;
  final FacialAnalysisResult? result;
  final Offset? lesionPosition;

  ImagePainter({required this.image, this.result, this.lesionPosition});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw image fitted to size
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, src, dst, Paint());

    // Scale factors
    final scaleX = size.width / image.width;
    final scaleY = size.height / image.height;

    // Helper to scale points from image coordinates to display coordinates
    Offset scalePoint(Offset p) => Offset(p.dx * scaleX, p.dy * scaleY);

    // 2. Draw landmarks if available
    if (result != null) {
      final paintLandmark =
          Paint()
            ..color = Colors.green.withValues(alpha: 0.5)
            ..style = PaintingStyle.fill;

      for (var p in result!.keyPoints.allPoints.values) {
        if (p != null) {
          canvas.drawCircle(scalePoint(p), 3, paintLandmark);
        }
      }

      // Draw Face Contour
      if (result!.keyPoints.faceContour.isNotEmpty) {
        final paintContour =
            Paint()
              ..color = Colors.green.withValues(alpha: 0.3)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5;

        final path = Path();
        final points = result!.keyPoints.faceContour.map(scalePoint).toList();
        if (points.isNotEmpty) {
          path.moveTo(points.first.dx, points.first.dy);
          for (var i = 1; i < points.length; i++) {
            path.lineTo(points[i].dx, points[i].dy);
          }
          path.close();
          canvas.drawPath(path, paintContour);
        }
      }
    }

    // 3. Draw Lesion Point (User Tap)
    if (lesionPosition != null) {
      final paintLesion =
          Paint()
            ..color = Colors.red
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0;

      final paintCenter =
          Paint()
            ..color = Colors.red.withValues(alpha: 0.5)
            ..style = PaintingStyle.fill;

      // lesionPosition is already in display coordinates
      canvas.drawCircle(lesionPosition!, 15, paintLesion);
      canvas.drawCircle(lesionPosition!, 3, paintCenter);
    }
  }

  @override
  bool shouldRepaint(covariant ImagePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.result != result ||
        oldDelegate.lesionPosition != lesionPosition;
  }
}
