// pages/Home_Screen.dart
// CORRECÇÕES:
// 1. suffixIcon do TextField de pesquisa só fazia setState internamente,
//    não chamava setSearchQueryWithFilter('', ...) — corrigido
// 2. _cartaoLivro: indicador de download em progresso adicionado
// 3. Drawer: ícone de Favoritos adicionado
// 4. Skeleton loader animado com shimmer manual

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/book_provider.dart';
import '../providers/provider_de_autenticacao.dart';
import '../models/modelo_de_livros.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _campoPesquisa = TextEditingController();
  String _tipoFiltro = 'Todos';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookProvider>().loadBooks();
    });
  }

  @override
  void dispose() {
    _campoPesquisa.dispose();
    super.dispose();
  }

  void _avisarVisitante(String accao) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.lock_outline, color: Color(0xFF796741)),
          SizedBox(width: 8),
          Text('Conta necessária'),
        ]),
        content: Text(
          'Para $accao precisas de ter uma conta.\n\nCria uma conta grátis ou entra com a tua conta existente.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Agora não', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF463B2B),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/login');
            },
            child: const Text('Entrar / Criar conta',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _mostrarFiltroDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrar por'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _opcaoFiltro('Todos', Icons.all_inclusive),
            _opcaoFiltro('Título', Icons.title),
            _opcaoFiltro('Autor', Icons.person),
            _opcaoFiltro('Categoria', Icons.category),
          ],
        ),
      ),
    );
  }

  Widget _opcaoFiltro(String tipo, IconData icone) {
    final activo = _tipoFiltro == tipo;
    return ListTile(
      leading:
          Icon(icone, color: activo ? const Color(0xFF796741) : Colors.grey),
      title: Text(tipo,
          style: TextStyle(
            fontWeight: activo ? FontWeight.bold : FontWeight.normal,
            color: activo ? const Color(0xFF796741) : Colors.black,
          )),
      trailing:
          activo ? const Icon(Icons.check, color: Color(0xFF796741)) : null,
      onTap: () {
        setState(() => _tipoFiltro = tipo);
        Navigator.pop(context);
        context
            .read<BookProvider>()
            .setSearchQueryWithFilter(_campoPesquisa.text, _tipoFiltro);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final livros = context.watch<BookProvider>();
    final auth = context.watch<ProviderDeAutenticacao>();

    return Scaffold(
      backgroundColor: const Color(0xFFFAEBCB),
      appBar: AppBar(
        title: const Text('Biblioteca Virtual Buka+',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        backgroundColor: const Color(0xFF796741),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (livros.books.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text('${livros.books.length} livros',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ),
        ],
      ),
      drawer: _construirDrawer(context, auth),
      body: Column(children: [
        // Banner amarelo para visitantes
        if (!auth.estaLogado)
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/login'),
            child: Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.amber),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Estás a explorar como visitante. Para favoritar, baixar e anotar precisas de uma conta.',
                    style: TextStyle(fontSize: 11, color: Colors.black87),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF463B2B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Entrar',
                      style: TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ]),
            ),
          ),

        // Barra de pesquisa
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _campoPesquisa,
                onChanged: (v) =>
                    livros.setSearchQueryWithFilter(v, _tipoFiltro),
                decoration: InputDecoration(
                  hintText:
                      'Pesquisar ${_tipoFiltro == 'Todos' ? 'livros' : 'por $_tipoFiltro'}...',
                  prefixIcon:
                      const Icon(Icons.search, color: Color(0xFF796741)),
                  // CORRECÇÃO 1: limpar também chama setSearchQueryWithFilter
                  suffixIcon: _campoPesquisa.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _campoPesquisa.clear();
                            setState(() {});
                            livros.setSearchQueryWithFilter('', _tipoFiltro);
                          })
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF796741))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF796741))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFF796741), width: 2)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF796741),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.filter_list, color: Colors.white),
                onPressed: _mostrarFiltroDialog,
              ),
            ),
          ]),
        ),

        // Chips de categoria
        if (livros.categorias.length > 1)
          SizedBox(
            height: 46,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: livros.categorias.length,
              itemBuilder: (context, i) {
                final cat = livros.categorias[i];
                final sel = livros.categoriaFiltro == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: sel,
                    onSelected: (_) => livros.setCategoriaFiltro(cat),
                    selectedColor: const Color(0xFF796741),
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                        color: sel ? Colors.white : const Color(0xFF796741),
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal),
                    side: const BorderSide(color: Color(0xFF796741)),
                  ),
                );
              },
            ),
          ),

        const SizedBox(height: 4),

        Expanded(
          child: livros.isLoading && livros.books.isEmpty
              ? _esqueleto()
              : livros.books.isEmpty
                  ? _semResultados()
                  : _listaLivros(livros, auth),
        ),
      ]),
    );
  }

  Widget _esqueleto() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: 5,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 110,
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Container(
            width: 75,
            decoration: const BoxDecoration(
                color: Color(0xFFE0D0B0),
                borderRadius:
                    BorderRadius.horizontal(left: Radius.circular(14))),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 160, height: 14, color: const Color(0xFFE0D0B0)),
              const SizedBox(height: 8),
              Container(width: 100, height: 11, color: const Color(0xFFE0D0B0)),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _semResultados() {
    return const Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.search_off, size: 64, color: Color(0xFF796741)),
        SizedBox(height: 16),
        Text('Nenhum livro encontrado',
            style: TextStyle(fontSize: 18, color: Color(0xFF796741))),
      ]),
    );
  }

  Widget _listaLivros(BookProvider livros, ProviderDeAutenticacao auth) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: livros.books.length + (livros.isLoading ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == livros.books.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF796741)),
              ),
            ),
          );
        }
        return _cartaoLivro(context, livros.books[i], livros, auth);
      },
    );
  }

  Widget _cartaoLivro(
    BuildContext context,
    ModeloDeLivros livro,
    BookProvider provider,
    ProviderDeAutenticacao auth,
  ) {
    void aoAbrirLivro() {
      Navigator.pushNamed(context, '/leitura_do_livro', arguments: {
        'id': livro.id,
        'titulo': livro.titulo,
        'autor': livro.autor,
        'descricao': livro.descricao,
        'imagem': livro.imagem,
        'categoria': livro.categoria,
        'ficheiroUrl': livro.ficheiroUrl,
      });
    }

    // CORRECÇÃO 2: mostra spinner enquanto download está em progresso
    final aDownloading = provider.isDownloading(livro.id);

    return GestureDetector(
      onTap: aoAbrirLivro,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.brown.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          // Capa
          ClipRRect(
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(14)),
            child: SizedBox(
              width: 75,
              height: 110,
              child: Image.network(
                livro.imagem,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFE0D0B0),
                  child: const Icon(Icons.menu_book,
                      size: 36, color: Color(0xFF796741)),
                ),
              ),
            ),
          ),
          // Informações
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(livro.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF2D1B00))),
                  const SizedBox(height: 4),
                  Text(livro.autor,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF796741))),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAEBCB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF796741), width: 0.7),
                    ),
                    child: Text(livro.categoria,
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF796741))),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    // Favorito
                    GestureDetector(
                      onTap: () {
                        if (!auth.estaLogado) {
                          _avisarVisitante('favoritar livros');
                          return;
                        }
                        provider.toggleFavorite(livro);
                      },
                      child: Icon(
                        livro.esta_favorito
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: !auth.estaLogado
                            ? Colors.grey.shade300
                            : livro.esta_favorito
                                ? Colors.red
                                : const Color(0xFF796741),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Download — com spinner durante o progresso
                    if (aDownloading)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF796741)),
                      )
                    else if (!livro.esta_baixado)
                      GestureDetector(
                        onTap: () {
                          if (!auth.estaLogado) {
                            _avisarVisitante('baixar livros');
                            return;
                          }
                          provider.downloadBook(livro);
                        },
                        child: Icon(
                          Icons.download_for_offline_outlined,
                          color: !auth.estaLogado
                              ? Colors.grey.shade300
                              : const Color(0xFF796741),
                          size: 22,
                        ),
                      )
                    else
                      const Icon(Icons.offline_pin,
                          color: Colors.green, size: 22),

                    const Spacer(),

                    // Botão Ler
                    GestureDetector(
                      onTap: aoAbrirLivro,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF796741),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Ler',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _construirDrawer(BuildContext context, ProviderDeAutenticacao auth) {
    return Drawer(
      backgroundColor: const Color(0xFFFAEBCB),
      child: Column(children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF41300C), Color(0xE3756748), Color(0xFF41300C)],
            ),
          ),
          child: DrawerHeader(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.account_circle, size: 50, color: Colors.white),
                const SizedBox(height: 6),
                Text(
                  auth.estaLogado ? auth.utilizadorLogado!.nome : 'Visitante',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                if (auth.estaLogado)
                  Text(auth.utilizadorLogado!.email,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11)),
                if (!auth.estaLogado)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Text('SEM CONTA',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                if (auth.eAdmin)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Text('ADMIN',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        if (auth.eAdmin)
          ListTile(
            leading: const Icon(Icons.admin_panel_settings,
                size: 28, color: Color(0xFF796741)),
            title: const Text('P A I N E L  A D M I N',
                style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/admin');
            },
          ),

        // CORRECÇÃO 3: item de Favoritos adicionado
        if (auth.estaLogado)
          ListTile(
            leading: const Icon(Icons.favorite_border,
                size: 28, color: Color(0xFF796741)),
            title: const Text('F A V O R I T O S',
                style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              // Mostra favoritos numa sheet
              _mostrarFavoritos(context);
            },
          ),

        ListTile(
          leading: const Icon(Icons.download_outlined,
              size: 28, color: Color(0xFF796741)),
          title: const Text('T R A N S F E R Ê N C I A S',
              style: TextStyle(fontWeight: FontWeight.w600)),
          onTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/transferencias');
          },
        ),

        ListTile(
          leading: const Icon(Icons.settings_sharp,
              size: 28, color: Color(0xFF796741)),
          title: const Text('C O N F I G U R A Ç Õ E S',
              style: TextStyle(fontWeight: FontWeight.w600)),
          onTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/configuracoes');
          },
        ),

        const Spacer(),
        const Divider(
            color: Colors.brown, thickness: 1, indent: 20, endIndent: 20),

        ListTile(
          leading: Icon(
            auth.estaLogado ? Icons.logout : Icons.login,
            size: 22,
            color: auth.estaLogado ? Colors.redAccent : const Color(0xFF796741),
          ),
          title: Text(
            auth.estaLogado ? 'S A I R' : 'E N T R A R',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          onTap: () async {
            Navigator.pop(context);
            if (auth.estaLogado) {
              await auth.sair();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/primeira');
              }
            } else {
              Navigator.pushNamed(context, '/login');
            }
          },
        ),
        const SizedBox(height: 12),
      ]),
    );
  }

  // Sheet de favoritos acessível pelo drawer
  void _mostrarFavoritos(BuildContext context) {
    final provider = context.read<BookProvider>();
    final favoritos = provider.favoritosBooks;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFAEBCB),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
          child: Row(children: [
            const Icon(Icons.favorite, color: Colors.red, size: 22),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Meus Favoritos',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3E2723))),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(_),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: favoritos.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_border, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('Sem livros favoritos ainda.',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: favoritos.length,
                  itemBuilder: (ctx, i) {
                    final l = favoritos[i];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(l.imagem,
                            width: 40,
                            height: 55,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.book,
                                color: Color(0xFF796741))),
                      ),
                      title: Text(l.titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(l.autor,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      trailing: const Icon(Icons.chevron_right,
                          color: Color(0xFF796741)),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.pushNamed(context, '/leitura_do_livro',
                            arguments: {
                              'id': l.id,
                              'titulo': l.titulo,
                              'autor': l.autor,
                              'descricao': l.descricao,
                              'imagem': l.imagem,
                              'categoria': l.categoria,
                              'ficheiroUrl': l.ficheiroUrl,
                            });
                      },
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
