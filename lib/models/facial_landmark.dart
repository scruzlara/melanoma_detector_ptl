import 'dart:ui';

/// Représente un point de landmark facial avec ses coordonnées 3D
class FacialLandmark {
  final int index;
  final double x;
  final double y;
  final double z;

  const FacialLandmark({
    required this.index,
    required this.x,
    required this.y,
    this.z = 0.0,
  });

  Offset get offset => Offset(x, y);

  Map<String, dynamic> toJson() => {'index': index, 'x': x, 'y': y, 'z': z};

  factory FacialLandmark.fromJson(Map<String, dynamic> json) {
    return FacialLandmark(
      index: json['index'] as int,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      z: (json['z'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Points clés du visage pour le calcul des distances
class FacialKeyPoints {
  final Offset? leftEye;
  final Offset? rightEye;
  final Offset? noseTip;
  final Offset? noseBase;
  final Offset? leftMouth;
  final Offset? rightMouth;
  final Offset? mouthCenter;
  final Offset? leftCheek;
  final Offset? rightCheek;
  final Offset? chin;
  final Offset? forehead;
  final List<Offset> faceContour;

  const FacialKeyPoints({
    this.leftEye,
    this.rightEye,
    this.noseTip,
    this.noseBase,
    this.leftMouth,
    this.rightMouth,
    this.mouthCenter,
    this.leftCheek,
    this.rightCheek,
    this.chin,
    this.forehead,
    this.faceContour = const [],
  });

  /// Calcule le centre du visage
  Offset? get faceCenter {
    if (leftEye == null || rightEye == null || chin == null) return null;
    return Offset(
      (leftEye!.dx + rightEye!.dx) / 2,
      (leftEye!.dy + rightEye!.dy + chin!.dy) / 3,
    );
  }

  /// Calcule la distance entre deux points en pixels
  static double distanceBetween(Offset a, Offset b) {
    return (a - b).distance;
  }

  /// Retourne tous les points clés avec leurs noms
  Map<String, Offset?> get allPoints => {
    'Œil gauche': leftEye,
    'Œil droit': rightEye,
    'Nez': noseTip,
    'Base du nez': noseBase,
    'Bouche (gauche)': leftMouth,
    'Bouche (droite)': rightMouth,
    'Centre bouche': mouthCenter,
    'Joue gauche': leftCheek,
    'Joue droite': rightCheek,
    'Menton': chin,
    'Front': forehead,
  };

  Map<String, dynamic> toJson() => {
    'leftEye': leftEye != null ? {'dx': leftEye!.dx, 'dy': leftEye!.dy} : null,
    'rightEye':
        rightEye != null ? {'dx': rightEye!.dx, 'dy': rightEye!.dy} : null,
    'noseTip': noseTip != null ? {'dx': noseTip!.dx, 'dy': noseTip!.dy} : null,
    'noseBase':
        noseBase != null ? {'dx': noseBase!.dx, 'dy': noseBase!.dy} : null,
    'leftMouth':
        leftMouth != null ? {'dx': leftMouth!.dx, 'dy': leftMouth!.dy} : null,
    'rightMouth':
        rightMouth != null
            ? {'dx': rightMouth!.dx, 'dy': rightMouth!.dy}
            : null,
    'mouthCenter':
        mouthCenter != null
            ? {'dx': mouthCenter!.dx, 'dy': mouthCenter!.dy}
            : null,
    'leftCheek':
        leftCheek != null ? {'dx': leftCheek!.dx, 'dy': leftCheek!.dy} : null,
    'rightCheek':
        rightCheek != null
            ? {'dx': rightCheek!.dx, 'dy': rightCheek!.dy}
            : null,
    'chin': chin != null ? {'dx': chin!.dx, 'dy': chin!.dy} : null,
    'forehead':
        forehead != null ? {'dx': forehead!.dx, 'dy': forehead!.dy} : null,
    'faceContour': faceContour.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
  };

  factory FacialKeyPoints.fromJson(Map<String, dynamic> json) {
    Offset? parseOffset(dynamic data) {
      if (data == null) return null;
      return Offset(
        (data['dx'] as num).toDouble(),
        (data['dy'] as num).toDouble(),
      );
    }

    return FacialKeyPoints(
      leftEye: parseOffset(json['leftEye']),
      rightEye: parseOffset(json['rightEye']),
      noseTip: parseOffset(json['noseTip']),
      noseBase: parseOffset(json['noseBase']),
      leftMouth: parseOffset(json['leftMouth']),
      rightMouth: parseOffset(json['rightMouth']),
      mouthCenter: parseOffset(json['mouthCenter']),
      leftCheek: parseOffset(json['leftCheek']),
      rightCheek: parseOffset(json['rightCheek']),
      chin: parseOffset(json['chin']),
      forehead: parseOffset(json['forehead']),
      faceContour:
          (json['faceContour'] as List<dynamic>?)
              ?.map(
                (p) => Offset(
                  (p['dx'] as num).toDouble(),
                  (p['dy'] as num).toDouble(),
                ),
              )
              .toList() ??
          [],
    );
  }
}

/// Régions anatomiques du visage
enum FacialRegion {
  forehead('Front'),
  leftTemple('Tempe gauche'),
  rightTemple('Tempe droite'),
  leftPeriorbital('Zone péri-orbitaire gauche'),
  rightPeriorbital('Zone péri-orbitaire droite'),
  nose('Nez'),
  leftCheek('Joue gauche'),
  rightCheek('Joue droite'),
  upperLip('Lèvre supérieure'),
  lowerLip('Lèvre inférieure'),
  chin('Menton'),
  leftEar('Oreille gauche'),
  rightEar('Oreille droite'),
  unknown('Zone inconnue');

  final String displayName;
  const FacialRegion(this.displayName);

  /// Retourne les considérations chirurgicales pour chaque région
  String get surgicalConsiderations {
    switch (this) {
      case FacialRegion.leftPeriorbital:
      case FacialRegion.rightPeriorbital:
        return 'Zone sensible - proximité de l\'œil. Attention aux structures nerveuses et vasculaires.';
      case FacialRegion.nose:
        return 'Zone centrale du visage - résultat esthétique critique. Risque de déformation.';
      case FacialRegion.upperLip:
      case FacialRegion.lowerLip:
        return 'Zone fonctionnelle - attention à préserver la mobilité labiale.';
      case FacialRegion.forehead:
        return 'Large surface disponible pour les lambeaux. Attention aux branches du nerf facial.';
      case FacialRegion.leftCheek:
      case FacialRegion.rightCheek:
        return 'Bonne laxité cutanée. Options de reconstruction multiples.';
      default:
        return 'Évaluation chirurgicale individuelle nécessaire.';
    }
  }
}
