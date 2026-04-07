import 'dart:io';
import 'dart:typed_data';

import 'dart:ui';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domaine/entites/entite_analyse_sauvegardee.dart';

import '../../services/facial_analysis_service.dart';
import '../../services/reconstruction_service.dart';

/// Service de génération de rapports PDF.
///
/// Couche données — produit un fichier PDF contenant :
/// - Page 1 : résultat, métriques, image originale, notes, avertissement
/// - Page 2 : image avec contours de segmentation (si disponible)
///
/// Gère gracieusement l'absence de fichier image.
class ServiceExportPdf {
  ServiceExportPdf._();

  /// Génère un rapport PDF et retourne le [File] résultant.
  static Future<File> generer(EntiteAnalyseSauvegardee analyse) async {
    final pdf = pw.Document(
      title: 'Rapport Analyse Mélanome',
      author: 'DermAI',
    );

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');
    final dateStr = dateFormat.format(analyse.horodatage);

    // Charger l'image si disponible
    pw.MemoryImage? image;
    try {
      final fichier = File(analyse.cheminImageOriginale);
      if (await fichier.exists()) {
        final octets = await fichier.readAsBytes();
        image = pw.MemoryImage(octets);
      }
    } catch (_) {
      // Image non disponible — on continue sans
    }

    // Déterminer le niveau de risque
    final probPct = (analyse.probMalignant * 100).toStringAsFixed(1);
    final confPct = (analyse.confiance * 100).toStringAsFixed(1);

    String niveauRisque;
    PdfColor couleurRisque;
    if (analyse.probMalignant < 0.30) {
      niveauRisque = 'Faible (Bénin)';
      couleurRisque = PdfColors.green;
    } else if (analyse.probMalignant < 0.60) {
      niveauRisque = 'Modéré (Suspect)';
      couleurRisque = PdfColors.orange;
    } else {
      niveauRisque = 'Élevé (Mélanome)';
      couleurRisque = PdfColors.red;
    }

    // Extraire métriques géométriques
    final aire = analyse.metriquesGeometriques['area_px'];
    final diametre = analyse.metriquesGeometriques['diam_px'];

    // Taille originale de l'image (pour mise à l'échelle des contours)
    final originalSize = analyse.resultJsonComplet['original_size'];
    final double? origW = (originalSize?['width'] as num?)?.toDouble();
    final double? origH = (originalSize?['height'] as num?)?.toDouble();

    // -------------------------------------------------------------------
    // Page 1 : Rapport principal
    // -------------------------------------------------------------------
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build:
            (context) => [
              // En-tête
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Rapport d\'Analyse de Lésion Cutanée',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),

              // Informations générales
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _construireLignePdf('Date', dateStr),
                    _construireLignePdf('Modèle IA', analyse.nomModele),
                    _construireLignePdf(
                      'Classification',
                      analyse.resultatClassification,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Text(
                          'Niveau de Risque : ',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: pw.BoxDecoration(
                            color: couleurRisque,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            niveauRisque,
                            style: const pw.TextStyle(color: PdfColors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Métriques
              pw.Header(level: 1, text: 'Métriques'),
              pw.Table.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
                data: [
                  ['Métrique', 'Valeur'],
                  ['Probabilité Malignité', '$probPct%'],
                  ['Confiance', '$confPct%'],
                  if (aire != null) ['Aire (px²)', '$aire'],
                  if (diametre != null)
                    [
                      'Diamètre équivalent (px)',
                      diametre is double
                          ? diametre.toStringAsFixed(1)
                          : '$diametre',
                    ],
                ],
              ),
              pw.SizedBox(height: 16),

              // Image originale
              if (image != null) ...[
                pw.Header(level: 1, text: 'Image Analysée'),
                pw.Center(
                  child: pw.Image(
                    image,
                    width: 300,
                    height: 300,
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ],

              // Notes de l'utilisateur
              if (analyse.notes != null && analyse.notes!.isNotEmpty) ...[
                pw.SizedBox(height: 16),
                pw.Header(level: 1, text: 'Notes'),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    border: pw.Border.all(color: PdfColors.blue200),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    analyse.notes!,
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ),
              ],

              // Avertissement
              pw.SizedBox(height: 24),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.amber50,
                  border: pw.Border.all(color: PdfColors.amber),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'AVERTISSEMENT : Ce rapport est généré par un outil d\'aide '
                  'à la décision. Il ne constitue pas un diagnostic médical. '
                  'Consultez un dermatologue qualifié pour tout avis médical.',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
            ],
      ),
    );

    // -------------------------------------------------------------------
    // Page 2 : Segmentation visuelle (image + contours)
    // -------------------------------------------------------------------
    final contours = analyse.contours;
    if (image != null &&
        contours != null &&
        contours.isNotEmpty &&
        origW != null &&
        origH != null &&
        origW > 0 &&
        origH > 0) {
      // Taille d'affichage dans le PDF
      const double displayW = 400;
      final double displayH = displayW * (origH / origW);

      final scaleX = displayW / origW;
      final scaleY = displayH / origH;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    'Analyse Visuelle - Segmentation',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  'Contours de segmentation détectés par le modèle U-Net.',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 16),

                // Image avec contours superposés
                pw.Center(
                  child: pw.SizedBox(
                    width: displayW,
                    height: displayH,
                    child: pw.Stack(
                      children: [
                        pw.Positioned.fill(
                          child: pw.Image(image!, fit: pw.BoxFit.contain),
                        ),
                        pw.Positioned.fill(
                          child: pw.CustomPaint(
                            size: PdfPoint(displayW, displayH),
                            painter: (PdfGraphics canvas, PdfPoint size) {
                              canvas
                                ..setStrokeColor(PdfColors.red)
                                ..setLineWidth(2);

                              if (contours.length > 1) {
                                final firstPt = contours.first;
                                canvas.moveTo(
                                  firstPt[0] * scaleX,
                                  displayH - firstPt[1] * scaleY,
                                );

                                for (int i = 1; i < contours.length; i++) {
                                  canvas.lineTo(
                                    contours[i][0] * scaleX,
                                    displayH - contours[i][1] * scaleY,
                                  );
                                }

                                // Fermer le contour
                                canvas.lineTo(
                                  firstPt[0] * scaleX,
                                  displayH - firstPt[1] * scaleY,
                                );
                                canvas.strokePath();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                pw.SizedBox(height: 16),
                pw.Text(
                  'La ligne rouge représente les limites de la lésion '
                  'détectées automatiquement. Les mesures géométriques '
                  '(aire, diamètre) sont calculées à partir de ces contours.',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    // Écrire le fichier
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fichier = File('${dir.path}/rapport_melanome_$timestamp.pdf');
    await fichier.writeAsBytes(await pdf.save());

    return fichier;
  }

  /// Génère un rapport PDF pour l'analyse faciale (reconstruction).
  static Future<File> genererRapportFacial({
    required FacialAnalysisResult result,
    required File imageFile,
    required Offset lesionPosition, // Coordonnées image
    String? patientName,
    Uint8List? lesionCropBytes,
    Rect? cropRect,
  }) async {
    final pdf = pw.Document(
      title: 'Rapport Analyse Faciale & Reconstruction',
      author: 'DermAI',
    );

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');
    final dateStr = dateFormat.format(DateTime.now());

    // Charger l'image
    pw.MemoryImage? image;
    try {
      if (await imageFile.exists()) {
        final octets = await imageFile.readAsBytes();
        image = pw.MemoryImage(octets);
      }
    } catch (_) {}

    // Charger police pour le texte (Low-level PdfFont pour le canvas)
    final font = PdfFont.helvetica(pdf.document);

    // Page 1 : Résumé et Image avec repères
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build:
            (context) => [
              // En-tête
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Rapport : Analyse Faciale & Reconstruction',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),

              // Info patient / date
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _construireLignePdf('Date', dateStr),
                    if (patientName != null)
                      _construireLignePdf('Patient', patientName),
                    _construireLignePdf(
                      'Zone Détectée',
                      result.region.displayName,
                    ),
                    if (result.diagnosis != null)
                      _construireLignePdf('Diagnostic IA', result.diagnosis!),
                    if (result.confidence != null)
                      _construireLignePdf(
                        'Confiance',
                        '${(result.confidence! * 100).toStringAsFixed(1)}%',
                      ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Image Faciale avec Repères
              if (image != null) ...[
                pw.Header(level: 1, text: 'Visualisation'),
                pw.Center(
                  child: pw.Container(
                    height: 400, // Increased height for better view
                    child: pw.FittedBox(
                      child: pw.Stack(
                        children: [
                          pw.Image(image),
                          // Dessin des repères et de la lésion
                          pw.Positioned.fill(
                            child: pw.CustomPaint(
                              painter: (PdfGraphics canvas, PdfPoint size) {
                                final double scaleX = size.x / image!.width!;
                                final double scaleY = size.y / image.height!;

                                final lx = lesionPosition.dx * scaleX;
                                final ly =
                                    size.y - (lesionPosition.dy * scaleY);

                                // 1. Dessiner la segmentation (contours)
                                if (result.contours != null &&
                                    result.contours!.isNotEmpty) {
                                  canvas.setColor(PdfColors.cyan);
                                  canvas.setLineWidth(2);

                                  final start = result.contours!.first;
                                  canvas.moveTo(
                                    start[0] * scaleX,
                                    size.y - (start[1] * scaleY),
                                  );
                                  for (
                                    int i = 1;
                                    i < result.contours!.length;
                                    i++
                                  ) {
                                    final p = result.contours![i];
                                    canvas.lineTo(
                                      p[0] * scaleX,
                                      size.y - (p[1] * scaleY),
                                    );
                                  }
                                  canvas.closePath();
                                  canvas.strokePath();
                                }

                                // 2. Dessiner les lignes de distance
                                canvas.setColor(PdfColors.blue);
                                canvas.setLineWidth(1);

                                for (var entry
                                    in result.keyPoints.allPoints.entries) {
                                  final p = entry.value;
                                  if (p != null) {
                                    final px = p.dx * scaleX;
                                    final py = size.y - (p.dy * scaleY);

                                    // Ligne
                                    canvas.drawLine(lx, ly, px, py);
                                    canvas.strokePath();

                                    // Label avec distance
                                    if (result.pxToMmRatio != null) {
                                      // Calculer distance en pixels originaux
                                      final distPx =
                                          (p - lesionPosition).distance;
                                      final distCm =
                                          distPx * result.pxToMmRatio! / 10.0;
                                      final text =
                                          '${distCm.toStringAsFixed(1)}';

                                      final midX = (lx + px) / 2;
                                      final midY = (ly + py) / 2;

                                      canvas.setFillColor(PdfColors.black);
                                      canvas.drawString(
                                        font,
                                        10,
                                        text,
                                        midX,
                                        midY,
                                      );
                                    }
                                  }
                                }

                                // 3. Dessiner les landmarks
                                canvas.setColor(PdfColors.green);
                                for (var p
                                    in result.keyPoints.allPoints.values) {
                                  if (p != null) {
                                    canvas.drawEllipse(
                                      p.dx * scaleX,
                                      size.y - (p.dy * scaleY),
                                      3,
                                      3,
                                    );
                                    canvas.fillPath();
                                  }
                                }

                                // 4. Dessiner la lésion (centre)
                                canvas.setColor(PdfColors.red);
                                canvas.drawEllipse(lx, ly, 4, 4);
                                canvas.fillPath();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              pw.SizedBox(height: 16),

              // Détail de la lésion (Zoom)
              if (lesionCropBytes != null && cropRect != null) ...[
                pw.Header(level: 1, text: 'Détail de la Lésion'),
                pw.Center(
                  child: pw.Container(
                    height: 200,
                    width: 200,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Stack(
                      children: [
                        pw.Image(pw.MemoryImage(lesionCropBytes)),
                        // Segmentation sur le crop
                        if (result.contours != null &&
                            result.contours!.isNotEmpty)
                          pw.Positioned.fill(
                            child: pw.CustomPaint(
                              painter: (PdfGraphics canvas, PdfPoint size) {
                                final double scaleX = size.x / cropRect.width;
                                final double scaleY = size.y / cropRect.height;

                                canvas.setColor(PdfColors.cyan);
                                canvas.setLineWidth(2);

                                final start = result.contours!.first;
                                canvas.moveTo(
                                  (start[0] - cropRect.left) * scaleX,
                                  size.y - ((start[1] - cropRect.top) * scaleY),
                                );

                                for (
                                  int i = 1;
                                  i < result.contours!.length;
                                  i++
                                ) {
                                  final p = result.contours![i];
                                  canvas.lineTo(
                                    (p[0] - cropRect.left) * scaleX,
                                    size.y - ((p[1] - cropRect.top) * scaleY),
                                  );
                                }
                                canvas.closePath();
                                canvas.strokePath();
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(height: 16),
              ],

              // Distances
              if (result.distancesPx.isNotEmpty) ...[
                pw.Header(level: 1, text: 'Mesures Géométriques'),
                pw.Table.fromTextArray(
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerLeft,
                  data: [
                    [
                      'Distance à',
                      result.pxToMmRatio != null
                          ? 'Valeur (cm)'
                          : 'Valeur (px)',
                    ],
                    ...result.distancesPx.entries.map((e) {
                      String val;
                      if (result.pxToMmRatio != null) {
                        final cm = e.value * result.pxToMmRatio! / 10.0;
                        val = '${cm.toStringAsFixed(1)} cm';
                      } else {
                        val = '${e.value.toStringAsFixed(0)} px';
                      }
                      return [e.key, val];
                    }),
                  ],
                ),
                pw.SizedBox(height: 16),
              ],

              // Options de Reconstruction
              if (result.reconstructionOptions.isNotEmpty) ...[
                pw.Header(level: 1, text: 'Options de Reconstruction'),
                ...result.reconstructionOptions.map((option) {
                  PdfColor color;
                  switch (option.complexity) {
                    case ReconstructionComplexity.simple:
                      color = PdfColors.green;
                      break;
                    case ReconstructionComplexity.moderate:
                      color = PdfColors.orange;
                      break;
                    case ReconstructionComplexity.complex:
                      color = PdfColors.red;
                      break;
                  }

                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 12),
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              option.name,
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            pw.Text(
                              option.complexity.displayName,
                              style: pw.TextStyle(
                                color: color,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          option.description,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        if (option.considerations.isNotEmpty) ...[
                          pw.SizedBox(height: 4),
                          pw.Bullet(
                            text:
                                'Points clés: ${option.considerations.join(", ")}',
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],

              // Avertissement
              pw.SizedBox(height: 24),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.amber50,
                  border: pw.Border.all(color: PdfColors.amber),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'AVERTISSEMENT : Ce rapport est une aide à la décision chirurgicale. '
                  'La stratégie de reconstruction finale dépend de facteurs cliniques non évalués ici '
                  '(laxité cutanée réelle, antécédents, etc.).',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
            ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fichier = File('${dir.path}/rapport_facial_$timestamp.pdf');
    await fichier.writeAsBytes(await pdf.save());

    return fichier;
  }

  /// Construit une ligne label-valeur pour le PDF.
  static pw.Widget _construireLignePdf(String label, String valeur) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.Text(
            '$label : ',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(valeur),
        ],
      ),
    );
  }
}
