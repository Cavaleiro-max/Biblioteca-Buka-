// models/modelo_de_nota.dart
// Modelo de uma anotação feita pelo utilizador durante a leitura

import 'package:hive/hive.dart';

part 'modelo_de_nota.g.dart';

@HiveType(typeId: 1)
class ModeloDeNota extends HiveObject {

  // Título do livro a que esta anotação pertence
  @HiveField(0)
  final String tituloLivro;

  // Número da página onde foi feita a anotação
  @HiveField(1)
  final int pagina;

  // Cor da marcação guardada em hexadecimal (ex: "ffff00" = amarelo)
  @HiveField(2)
  final String corHex;

  // Texto da nota escrito pelo utilizador (pode estar vazio)
  @HiveField(3)
  final String? nota;

  // Data em que foi criada a anotação
  @HiveField(4)
  final DateTime dataCriacao;

  ModeloDeNota({
    required this.tituloLivro,
    required this.pagina,
    required this.corHex,
    this.nota,
    required this.dataCriacao,
  });
}
