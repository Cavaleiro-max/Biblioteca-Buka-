// models/modelo_de_livros.dart
// CORRECÇÃO 1: Nome da classe mudado de 'modelo_de_livros' para 'ModeloDeLivros'
//              (convenção Dart: classes em PascalCase)
// CORRECÇÃO 2: Adicionado método copyWith para facilitar actualizações de estado
// CORRECÇÃO 3: Adicionado factory fromFirestore como alias claro do fromMap

class ModeloDeLivros {
  final String id;
  final String titulo;
  final String autor;
  final String descricao;
  final String imagem;
  final String categoria;
  final String ficheiroUrl;
  int downloads;
  bool esta_favorito;
  bool esta_baixado;

  ModeloDeLivros({
    required this.id,
    required this.titulo,
    required this.autor,
    required this.descricao,
    required this.imagem,
    required this.categoria,
    required this.ficheiroUrl,
    this.downloads = 0,
    this.esta_favorito = false,
    this.esta_baixado = false,
  });

  factory ModeloDeLivros.fromMap(Map<String, dynamic> data, String docId) {
    return ModeloDeLivros(
      id: docId,
      titulo: data['titulo'] ?? '',
      autor: data['autor'] ?? '',
      descricao: data['descricao'] ?? '',
      imagem: data['imagem'] ?? '',
      categoria: data['categoria'] ?? '',
      ficheiroUrl: data['ficheiroUrl'] ?? '',
      downloads: (data['downloads'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'autor': autor,
      'descricao': descricao,
      'imagem': imagem,
      'categoria': categoria,
      'ficheiroUrl': ficheiroUrl,
      'downloads': downloads,
    };
  }

  // CORRECÇÃO 2: copyWith facilita actualizar só alguns campos
  ModeloDeLivros copyWith({
    bool? esta_favorito,
    bool? esta_baixado,
    int? downloads,
  }) {
    return ModeloDeLivros(
      id: id,
      titulo: titulo,
      autor: autor,
      descricao: descricao,
      imagem: imagem,
      categoria: categoria,
      ficheiroUrl: ficheiroUrl,
      downloads: downloads ?? this.downloads,
      esta_favorito: esta_favorito ?? this.esta_favorito,
      esta_baixado: esta_baixado ?? this.esta_baixado,
    );
  }
}

// COMPATIBILIDADE: alias do nome antigo para não quebrar ficheiros ainda não actualizados
typedef modelo_de_livros = ModeloDeLivros;
