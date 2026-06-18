// providers/book_provider.dart
//
// CORRECÇÃO — ISOLAMENTO POR UTILIZADOR:
// Todos os acessos ao ServicosLivrosLocais agora passam o userId.
// Isto garante que nas Transferências cada utilizador só vê
// os seus próprios livros baixados, mesmo partilhando o mesmo dispositivo.
//
// INTEGRAÇÃO COM O REPOSITÓRIO (Repos.dart):
// O BookRepository.getBooks(), colocaFavorito() e baixaLivro()
// também precisam de receber o userId — ver comentários abaixo.
// Se o teu Repos.dart ainda não tem userId, adiciona o parâmetro
// conforme indicado nos métodos loadBooks(), toggleFavorite() e downloadBook().

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/modelo_de_livros.dart';
import '../service/Armazenamento_remoto/servicos_de_livros_remotos.dart';
import '../service/Armazenamento_Local/servicos_de_livros_locais.dart';
import '../service/Armazenamento_Local/download_service.dart';
import '../Repositorios/Repos.dart';

class BookProvider extends ChangeNotifier {
  late final BookRepository _repository;

  List<modelo_de_livros> _livros = [];
  List<modelo_de_livros> _livrosFiltrados = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _tipoFiltro = 'Todos';
  String _categoriaFiltro = 'Todos';

  // Mapa para rastrear progresso de download individual
  final Map<String, bool> _downloadingBooks = {};

  BookProvider() {
    _repository = BookRepository(
      remote: ServicosLivrosRemotos(),
      local: ServicosLivrosLocais(),
      downloader: DownloadService(),
    );
  }

  // ── UID do utilizador actualmente autenticado ─────────────────────────────
  // Fallback para 'anonimo' se não houver sessão (nunca deve acontecer em uso normal)
  String get _userId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'anonimo';

  // ── Getters ───────────────────────────────────────────────────────────────
  List<modelo_de_livros> get books =>
      _livrosFiltrados.isEmpty &&
              _searchQuery.isEmpty &&
              _categoriaFiltro == 'Todos'
          ? _livros
          : _livrosFiltrados;

  List<modelo_de_livros> get downloadedBooks =>
      _livros.where((b) => b.esta_baixado).toList();

  List<modelo_de_livros> get favoritosBooks =>
      _livros.where((b) => b.esta_favorito).toList();

  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get tipoFiltro => _tipoFiltro;
  String get categoriaFiltro => _categoriaFiltro;

  bool isDownloading(String bookId) => _downloadingBooks[bookId] == true;

  List<String> get categorias {
    final cats = _livros.map((book) => book.categoria).toSet().toList();
    cats.sort();
    return ['Todos', ...cats];
  }

  // ── Carregar livros (estado local por utilizador) ─────────────────────────
  Future<void> loadBooks() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Passa o userId para que o repositório filtre os dados locais correctamente
      // Se o teu Repos.dart ainda não aceita userId, adiciona:
      //   Future<List<ModeloDeLivros>> getBooks(String userId)
      // e passa para ServicosLivrosLocais.getAll(userId)
      final livros = await _repository.getBooks(_userId);
      _livros.clear();

      const batchSize = 5;
      for (int i = 0; i < livros.length; i += batchSize) {
        final end =
            (i + batchSize < livros.length) ? i + batchSize : livros.length;
        _livros.addAll(livros.sublist(i, end));
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 16));
      }

      _aplicarFiltros();
    } catch (e) {
      debugPrint("Erro ao carregar livros: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Filtros ───────────────────────────────────────────────────────────────
  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase();
    _aplicarFiltros();
    notifyListeners();
  }

  void setSearchQueryWithFilter(String query, String tipo) {
    _searchQuery = query.toLowerCase();
    _tipoFiltro = tipo;
    _aplicarFiltros();
    notifyListeners();
  }

  void setCategoriaFiltro(String categoria) {
    _categoriaFiltro = categoria;
    _aplicarFiltros();
    notifyListeners();
  }

  void _aplicarFiltros() {
    _livrosFiltrados = _livros.where((book) {
      final categoriaMatch =
          _categoriaFiltro == 'Todos' || book.categoria == _categoriaFiltro;

      if (_searchQuery.isEmpty) return categoriaMatch;

      bool searchMatch = false;
      switch (_tipoFiltro) {
        case 'Título':
          searchMatch = book.titulo.toLowerCase().contains(_searchQuery);
          break;
        case 'Autor':
          searchMatch = book.autor.toLowerCase().contains(_searchQuery);
          break;
        case 'Categoria':
          searchMatch = book.categoria.toLowerCase().contains(_searchQuery);
          break;
        default:
          searchMatch = book.titulo.toLowerCase().contains(_searchQuery) ||
              book.autor.toLowerCase().contains(_searchQuery) ||
              book.descricao.toLowerCase().contains(_searchQuery) ||
              book.categoria.toLowerCase().contains(_searchQuery);
      }

      return categoriaMatch && searchMatch;
    }).toList();
  }

  // ── Favoritos ─────────────────────────────────────────────────────────────
  Future<void> toggleFavorite(modelo_de_livros livro) async {
    try {
      await _repository.colocaFavorito(livro, _userId);
      notifyListeners();
    } catch (e) {
      debugPrint("Erro ao favoritar: $e");
    }
  }

  // ── Download ──────────────────────────────────────────────────────────────
  Future<void> downloadBook(modelo_de_livros livro) async {
    if (_downloadingBooks[livro.id] == true) return;

    _downloadingBooks[livro.id] = true;
    notifyListeners();

    try {
      await _repository.baixaLivro(livro, _userId);
    } catch (e) {
      debugPrint("Erro ao baixar livro: $e");
    } finally {
      _downloadingBooks.remove(livro.id);
      notifyListeners();
    }
  }

  // ── Limpar estado ao fazer logout ─────────────────────────────────────────
  // Chama este método no ProviderDeAutenticacao.terminarSessao()
  // para que a lista de livros seja limpa e não fique visível ao próximo utilizador
  void limparAoSair() {
    _livros.clear();
    _livrosFiltrados.clear();
    _searchQuery = '';
    _categoriaFiltro = 'Todos';
    _tipoFiltro = 'Todos';
    _downloadingBooks.clear();
    notifyListeners();
  }
}