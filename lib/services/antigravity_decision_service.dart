/// Service d'arbres de décision de reconstruction faciale
/// Données issues de la thèse : chaque zone/sous-région possède des branches
/// par taille de lésion menant à des techniques de reconstruction spécifiques.

import '../models/facial_landmark.dart';

// ─── MODÈLES ──────────────────────────────────────────────────

/// Zone principale du visage
enum ReconstructionZone {
  nez('Nez', '👃'),
  joue('Joue', '🫧'),
  levre('Lèvre', '👄'),
  front('Front', '🧠'),
  menton('Menton', '🫥');

  final String displayName;
  final String emoji;
  const ReconstructionZone(this.displayName, this.emoji);
}

/// Critère de taille pour une branche de l'arbre
enum SizeCriteria {
  // Nez - Pointe
  lessThan2cmMedian('<2cm et médian'),
  lessThan2cmParamedian('<2cm et paramédian'),
  greaterThan2cm('>2cm'),
  transfixiant('Transfixiant'),

  // Nez - Aile
  lessThan2cmNonTransfixiant('<2cm et non transfixiant'),
  lessThan2cmTransfixiant('<2cm et transfixiant'),
  greaterThan2cmNonTransfixiant('>2cm et non transfixiant'),
  greaterThan2cmTransfixiant('>2cm et transfixiant'),

  // Nez - Columelle
  lessThan1cm('<1cm'),
  greaterThan1cm('>1cm'),

  // Nez - Dorsum & Face latérale, Joue, Front
  lessThan1cmSimple('<1cm'),
  between1and2cm('1-2cm'),
  greaterThan2cmSimple('>2cm'),

  // Joue / Front / Menton
  lessThan2cm('<2cm'),
  etendue('Étendue'),

  // Lèvre - Transfixiante
  lessThanOneThird('<1/3'),
  oneThirdToTwoThirds('1/3 - 2/3'),
  greaterThanTwoThirds('>2/3'),

  // Lèvre - Superficielle positions
  philtrum('Philtrum'),
  laterale('Latérale'),
  levreRouge('Lèvre rouge'),
  levreBlanche('Lèvre blanche'),

  // Tempe spécifique
  greaterThan2cmDistanceCheveux('>2cm (à distance implantation cheveux)'),
  greaterThan2cmLisiereCheveux('>2cm (lisière des cheveux)'),

  // Pas de critère (techniques directes)
  all('Toutes tailles');

  final String displayName;
  const SizeCriteria(this.displayName);
}

/// Une branche de l'arbre : un critère de taille → liste de techniques
class DecisionBranch {
  final SizeCriteria criteria;
  final List<String> techniques;

  const DecisionBranch({required this.criteria, required this.techniques});

  /// Vérifie si cette branche correspond à une taille donnée en mm
  bool matchesSize(double sizeMm) {
    final sizeCm = sizeMm / 10.0;
    switch (criteria) {
      case SizeCriteria.lessThan1cm:
      case SizeCriteria.lessThan1cmSimple:
        return sizeCm < 1.0;
      case SizeCriteria.between1and2cm:
        return sizeCm >= 1.0 && sizeCm <= 2.0;
      case SizeCriteria.greaterThan1cm:
        return sizeCm >= 1.0;
      case SizeCriteria.lessThan2cm:
      case SizeCriteria.lessThan2cmMedian:
      case SizeCriteria.lessThan2cmParamedian:
      case SizeCriteria.lessThan2cmNonTransfixiant:
      case SizeCriteria.lessThan2cmTransfixiant:
        return sizeCm < 2.0;
      case SizeCriteria.greaterThan2cm:
      case SizeCriteria.greaterThan2cmSimple:
      case SizeCriteria.greaterThan2cmNonTransfixiant:
      case SizeCriteria.greaterThan2cmTransfixiant:
      case SizeCriteria.greaterThan2cmDistanceCheveux:
      case SizeCriteria.greaterThan2cmLisiereCheveux:
        return sizeCm >= 2.0;
      case SizeCriteria.etendue:
        return sizeCm >= 4.0; // Étendue = très grande
      case SizeCriteria.lessThanOneThird:
      case SizeCriteria.oneThirdToTwoThirds:
      case SizeCriteria.greaterThanTwoThirds:
        return true; // Proportion, pas taille absolue
      case SizeCriteria.transfixiant:
        return true; // Critère clinique, pas de taille
      case SizeCriteria.philtrum:
      case SizeCriteria.laterale:
      case SizeCriteria.levreRouge:
      case SizeCriteria.levreBlanche:
        return true; // Position, pas taille
      case SizeCriteria.all:
        return true;
    }
  }
}

