// Repositorios/Repos.dart
// Liga o serviço remoto (Firebase) com o armazenamento local (Hive).
//
// FUNCIONAMENTO OFFLINE:
// - Se há internet → busca livros do Firebase e actualiza o Hive
// - Se não há internet → usa os livros já guardados no Hive
// - Downloads ficam guardados localmente e funcionam sempre offline

import 'package:buka/service/Armazenamento_remoto/servicos_de_livros_remotos.dart';
import 'package:buka/service/Armazenamento_Local/servicos_de_livros_locais.dart';
import 'package:buka/service/Armazenamento_Local/download_service.dart';
import '../models/modelo_de_livros.dart';
import '../models/livros_locais.dart';

class BookRepository {
  final ServicosLivrosRemotos remote;
  final ServicosLivrosLocais local;
  final DownloadService downloader;

  BookRepository({
    required this.remote,
    required this.local,
    required this.downloader,
  });

  // Busca livros: tenta online, se falhar usa os guardados localmente
  Future<List<modelo_de_livros>> getBooks(String userId) async {
    List<modelo_de_livros> livrosRemotos = [];

    try {
      // Tenta buscar do Firebase
      livrosRemotos = await remote.fetchBooks();

      // Junta com o estado local (favoritos, downloads)
      for (var livro in livrosRemotos) {
        final localBook = local.getOrCreate(userId,livro.id);
        livro.esta_favorito = localBook.esta_favorito;
        livro.esta_baixado = localBook.esta_baixado;
      }
      return livrosRemotos;
    } catch (_) {
      // Sem internet — usa os livros já guardados no Hive
      // Só aparecem os que foram baixados antes
      final livrosLocais = local.getAll(userId);
      return livrosLocais
          .where((l) => l.esta_baixado && l.caminholocal != null)
          .map((l) => modelo_de_livros(
                id: l.id,
                titulo: l.titulo ?? 'Livro guardado',
                autor: l.autor ?? '',
                descricao: '',
                categoria: '',
                imagem: '',
                ficheiroUrl: l.caminholocal ?? '', // caminho local do PDF
                downloads: 0,
              )
                ..esta_baixado = true
                ..esta_favorito = l.esta_favorito)
          .toList();
    }
  }

  Future<void> colocaFavorito(modelo_de_livros livro,String userId) async {
    final livroLocal = local.getOrCreate(userId,livro.id);
    livroLocal.esta_favorito = !livroLocal.esta_favorito;
    await livroLocal.save();
    livro.esta_favorito = livroLocal.esta_favorito;
  }

  // Baixa o PDF e guarda o caminho local para leitura offline
  Future<void> baixaLivro(modelo_de_livros livro,String userId) async {
    final path = await downloader.download(livro.ficheiroUrl, livro.id);

    final livroLocal = local.getOrCreate(userId,livro.id);
    livroLocal.caminholocal = path;
    livroLocal.esta_baixado = true;
    // Guardar título e autor para mostrar offline
    livroLocal.titulo = livro.titulo;
    livroLocal.autor = livro.autor;
    await livroLocal.save();

    livro.esta_baixado = true;
  }
}
