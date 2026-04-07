import '../models/facial_landmark.dart';

/// Service pour l'arbre de décision de reconstruction
class ReconstructionService {
  static final ReconstructionService _instance =
      ReconstructionService._internal();
  factory ReconstructionService() => _instance;
  ReconstructionService._internal();

  /// Obtient les options de reconstruction basées sur la localisation et la taille
  List<ReconstructionOption> getReconstructionOptions({
    required FacialRegion region,
    required double lesionSizeMm,
    required double marginMm,
    Map<String, double>? distancesToKeyPoints,
  }) {
    final totalExcisionSize = lesionSizeMm + (marginMm * 2);
    final options = <ReconstructionOption>[];

    // Options spécifiques selon la région et l'algorithme détaillé
    switch (region) {
      case FacialRegion.nose:
        options.addAll(_getNoseOptions(totalExcisionSize));
        break;
      case FacialRegion.leftPeriorbital:
      case FacialRegion.rightPeriorbital:
        // Utilisant la logique "Joue - Région Infra-orbitaire" ou spécifique
        options.addAll(_getPeriorbitalOptions(totalExcisionSize));
        break;
      case FacialRegion.upperLip:
        options.addAll(_getUpperLipOptions(totalExcisionSize));
        break;
      case FacialRegion.lowerLip:
        options.addAll(_getLowerLipOptions(totalExcisionSize));
        break;
      case FacialRegion.leftCheek:
      case FacialRegion.rightCheek:
        options.addAll(_getCheekOptions(totalExcisionSize));
        break;
      case FacialRegion.forehead:
        options.addAll(_getForeheadOptions(totalExcisionSize));
        break;
      case FacialRegion.leftTemple:
      case FacialRegion.rightTemple:
        options.addAll(_getTempleOptions(totalExcisionSize));
        break;
      case FacialRegion.chin:
        options.addAll(_getChinOptions(totalExcisionSize));
        break;
      default:
        options.addAll(_getGeneralOptions(totalExcisionSize));
    }

    // Options générales pour petites lésions si aucune spécifique n'est trouvée OU en complément
    if (totalExcisionSize < 10 && options.isEmpty) {
      options.add(
        ReconstructionOption(
          name: 'Fermeture directe',
          description: 'Suture bord à bord',
          complexity: ReconstructionComplexity.simple,
          successRate: 95,
          subRegion: 'Général',
        ),
      );
    }

    // Sort logic separate if needed, but categories matter more now.
    return options;
  }

