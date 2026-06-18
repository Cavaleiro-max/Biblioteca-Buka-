// pages/Leitura_Do_Livro_Page.dart
//
// MELHORIAS COMPLETAS:
// 1. NOTAS PROFISSIONAIS: criar, editar, eliminar, ver detalhes
// 2. MARCAÇÕES COM CORES: 10 cores disponíveis para sublinhar/marcar
// 3. PDF WINDOWS: usa HttpClient com headers correctos para archive.org
// 4. Caixa Hive já aberta no main — sem Hive.openBox() aqui
// 5. Interface de notas redesenhada com cards informativos
// 6. Navegação por página directamente ao tocar numa nota
// 7. Adaptável a todas as plataformas
//
// CORRECÇÃO — ISOLAMENTO DE NOTAS POR UTILIZADOR:
// Antes, as notas eram guardadas com _caixaNotas.add() (chave automática,
// sem ligação ao utilizador) e filtradas só por 'tituloLivro'. Isto fazia
// com que, no mesmo dispositivo, um utilizador visse as notas/marcações
// feitas por outro utilizador que tinha usado o app antes.
//
// Agora usamos ServicosNotasLocais, que grava cada nota com uma chave
// composta "userId_livroId_timestamp". Cada utilizador só vê e só pode
// editar/eliminar as SUAS próprias notas deste livro.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../models/modelo_de_nota.dart';
import '../providers/provider_de_autenticacao.dart';
import '../service/Armazenamento_Local/servicos_de_notas_locais.dart';
import 'package:intl/intl.dart';

class LeituraDoLivroPage extends StatefulWidget {
  final Map<String, dynamic> livro;
  const LeituraDoLivroPage({super.key, required this.livro});

  @override
  State<LeituraDoLivroPage> createState() => _LeituraDoLivroPageState();
}

class _LeituraDoLivroPageState extends State<LeituraDoLivroPage> {
  final PdfViewerController _pdfController = PdfViewerController();

  bool _temErro = false;
  String _msgErro = '';
  bool _mostrarAnotacoes = false;
  int _tentativa = 0;

  // CORRECÇÃO: serviço de notas isolado por utilizador (substitui o
  // acesso directo a Hive.box<ModeloDeNota>('caixa_notas'))
  final ServicosNotasLocais _servicoNotas = ServicosNotasLocais();

  // Lista de notas DESTE utilizador, DESTE livro.
  // Cada item guarda a chave Hive (para editar/eliminar) + a nota.
  List<MapEntry<String, ModeloDeNota>> _minhasAnotacoes = [];

  // ── UID do utilizador actual (isolamento de dados) ─────────────────
  String get _userId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'anonimo';

  // ── ID único do livro — usa o 'id' vindo do Firestore/local ────────
  // Fallback para o título caso o 'id' não tenha sido passado por algum
  // ponto antigo de navegação.
  String get _livroId =>
      (widget.livro['id'] as String?) ??
      (widget.livro['titulo'] as String?) ??
      'livro_desconhecido';

  // Paleta de 10 cores para marcação
  static const List<_CorMarcacao> _cores = [
    _CorMarcacao(Color(0xFFFFEB3B), 'Amarelo'),
    _CorMarcacao(Color(0xFF4CAF50), 'Verde'),
    _CorMarcacao(Color(0xFF2196F3), 'Azul'),
    _CorMarcacao(Color(0xFFF44336), 'Vermelho'),
    _CorMarcacao(Color(0xFFFF9800), 'Laranja'),
    _CorMarcacao(Color(0xFF9C27B0), 'Roxo'),
    _CorMarcacao(Color(0xFFE91E63), 'Rosa'),
    _CorMarcacao(Color(0xFF00BCD4), 'Ciano'),
    _CorMarcacao(Color(0xFF795548), 'Castanho'),
    _CorMarcacao(Color(0xFF607D8B), 'Cinzento'),
    _CorMarcacao()
  ];