/// Sous-région d'une zone avec ses branches de décision
class SubRegionTree {
  final String name;
  final List<DecisionBranch> branches;

  const SubRegionTree({required this.name, required this.branches});

  /// Retourne les techniques recommandées pour une taille donnée
  List<DecisionBranch> getBranchesForSize(double sizeMm) {
    return branches.where((b) => b.matchesSize(sizeMm)).toList();
  }
}

/// Résultat complet pour une zone
class ZoneDecisionTree {
  final ReconstructionZone zone;
  final List<SubRegionTree> subRegions;

  const ZoneDecisionTree({required this.zone, required this.subRegions});
}

// ─── SERVICE ──────────────────────────────────────────────────

class AntigravityDecisionService {
  static final AntigravityDecisionService _instance =
      AntigravityDecisionService._internal();
  factory AntigravityDecisionService() => _instance;
  AntigravityDecisionService._internal();

  /// Mappe FacialRegion → ReconstructionZone
  ReconstructionZone? getZoneForRegion(FacialRegion region) {
    switch (region) {
      case FacialRegion.nose:
        return ReconstructionZone.nez;
      case FacialRegion.leftCheek:
      case FacialRegion.rightCheek:
      case FacialRegion.leftPeriorbital:
      case FacialRegion.rightPeriorbital:
        return ReconstructionZone.joue;
      case FacialRegion.upperLip:
      case FacialRegion.lowerLip:
        return ReconstructionZone.levre;
      case FacialRegion.forehead:
      case FacialRegion.leftTemple:
      case FacialRegion.rightTemple:
        return ReconstructionZone.front;
      case FacialRegion.chin:
        return ReconstructionZone.menton;
      default:
        return null;
    }
  }

  /// Obtient l'arbre de décision complet pour une zone
  ZoneDecisionTree getDecisionTree(ReconstructionZone zone) {
    switch (zone) {
      case ReconstructionZone.nez:
        return _buildNezTree();
      case ReconstructionZone.joue:
        return _buildJoueTree();
      case ReconstructionZone.levre:
        return _buildLevreTree();
      case ReconstructionZone.front:
        return _buildFrontTree();
      case ReconstructionZone.menton:
        return _buildMentonTree();
    }
  }

  /// Obtient l'arbre adapté à la FacialRegion détectée
  ZoneDecisionTree? getDecisionTreeForRegion(FacialRegion region) {
    final zone = getZoneForRegion(region);
    if (zone == null) return null;
    return getDecisionTree(zone);
  }

  /// Retourne tous les arbres
  List<ZoneDecisionTree> getAllDecisionTrees() {
    return ReconstructionZone.values.map((z) => getDecisionTree(z)).toList();
  }

  // ═══════════════════════════════════════════════════════════
  // NEZ
  // ═══════════════════════════════════════════════════════════

