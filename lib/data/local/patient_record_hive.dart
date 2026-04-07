import 'package:hive/hive.dart';

part 'patient_record_hive.g.dart';

/// Modèle Hive pour la persistance des dossiers patients.
///
/// Couche données — stocke les informations de base d'un patient
/// pour regrouper les analyses par patient dans l'historique.
///
/// Chaque patient peut avoir plusieurs analyses associées via
/// son [id] (référencé dans les analyses via un champ `patientId`).
@HiveType(typeId: 1)
class PatientRecordHive extends HiveObject {
  /// Identifiant unique du patient (UUID ou timestamp).
  @HiveField(0)
  final String id;

  /// Nom de famille du patient.
  @HiveField(1)
  final String nom;

  /// Prénom du patient.
  @HiveField(2)
  final String prenom;

  /// Date de naissance (millisecondes depuis epoch, nullable).
  @HiveField(3)
  final int? dateNaissanceMs;

  /// Notes libres sur le patient (antécédents, observations).
  @HiveField(4)
  final String? notes;

  /// Date de création du dossier (millisecondes depuis epoch).
  @HiveField(5)
  final int dateCreationMs;

  PatientRecordHive({
    required this.id,
    required this.nom,
    required this.prenom,
    this.dateNaissanceMs,
    this.notes,
    required this.dateCreationMs,
  });

  /// Date de naissance convertie en [DateTime] (nullable).
  DateTime? get dateNaissance =>
      dateNaissanceMs != null
          ? DateTime.fromMillisecondsSinceEpoch(dateNaissanceMs!)
          : null;

  /// Date de création convertie en [DateTime].
  DateTime get dateCreation =>
      DateTime.fromMillisecondsSinceEpoch(dateCreationMs);

  /// Nom complet du patient (prénom + nom).
  String get nomComplet => '$prenom $nom';
}