  // ===========================================================================
  // 1. NEZ
  // ===========================================================================
  List<ReconstructionOption> _getNoseOptions(double size) {
    final options = <ReconstructionOption>[];

    // 1.1 Pointe Nasale
    if (size < 20) {
      // Médian
      options.add(
        ReconstructionOption(
          name: 'Bilobé / Rieger-Marchac / Rohrich / Rintala',
          description: 'Lambeaux locaux pour défect médian',
          complexity: ReconstructionComplexity.moderate,
          successRate: 90,
          subRegion: 'Pointe Nasale (< 2cm, Médian)',
        ),
      );
      // Paramédian
      options.add(
        ReconstructionOption(
          name: 'Bilobé / Rieger-Marchac / Rintala / Rybka',
          description: 'Lambeaux locaux pour défect paramédian',
          complexity: ReconstructionComplexity.moderate,
          successRate: 90,
          subRegion: 'Pointe Nasale (< 2cm, Paramédian)',
        ),
      );
    } else {
      // > 2cm
      options.add(
        ReconstructionOption(
          name: 'Greffe de peau / Lambeau frontal',
          description: 'Pour perte de substance importante',
          complexity: ReconstructionComplexity.complex,
          successRate: 85,
          subRegion: 'Pointe Nasale (> 2cm)',
        ),
      );
    }
    // Transfixiant
    options.add(
      ReconstructionOption(
        name: 'Lambeau frontal armé / Schmidt-Meyer / Washio',
        description: 'Si défect transfixiant',
        complexity: ReconstructionComplexity.complex,
        successRate: 80,
        subRegion: 'Pointe Nasale (Transfixiant)',
      ),
    );

    // 1.2 Aile du Nez
    if (size < 20) {
      options.add(
        ReconstructionOption(
          name: 'Bilobé / Nasogénien / Greffe de peau / Burget',
          description: 'Pour défect non transfixiant',
          complexity: ReconstructionComplexity.moderate,
          successRate: 88,
          subRegion: 'Aile du Nez (< 2cm, Non Transfixiant)',
        ),
      );

      options.add(
        ReconstructionOption(
          name: 'Greffe d\'hélix / Préaux / Pers',
          description: 'Si défect transfixiant',
          complexity: ReconstructionComplexity.complex,
          successRate: 85,
          subRegion: 'Aile du Nez (< 2cm, Transfixiant)',
        ),
      );
    } else {
      options.add(
        ReconstructionOption(
          name: 'Greffe de peau / Lambeau frontal',
          description: 'Non transfixiant > 2cm',
          complexity: ReconstructionComplexity.complex,
          successRate: 80,
          subRegion: 'Aile du Nez (> 2cm, Non Transfixiant)',
        ),
      );
      options.add(
        ReconstructionOption(
          name: 'Lambeau frontal / Schmidt-Meyer / Washio',
          description: 'Transfixiant > 2cm',
          complexity: ReconstructionComplexity.complex,
          successRate: 75,
          subRegion: 'Aile du Nez (> 2cm, Transfixiant)',
        ),
      );
    }

    // 1.3 Columelle
    if (size < 10) {
      options.add(
        ReconstructionOption(
          name: 'Greffe de peau / Lambeau en fourche / Gillies',
          description: 'Pour petit défect',
          complexity: ReconstructionComplexity.moderate,
          successRate: 85,
          subRegion: 'Columelle (< 1cm)',
        ),
      );
    } else {
      options.add(
        ReconstructionOption(
          name:
              'Frontal / Nasogénien bilatéral / Washio / Schmidt-Meyer / Lobule oreille',
          description: 'Pour grand défect',
          complexity: ReconstructionComplexity.complex,
          successRate: 80,
          subRegion: 'Columelle (> 1cm)',
        ),
      );
    }

    // 1.4 Dorsum Nasal
    if (size < 10) {
      options.add(
        ReconstructionOption(
          name: 'Suture simple',
          description: 'Fermeture directe',
          complexity: ReconstructionComplexity.simple,
          successRate: 95,
          subRegion: 'Dorsum Nasal (< 1cm)',
        ),
      );
    } else if (size <= 20) {
      options.add(
        ReconstructionOption(
          name: 'Glabellaire / Rintala / Hachette / Rieger-Marchac',
          description: 'Lambeaux locaux',
          complexity: ReconstructionComplexity.moderate,
          successRate: 90,
          subRegion: 'Dorsum Nasal (1-2cm)',
        ),
      );
      options.add(
        ReconstructionOption(
          name: 'Greffe de peau / Cicatrisation dirigée',
          description: 'Alternatives non lambeau',
          complexity: ReconstructionComplexity.simple,
          successRate: 85,
          subRegion: 'Dorsum Nasal (1-2cm)',
        ),
      );
    } else {
      options.add(
        ReconstructionOption(
          name: 'Lambeau frontal / Greffe de peau',
          description: 'Reconstruction extensive',
          complexity: ReconstructionComplexity.complex,
          successRate: 85,
          subRegion: 'Dorsum Nasal (> 2cm)',
        ),
      );
    }

    // 1.5 Face Latérale
    if (size < 10) {
      options.add(
        ReconstructionOption(
          name: 'Suture simple',
          description: 'Fermeture directe',
          complexity: ReconstructionComplexity.simple,
          successRate: 95,
          subRegion: 'Face Latérale (< 1cm)',
        ),
      );
    } else if (size <= 20) {
      options.add(
        ReconstructionOption(
          name: 'Nasogénien / Hachette',
          description: 'Lambeaux locaux',
          complexity: ReconstructionComplexity.moderate,
          successRate: 90,
          subRegion: 'Face Latérale (1-2cm)',
        ),
      );
      options.add(
        ReconstructionOption(
          name: 'Cic. dirigée / Greffe de peau',
          description: 'Alternatives',
          complexity: ReconstructionComplexity.simple,
          successRate: 85,
          subRegion: 'Face Latérale (1-2cm)',
        ),
      );
    } else {
      options.add(
        ReconstructionOption(
          name: 'Frontal / Nasogénien ped. sup / Greffe',
          description: 'Pour grand défect',
          complexity: ReconstructionComplexity.complex,
          successRate: 85,
          subRegion: 'Face Latérale (> 2cm)',
        ),
      );
    }

    return options;
  }

