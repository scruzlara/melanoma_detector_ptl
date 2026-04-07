import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Page d'édition interactive des contours de segmentation.
///
/// Permet à l'utilisateur de déplacer les points du contour
/// sur l'image pour affiner la segmentation. Les métriques
/// (aire, diamètre) sont recalculées en temps réel.
/// Le nombre de points est ajustable via un slider.
class PageEditeurContours extends StatefulWidget {
  /// Fichier image sur lequel dessiner les contours.
  final File fichierImage;

  /// Contours initiaux (liste de points [x, y] en coordonnées image).
  final List<List<double>> contoursInitiaux;

  /// Facteur de conversion mm/pixel (0.0 si non calibré).
  final double mmParPixel;

  const PageEditeurContours({
    super.key,
    required this.fichierImage,
    required this.contoursInitiaux,
    this.mmParPixel = 0.0,
  });

  @override
  State<PageEditeurContours> createState() => _PageEditeurContoursState();
}

class _PageEditeurContoursState extends State<PageEditeurContours> {
  /// Image décodée pour le rendu.
  ui.Image? _image;

  /// Indique si l'image a été chargée.
  bool _imageChargee = false;

  /// Points du contour (en coordonnées image).
  late List<Offset> _points;

  /// Points originaux (non rééchantillonnés) — pour le rééchantillonnage.
  late List<Offset> _pointsOriginaux;

  /// Index du point en cours de déplacement.
  int? _indexPointDeplace;

  /// Aire du contour en pixels².
  double _airePx = 0;

  /// Diamètre équivalent en pixels.
  double _diametrePx = 0;

  /// Nombre de points actuel.
  late int _nombrePoints;

  /// Nombre de points minimum.
  static const int _minPoints = 8;

  /// Nombre de points maximum.
  static const int _maxPoints = 200;