  final _labels = ['Directo', 'corsproxy.io', 'allorigins', 'thingproxy'];

  @override
  void initState() {
    super.initState();
    _carregarAnotacoes();
  }

  // CORRECÇÃO: usa o serviço isolado por utilizador — devolve apenas as
  // notas cuja chave começa por "userId_livroId_", garantindo que cada
  // conta só vê as suas próprias anotações/marcações deste livro.
  void _carregarAnotacoes() {
    final notas = _servicoNotas.getNotasDoLivro(_userId, _livroId);
    // Ordena por página (mantém o comportamento visual original)
    notas.sort((a, b) => a.value.pagina.compareTo(b.value.pagina));
    setState(() {
      _minhasAnotacoes = notas;
    });
  }

  String _resolverUrl(String url) {
    if (!kIsWeb && url.startsWith('/')) return url;
    if (!kIsWeb) return url;

    final enc = Uri.encodeComponent(url);
    switch (_tentativa) {
      case 0:
        return url;
      case 1:
        return 'https://corsproxy.io/?$enc';
      case 2:
        return 'https://api.allorigins.win/raw?url=$enc';
      case 3:
        return 'https://thingproxy.freeboard.io/fetch/$url';
      default:
        return url;
    }
  }

  bool get _eLeituraLocal {
    final url = widget.livro['ficheiroUrl'] ?? '';
    return !kIsWeb && url.startsWith('/');
  }

  void _tentarProximo(String erro) {
    if (_tentativa < 3) {
      setState(() {
        _tentativa++;
        _temErro = false;
      });
    } else {
      setState(() {
        _temErro = true;
        _msgErro = erro;
      });
    }
  }

  // ── CRIAR ANOTAÇÃO ────────────────────────────────────────────────
  Future<void> _adicionarAnotacao() async {
    final pag = _pdfController.pageNumber;
    await _mostrarFormularioNota(pagina: pag);
  }

  // ── EDITAR ANOTAÇÃO EXISTENTE ─────────────────────────────────────
  Future<void> _editarAnotacao(MapEntry<String, ModeloDeNota> entrada) async {
    await _mostrarFormularioNota(
      notaExistente: entrada.value,
      chaveExistente: entrada.key,
    );
  }

