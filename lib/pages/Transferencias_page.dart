// pages/Transferencias_page.dart
//
// CORRECÇÕES:
// 1. Rota '/leitura_do_livro' espera Map<String,dynamic> mas estava a receber
//    um objeto modelo_de_livros — corrigido para passar toMap() + 'id'
// 2. Card com ListTile envolvido em Material para evitar
//    "ink splashes may be invisible" quando o Card tem cor de fundo
// 3. Filtro de pesquisa inicializado correctamente via initState

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../providers/book_provider.dart';
import '../models/livros_locais.dart';
import '../models/modelo_de_livros.dart';
import 'package:hive/hive.dart';

class TransferenciasPage extends StatefulWidget {
  const TransferenciasPage({super.key});

  @override
  State<TransferenciasPage> createState() => _TransferenciasPageState();
}

class _TransferenciasPageState extends State<TransferenciasPage> {
  final TextEditingController _searchController = TextEditingController();
  List<modelo_de_livros>      _livrosFiltrados  = [];
  // Guarda a última lista para comparar mudanças
  List<modelo_de_livros>      _ultimaListaBase  = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filtrarLivros(List<modelo_de_livros> livros, String query) {
    if (query.isEmpty) {
      setState(() => _livrosFiltrados = livros);
      return;
    }
    final queryLower = query.toLowerCase();
    setState(() {
      _livrosFiltrados = livros.where((book) {
        return book.titulo.toLowerCase().contains(queryLower) ||
               book.autor.toLowerCase().contains(queryLower);
      }).toList();
    });
  }

  Future<void> _removerDownload(
      BuildContext context, String bookId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title:   const Text('Remover Download'),
        content: const Text(
            'Tem certeza que deseja remover este livro baixado?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final box       = Hive.box<LivrosLocais>('caixa_livros');
      final localBook = box.get(bookId);

      if (localBook != null && localBook.caminholocal != null) {
        final file = File(localBook.caminholocal!);
        if (await file.exists()) await file.delete();

        localBook.esta_baixado  = false;
        localBook.caminholocal  = null;
        await localBook.save();

        if (mounted) {
          context.read<BookProvider>().loadBooks();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:         Text('Livro removido com sucesso'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:         Text('Erro ao remover: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatarTamanho(String? caminho) {
    if (caminho == null) return 'Tamanho desconhecido';
    try {
      final file  = File(caminho);
      final bytes = file.lengthSync();
      if (bytes < 1024)          return '$bytes B';
      if (bytes < 1024 * 1024)   return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return 'Tamanho desconhecido';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider        = context.watch<BookProvider>();
    final downloadedBooks = provider.downloadedBooks;

    // Actualiza a lista filtrada quando a lista base muda
    if (_ultimaListaBase.length != downloadedBooks.length ||
        !_listasIguais(_ultimaListaBase, downloadedBooks)) {
      _ultimaListaBase = List.from(downloadedBooks);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _filtrarLivros(downloadedBooks, _searchController.text);
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAEBCB),
      appBar: AppBar(
        title:           const Text('Transferências'),
        backgroundColor: const Color(0xFFA58D5A),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Barra de pesquisa — só aparece se houver livros baixados
          if (downloadedBooks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => _filtrarLivros(downloadedBooks, v),
                decoration: InputDecoration(
                  hintText: 'Pesquisar livros baixados...',
                  prefixIcon:
                      const Icon(Icons.search, color: Color(0xFFA58D5A)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _filtrarLivros(downloadedBooks, '');
                          },
                        )
                      : null,
                  filled:    true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFA58D5A)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFA58D5A)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFFA58D5A), width: 2),
                  ),
                ),
              ),
            ),

          // Lista
          Expanded(
            child: downloadedBooks.isEmpty
                ? _ecraSemDownloads()
                : _livrosFiltrados.isEmpty
                    ? _ecraSemResultados()
                    : _listaLivros(),
          ),
        ],
      ),
    );
  }

  Widget _ecraSemDownloads() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.download_outlined,
              size: 64, color: Color(0xFF796741)),
          SizedBox(height: 16),
          Text('Nenhum livro baixado',
              style: TextStyle(fontSize: 18, color: Color(0xFF796741))),
          SizedBox(height: 8),
          Text('Baixe livros para ler offline',
              style: TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _ecraSemResultados() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Color(0xFF796741)),
          SizedBox(height: 16),
          Text('Nenhum livro encontrado',
              style: TextStyle(fontSize: 18, color: Color(0xFF796741))),
        ],
      ),
    );
  }

  Widget _listaLivros() {
    return ListView.builder(
      padding:   const EdgeInsets.all(12),
      itemCount: _livrosFiltrados.length,
      itemBuilder: (context, index) {
        final book      = _livrosFiltrados[index];
        final box       = Hive.box<LivrosLocais>('caixa_livros');
        final localBook = box.get(book.id);
        final fileSize  = _formatarTamanho(localBook?.caminholocal);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          // CORRECÇÃO: Material dentro do Card para que os ink splashes
          // do ListTile funcionem correctamente
          child: Material(
            color:        Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.all(12),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  book.imagem,
                  width:  50,
                  height: 70,
                  fit:    BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width:  50,
                    height: 70,
                    color:  Colors.grey[300],
                    child:  const Icon(Icons.book, color: Colors.grey),
                  ),
                ),
              ),
              title: Text(
                book.titulo,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
                maxLines:  2,
                overflow:  TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(book.autor,
                      style: const TextStyle(
                          fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.storage,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(fileSize,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ]),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red),
                    onPressed: () =>
                        _removerDownload(context, book.id),
                    tooltip: 'Remover download',
                  ),
                  const Icon(Icons.chevron_right,
                      color: Color(0xFF796741)),
                ],
              ),
              // CORRECÇÃO: converte o modelo para Map<String, dynamic>
              // que é o que a rota '/leitura_do_livro' espera receber
              onTap: () => Navigator.pushNamed(
                context,
                '/leitura_do_livro',
                arguments: {
                  ...book.toMap(),
                  'id': book.id,
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // Compara se duas listas têm os mesmos IDs (evita rebuilds desnecessários)
  bool _listasIguais(
      List<modelo_de_livros> a, List<modelo_de_livros> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }
}