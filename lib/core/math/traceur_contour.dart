/// Traceur de contour par l'algorithme de Moore-Neighbor.
///
/// Couche algorithmique pure Dart — aucune dépendance Flutter ni IA.
///
/// L'algorithme explore les 8 voisins d'un pixel de premier plan
/// en sens horaire pour tracer le contour d'une forme binaire.
///
/// **Complexité :**
/// - Temporelle : O(P) où P = périmètre de la forme.
/// - Spatiale : O(P) pour stocker les points du contour.
///
/// **Optimisation clé :** la recherche de direction utilise une
/// table de correspondance O(1) au lieu de 8 branchements if-else.
class TraceurContour {
  TraceurContour._();

  // -------------------------------------------------------------------------
  // Tables de correspondance O(1) pour les 8 voisins
  // -------------------------------------------------------------------------

  /// Décalages X des 8 voisins (sens horaire depuis le haut).
  ///
  /// Index 0 = haut, 1 = haut-droite, 2 = droite, 3 = bas-droite,
  /// 4 = bas, 5 = bas-gauche, 6 = gauche, 7 = haut-gauche.
  static const _ox = [0, 1, 1, 1, 0, -1, -1, -1];

  /// Décalages Y des 8 voisins (sens horaire depuis le haut).
  static const _oy = [-1, -1, 0, 1, 1, 1, 0, -1];

  /// Obtient la direction d'un voisin via une table de lookup O(1).
  ///
  /// Encodage : `(dX + 1) * 3 + (dY + 1)` → index dans la table.
  /// Cela transforme les 8 combinaisons de (dX, dY) ∈ {-1, 0, 1}²
  /// en un index linéaire [0..8], évitant toute chaîne de if-else.
  ///
  /// Retourne la direction [0..7] correspondant au voisin (dX, dY),
  /// ou -1 si (dX, dY) = (0, 0) (pixel courant, invalide).
  static int obtenirDirection(int dX, int dY) {
    const table = [7, 6, 5, 0, -1, 4, 1, 2, 3];
    final index = (dX + 1) * 3 + (dY + 1);
    return table[index];
  }

  /// Extrait le contour d'un masque binaire via Moore-Neighbor.
  ///
  /// [masque] — Masque plat (hauteur × largeur) de valeurs flottantes,
  ///   issu de la sortie du modèle de segmentation.
  /// [largeur] / [hauteur] — Dimensions du masque en pixels.
  /// [seuil] — Seuil de binarisation (> seuil = premier plan).
  /// [maxPointsSortie] — Nombre maximal de points dans le contour simplifié.
  ///
  /// Retourne une liste de points normalisés `[x/largeur, y/hauteur]`,
  /// ou `null` si aucun pixel de premier plan n'est trouvé.
  ///
  /// L'algorithme :
  /// 1. Balaye le masque ligne par ligne pour trouver le premier pixel.
  /// 2. À partir de ce pixel, parcourt les voisins en sens horaire
  ///    en commençant par la direction du dernier pixel d'arrière-plan.
  /// 3. S'arrête lorsqu'il revient au pixel de départ.
  /// 4. Simplifie le contour à ~[maxPointsSortie] points par sous-échantillonnage.
  static List<List<double>>? extraireContour(
    List<double?> masque,
    int largeur,
    int hauteur, {
    double seuil = 0.0,
    int maxPointsSortie = 300,
  }) {
    /// Vérifie si un pixel appartient au premier plan.
    bool estPremierPlan(int x, int y) {
      if (x < 0 || x >= largeur || y < 0 || y >= hauteur) return false;
      final val = masque[y * largeur + x] ?? 0.0;
      return val > seuil;
    }

    // Recherche du premier pixel de premier plan (balayage raster)
    int debutX = -1;
    int debutY = -1;
    for (int y = 0; y < hauteur; y++) {
      for (int x = 0; x < largeur; x++) {
        if (estPremierPlan(x, y)) {
          debutX = x;
          debutY = y;
          break;
        }
      }
      if (debutX != -1) break;
    }

    if (debutX == -1) return null;

    // Traçage de Moore-Neighbor
    final contour = <List<double>>[];
    contour.add([debutX / largeur, debutY / hauteur]);

    int px = debutX;
    int py = debutY;
    int bx = debutX - 1; // Premier backtrack : voisin gauche
    int by = debutY;

    final maxPoints = largeur * hauteur; // Garde-fou anti-boucle infinie

    do {
      bool suivantTrouve = false;
      final dirDepart = obtenirDirection(bx - px, by - py);

      for (int i = 0; i < 8; i++) {
        final dir = (dirDepart + i) % 8;
        final nx = px + _ox[dir];
        final ny = py + _oy[dir];

        if (estPremierPlan(nx, ny)) {
          // Le backtrack devient le voisin précédent (sens anti-horaire)
          final bDir = (dir - 1 + 8) % 8;
          bx = px + _ox[bDir];
          by = py + _oy[bDir];
          px = nx;
          py = ny;
          contour.add([px / largeur, py / hauteur]);
          suivantTrouve = true;
          break;
        }
      }

      if (!suivantTrouve) break;
      if (contour.length > maxPoints) break;
    } while (px != debutX || py != debutY);

    // Simplification par sous-échantillonnage régulier
    if (contour.length > maxPointsSortie) {
      final simple = <List<double>>[];
      final pas = (contour.length / maxPointsSortie).ceil();
      for (int i = 0; i < contour.length; i += pas) {
        simple.add(contour[i]);
      }
      return simple;
    }
    return contour;
  }
}