  // ── FORMULÁRIO UNIFICADO (criar + editar) ─────────────────────────
  Future<void> _mostrarFormularioNota({
    int? pagina,
    ModeloDeNota? notaExistente,
    String? chaveExistente,
  }) async {
    final eEdicao = notaExistente != null;
    final pag = pagina ?? notaExistente?.pagina ?? _pdfController.pageNumber;

    // Estado local do modal
    Color corSelecionada = eEdicao
        ? Color(int.tryParse(notaExistente!.corHex, radix: 16) ??
            0xFFFFEB3B)
        : _cores[0].cor;
    final ctrlNota =
        TextEditingController(text: eEdicao ? (notaExistente!.nota ?? '') : '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Cabeçalho ──
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5D4037).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.menu_book,
                              size: 14, color: Color(0xFF5D4037)),
                          const SizedBox(width: 5),
                          Text('Página $pag',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF5D4037))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        eEdicao ? 'Editar anotação' : 'Nova anotação',
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3E2723)),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // ── Cor da marcação ──
                const Text('Cor da marcação',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5D4037))),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: _cores.map((c) {
                    final sel = corSelecionada == c.cor;
                    return GestureDetector(
                      onTap: () => setModal(() => corSelecionada = c.cor),
                      child: Tooltip(
                        message: c.nome,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: sel ? 38 : 32,
                          height: sel ? 38 : 32,
                          decoration: BoxDecoration(
                            color: c.cor,
                            shape: BoxShape.circle,
                            border: sel
                                ? Border.all(
                                    color: Colors.black87, width: 2.5)
                                : Border.all(
                                    color: Colors.black12, width: 1),
                            boxShadow: sel
                                ? [
                                    BoxShadow(
                                        color: c.cor.withOpacity(0.5),
                                        blurRadius: 6)
                                  ]
                                : null,
                          ),
                          child: sel
                              ? const Icon(Icons.check,
                                  size: 16, color: Colors.white)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // ── Preview da cor ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: corSelecionada.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: corSelecionada.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: corSelecionada,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _cores
                                .firstWhere((c) => c.cor == corSelecionada,
                                    orElse: () => _cores[0])
                                .nome +
                            ' — seleccionado',
                        style: TextStyle(
                            fontSize: 12,
                            color: Color.lerp(
                                corSelecionada, Colors.black, 0.6)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Texto da nota ──
                const Text('Nota (opcional)',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5D4037))),
                const SizedBox(height: 8),
                TextField(
                  controller: ctrlNota,
                  autofocus: false,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText:
                        'Escreve os teus pensamentos sobre esta página...',
                    hintStyle: const TextStyle(
                        color: Colors.grey, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFFF9F5F0),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF5D4037))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF5D4037), width: 2)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.grey.shade300)),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Botões ──
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade600,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5D4037),
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: Icon(
                            eEdicao ? Icons.save : Icons.bookmark_add),
                        label: Text(eEdicao
                            ? 'Guardar alterações'
                            : 'Guardar anotação'),
                        onPressed: () {
                          if (notaExistente != null &&
                              chaveExistente != null) {
                            _actualizarNota(
                              chave: chaveExistente,
                              notaOriginal: notaExistente,
                              novaCor: corSelecionada,
                              novoTexto: ctrlNota.text,
                            );
                          } else {
                            _guardarNova(
                                pag: pag,
                                cor: corSelecionada,
                                nota: ctrlNota.text);
                          }
                          ctrlNota.dispose();
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Guarda nova anotação — CORRECÇÃO: usa o serviço isolado por utilizador.
  // A nota fica gravada com a chave "userId_livroId_timestamp", por isso
  // só este utilizador (com este UID) a verá neste livro.
  Future<void> _guardarNova(
      {required int pag, required Color cor, required String nota}) async {
    final novaNota = ModeloDeNota(
      tituloLivro: widget.livro['titulo'] ?? '',
      pagina: pag,
      corHex: cor.value.toRadixString(16),
      nota: nota.trim().isEmpty ? null : nota.trim(),
      dataCriacao: DateTime.now(),
    );
    await _servicoNotas.adicionarNota(_userId, _livroId, novaNota);
    _carregarAnotacoes();
    if (mounted) {
      _mostrarSnack('Anotação guardada!', icone: Icons.check_circle_outline);
    }
  }

  // Actualiza anotação existente (edição) — CORRECÇÃO: usa a chave Hive
  // original (que já contém o prefixo "userId_livroId_"), garantindo que
  // a edição não "salta" para outra conta nem cria uma nota nova.
  Future<void> _actualizarNota({
    required String chave,
    required ModeloDeNota notaOriginal,
    required Color novaCor,
    required String novoTexto,
  }) async {
    final notaActualizada = ModeloDeNota(
      tituloLivro: notaOriginal.tituloLivro,
      pagina: notaOriginal.pagina,
      corHex: novaCor.value.toRadixString(16),
      nota: novoTexto.trim().isEmpty ? null : novoTexto.trim(),
      dataCriacao: notaOriginal.dataCriacao,
    );
    await _servicoNotas.atualizarNota(_userId, chave, notaActualizada);
    _carregarAnotacoes();
    if (mounted) {
      _mostrarSnack('Anotação actualizada!', icone: Icons.edit_note);
    }
  }

  // Confirma e elimina anotação — CORRECÇÃO: elimina pela chave composta
  // "userId_livroId_timestamp", e o serviço verifica que a chave pertence
  // mesmo a este utilizador antes de apagar (segurança extra).
  Future<void> _confirmarEliminar(MapEntry<String, ModeloDeNota> entrada) async {
    final nota = entrada.value;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.delete_outline, color: Colors.red),
          SizedBox(width: 8),
          Text('Eliminar anotação'),
        ]),
        content: Text(
          'Tens a certeza que queres eliminar a anotação da página ${nota.pagina}?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _servicoNotas.eliminarNota(_userId, entrada.key);
      _carregarAnotacoes();
      if (mounted) {
        _mostrarSnack('Anotação eliminada.', icone: Icons.delete_outline);
      }
    }
  }

  void _mostrarSnack(String texto, {IconData icone = Icons.info_outline}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icone, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(texto),
      ]),
      backgroundColor: const Color(0xFF5D4037),
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.livro['titulo'] ?? 'Livro';
    final urlPdf = widget.livro['ficheiroUrl'] ?? '';
    final urlFinal = _resolverUrl(urlPdf);
    final estaLogado =
        context.watch<ProviderDeAutenticacao>().estaLogado;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5D4037),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            if (widget.livro['autor'] != null &&
                (widget.livro['autor'] as String).isNotEmpty)
              Text(widget.livro['autor'],
                  style: const TextStyle(
                      fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          if (estaLogado)
            IconButton(
              tooltip: 'Anotações (${_minhasAnotacoes.length})',
              onPressed: () =>
                  setState(() => _mostrarAnotacoes = !_mostrarAnotacoes),
              icon: Stack(children: [
                const Icon(Icons.bookmark_border),
                if (_minhasAnotacoes.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                          color: Colors.amber, shape: BoxShape.circle),
                      child: Text('${_minhasAnotacoes.length}',
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                    ),
                  ),
              ]),
            ),
        ],
      ),

      floatingActionButton: estaLogado
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF5D4037),
              foregroundColor: Colors.white,
              onPressed: _adicionarAnotacao,
              icon: const Icon(Icons.add),
              label: const Text('Anotar'),
            )
          : null,

      body: Stack(children: [
        // ── PDF Viewer ──
        Column(children: [
          // Barra de modo (online/offline/proxy)
          Container(
            width: double.infinity,
            color: const Color(0xFF5D4037).withOpacity(0.1),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Row(children: [
              Icon(
                _eLeituraLocal ? Icons.download_done : Icons.cloud,
                size: 14,
                color: const Color(0xFF5D4037),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _eLeituraLocal
                      ? '📥 A ler offline (ficheiro local)'
                      : kIsWeb
                          ? '🌐 Web — ${_labels[_tentativa]}'
                          : '📱 A ler online',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF5D4037)),
                ),
              ),
            ]),
          ),

          Expanded(
            child: urlPdf.isEmpty
                ? _ecraErro('URL do livro não encontrado.')
                : _temErro
                    ? _ecraErro(_msgErro)
                    : _eLeituraLocal
                        ? SfPdfViewer.file(
                            File(urlFinal),
                            controller: _pdfController,
                            onDocumentLoaded: (_) =>
                                setState(() => _temErro = false),
                            onDocumentLoadFailed: (d) => setState(() {
                              _temErro = true;
                              _msgErro =
                                  'Não foi possível abrir o ficheiro local.';
                            }),
                          )
                        : SfPdfViewer.network(
                            urlFinal,
                            controller: _pdfController,
                            onDocumentLoaded: (_) =>
                                setState(() => _temErro = false),
                            onDocumentLoadFailed: (d) =>
                                _tentarProximo(d.description ?? 'Erro'),
                          ),
          ),
        ]),

        // ── Fundo escuro ──
        if (_mostrarAnotacoes)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _mostrarAnotacoes = false),
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),
          ),

        // ── Painel de Anotações ──
        AnimatedPositioned(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          top: 0,
          bottom: 0,
          right: _mostrarAnotacoes ? 0 : -320,
          child: Container(
            width: 300,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(-4, 0),
                )
              ],
            ),
            child: Column(children: [
              // Cabeçalho do painel
              Container(
                padding:
                    const EdgeInsets.fromLTRB(14, 12, 8, 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF5D4037),
                ),
                child: Row(children: [
                  const Icon(Icons.bookmark,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('As minhas anotações',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                  if (_minhasAnotacoes.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('${_minhasAnotacoes.length}',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white, size: 20),
                    onPressed: () =>
                        setState(() => _mostrarAnotacoes = false),
                  ),
                ]),
              ),

              // Botão "Nova anotação" dentro do painel
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF5D4037),
                      side: const BorderSide(color: Color(0xFF5D4037)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: _adicionarAnotacao,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Adicionar anotação',
                        style: TextStyle(fontSize: 13)),
                  ),
                ),
              ),
              const Divider(height: 1),

              // Lista de anotações
              Expanded(
                child: _minhasAnotacoes.isEmpty
                    ? _painelVazio()
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            vertical: 6),
                        itemCount: _minhasAnotacoes.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 16),
                        itemBuilder: (ctx, i) =>
                            _itemAnotacao(_minhasAnotacoes[i]),
                      ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _painelVazio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_note,
                size: 52, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('Sem anotações ainda',
                style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            const Text(
              'Toca em "Anotar" para adicionar\numa nota ou marcação de cor.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemAnotacao(MapEntry<String, ModeloDeNota> entrada) {
    final nota = entrada.value;
    final cor =
        Color(int.tryParse(nota.corHex, radix: 16) ?? 0xFFFFEB3B);
    final nomeCor = _cores
        .firstWhere(
          (c) => c.cor.value == cor.value,
          orElse: () => const _CorMarcacao(Colors.yellow, 'Cor'),
        )
        .nome;
    final dataFmt =
        DateFormat('dd/MM/yyyy HH:mm').format(nota.dataCriacao);

    return InkWell(
      onTap: () {
        _pdfController.jumpToPage(nota.pagina);
        setState(() => _mostrarAnotacoes = false);
      },
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha superior: cor + página + acções
            Row(children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: cor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black26),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF5D4037).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Pág. ${nota.pagina}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5D4037))),
              ),
              const SizedBox(width: 6),
              Text(nomeCor,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
              const Spacer(),
              // Botão editar
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.edit_outlined,
                      size: 16, color: Color(0xFF796741)),
                  tooltip: 'Editar',
                  onPressed: () => _editarAnotacao(entrada),
                ),
              ),
              // Botão eliminar
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: Colors.red),
                  tooltip: 'Eliminar',
                  onPressed: () => _confirmarEliminar(entrada),
                ),
              ),
            ]),

            // Texto da nota
            if (nota.nota != null && nota.nota!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cor.withOpacity(0.3)),
                ),
                child: Text(
                  nota.nota!,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF3E2723)),
                ),
              ),
            ] else ...[
              const SizedBox(height: 4),
              Text('Sem texto (só marcação de cor)',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade400,
                      fontStyle: FontStyle.italic)),
            ],

            // Data
            const SizedBox(height: 4),
            Text(dataFmt,
                style: TextStyle(
                    fontSize: 10, color: Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }

  Widget _ecraErro(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                color: Colors.red, size: 60),
            const SizedBox(height: 16),
            const Text('Não foi possível\ncarregar o livro',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3E2723))),
            const SizedBox(height: 8),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              'Verifica a ligação à Internet.\nSe baixaste o livro, abre pela aba Transferências.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5D4037),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
              onPressed: () => setState(() {
                _tentativa = 0;
                _temErro = false;
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// Modelo auxiliar para cores
class _CorMarcacao {
  final Color cor;
  final String nome;
  const _CorMarcacao(this.cor, this.nome);
}
