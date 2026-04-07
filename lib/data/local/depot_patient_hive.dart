import 'package:hive_flutter/hive_flutter.dart';
import 'patient_record_hive.dart';

/// Dépôt Hive pour la gestion des dossiers patients.
///
/// Couche données — fournit les opérations CRUD sur les dossiers patients
/// stockés localement via Hive. Chaque patient est identifié par un [id]
/// unique et peut être lié à des analyses via cet identifiant.
///
/// Utilisation :
/// ```dart
/// final depot = DepotPatientHive();
/// await depot.initialiser();
/// await depot.ajouterPatient(patient);
/// final patients = await depot.obtenirTousLesPatients();
/// ```
class DepotPatientHive {
  /// Nom de la boîte Hive pour les patients.
  static const String _nomBoite = 'patients';

  /// Boîte Hive typée (initialisée dans [initialiser]).
  Box<PatientRecordHive>? _boite;

  /// Initialise la boîte Hive pour les patients.
  ///
  /// Doit être appelé une seule fois au démarrage, après
  /// l'enregistrement de l'adaptateur [PatientRecordHiveAdapter].
  Future<void> initialiser() async {
    _boite = await Hive.openBox<PatientRecordHive>(_nomBoite);
  }

  /// Ajoute ou met à jour un dossier patient.
  ///
  /// Utilise l'[id] du patient comme clé Hive pour permettre
  /// les mises à jour sans duplication.
  Future<void> ajouterPatient(PatientRecordHive patient) async {
    await _boite?.put(patient.id, patient);
  }

  /// Récupère un patient par son [id].
  ///
  /// Retourne `null` si aucun patient ne correspond.
  PatientRecordHive? obtenirPatient(String id) {
    return _boite?.get(id);
  }

  /// Récupère tous les dossiers patients enregistrés.
  ///
  /// Les patients sont retournés dans l'ordre d'insertion Hive.
  List<PatientRecordHive> obtenirTousLesPatients() {
    return _boite?.values.toList() ?? [];
  }

  /// Supprime un dossier patient par son [id].
  ///
  /// Note : cette opération ne supprime pas les analyses associées.
  /// Les analyses orphelines restent accessibles dans leur propre dépôt.
  Future<void> supprimerPatient(String id) async {
    await _boite?.delete(id);
  }

  /// Recherche les patients dont le nom ou prénom contient [terme].
  ///
  /// La recherche est insensible à la casse.
  List<PatientRecordHive> rechercherPatients(String terme) {
    final termeLower = terme.toLowerCase();
    return obtenirTousLesPatients()
        .where(
          (p) =>
              p.nom.toLowerCase().contains(termeLower) ||
              p.prenom.toLowerCase().contains(termeLower),
        )
        .toList();
  }

  /// Nombre total de patients enregistrés.
  int get nombrePatients => _boite?.length ?? 0;
}
