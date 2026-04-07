/// Model representing the result of a skin lesion analysis
class SkinAnalysisResult {
  final String id;
  final String imagePath;
  final String lesionClass;
  final String lesionName;
  final double confidence;
  final RiskLevel riskLevel;
  final DateTime timestamp;
  final List<Detection> detections;

  SkinAnalysisResult({
    required this.id,
    required this.imagePath,
    required this.lesionClass,
    required this.lesionName,
    required this.confidence,
    required this.riskLevel,
    required this.timestamp,
    this.detections = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imagePath': imagePath,
      'lesionClass': lesionClass,
      'lesionName': lesionName,
      'confidence': confidence,
      'riskLevel': riskLevel.name,
      'timestamp': timestamp.toIso8601String(),
      'detections': detections.map((d) => d.toJson()).toList(),
    };
  }

  factory SkinAnalysisResult.fromJson(Map<String, dynamic> json) {
    return SkinAnalysisResult(
      id: json['id'] as String,
      imagePath: json['imagePath'] as String,
      lesionClass: json['lesionClass'] as String,
      lesionName: json['lesionName'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      riskLevel: RiskLevel.values.firstWhere(
        (e) => e.name == json['riskLevel'],
        orElse: () => RiskLevel.unknown,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      detections:
          (json['detections'] as List<dynamic>?)
              ?.map((d) => Detection.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Detection bounding box from the API response
class Detection {
  final String className;
  final double confidence;
  final double x;
  final double y;
  final double width;
  final double height;

  Detection({
    required this.className,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  Map<String, dynamic> toJson() {
    return {
      'class': className,
      'confidence': confidence,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }

  factory Detection.fromJson(Map<String, dynamic> json) {
    return Detection(
      className: json['class'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      width: (json['width'] as num?)?.toDouble() ?? 0.0,
      height: (json['height'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Risk level enumeration for skin lesions
enum RiskLevel { high, medium, low, unknown }

/// Mapping of HAM10000 lesion classes to human-readable names and risk levels
class LesionClassInfo {
  static const Map<String, Map<String, dynamic>> lesionMap = {
    // New model: shawn-f/melanoma-b2rp6/1 (98.5% accuracy)
    'MALIGNANT': {
      'name': 'Lésion Maligne (Cancéreuse)',
      'description': '⚠️ ATTENTION: Lésion potentiellement cancéreuse détectée',
      'risk': RiskLevel.high,
      'recommendation':
          'URGENT: Consultez immédiatement un dermatologue. Cette lésion nécessite une évaluation médicale urgente.',
    },
    'BENIGN': {
      'name': 'Lésion Bénigne',
      'description': 'Lésion non cancéreuse détectée',
      'risk': RiskLevel.low,
      'recommendation':
          'Aucune action urgente requise. Surveiller les changements de taille, forme ou couleur.',
    },
    'NON-MELANOMA': {
      'name': 'Non-Mélanome',
      'description': 'Lésion cutanée non identifiée comme mélanome',
      'risk': RiskLevel.medium,
      'recommendation':
          'Surveillance recommandée. Consultez un dermatologue en cas de doute ou d\'évolution.',
    },
    // Legacy HAM10000 classes (for backward compatibility)
    'MEL': {
      'name': 'Mélanome',
      'description': 'Cancer de la peau le plus dangereux',
      'risk': RiskLevel.high,
      'recommendation': 'Consultez immédiatement un dermatologue',
    },
    'BCC': {
      'name': 'Carcinome basocellulaire',
      'description': 'Cancer de la peau à croissance lente',
      'risk': RiskLevel.high,
      'recommendation': 'Consultez un dermatologue rapidement',
    },
    'AKIEC': {
      'name': 'Kératose actinique',
      'description': 'Lésion pré-cancéreuse due au soleil',
      'risk': RiskLevel.medium,
      'recommendation': 'Surveillance recommandée par un dermatologue',
    },
    'BKL': {
      'name': 'Kératose bénigne',
      'description': 'Excroissance cutanée non cancéreuse',
      'risk': RiskLevel.low,
      'recommendation': 'Généralement sans danger, surveillance optionnelle',
    },
    'NV': {
      'name': 'Nævus mélanocytaire',
      'description': 'Grain de beauté bénin',
      'risk': RiskLevel.low,
      'recommendation': 'Aucune action requise, surveiller les changements',
    },
    'DF': {
      'name': 'Dermatofibrome',
      'description': 'Nodule cutané bénin',
      'risk': RiskLevel.low,
      'recommendation': 'Bénin, aucun traitement nécessaire',
    },
    'VASC': {
      'name': 'Lésion vasculaire',
      'description': 'Anomalie des vaisseaux sanguins',
      'risk': RiskLevel.low,
      'recommendation': 'Généralement bénin, consultation si gêne',
    },
    // Skin Lesion Classification model (skindiseasedetection-d7mln)
    'ACTINIC KERATOSIS': {
      'name': 'Kératose actinique',
      'description': 'Lésion pré-cancéreuse causée par l\'exposition au soleil',
      'risk': RiskLevel.medium,
      'recommendation':
          'Consultation recommandée, risque de progression vers un cancer',
    },
    'ATOPIC DERMATITIS': {
      'name': 'Dermatite atopique',
      'description': 'Eczéma - inflammation chronique de la peau',
      'risk': RiskLevel.low,
      'recommendation':
          'Condition bénigne, traitements disponibles pour soulager les symptômes',
    },
    'BENIGN KERATOSIS': {
      'name': 'Kératose bénigne',
      'description': 'Excroissance cutanée non cancéreuse',
      'risk': RiskLevel.low,
      'recommendation': 'Bénin, surveillance des changements',
    },
    'DERMATOFIBROMA': {
      'name': 'Dermatofibrome',
      'description': 'Nodule cutané bénin, ferme au toucher',
      'risk': RiskLevel.low,
      'recommendation': 'Bénin, aucun traitement nécessaire',
    },
    'MELANOMA': {
      'name': 'Mélanome',
      'description': '⚠️ ATTENTION: Cancer de la peau agressif',
      'risk': RiskLevel.high,
      'recommendation': 'URGENT: Consultez immédiatement un dermatologue',
    },
    'SQUAMOUS CELL CARCINOMA': {
      'name': 'Carcinome épidermoïde',
      'description': 'Cancer de la peau nécessitant un traitement',
      'risk': RiskLevel.high,
      'recommendation': 'Consultez rapidement un dermatologue pour traitement',
    },
    'TINEA RINGWORM CANDIDIASIS': {
      'name': 'Mycose cutanée',
      'description': 'Infection fongique de la peau (teigne)',
      'risk': RiskLevel.low,
      'recommendation':
          'Traitement antifongique recommandé, consulter un médecin',
    },
    'VASCULAR LESION': {
      'name': 'Lésion vasculaire',
      'description': 'Anomalie des vaisseaux sanguins cutanés',
      'risk': RiskLevel.low,
      'recommendation': 'Généralement bénin, consultation si gêne esthétique',
    },
  };

  static String getName(String classCode) {
    return lesionMap[classCode.toUpperCase()]?['name'] as String? ??
        'Lésion inconnue';
  }

  static String getDescription(String classCode) {
    return lesionMap[classCode.toUpperCase()]?['description'] as String? ??
        'Description non disponible';
  }

  static RiskLevel getRiskLevel(String classCode) {
    return lesionMap[classCode.toUpperCase()]?['risk'] as RiskLevel? ??
        RiskLevel.unknown;
  }

  static String getRecommendation(String classCode) {
    return lesionMap[classCode.toUpperCase()]?['recommendation'] as String? ??
        'Consultez un professionnel de santé';
  }
}
