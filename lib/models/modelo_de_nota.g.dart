// GENERATED CODE - NÃO MODIFICAR MANUALMENTE
// models/modelo_de_nota.g.dart

part of 'modelo_de_nota.dart';

class ModeloDeNotaAdapter extends TypeAdapter<ModeloDeNota> {
  @override
  final int typeId = 1;

  @override
  ModeloDeNota read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ModeloDeNota(
      tituloLivro: fields[0] as String,
      pagina:      fields[1] as int,
      corHex:      fields[2] as String,
      nota:        fields[3] as String?,
      dataCriacao: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ModeloDeNota obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.tituloLivro)
      ..writeByte(1)
      ..write(obj.pagina)
      ..writeByte(2)
      ..write(obj.corHex)
      ..writeByte(3)
      ..write(obj.nota)
      ..writeByte(4)
      ..write(obj.dataCriacao);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModeloDeNotaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
