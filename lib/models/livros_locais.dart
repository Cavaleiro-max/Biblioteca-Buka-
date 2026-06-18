// models/livros_locais.dart
// Modelo do livro guardado localmente no Hive.
// Guarda favoritos, downloads e o caminho local do PDF.
// ACTUALIZADO: adicionados campos 'titulo' e 'autor' para mostrar livros offline.

import 'package:hive/hive.dart';
import 'modelo_de_nota.dart';

part 'livros_locais.g.dart';

@HiveType(typeId: 0)
class LivrosLocais extends HiveObject {

  @HiveField(0)
  String id;

  @HiveField(1)
  bool esta_favorito;

  @HiveField(2)
  bool esta_baixado;

  // Caminho local do PDF no dispositivo (ex: /data/.../livro.pdf)
  @HiveField(3)
  String? caminholocal;

  @HiveField(4)
  int ultimaPage;

  @HiveField(5)
  List<ModeloDeNota> notas;

  // Campos novos para mostrar o livro mesmo offline
  @HiveField(6)
  String? titulo;

  @HiveField(7)
  String? autor;

  LivrosLocais({
    required this.id,
    this.esta_favorito = false,
    this.esta_baixado  = false,
    this.caminholocal,
    this.ultimaPage    = 0,
    this.notas         = const [],
    this.titulo,
    this.autor,
  });
}
