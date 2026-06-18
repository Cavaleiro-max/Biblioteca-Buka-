// GENERATED CODE — corrigido manualmente
// CORRECÇÃO: O adapter original só escrevia 6 campos (writeByte(6))
//            mas o modelo tem 8 campos (0..7), incluindo titulo e autor.
//            Corrected: writeByte(8) e leitura/escrita dos campos 6 e 7.

part of 'livros_locais.dart';

class LivrosLocaisAdapter extends TypeAdapter<LivrosLocais> {
  @override
  final int typeId = 0;

  @override
  LivrosLocais read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LivrosLocais(
      id: fields[0] as String,
      esta_favorito: fields[1] as bool,
      esta_baixado: fields[2] as bool,
      caminholocal: fields[3] as String?,
      ultimaPage: fields[4] as int,
      notas: (fields[5] as List).cast<ModeloDeNota>(),
      // Campos novos — lidos com fallback null para bases de dados antigas
      titulo: fields[6] as String?,
      autor: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LivrosLocais obj) {
    writer
      ..writeByte(8) // ← era 6, agora 8 campos
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.esta_favorito)
      ..writeByte(2)
      ..write(obj.esta_baixado)
      ..writeByte(3)
      ..write(obj.caminholocal)
      ..writeByte(4)
      ..write(obj.ultimaPage)
      ..writeByte(5)
      ..write(obj.notas)
      ..writeByte(6)
      ..write(obj.titulo)
      ..writeByte(7)
      ..write(obj.autor);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LivrosLocaisAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
