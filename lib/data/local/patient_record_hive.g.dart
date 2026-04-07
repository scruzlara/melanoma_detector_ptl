// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patient_record_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

/// Adaptateur Hive auto-généré pour [PatientRecordHive].
class PatientRecordHiveAdapter extends TypeAdapter<PatientRecordHive> {
  @override
  final int typeId = 1;

  @override
  PatientRecordHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PatientRecordHive(
      id: fields[0] as String,
      nom: fields[1] as String,
      prenom: fields[2] as String,
      dateNaissanceMs: fields[3] as int?,
      notes: fields[4] as String?,
      dateCreationMs: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, PatientRecordHive obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nom)
      ..writeByte(2)
      ..write(obj.prenom)
      ..writeByte(3)
      ..write(obj.dateNaissanceMs)
      ..writeByte(4)
      ..write(obj.notes)
      ..writeByte(5)
      ..write(obj.dateCreationMs);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatientRecordHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
