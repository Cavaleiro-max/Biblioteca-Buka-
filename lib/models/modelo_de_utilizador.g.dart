// GENERATED CODE - NÃO MODIFICAR
// models/modelo_de_utilizador.g.dart

part of 'modelo_de_utilizador.dart';

class ModeloDeUtilizadorAdapter extends TypeAdapter<ModeloDeUtilizador> {
  @override
  final int typeId = 2;

  @override
  ModeloDeUtilizador read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ModeloDeUtilizador(
      id: fields[0] as String,
      nome: fields[1] as String,
      email: fields[2] as String,
      tipo: fields[3] as String,
      dataCriacao: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ModeloDeUtilizador obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nome)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.tipo)
      ..writeByte(4)
      ..write(obj.dataCriacao);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModeloDeUtilizadorAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