  @override
  void initState() {
    super.initState();
    _chargerImage();
    _pointsOriginaux =
        widget.contoursInitiaux.map((e) => Offset(e[0], e[1])).toList();
    _points = List.from(_pointsOriginaux);
    _nombrePoints = _points.length.clamp(_minPoints, _maxPoints);
    _recalculerMetriques();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  /// Charge l'image en mémoire pour le rendu personnalisé.
  Future<void> _chargerImage() async {
    final donnees = await widget.fichierImage.readAsBytes();
    final codec = await ui.instantiateImageCodec(donnees);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() {
        _image = frame.image;
        _imageChargee = true;
      });
    }
  }

  /// Recalcule l'aire et le diamètre à partir des points actuels.
  ///
  /// Utilise la formule du lacet (Shoelace) pour l'aire,
  /// puis le diamètre d'un cercle de même aire.
  void _recalculerMetriques() {
    if (_points.isEmpty) {
      _airePx = 0;
      _diametrePx = 0;
      return;
    }

    double aire = 0.0;
    for (int i = 0; i < _points.length; i++) {
      final p1 = _points[i];
      final p2 = _points[(i + 1) % _points.length];
      aire += p1.dx * p2.dy;
      aire -= p1.dy * p2.dx;
    }
    aire = aire.abs() / 2.0;
    final diametre = 2 * sqrt(aire / pi);

    setState(() {
      _airePx = aire;
      _diametrePx = diametre;
    });
  }

  /// Rééchantillonne les contours originaux au nombre de points donné.
  ///
  /// Interpole linéairement le long du périmètre du polygone pour
  /// distribuer les points de manière uniforme.
  void _reechantillonnerContour(int nombreCible) {
    if (_pointsOriginaux.length < 2) return;

    // Calculer les distances cumulées le long du contour
    final n = _pointsOriginaux.length;
    final distances = <double>[0.0];
    for (int i = 1; i <= n; i++) {
      final p1 = _pointsOriginaux[i - 1];
      final p2 = _pointsOriginaux[i % n];
      distances.add(distances.last + (p2 - p1).distance);
    }
    final perimetre = distances.last;

    if (perimetre <= 0) return;

    // Interpoler les nouveaux points uniformément
    final nouveauxPoints = <Offset>[];
    final pas = perimetre / nombreCible;

    int indexSegment = 0;
    for (int i = 0; i < nombreCible; i++) {
      final distanceCible = i * pas;

      // Avancer jusqu'au bon segment
      while (indexSegment < n - 1 &&
          distances[indexSegment + 1] < distanceCible) {
        indexSegment++;
      }

      // Interpoler entre les deux points du segment
      final d1 = distances[indexSegment];
      final d2 = distances[indexSegment + 1];
      final longueurSegment = d2 - d1;
      final t =
          longueurSegment > 0 ? (distanceCible - d1) / longueurSegment : 0.0;

      final p1 = _pointsOriginaux[indexSegment];
      final p2 = _pointsOriginaux[(indexSegment + 1) % n];
      nouveauxPoints.add(Offset.lerp(p1, p2, t)!);
    }

    setState(() {
      _points = nouveauxPoints;
      _nombrePoints = nombreCible;
      _recalculerMetriques();
    });
  }

  /// Gère le début du glissement : trouve le point le plus proche.
  void _gererDebutGlissement(
    DragStartDetails details,
    Size tailleAffichee,
    Rect rectImage,
  ) {
    if (!_imageChargee || _image == null) return;

    final posImage = _localVersImage(
      details.localPosition,
      tailleAffichee,
      rectImage,
    );
    final echelle = rectImage.width / _image!.width;
    final rayonTactile = 25.0 / echelle;

    double distMin = double.infinity;
    int? indexProche;

    for (int i = 0; i < _points.length; i++) {
      final dist = (posImage - _points[i]).distance;
      if (dist < distMin && dist < rayonTactile) {
        distMin = dist;
        indexProche = i;
      }
    }

    setState(() => _indexPointDeplace = indexProche);
  }

  /// Met à jour la position du point pendant le glissement.
  void _gererMiseAJourGlissement(
    DragUpdateDetails details,
    Size tailleAffichee,
    Rect rectImage,
  ) {
    if (_indexPointDeplace == null) return;

    final posImage = _localVersImage(
      details.localPosition,
      tailleAffichee,
      rectImage,
    );
    setState(() {
      _points[_indexPointDeplace!] = posImage;
      _recalculerMetriques();
    });
  }

  /// Termine le glissement.
  void _gererFinGlissement(DragEndDetails details) {
    setState(() => _indexPointDeplace = null);
  }

  /// Convertit les coordonnées tactiles en coordonnées image.
  Offset _localVersImage(Offset local, Size tailleAffichee, Rect rectImage) {
    final dx = (local.dx - rectImage.left) / rectImage.width * _image!.width;
    final dy = (local.dy - rectImage.top) / rectImage.height * _image!.height;
    return Offset(dx, dy);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Éditeur de Segmentation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Valider les modifications',
            onPressed: () {
              final resultat = _points.map((p) => [p.dx, p.dy]).toList();
              Navigator.pop(context, resultat);
            },
          ),
        ],
      ),
      backgroundColor: theme.colorScheme.surface,
      body:
          !_imageChargee
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                builder: (ctx, contraintes) {
                  final tailleAffichee = Size(
                    contraintes.maxWidth,
                    contraintes.maxHeight,
                  );
                  final src = Size(
                    _image!.width.toDouble(),
                    _image!.height.toDouble(),
                  );
                  final taillesAjustees = applyBoxFit(
                    BoxFit.contain,
                    src,
                    tailleAffichee,
                  );
                  final tailleDest = taillesAjustees.destination;
                  final dx = (tailleAffichee.width - tailleDest.width) / 2;
                  final dy = (tailleAffichee.height - tailleDest.height) / 2;
                  final rectImage = Rect.fromLTWH(
                    dx,
                    dy,
                    tailleDest.width,
                    tailleDest.height,
                  );

                  return Stack(
                    children: [
                      // Zone interactive
                      GestureDetector(
                        onPanStart:
                            (d) => _gererDebutGlissement(
                              d,
                              tailleAffichee,
                              rectImage,
                            ),
                        onPanUpdate:
                            (d) => _gererMiseAJourGlissement(
                              d,
                              tailleAffichee,
                              rectImage,
                            ),
                        onPanEnd: _gererFinGlissement,
                        child: CustomPaint(
                          size: tailleAffichee,
                          painter: _PeintreEditeur(
                            image: _image!,
                            points: _points,
                            rectImage: rectImage,
                          ),
                        ),
                      ),

                      // Carte de métriques et contrôle de points
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: Card(
                          color: theme.colorScheme.surfaceContainerHigh,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _construireLigneMetrique(
                                  'Aire (px)',
                                  _airePx.toStringAsFixed(0),
                                ),
                                const SizedBox(height: 8),
                                _construireLigneMetrique(
                                  'Diamètre (px)',
                                  _diametrePx.toStringAsFixed(1),
                                ),
                                if (widget.mmParPixel > 0) ...[
                                  Divider(
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                  _construireLigneMetrique(
                                    'Diamètre (mm)',
                                    (_diametrePx * widget.mmParPixel)
                                        .toStringAsFixed(2),
                                  ),
                                ],
                                Divider(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                                // Contrôle du nombre de points
                                Row(
                                  children: [
                                    Text(
                                      'Points',
                                      style: TextStyle(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    Expanded(
                                      child: Slider(
                                        value: _nombrePoints.toDouble(),
                                        min: _minPoints.toDouble(),
                                        max: _maxPoints.toDouble(),
                                        divisions: _maxPoints - _minPoints,
                                        label: _nombrePoints.toString(),
                                        onChanged: (val) {
                                          _reechantillonnerContour(val.round());
                                        },
                                      ),
                                    ),
                                    SizedBox(
                                      width: 36,
                                      child: Text(
                                        '$_nombrePoints',
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.end,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
    );
  }

  /// Construit une ligne de métrique (label + valeur).
  Widget _construireLigneMetrique(String libelle, String valeur) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          libelle,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        Text(
          valeur,
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

/// Peintre personnalisé pour l'éditeur de contours.
///
/// Dessine l'image, le polygone de contour et les points de contrôle.
class _PeintreEditeur extends CustomPainter {
  final ui.Image image;
  final List<Offset> points;
  final Rect rectImage;

  _PeintreEditeur({
    required this.image,
    required this.points,
    required this.rectImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dessiner l'image
    paintImage(
      canvas: canvas,
      rect: rectImage,
      image: image,
      fit: BoxFit.contain,
    );

    // 2. Dessiner le polygone
    if (points.isNotEmpty) {
      final echelleX = rectImage.width / image.width;
      final echelleY = rectImage.height / image.height;

      final pointsEcran =
          points.map((p) {
            return Offset(
              rectImage.left + p.dx * echelleX,
              rectImage.top + p.dy * echelleY,
            );
          }).toList();

      // Trait du contour
      final peintureChemin =
          Paint()
            ..color = Colors.blueAccent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0;

      final chemin = Path()..addPolygon(pointsEcran, true);
      canvas.drawPath(chemin, peintureChemin);

      // Remplissage semi-transparent
      final peintureRemplissage =
          Paint()
            ..color = Colors.blueAccent.withValues(alpha: 0.1)
            ..style = PaintingStyle.fill;
      canvas.drawPath(chemin, peintureRemplissage);

      // 3. Dessiner les points de contrôle
      final peinturePoint =
          Paint()
            ..color = Colors.yellowAccent
            ..style = PaintingStyle.fill;

      final peintureBordPoint =
          Paint()
            ..color = Colors.black54
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;

      for (var p in pointsEcran) {
        canvas.drawCircle(p, 5.0, peinturePoint);
        canvas.drawCircle(p, 5.0, peintureBordPoint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