  ZoneDecisionTree _buildNezTree() {
    return ZoneDecisionTree(
      zone: ReconstructionZone.nez,
      subRegions: [
        // ── Pointe ──
        SubRegionTree(
          name: 'Pointe',
          branches: [
            const DecisionBranch(
              criteria: SizeCriteria.lessThan2cmMedian,
              techniques: [
                'Bilobé',
                'Rybka',
                'Greffe de peau',
                'Rohrich',
                'Rintala',
                'Rieger',
                'Avancement vertical du nez',
              ],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.lessThan2cmParamedian,
              techniques: ['Bilobé', 'Greffe de peau', 'Rintala', 'Rieger'],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.greaterThan2cm,
              techniques: ['Greffe', 'Lambeau frontal'],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.transfixiant,
              techniques: ['Lambeau frontal', 'Schmidt-Meyer', 'Washio'],
            ),
          ],
        ),

        // ── Aile du nez ──
        SubRegionTree(
          name: 'Aile du nez',
          branches: [
            const DecisionBranch(
              criteria: SizeCriteria.lessThan2cmNonTransfixiant,
              techniques: ['Bilobé', 'Nasogénien', 'Greffe de peau'],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.lessThan2cmTransfixiant,
              techniques: [
                'Greffe hélix',
                'Lambeau de Préaux',
                'Lambeau de Pers',
              ],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.greaterThan2cmNonTransfixiant,
              techniques: ['Greffe', 'Lambeau frontal'],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.greaterThan2cmTransfixiant,
              techniques: [
                'Lambeau fronto-temporal de Schmidt-Meyer',
                'Lambeau de Washio',
              ],
            ),
          ],
        ),

        // ── Columelle ──
        SubRegionTree(
          name: 'Columelle',
          branches: [
            const DecisionBranch(
              criteria: SizeCriteria.lessThan1cm,
              techniques: [
                'Greffe de peau',
                'Lambeau en fourche',
                'Lambeau frontal',
              ],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.greaterThan1cm,
              techniques: [
                'Lambeau nasogénien bilatéral',
                'Washio',
                'Schmidt-Meyer',
              ],
            ),
          ],
        ),

        // ── Dorsum ──
        SubRegionTree(
          name: 'Dorsum',
          branches: [
            const DecisionBranch(
              criteria: SizeCriteria.lessThan1cmSimple,
              techniques: ['Suture simple', 'Lambeau glabellaire', 'Rintala'],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.between1and2cm,
              techniques: [
                'Lambeau en hachette',
                'Lambeau de Rieger-Marchac',
                'Greffe de peau',
                'Cicatrisation dirigée',
              ],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.greaterThan2cmSimple,
              techniques: ['Lambeau frontal', 'Greffe de peau'],
            ),
          ],
        ),

        // ── Face latérale ──
        SubRegionTree(
          name: 'Face latérale',
          branches: [
            const DecisionBranch(
              criteria: SizeCriteria.lessThan1cmSimple,
              techniques: ['Suture simple'],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.between1and2cm,
              techniques: [
                'Lambeau nasogénien',
                'Lambeau en hachette',
                'Cicatrisation dirigée',
              ],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.greaterThan2cmSimple,
              techniques: [
                'Greffe de peau',
                'Lambeau frontal',
                'Lambeau d\'avancement jugal',
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // JOUE
  // ═══════════════════════════════════════════════════════════

  ZoneDecisionTree _buildJoueTree() {
    return ZoneDecisionTree(
      zone: ReconstructionZone.joue,
      subRegions: [
        // ── Région infra-orbitaire ──
        SubRegionTree(
          name: 'Région infra-orbitaire',
          branches: [
            const DecisionBranch(
              criteria: SizeCriteria.lessThan2cm,
              techniques: ['Suture simple', 'Lambeau de rotation'],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.greaterThan2cm,
              techniques: ['Lambeau cerf-volant', 'Greffe de peau'],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.etendue,
              techniques: [
                'Lambeau sous-mental',
                'Lambeau de Mustardé',
                'Greffe de peau',
              ],
            ),
          ],
        ),

        // ── Région jugale interne ──
        SubRegionTree(
          name: 'Région jugale interne',
          branches: [
            const DecisionBranch(
              criteria: SizeCriteria.lessThan2cm,
              techniques: ['Suture simple'],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.greaterThan2cm,
              techniques: [
                'Lambeau de Mustardé',
                'Lambeau naso-génien',
                'Lambeau sous-mental',
              ],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.etendue,
              techniques: [
                'Lambeau cervico-jugal de Stark',
                'Lambeau cervico-jugal de Zimany',
              ],
            ),
          ],
        ),

        // ── Région jugale externe ──
        SubRegionTree(
          name: 'Région jugale externe',
          branches: [
            const DecisionBranch(
              criteria: SizeCriteria.lessThan2cm,
              techniques: ['Suture simple'],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.greaterThan2cm,
              techniques: ['Lambeau liftant', 'Lambeau LLL'],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.etendue,
              techniques: [
                'Lambeau sous-mental',
                'Lambeau de rotation cervico-jugal',
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // LÈVRE
  // ═══════════════════════════════════════════════════════════

  ZoneDecisionTree _buildLevreTree() {
    return ZoneDecisionTree(
      zone: ReconstructionZone.levre,
      subRegions: [
        // ── Lèvre supérieure – Superficielle ──
        SubRegionTree(
          name: 'Lèvre supérieure – Superficielle',
          branches: [
            const DecisionBranch(
              criteria: SizeCriteria.philtrum,
              techniques: [
                'Greffe de peau',
                'Lambeau d\'Abbé',
                'Lambeau de Webster',
              ],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.laterale,
              techniques: [
                'Lambeau d\'avancement',
                'Escalier',
                'Naso-génien en rotation',
                'Avancement muco',
              ],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.levreRouge,
              techniques: ['Avancement muqueux', 'Vermillonectomie'],
            ),
          ],
        ),

        // ── Lèvre supérieure – Transfixiante ──
        SubRegionTree(
          name: 'Lèvre supérieure – Transfixiante',
          branches: [
            const DecisionBranch(
              criteria: SizeCriteria.lessThanOneThird,
              techniques: ['Webster', 'Suture directe'],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.oneThirdToTwoThirds,
              techniques: [
                'Lambeau d\'Abbé',
                'Escalier de Johanson',
                'Bernard',
              ],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.greaterThanTwoThirds,
              techniques: ['Karapandzic', 'Camille', 'Gillies'],
            ),
          ],
        ),

        // ── Lèvre inférieure – Superficielle ──
        SubRegionTree(
          name: 'Lèvre inférieure – Superficielle',
          branches: [
            const DecisionBranch(
              criteria: SizeCriteria.levreBlanche,
              techniques: ['Lambeau de Tobin', 'Bilobé', 'Greffe de peau'],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.levreRouge,
              techniques: ['Lambeau d\'avancement de Goldstein'],
            ),
          ],
        ),

        // ── Lèvre inférieure – Transfixiante ──
        SubRegionTree(
          name: 'Lèvre inférieure – Transfixiante',
          branches: [
            const DecisionBranch(
              criteria: SizeCriteria.lessThanOneThird,
              techniques: ['Vermillonectomie', 'Suture directe'],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.oneThirdToTwoThirds,
              techniques: [
                'Lambeau d\'Abbé',
                'Escalier de Johanson',
                'Rotation de Bernard',
              ],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.greaterThanTwoThirds,
              techniques: ['Lambeau de Gillies', 'Lambeau de Karapandzic'],
            ),
          ],
        ),

        // ── Commissure labiale ──
        SubRegionTree(
          name: 'Commissure labiale',
          branches: [
            const DecisionBranch(
              criteria: SizeCriteria.all,
              techniques: [
                'Lambeau d\'Estlander',
                'Lambeau rhomboïde de joue',
                'Commissuroplastie',
                'Lambeau d\'avancement jugale par procédé de Brusati',
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // FRONT / TIERS SUPÉRIEUR
  // ═══════════════════════════════════════════════════════════

  ZoneDecisionTree _buildFrontTree() {
    return ZoneDecisionTree(
      zone: ReconstructionZone.front,
      subRegions: [
        // ── Région frontale (médiane et latérale) ──
        SubRegionTree(
          name: 'Région frontale',
          branches: [
            const DecisionBranch(
              criteria: SizeCriteria.lessThan1cmSimple,
              techniques: ['Suture simple', 'Lambeau AT'],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.between1and2cm,
              techniques: ['Lambeau en H', 'Lambeau cerf-volant'],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.etendue,
              techniques: [
                'Expansion cutanée',
                'Greffe de peau',
                'Lambeau de transposition',
              ],
            ),
          ],
        ),

        // ── Glabelle ──
        SubRegionTree(
          name: 'Glabelle',
          branches: [
            const DecisionBranch(
              criteria: SizeCriteria.all,
              techniques: [
                'Suture simple',
                'Lambeau en H',
                'Lambeau en hélice',
              ],
            ),
          ],
        ),

        // ── Tempe ──
        SubRegionTree(
          name: 'Tempe',
          branches: [
            const DecisionBranch(
              criteria: SizeCriteria.lessThan2cm,
              techniques: ['Suture simple'],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.greaterThan2cmDistanceCheveux,
              techniques: ['Lambeau LLL', 'Greffe de peau', 'Lambeau en H'],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.greaterThan2cmLisiereCheveux,
              techniques: ['Lambeau Liftant', 'Lambeau VY'],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.etendue,
              techniques: ['Greffe de peau'],
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // MENTON
  // ═══════════════════════════════════════════════════════════

  ZoneDecisionTree _buildMentonTree() {
    return ZoneDecisionTree(
      zone: ReconstructionZone.menton,
      subRegions: [
        SubRegionTree(
          name: 'Menton',
          branches: [
            const DecisionBranch(
              criteria: SizeCriteria.lessThan2cm,
              techniques: ['Suture simple'],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.greaterThan2cm,
              techniques: ['Lambeau LLL'],
            ),
            const DecisionBranch(
              criteria: SizeCriteria.etendue,
              techniques: ['Bilobé', 'Greffe de peau'],
            ),
          ],
        ),
      ],
    );
  }
}