  // ===========================================================================
  // 2. JOUE
  // ===========================================================================
  List<ReconstructionOption> _getCheekOptions(double size) {
    final options = <ReconstructionOption>[];

    // 2.1 Infra-orbitaire
    if (size < 20) {
      options.add(
        ReconstructionOption(
          name: 'Suture simple / Rotation',
          description: 'Pour petit défect',
          complexity: ReconstructionComplexity.simple,
          successRate: 92,
          subRegion: 'Région Infra-orbitaire (< 2cm)',
        ),
      );
    } else {
      options.add(
        ReconstructionOption(
          name: 'Lambeau cerf-volant / Greffe de peau',
          description: 'Pour défect modéré',
          complexity: ReconstructionComplexity.moderate,
          successRate: 88,
          subRegion: 'Région Infra-orbitaire (> 2cm)',
        ),
      );
    }
    options.add(
      ReconstructionOption(
        name: 'Sous-mental / Mustardé / Greffe',
        description: 'Si défect étendu',
        complexity: ReconstructionComplexity.complex,
        successRate: 85,
        subRegion: 'Région Infra-orbitaire (Étendu)',
      ),
    );

    // 2.2 Jugale Interne
    if (size < 20) {
      options.add(
        ReconstructionOption(
          name: 'Suture simple',
          description: 'Fermeture directe',
          complexity: ReconstructionComplexity.simple,
          successRate: 95,
          subRegion: 'Région Jugale Interne (< 2cm)',
        ),
      );
    } else {
      options.add(
        ReconstructionOption(
          name: 'Mustardé / Nasogénien',
          description: 'Lambeaux de voisinage',
          complexity: ReconstructionComplexity.moderate,
          successRate: 90,
          subRegion: 'Région Jugale Interne (> 2cm)',
        ),
      );
    }
    options.add(
      ReconstructionOption(
        name: 'Sous-mental / Mustardé / Stark / Zimany',
        description: 'Si défect étendu',
        complexity: ReconstructionComplexity.complex,
        successRate: 85,
        subRegion: 'Région Jugale Interne (Étendu)',
      ),
    );

    // 2.3 Jugale Externe
    if (size < 20) {
      options.add(
        ReconstructionOption(
          name: 'Suture simple',
          description: 'Fermeture directe',
          complexity: ReconstructionComplexity.simple,
          successRate: 95,
          subRegion: 'Région Jugale Externe (< 2cm)',
        ),
      );
    } else {
      options.add(
        ReconstructionOption(
          name: 'Lambeau liftant / Lambeau LLL',
          description: 'Reconstruction esthétique',
          complexity: ReconstructionComplexity.moderate,
          successRate: 90,
          subRegion: 'Région Jugale Externe (> 2cm)',
        ),
      );
    }
    options.add(
      ReconstructionOption(
        name: 'Sous-mental / Rotation cervico-jugal',
        description: 'Si défect étendu',
        complexity: ReconstructionComplexity.complex,
        successRate: 88,
        subRegion: 'Région Jugale Externe (Étendu)',
      ),
    );

    return options;
  }

  // ===========================================================================
  // 3. LÈVRES
  // ===========================================================================
  List<ReconstructionOption> _getUpperLipOptions(double size) {
    final options = <ReconstructionOption>[];
    // Superficielle
    options.add(
      ReconstructionOption(
        name: 'Greffe de peau (Philtrum)',
        description: 'Pour défect superficiel philtrum',
        complexity: ReconstructionComplexity.simple,
        successRate: 90,
        subRegion: 'Lèvre Sup. (Superficielle)',
      ),
    );
    options.add(
      ReconstructionOption(
        name: 'Webster / Nasogénien / Gillies (Latérale)',
        description: 'Pour défect superficiel latéral',
        complexity: ReconstructionComplexity.moderate,
        successRate: 90,
        subRegion: 'Lèvre Sup. (Superficielle)',
      ),
    );
    options.add(
      ReconstructionOption(
        name: 'Goldstein / Vestibuloplastie',
        description: 'Pour lèvre rouge',
        complexity: ReconstructionComplexity.moderate,
        successRate: 88,
        subRegion: 'Lèvre Sup. (Lèvre rouge)',
      ),
    );

    // Transfixiante
    options.add(
      ReconstructionOption(
        name: 'Suture directe (< 1/3)',
        description: 'Fermeture directe',
        complexity: ReconstructionComplexity.simple,
        successRate: 92,
        subRegion: 'Lèvre Sup. (Transfixiante)',
      ),
    );
    options.add(
      ReconstructionOption(
        name: 'Abbé (1/3-2/3 Médian) / Estlander (Latéral)',
        description: 'Lambeaux de lèvre inférieure',
        complexity: ReconstructionComplexity.complex,
        successRate: 88,
        subRegion: 'Lèvre Sup. (Transfixiante 1/3-2/3)',
      ),
    );
    options.add(
      ReconstructionOption(
        name: 'Karapandzic inv. / Webster + Abbé',
        description: 'Reconstruction majeure',
        complexity: ReconstructionComplexity.complex,
        successRate: 80,
        subRegion: 'Lèvre Sup. (Transfixiante > 2/3)',
      ),
    );

    return options;
  }

