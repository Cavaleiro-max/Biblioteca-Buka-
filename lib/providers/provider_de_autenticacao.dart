// providers/provider_de_autenticacao.dart
//
// MELHORIAS:
// 1. alterarNome() e alterarSenha() são agora rápidos e directos —
//    sem estados de loading globais que bloqueiam a UI toda.
//    Cada operação retorna imediatamente após terminar.
// 2. Ao fazer logout, chama BookProvider.limparAoSair() para limpar
//    a lista de livros em memória — o próximo utilizador começa limpo.
// 3. Mantida toda a lógica de presença e ciclo de vida do app.

import 'package:flutter/material.dart';
import '../service/servico_de_autenticacao.dart';
import '../service/servico_de_presenca.dart';
import '../models/modelo_de_utilizador.dart';
import 'book_provider.dart';

class ProviderDeAutenticacao extends ChangeNotifier {
  final ServicoDeAutenticacao _servicoAuth = ServicoDeAutenticacao();
  final ServicodePresenca _servicoPresenca = ServicodePresenca();

  ModeloDeUtilizador? _utilizadorAtual;
  bool _carregando = false;
  String? _mensagemErro;

  ProviderDeAutenticacao() {
    _servicoPresenca.iniciar();
  }

  @override
  void dispose() {
    _servicoPresenca.parar();
    super.dispose();
  }

  // ── Getters ───────────────────────────────────────────────────────
  ModeloDeUtilizador? get utilizadorAtual => _utilizadorAtual;
  ModeloDeUtilizador? get utilizadorLogado => _utilizadorAtual;
  bool get carregando => _carregando;
  String? get mensagemErro => _mensagemErro;
  bool get estaLogado => _utilizadorAtual != null;
  bool get eAdmin => _utilizadorAtual?.tipo == 'admin';
  bool get emailVerificado => _servicoAuth.emailVerificado;

  // ── Inicializar sessão ─────────────────────────────────────────────
  Future<void> inicializar() async {
    _carregando = true;
    notifyListeners();

    _utilizadorAtual = await _servicoAuth.verificarSessao();
    if (_utilizadorAtual != null) {
      _servicoPresenca.marcarOnline().catchError((_) {});
    }

    _carregando = false;
    notifyListeners();
  }

  Future<void> verificarSessao() => inicializar();

  // ── Login ─────────────────────────────────────────────────────────
  Future<bool> entrar({required String email, required String senha}) async {
    _carregando = true;
    _mensagemErro = null;
    notifyListeners();

    try {
      _utilizadorAtual = await _servicoAuth.entrar(email: email, senha: senha);
      _servicoPresenca.marcarOnline().catchError((_) {});
      _carregando = false;
      notifyListeners();
      return true;
    } catch (e) {
      _mensagemErro = _traduzir(e.toString());
      _carregando = false;
      notifyListeners();
      return false;
    }
  }

  // ── Registo ───────────────────────────────────────────────────────
  Future<bool> registar({
    required String nome,
    required String email,
    required String senha,
  }) async {
    _carregando = true;
    _mensagemErro = null;
    notifyListeners();

    try {
      _utilizadorAtual =
          await _servicoAuth.registar(nome: nome, email: email, senha: senha);
      _servicoPresenca.marcarOnline().catchError((_) {});
      _carregando = false;
      notifyListeners();
      return true;
    } catch (e) {
      _mensagemErro = _traduzir(e.toString());
      _carregando = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> reenviarEmailVerificacao() async {
    await _servicoAuth.reenviarEmailVerificacao();
  }

  Future<bool> recuperarSenha(String email) async {
    try {
      await _servicoAuth.recuperarSenha(email);
      return true;
    } catch (e) {
      _mensagemErro = 'Não foi possível enviar o email. Verifica o endereço.';
      notifyListeners();
      return false;
    }
  }

  // ── Alterar Nome (rápido, sem loading global) ──────────────────────
  // Na ConfiguracoesPage, usa um loading LOCAL no botão em vez de
  // depender do carregando global do provider.
  // Exemplo de uso na página:
  //
  //   bool _salvando = false;
  //   Future<void> _guardarNome() async {
  //     setState(() => _salvando = true);
  //     final ok = await context.read<ProviderDeAutenticacao>().alterarNome(_nomeController.text.trim());
  //     setState(() => _salvando = false);
  //     if (ok) ScaffoldMessenger.of(context).showSnackBar(...);
  //   }
  Future<bool> alterarNome(String novoNome) async {
    if (novoNome.trim().isEmpty || _utilizadorAtual == null) return false;
    try {
      await _servicoAuth.alterarNome(novoNome.trim());
      // Actualiza o objecto local sem rebuildar tudo
      _utilizadorAtual = ModeloDeUtilizador(
        id: _utilizadorAtual!.id,
        nome: novoNome.trim(),
        email: _utilizadorAtual!.email,
        tipo: _utilizadorAtual!.tipo,
        dataCriacao: _utilizadorAtual!.dataCriacao,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _mensagemErro = _traduzir(e.toString());
      notifyListeners();
      return false;
    }
  }

  // ── Alterar Senha (rápido, sem loading global) ─────────────────────
  // Mesma abordagem: o loading fica na página, não no provider.
  Future<bool> alterarSenha({
    required String senhaActual,
    required String novaSenha,
  }) async {
    if (_utilizadorAtual == null) return false;
    try {
      await _servicoAuth.alterarSenha(
        senhaActual: senhaActual,
        novaSenha: novaSenha,
      );
      return true;
    } catch (e) {
      _mensagemErro = _traduzir(e.toString());
      notifyListeners();
      return false;
    }
  }

  // ── Logout ────────────────────────────────────────────────────────
  Future<void> sair({
    BookProvider? bookProvider,
  }) async {
    await terminarSessao(
      bookProvider: bookProvider,
    );
  }

  Future<void> terminarSessao({BookProvider? bookProvider}) async {
    // Marca offline ANTES de fazer logout
    await _servicoPresenca.marcarOffline().catchError((_) {});

    // Limpa a lista de livros em memória — o próximo utilizador começa limpo
    // Os dados no Hive ficam isolados por userId, mas a lista em RAM é global
    bookProvider?.limparAoSair();

    await _servicoAuth.terminarSessao();
    _utilizadorAtual = null;
    notifyListeners();
  }

  // ── Traduzir erros ────────────────────────────────────────────────
  String _traduzir(String erro) {
    if (erro.contains('wrong-password') || erro.contains('invalid-credential'))
      return 'Email ou senha incorrectos.';
    if (erro.contains('user-not-found'))
      return 'Não existe conta com este email.';
    if (erro.contains('email-already-in-use'))
      return 'Este email já está registado.';
    if (erro.contains('weak-password'))
      return 'A senha deve ter pelo menos 6 caracteres.';
    if (erro.contains('invalid-email')) return 'O formato do email é inválido.';
    if (erro.contains('network') || erro.contains('unavailable'))
      return 'Sem conexão à Internet.';
    if (erro.contains('requires-recent-login'))
      return 'Por segurança, volta a fazer login antes de alterar a senha.';
    return 'Ocorreu um erro. Tenta novamente.';
  }
}
