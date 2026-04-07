import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Page d'édition interactive des contours de segmentation.
///
/// Affiche une vue zoomée autour de la lésion avec des points de contrôle
/// déplaçables et un slider pour ajuster le nombre de points.
/// Les métriques (aire, diamètre) sont recalculées en temps réel.
class PageEditeurSegmentation extends StatefulWidget {
  /// Fichier image originel.
  final File fichierImage;

  /// Contours initiaux (liste de points [x, y] en coordonnées image).
  final List<List<double>> contoursInitiaux;

  /// Ratio px → mm (null si non calibré).
  final double? pxToMmRatio;

  /// Rectangle de recadrage dans l'image originale (pour centrer la vue).
  final Rect? cropRect;

  const PageEditeurSegmentation({
    super.key,
    required this.fichierImage,
    required this.contoursInitiaux,
    this.pxToMmRatio,
    this.cropRect,
  });

  @override
  State<PageEditeurSegmentation> createState() =>
      _PageEditeurSegmentationState();
}

class _PageEditeurSegmentationState extends State<PageEditeurSegmentation> {
  ui.Image? _image;
  bool _imageChargee = false;

  /// Points du contour (en coordonnées image).
  late List<Offset> _points;

  /// Points originaux pour le rééchantillonnage.
  late List<Offset> _pointsOriginaux;

  /// Index du point en cours de déplacement.
  int? _indexPointDeplace;

  /// Aire du contour en pixels².
  double _airePx = 0;

  /// Diamètre équivalent en pixels.
  double _diametrePx = 0;

  /// Nombre de points actuel.
  late int _nombrePoints;

  static const int _minPoints = 8;
  static const int _maxPoints = 200;

  final TransformationController _transformController =
      TransformationController();

  // Gestion des gestes : si on touche un point, on désactive le pan/zoom
  bool _canPan = true;

  @override
  void initState() {
    super.initState();
    _chargerImage();
    _pointsOriginaux =
        widget.contoursInitiaux.map((e) => Offset(e[0], e[1])).toList();
    _nombrePoints = _pointsOriginaux.length.clamp(_minPoints, _maxPoints);
    _reechantillonnerContour(_nombrePoints);
  }