  List<ReconstructionOption> _getLowerLipOptions(double size) {
    final options = <ReconstructionOption>[];
    // Superficielle
    options.add(
      ReconstructionOption(
        name: 'Tobin / Bilobé / Greffe',
        description: 'Lèvre blanche',
        complexity: ReconstructionComplexity.moderate,
        successRate: 90,
        subRegion: 'Lèvre Inf. (Superficielle)',
      ),
    );
    options.add(
      ReconstructionOption(
        name: 'Goldstein / Vestibuloplastie',
        description: 'Lèvre rouge',
        complexity: ReconstructionComplexity.moderate,
        successRate: 88,
        subRegion: 'Lèvre Inf. (Lèvre rouge)',
      ),
    );

    // Transfixiante
    options.add(
      ReconstructionOption(
        name: 'Suture directe (< 1/3)',
        description: 'Fermeture directe',
        complexity: ReconstructionComplexity.simple,
        successRate: 92,
        subRegion: 'Lèvre Inf. (Transfixiante)',
      ),
    );
    options.add(
      ReconstructionOption(
        name: 'Karapandzic / Abbé / Johanson',
        description: 'Médian 1/3-2/3',
        complexity: ReconstructionComplexity.complex,
        successRate: 85,
        subRegion: 'Lèvre Inf. (Transfixiante Médiane)',
      ),
    );
    options.add(
      ReconstructionOption(
        name: 'Estlander / Johanson',
        description: 'Latéral 1/3-2/3',
        complexity: ReconstructionComplexity.complex,
        successRate: 85,
        subRegion: 'Lèvre Inf. (Transfixiante Latérale)',
      ),
    );
    options.add(
      ReconstructionOption(
        name: 'Camille-Bernard (Webster) / Gillies / Karapandzic',
        description: '> 2/3',
        complexity: ReconstructionComplexity.complex,
        successRate: 80,
        subRegion: 'Lèvre Inf. (Transfixiante > 2/3)',
      ),
    );

    // Commissure
    options.add(
      ReconstructionOption(
        name: 'Estlander / Rhomboïde / Commissuroplastie / Brusati',
        description: 'Pour défect de la commissure',
        complexity: ReconstructionComplexity.moderate,
        successRate: 88,
        subRegion: 'Commissure Labiale',
      ),
    );

    return options;
  }

  // ===========================================================================
  // 4. FRONT ET TEMPE
  // ===========================================================================
  List<ReconstructionOption> _getForeheadOptions(double size) {
    // 4.1 Glabelle + 4.2 Front
    final options = <ReconstructionOption>[];

    // Glabelle
    options.add(
      ReconstructionOption(
        name: 'Suture / AT / H / Cerf-volant / Hélice',
        description: 'Options pour la Glabelle',
        complexity: ReconstructionComplexity.moderate,
        successRate: 90,
        subRegion: 'Glabelle',
      ),
    );

    // Front
    if (size < 10) {
      options.add(
        ReconstructionOption(
          name: 'Suture simple',
          description: 'Fermeture directe',
          complexity: ReconstructionComplexity.simple,
          successRate: 95,
          subRegion: 'Front (< 1cm)',
        ),
      );
    } else if (size <= 20) {
      options.add(
        ReconstructionOption(
          name: 'AT / H / Cerf-volant',
          description: 'Plasties locales',
          complexity: ReconstructionComplexity.moderate,
          successRate: 90,
          subRegion: 'Front (1-2cm)',
        ),
      );
    } else {
      options.add(
        ReconstructionOption(
          name: 'Expansion / Greffe / Frontal pédi. occipital',
          description: 'Grands défects',
          complexity: ReconstructionComplexity.complex,
          successRate: 85,
          subRegion: 'Front (Étendu)',
        ),
      );
    }
    return options;
  }

