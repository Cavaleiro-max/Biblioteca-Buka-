// pages/Configuracoes_Page.dart
//
// CORRECÇÕES NESTA VERSÃO:
// 1. Dead code removido — o catch genérico 'catch (e)' estava depois de
//    'on FirebaseAuthException' que já capturava tudo, tornando o segundo
//    bloco inacessível. Corrigido com ordem correcta dos catch.
// 2. Alterar senha: após updatePassword faz novo signIn para resolver
//    o problema específico do Windows/Web onde o token fica inválido.
// 3. import 'dart:async' adicionado para TimeoutException.

import 'dart:async';
import 'package:buka/providers/book_provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/provider_de_autenticacao.dart';

class ConfiguracoesPage extends StatefulWidget {
  const ConfiguracoesPage({super.key});

  @override
  State<ConfiguracoesPage> createState() => _ConfiguracoesPageState();
}

class _ConfiguracoesPageState extends State<ConfiguracoesPage> {
  final _auth      = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _ctrlNome       = TextEditingController();
  final _ctrlSenhaAtual = TextEditingController();
  final _ctrlSenhaNova  = TextEditingController();
  final _ctrlSenhaConf  = TextEditingController();

  String _nome      = '';
  String _email     = '';
  bool   _carregando       = true;
  bool   _aGuardarNome     = false;
  bool   _aAlterarSenha    = false;
  bool   _verSenhaAtual    = false;
  bool   _verSenhaNova     = false;
  bool   _verSenhaConf     = false;
  bool   _mostrarFormNome  = false;
  bool   _mostrarFormSenha = false;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _ctrlNome.dispose();
    _ctrlSenhaAtual.dispose();
    _ctrlSenhaNova.dispose();
    _ctrlSenhaConf.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _carregando = false);
      return;
    }
    try {
      final doc = await _firestore.collection('utilizadores').doc(uid).get();
      _nome  = doc.data()?['nome']  ?? '';
      _email = doc.data()?['email'] ?? _auth.currentUser?.email ?? '';
    } catch (_) {
      _email = _auth.currentUser?.email ?? '';
    }
    _ctrlNome.text = _nome;
    if (mounted) setState(() => _carregando = false);
  }

  // ── GUARDAR NOME ──────────────────────────────────────────────────
  Future<void> _guardarNome() async {
    final novoNome = _ctrlNome.text.trim();
    if (novoNome.isEmpty) {
      _snack('O nome não pode estar vazio.', erro: true);
      return;
    }
    if (novoNome == _nome) {
      if (mounted) setState(() => _mostrarFormNome = false);
      return;
    }

    if (mounted) setState(() => _aGuardarNome = true);
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _firestore
            .collection('utilizadores')
            .doc(uid)
            .update({'nome': novoNome});
        await _auth.currentUser?.updateDisplayName(novoNome);
      }
      if (!mounted) return;
      setState(() {
        _nome = novoNome;
        _mostrarFormNome = false;
      });
      _snack('Nome actualizado com sucesso!');
    } catch (e) {
      if (mounted) _snack('Erro ao actualizar nome. Tenta novamente.', erro: true);
    } finally {
      if (mounted) setState(() => _aGuardarNome = false);
    }
  }

  // ── ALTERAR SENHA ─────────────────────────────────────────────────
  // CORRECÇÃO PRINCIPAL:
  // - Dead code removido: a ordem catch estava errada
  //   (FirebaseAuthException nunca chegava ao catch genérico)
  // - Passo 4 adicionado: re-login após updatePassword resolve o
  //   problema no Windows/Web onde o token fica inválido após mudar senha
  Future<void> _alterarSenha() async {
    final senhaAtual = _ctrlSenhaAtual.text.trim();
    final senhaNova  = _ctrlSenhaNova.text.trim();
    final senhaConf  = _ctrlSenhaConf.text.trim();

    if (senhaAtual.isEmpty || senhaNova.isEmpty || senhaConf.isEmpty) {
      _snack('Preenche todos os campos.', erro: true);
      return;
    }
    if (senhaNova.length < 6) {
      _snack('A nova senha deve ter pelo menos 6 caracteres.', erro: true);
      return;
    }
    if (senhaNova != senhaConf) {
      _snack('As senhas novas não coincidem.', erro: true);
      return;
    }
    if (senhaAtual == senhaNova) {
      _snack('A nova senha deve ser diferente da actual.', erro: true);
      return;
    }

    if (mounted) setState(() => _aAlterarSenha = true);

    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        _snack('Sessão inválida. Faz login novamente.', erro: true);
        return;
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: senhaAtual,
      );

      // Passo 1 — Reautenticar
      await user
          .reauthenticateWithCredential(credential)
          .timeout(const Duration(seconds: 20));

      // Passo 2 — Buscar utilizador actualizado após reautenticação
      final userActualizado = _auth.currentUser;
      if (userActualizado == null) {
        _snack('Sessão expirou. Faz login novamente.', erro: true);
        return;
      }

      // Passo 3 — Alterar senha
      await userActualizado
          .updatePassword(senhaNova)
          .timeout(const Duration(seconds: 20));

      // Passo 4 — Forçar novo login com nova senha
      // MOTIVO: No Windows/Web o Firebase perde o token após updatePassword
      // e fica num estado inválido que aparece como erro de ligação.
      // O re-login resolve este problema específico da plataforma.
      await _auth.signInWithEmailAndPassword(
        email: userActualizado.email!,
        password: senhaNova,
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      _ctrlSenhaAtual.clear();
      _ctrlSenhaNova.clear();
      _ctrlSenhaConf.clear();
      setState(() => _mostrarFormSenha = false);
      _snack('Senha alterada com sucesso!');

    // CORRECÇÃO DO DEAD CODE:
    // TimeoutException PRIMEIRO (é Exception genérica, não FirebaseAuthException)
    // FirebaseAuthException SEGUNDO (captura erros específicos do Firebase)
    // catch(e) genérico por ÚLTIMO (captura qualquer outro erro restante)
    } on TimeoutException {
      if (!mounted) return;
      _snack('A operação demorou demasiado. Verifica a tua ligação e tenta novamente.', erro: true);

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          _snack('Senha actual incorrecta.', erro: true);
          break;
        case 'requires-recent-login':
          _snack('Por segurança, sai e volta a fazer login antes de alterar a senha.', erro: true);
          break;
        case 'weak-password':
          _snack('A senha é demasiado fraca. Usa pelo menos 6 caracteres.', erro: true);
          break;
        case 'network-request-failed':
          _snack('Erro de ligação. Fecha o app, volta a fazer login e tenta novamente.', erro: true);
          break;
        case 'too-many-requests':
          _snack('Demasiadas tentativas. Aguarda alguns minutos.', erro: true);
          break;
        default:
          _snack('Erro: ${e.message ?? e.code}', erro: true);
      }

    } catch (e) {
      // Este bloco agora é ACESSÍVEL porque está depois dos catch específicos
      if (!mounted) return;
      _snack('Erro inesperado. Tenta novamente.', erro: true);

    } finally {
      if (mounted) setState(() => _aAlterarSenha = false);
    }
  }

  // ── ENVIAR LINK DE RECUPERAÇÃO ────────────────────────────────────
  Future<void> _enviarLinkRecuperacao() async {
    final email = _auth.currentUser?.email ?? '';
    if (email.isEmpty) return;
    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      _snack('Link enviado para $email. Verifica o teu email.');
      setState(() => _mostrarFormSenha = false);
    } catch (_) {
      if (mounted) _snack('Erro ao enviar email.', erro: true);
    }
  }

  // ── TERMINAR SESSÃO ───────────────────────────────────────────────
  Future<void> _terminarSessao() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.logout, color: Colors.red),
          SizedBox(width: 8),
          Text('Terminar sessão'),
        ]),
        content: const Text('Tens a certeza que queres sair da tua conta?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<ProviderDeAutenticacao>().terminarSessao(
        bookProvider: context.read<BookProvider>(),
      );
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _snack(String texto, {bool erro = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(erro ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(texto)),
      ]),
      backgroundColor: erro ? Colors.redAccent : const Color(0xFF5D4037),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 4),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth       = context.watch<ProviderDeAutenticacao>();
    final eVisitante = !auth.estaLogado;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5D4037),
        foregroundColor: Colors.white,
        title: const Text('Configurações'),
      ),
      body: _carregando
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF5D4037)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: eVisitante ? _conteudoVisitante() : _conteudoLogado(),
            ),
    );
  }

  // ── VISITANTE ─────────────────────────────────────────────────────
  Widget _conteudoVisitante() {
    return Column(children: [
      const SizedBox(height: 20),
      Center(
        child: Column(children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.grey.shade300,
            child: const Icon(Icons.person, size: 40, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          const Text('Conta Visitante',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3E2723))),
          const Text('Sem sessão iniciada',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
        ]),
      ),
      const SizedBox(height: 30),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: const Column(children: [
          Icon(Icons.info_outline, color: Colors.amber, size: 28),
          SizedBox(height: 8),
          Text('Estás a usar o Buka+ como visitante.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF3E2723))),
          SizedBox(height: 6),
          Text(
            'Com uma conta podes:\n'
            '• Favoritar livros\n'
            '• Baixar livros para ler sem internet\n'
            '• Fazer anotações e marcações\n'
            '• Guardar o teu progresso de leitura',
            style: TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ]),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF463B2B),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.person_add),
          label: const Text('Criar conta / Entrar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
        ),
      ),
      const SizedBox(height: 30),
      _tituloSecao('Sobre'),
      _itemOpcao(
        icone: Icons.info_outline,
        titulo: 'Sobre o Buka+',
        subtitulo: 'Versão 1.0 — Biblioteca Virtual',
        onTap: () => showAboutDialog(
          context: context,
          applicationName: 'Buka+',
          applicationVersion: '1.0.0',
          applicationLegalese: '© 2026 — Projecto TCC',
        ),
      ),
    ]);
  }

  // ── UTILIZADOR LOGADO ─────────────────────────────────────────────
  Widget _conteudoLogado() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(
        child: Column(children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: const Color(0xFF5D4037),
            child: Text(
              _nome.isNotEmpty ? _nome[0].toUpperCase() : '?',
              style: const TextStyle(
                  fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
          Text(_nome.isNotEmpty ? _nome : 'Utilizador',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3E2723))),
          Text(_email,
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ]),
      ),
      const SizedBox(height: 28),

      _tituloSecao('Conta'),

      _cartaoExpandivel(
        icone: Icons.person_outline,
        titulo: 'Alterar nome',
        subtitulo: _nome.isNotEmpty ? _nome : 'Sem nome definido',
        expandido: _mostrarFormNome,
        onTap: () => setState(() {
          _mostrarFormNome = !_mostrarFormNome;
          if (_mostrarFormNome) _mostrarFormSenha = false;
        }),
        conteudo: _mostrarFormNome ? _formNome() : null,
      ),

      const SizedBox(height: 8),

      _cartaoExpandivel(
        icone: Icons.lock_outline,
        titulo: 'Alterar senha',
        subtitulo: 'Muda a tua senha de acesso',
        expandido: _mostrarFormSenha,
        onTap: () => setState(() {
          _mostrarFormSenha = !_mostrarFormSenha;
          if (_mostrarFormSenha) _mostrarFormNome = false;
        }),
        conteudo: _mostrarFormSenha ? _formSenha() : null,
      ),

      const SizedBox(height: 20),

      _tituloSecao('Sobre'),
      _itemOpcao(
        icone: Icons.info_outline,
        titulo: 'Sobre o Buka+',
        subtitulo: 'Versão 1.0 — Biblioteca Virtual',
        onTap: () => showAboutDialog(
          context: context,
          applicationName: 'Buka+',
          applicationVersion: '1.0.0',
          applicationLegalese: '© 2026 — Projecto TCC',
        ),
      ),

      const SizedBox(height: 20),

      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.logout),
          label: const Text('Terminar sessão',
              style: TextStyle(fontSize: 15)),
          onPressed: _terminarSessao,
        ),
      ),
      const SizedBox(height: 16),
    ]);
  }

  Widget _formNome() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Column(children: [
        const Divider(),
        const SizedBox(height: 8),
        TextField(
          controller: _ctrlNome,
          textCapitalization: TextCapitalization.words,
          decoration: _decoracao(
              rotulo: 'Novo nome', icone: Icons.person_outline),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey,
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => setState(() {
                _mostrarFormNome = false;
                _ctrlNome.text = _nome;
              }),
              child: const Text('Cancelar'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5D4037),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _aGuardarNome ? null : _guardarNome,
              child: _aGuardarNome
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Guardar nome'),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _formSenha() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Column(children: [
        const Divider(),
        const SizedBox(height: 8),

        TextField(
          controller: _ctrlSenhaAtual,
          obscureText: !_verSenhaAtual,
          decoration: _decoracao(
            rotulo: 'Senha actual',
            icone: Icons.lock_outline,
            sufixo: IconButton(
              icon: Icon(_verSenhaAtual ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFF796741)),
              onPressed: () => setState(() => _verSenhaAtual = !_verSenhaAtual),
            ),
          ),
        ),
        const SizedBox(height: 10),

        TextField(
          controller: _ctrlSenhaNova,
          obscureText: !_verSenhaNova,
          decoration: _decoracao(
            rotulo: 'Nova senha',
            icone: Icons.lock_reset,
            sufixo: IconButton(
              icon: Icon(_verSenhaNova ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFF796741)),
              onPressed: () => setState(() => _verSenhaNova = !_verSenhaNova),
            ),
          ),
        ),
        const SizedBox(height: 10),

        TextField(
          controller: _ctrlSenhaConf,
          obscureText: !_verSenhaConf,
          decoration: _decoracao(
            rotulo: 'Confirmar nova senha',
            icone: Icons.lock_reset,
            sufixo: IconButton(
              icon: Icon(_verSenhaConf ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFF796741)),
              onPressed: () => setState(() => _verSenhaConf = !_verSenhaConf),
            ),
          ),
        ),
        const SizedBox(height: 12),

        Row(children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey,
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _aAlterarSenha
                  ? null
                  : () => setState(() {
                        _mostrarFormSenha = false;
                        _ctrlSenhaAtual.clear();
                        _ctrlSenhaNova.clear();
                        _ctrlSenhaConf.clear();
                      }),
              child: const Text('Cancelar'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5D4037),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _aAlterarSenha ? null : _alterarSenha,
              child: _aAlterarSenha
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Alterar senha'),
            ),
          ),
        ]),

        const SizedBox(height: 10),

        TextButton.icon(
          onPressed: _aAlterarSenha ? null : _enviarLinkRecuperacao,
          icon: const Icon(Icons.email_outlined,
              size: 16, color: Color(0xFF796741)),
          label: const Text(
            'Prefiro receber um link por email',
            style: TextStyle(
                color: Color(0xFF796741),
                fontSize: 12,
                decoration: TextDecoration.underline),
          ),
        ),
      ]),
    );
  }

  Widget _tituloSecao(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(titulo,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.2)),
    );
  }

  Widget _cartaoExpandivel({
    required IconData icone,
    required String   titulo,
    required String   subtitulo,
    required bool     expandido,
    required VoidCallback onTap,
    Widget? conteudo,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        ListTile(
          leading: Icon(icone, color: const Color(0xFF5D4037)),
          title: Text(titulo,
              style: const TextStyle(
                  color: Color(0xFF3E2723), fontWeight: FontWeight.w500)),
          subtitle: Text(subtitulo,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          trailing: Icon(
            expandido ? Icons.expand_less : Icons.expand_more,
            color: const Color(0xFF5D4037),
          ),
          onTap: onTap,
        ),
        if (conteudo != null) conteudo,
      ]),
    );
  }

  Widget _itemOpcao({
    required IconData   icone,
    required String     titulo,
    required String     subtitulo,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: ListTile(
        leading: Icon(icone, color: const Color(0xFF5D4037)),
        title: Text(titulo,
            style: const TextStyle(
                color: Color(0xFF3E2723), fontWeight: FontWeight.w500)),
        subtitle: Text(subtitulo,
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  InputDecoration _decoracao({
    required String   rotulo,
    required IconData icone,
    Widget?           sufixo,
  }) {
    return InputDecoration(
      labelText: rotulo,
      prefixIcon: Icon(icone, color: const Color(0xFF796741)),
      suffixIcon: sufixo,
      filled: true,
      fillColor: const Color(0xFFF9F5F0),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF5D4037), width: 2)),
    );
  }
}