  @override
  void dispose() {
    _image?.dispose();
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _chargerImage() async {
    final donnees = await widget.fichierImage.readAsBytes();
    final codec = await ui.instantiateImageCodec(donnees);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() {
        _image = frame.image;
        _imageChargee = true;
      });
      // Centrer la vue sur la lésion
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _centrerSurLesion();
      });
    }
  }

  void _centrerSurLesion() {
    if (_image == null || _points.isEmpty) return;

    // Calculer le bounding box du contour
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final p in _points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }

    final contourW = maxX - minX;
    final contourH = maxY - minY;
    if (contourW <= 0 || contourH <= 0) return;

    final context = this.context;
    final screenSize = MediaQuery.of(context).size;
    final appBarH = kToolbarHeight + MediaQuery.of(context).padding.top;
    final bottomH = 180.0; // Panneau métriques approx
    final availableW = screenSize.width;
    final availableH = screenSize.height - appBarH - bottomH;

    // Marges autour de la lésion (20% de l'écran)
    final marginW = availableW * 0.2;
    final marginH = availableH * 0.2;
    final targetW = availableW - marginW;
    final targetH = availableH - marginH;

    // Zoom nécessaire pour faire entrer la lésion dans la zone cible
    final scaleX = targetW / contourW;
    final scaleY = targetH / contourH;
    final scale = min(scaleX, scaleY).clamp(0.5, 5.0).toDouble();

    // Centre de la lésion dans l'image
    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2;

    // Translation pour amener le centre de la lésion au centre de l'écran
    // T = (ScreenCenter) - (ImageCenter * Scale)
    final tx = (availableW / 2) - (cx * scale);
    final ty = (availableH / 2) - (cy * scale);

    _transformController.value =
        Matrix4.identity()
          ..translate(tx, ty)
          ..scale(scale);
  }

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
    _airePx = aire;
    _diametrePx = 2 * sqrt(aire / pi);
  }

  void _reechantillonnerContour(int nombreCible) {
    if (_pointsOriginaux.length < 2) return;

    final n = _pointsOriginaux.length;
    final distances = <double>[0.0];
    for (int i = 1; i <= n; i++) {
      final p1 = _pointsOriginaux[i - 1];
      final p2 = _pointsOriginaux[i % n];
      distances.add(distances.last + (p2 - p1).distance);
    }
    final perimetre = distances.last;
    if (perimetre <= 0) return;

    final nouveauxPoints = <Offset>[];
    final pas = perimetre / nombreCible;
    int indexSegment = 0;

    for (int i = 0; i < nombreCible; i++) {
      final distanceCible = i * pas;
      while (indexSegment < n - 1 &&
          distances[indexSegment + 1] < distanceCible) {
        indexSegment++;
      }
      final d1 = distances[indexSegment];
      final d2 = distances[indexSegment + 1];
      final longueur = d2 - d1;
      final t = longueur > 0 ? (distanceCible - d1) / longueur : 0.0;
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

  void _onPointerDown(PointerDownEvent details) {
    if (!_imageChargee || _image == null) return;

    // Le Listener est un enfant de InteractiveViewer, donc details.localPosition
    // est DÉJÀ dans le référentiel de l'image (transformé par Flutter).
    final posImage = details.localPosition;

    final matrix = _transformController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final rayonTactile = 30.0 / scale;

    int? indexProche;
    double distMin = double.infinity;

    for (int i = 0; i < _points.length; i++) {
      final dist = (posImage - _points[i]).distance;
      if (dist < distMin && dist < rayonTactile) {
        distMin = dist;
        indexProche = i;
      }
    }

    setState(() {
      _indexPointDeplace = indexProche;
      _canPan = indexProche == null;
    });
  }

  void _onPointerUp(PointerUpEvent details) {
    setState(() {
      _indexPointDeplace = null;
      _canPan = true;
    });
  }

  void _gererMiseAJourGlissement(DragUpdateDetails details) {
    if (_indexPointDeplace == null) return;

    // Idem ici : localPosition est dans le référentiel de l'image
    final posImage = details.localPosition;

    setState(() {
      _points[_indexPointDeplace!] = Offset(
        posImage.dx.clamp(0, _image!.width.toDouble()),
        posImage.dy.clamp(0, _image!.height.toDouble()),
      );
      _recalculerMetriques();
    });
  }

  void _gererFinGlissement(DragEndDetails details) {
    setState(() {
      _indexPointDeplace = null;
      _canPan = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : Colors.grey[100],
      appBar: AppBar(
        title: const Text('Éditeur de Segmentation'),
        backgroundColor: isDark ? const Color(0xFF161B22) : null,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.check, color: Colors.greenAccent),
            label: const Text(
              'Valider',
              style: TextStyle(color: Colors.greenAccent),
            ),
            onPressed: () {
              final resultat = _points.map((p) => [p.dx, p.dy]).toList();
              Navigator.pop(context, resultat);
            },
          ),
        ],
      ),
      body:
          !_imageChargee
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // ── Zone d'édition (zoomable) ──────────────────────────
                  Expanded(
                    child: LayoutBuilder(
                      builder: (ctx, contraintes) {
                        return InteractiveViewer(
                          transformationController: _transformController,
                          minScale: 0.1,
                          maxScale: 10.0,
                          boundaryMargin: const EdgeInsets.all(double.infinity),
                          constrained: false,
                          panEnabled: _canPan,
                          scaleEnabled: _canPan,
                          child: Listener(
                            onPointerDown: _onPointerDown,
                            onPointerUp: _onPointerUp,
                            child: GestureDetector(
                              onPanUpdate: _gererMiseAJourGlissement,
                              onPanEnd: _gererFinGlissement,
                              child: CustomPaint(
                                size: Size(
                                  _image!.width.toDouble(),
                                  _image!.height.toDouble(),
                                ),
                                painter: _PeintreEditeurSegmentation(
                                  image: _image!,
                                  points: _points,
                                  indexActif: _indexPointDeplace,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // ── Panneau de métriques ────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    decoration: BoxDecoration(
                      gradient:
                          isDark
                              ? AppTheme.cardGradient
                              : AppTheme.lightCardGradient,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      border: Border(
                        top: BorderSide(
                          color: AppTheme.accentCyan.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Métriques
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _metrique(
                              'Aire',
                              '${_airePx.toStringAsFixed(0)} px²',
                              isDark,
                            ),
                            _metrique(
                              'Diam.',
                              widget.pxToMmRatio != null
                                  ? '${(_diametrePx * widget.pxToMmRatio! / 10).toStringAsFixed(2)} cm'
                                  : '${_diametrePx.toStringAsFixed(1)} px',
                              isDark,
                            ),
                            _metrique('Points', '$_nombrePoints', isDark),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Slider
                        Row(
                          children: [
                            Icon(
                              Icons.remove,
                              size: 16,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                            Expanded(
                              child: Slider(
                                value: _nombrePoints.toDouble(),
                                min: _minPoints.toDouble(),
                                max: _maxPoints.toDouble(),
                                divisions: _maxPoints - _minPoints,
                                activeColor: AppTheme.accentCyan,
                                label: '$_nombrePoints pts',
                                onChanged: (val) {
                                  _reechantillonnerContour(val.round());
                                },
                              ),
                            ),
                            Icon(
                              Icons.add,
                              size: 16,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ],
                        ),

                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: _centrerSurLesion,
                              icon: const Icon(
                                Icons.center_focus_strong,
                                size: 14,
                              ),
                              label: const Text(
                                'Recentrer',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () {
                                _reechantillonnerContour(
                                  _pointsOriginaux.length.clamp(
                                    _minPoints,
                                    _maxPoints,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.refresh, size: 14),
                              label: const Text(
                                'Réinitialiser',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _metrique(String label, String value, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppTheme.accentCyan,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ],
    );
  }
}

/// Peintre pour l'éditeur de segmentation.
class _PeintreEditeurSegmentation extends CustomPainter {
  final ui.Image image;
  final List<Offset> points;
  final int? indexActif;

  _PeintreEditeurSegmentation({
    required this.image,
    required this.points,
    this.indexActif,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Dessiner l'image en (0,0) avec sa taille réelle
    canvas.drawImage(image, Offset.zero, Paint());

    if (points.isEmpty) return;

    // Les points sont déjà en coordonnées image
    final chemin = Path()..addPolygon(points, true);

    // Remplissage
    canvas.drawPath(
      chemin,
      Paint()
        ..color = Colors.redAccent.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill,
    );

    // Trait du contour
    canvas.drawPath(
      chemin,
      Paint()
        ..color = Colors.redAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Points de contrôle
    // Note : on garde une taille fixe en pixels écran, donc on divise par le scale si on voulait.
    // Mais ici le canvas est transformé avec l'image.
    // Pour avoir des points de taille constante à l'écran, il faudrait inverser le scale.
    // Pour l'instant, on laisse simple : les points grossissent avec le zoom,
    // ce qui est peut-être voulu pour les attraper.
    // Si on veut une taille constante, on passerait le scale au painter.

    // On réduit encore un peu la base puisque ça va être zoomé
    const radiusActive = 3.0; // était 4.5
    const radiusNormal = 2.0; // était 3.0

    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final isActive = i == indexActif;
      final radius = isActive ? radiusActive : radiusNormal;

      canvas.drawCircle(
        p,
        radius,
        Paint()
          ..color =
              isActive
                  ? Colors.orangeAccent
                  : Colors.yellowAccent.withValues(alpha: 0.85)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        p,
        radius,
        Paint()
          ..color = Colors.black54
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