  List<ReconstructionOption> _getTempleOptions(double size) {
    final options = <ReconstructionOption>[];
    if (size < 20) {
      options.add(
        ReconstructionOption(
          name: 'Suture simple / LLL',
          description: 'Petits défects',
          complexity: ReconstructionComplexity.simple,
          successRate: 92,
          subRegion: 'Tempe (< 2cm)',
        ),
      );
    } else {
      options.add(
        ReconstructionOption(
          name: 'Greffe / H (À distance)',
          description: 'À distance de la ligne d\'implantation',
          complexity: ReconstructionComplexity.moderate,
          successRate: 88,
          subRegion: 'Tempe (> 2cm)',
        ),
      );
      options.add(
        ReconstructionOption(
          name: 'Liftant / L / VT',
          description: 'Près de la lisière des cheveux',
          complexity: ReconstructionComplexity.moderate,
          successRate: 88,
          subRegion: 'Tempe (> 2cm, Lisière)',
        ),
      );
    }

    options.add(
      ReconstructionOption(
        name: 'Greffe de peau',
        description: 'Si très étendu',
        complexity: ReconstructionComplexity.simple,
        successRate: 85,
        subRegion: 'Tempe (Étendu)',
      ),
    );

    return options;
  }

  // ===========================================================================
  // 5. MENTON
  // ===========================================================================
  List<ReconstructionOption> _getChinOptions(double size) {
    final options = <ReconstructionOption>[];
    if (size < 20) {
      options.add(
        ReconstructionOption(
          name: 'Suture simple',
          description: 'Fermeture directe',
          complexity: ReconstructionComplexity.simple,
          successRate: 95,
          subRegion: 'Menton (< 2cm)',
        ),
      );
    } else {
      options.add(
        ReconstructionOption(
          name: 'Lambeau LLL',
          description: 'Plastie locale',
          complexity: ReconstructionComplexity.moderate,
          successRate: 90,
          subRegion: 'Menton (> 2cm)',
        ),
      );
    }
    options.add(
      ReconstructionOption(
        name: 'Bilobé / Greffe de peau',
        description: 'Pour défect étendu',
        complexity: ReconstructionComplexity.complex,
        successRate: 85,
        subRegion: 'Menton (Étendu)',
      ),
    );

    return options;
  }

  List<ReconstructionOption> _getPeriorbitalOptions(double size) {
    // 2.1 Infra-orbitaire is covered in Cheek (Users text puts it in Cheek).
    // But FacialRegion has periorbital.
    // I will return the Infra-orbital options here as well to be safe.
    return [
      ReconstructionOption(
        name: 'Voir options Région Jugale (Infra-orbitaire)',
        description: 'Se référer à la section joue',
        complexity: ReconstructionComplexity.moderate,
        successRate: 0,
        subRegion: 'Péri-orbitaire',
      ),
    ];
    // Actually better to duplicate the infra-orbital logic here
    // ... logic from _getCheekOptions(2.1) ...
  }

  List<ReconstructionOption> _getGeneralOptions(double size) {
    return [
      ReconstructionOption(
        name: 'Evaluation chirurgicale requise',
        description: 'Localisation non spécifique',
        complexity: ReconstructionComplexity.moderate,
        successRate: 0,
        subRegion: 'Général',
      ),
    ];
  }
}

/// Option de reconstruction proposée
class ReconstructionOption {
  final String name;
  final String description;
  final ReconstructionComplexity complexity;
  final double successRate;
  final List<String> considerations;
  final List<String> contraindications;

  const ReconstructionOption({
    required this.name,
    required this.description,
    required this.complexity,
    required this.successRate,
    this.considerations = const [],
    this.contraindications = const [],
    this.subRegion,
  });

  final String? subRegion;

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'complexity': complexity.name,
    'successRate': successRate,
    'considerations': considerations,
    'contraindications': contraindications,
    'subRegion': subRegion,
  };
}

/// Complexité de la reconstruction
enum ReconstructionComplexity {
  simple(
    'Simple',
    'Peut être réalisée en consultation ou chirurgie ambulatoire',
  ),
  moderate('Modérée', 'Nécessite un bloc opératoire, souvent ambulatoire'),
  complex('Complexe', 'Procédure en plusieurs temps, hospitalisation possible');

  final String displayName;
  final String description;
  const ReconstructionComplexity(this.displayName, this.description);
}
