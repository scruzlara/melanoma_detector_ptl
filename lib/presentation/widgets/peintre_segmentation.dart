import 'package:flutter/material.dart';

/// Peintre personnalisé pour afficher les contours de segmentation.
///
/// Dessine un polygone fermé (remplissage semi-transparent + trait)
/// sur l'image originale, en adaptant les coordonnées à la taille
/// réelle du widget via les facteurs d'échelle.
class PeintreSegmentation extends CustomPainter {
  /// Liste des points du contour en coordonnées image [x, y].
  final List<List<double>> contours;

  /// Couleur du contour et du remplissage.
  final Color couleur;

  /// Taille de l'image originale (pour calculer les facteurs d'échelle).
  final Size? tailleOriginale;

  PeintreSegmentation({
    required this.contours,
    this.couleur = Colors.red,
    this.tailleOriginale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (contours.isEmpty) return;

    // Facteurs d'échelle image → widget
    double sx = 1.0;
    double sy = 1.0;
    if (tailleOriginale != null) {
      sx = size.width / tailleOriginale!.width;
      sy = size.height / tailleOriginale!.height;
    }

    // Peinture du trait (épaisseur dynamique)
    final peintureContour =
        Paint()
          ..color = couleur
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 * ((sx + sy) / 2.0).clamp(0.5, 3.0);

    // Peinture du remplissage semi-transparent
    final peintureRemplissage =
        Paint()
          ..color = couleur.withValues(alpha: 0.25)
          ..style = PaintingStyle.fill;

    // Construction du chemin
    final chemin = Path();
    chemin.moveTo(contours[0][0] * sx, contours[0][1] * sy);
    for (int i = 1; i < contours.length; i++) {
      chemin.lineTo(contours[i][0] * sx, contours[i][1] * sy);
    }
    chemin.close();

    // Dessin : remplissage puis trait
    canvas.drawPath(chemin, peintureRemplissage);
    canvas.drawPath(chemin, peintureContour);
  }

  @override
  bool shouldRepaint(covariant PeintreSegmentation oldDelegate) {
    return oldDelegate.contours != contours ||
        oldDelegate.couleur != couleur ||
        oldDelegate.tailleOriginale != tailleOriginale;
  }
}
