// GENERATED CODE — DO NOT MODIFY BY HAND
// Adaptateur Hive écrit manuellement (équivalent de build_runner).

part of 'modele_analyse_hive.dart';

/// Adaptateur Hive pour [ModeleAnalyseHive].
///
/// TypeId = 0. Sérialise/désérialise les 11 champs du DTO.
class ModeleAnalyseHiveAdapter extends TypeAdapter<ModeleAnalyseHive> {
  @override
  final int typeId = 0;

  @override
  ModeleAnalyseHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ModeleAnalyseHive(
      id: fields[0] as String,
      cheminImageOriginale: fields[1] as String,
      contoursJson: fields[2] as String?,
      resultatClassification: fields[3] as String,
      probMalignant: fields[4] as double,
      confiance: fields[5] as double,
      metriquesGeometriquesJson: fields[6] as String,
      nomModele: fields[7] as String,
      notes: fields[8] as String?,
      horodatageMs: fields[9] as int,
      resultJsonCompletStr: fields[10] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ModeleAnalyseHive obj) {
    writer
      ..writeByte(11) // nombre de champs
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.cheminImageOriginale)
      ..writeByte(2)
      ..write(obj.contoursJson)
      ..writeByte(3)
      ..write(obj.resultatClassification)
      ..writeByte(4)
      ..write(obj.probMalignant)
      ..writeByte(5)
      ..write(obj.confiance)
      ..writeByte(6)
      ..write(obj.metriquesGeometriquesJson)
      ..writeByte(7)
      ..write(obj.nomModele)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.horodatageMs)
      ..writeByte(10)
      ..write(obj.resultJsonCompletStr);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModeleAnalyseHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
