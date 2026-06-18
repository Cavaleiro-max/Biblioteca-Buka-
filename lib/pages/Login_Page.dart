// pages/Login_Page.dart
// Ecrã de Login e Registo — simples e sem login por telefone

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/provider_de_autenticacao.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // 0 = login  |  1 = criar conta
  int  _modo     = 0;
  bool _verSenha = false;

  final _campoNome  = TextEditingController();
  final _campoEmail = TextEditingController();
  final _campoSenha = TextEditingController();

  @override
  void dispose() {
    _campoNome.dispose();
    _campoEmail.dispose();
    _campoSenha.dispose();
    super.dispose();
  }

  // Validação simples dos campos antes de enviar ao Firebase
  String? _validar() {
    final nome  = _campoNome.text.trim();
    final email = _campoEmail.text.trim();
    final senha = _campoSenha.text.trim();

    if (_modo == 1 && nome.isEmpty)  return 'Escreve o teu nome.';
    if (email.isEmpty)               return 'Introduz o teu email.';

    // Verifica se o email tem formato válido: algo@dominio.ext
    if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$').hasMatch(email)) {
      return 'Email inválido. Exemplo: nome@gmail.com';
    }
    if (senha.isEmpty)    return 'Introduz a tua senha.';
    if (senha.length < 6) return 'A senha deve ter pelo menos 6 caracteres.';
    return null;
  }

  // Botão principal: Entrar ou Criar conta
  Future<void> _confirmar() async {
    // Valida campos localmente primeiro (sem precisar do Firebase)
    final erroLocal = _validar();
    if (erroLocal != null) { _snack(erroLocal, erro: true); return; }

    final auth = context.read<ProviderDeAutenticacao>();

    if (_modo == 0) {
      // LOGIN
      final sucesso = await auth.entrar(
        email: _campoEmail.text.trim(),
        senha: _campoSenha.text.trim(),
      );
      if (!mounted) return;
      if (sucesso) {
        Navigator.pushReplacementNamed(context, '/homescreen');
      } else {
        _snack(auth.mensagemErro ?? 'Ocorreu um erro.', erro: true);
      }

    } else {
      // REGISTO — faz login automático após criar conta
      final sucesso = await auth.registar(
        nome:  _campoNome.text.trim(),
        email: _campoEmail.text.trim(),
        senha: _campoSenha.text.trim(),
      );
      if (!mounted) return;
      if (sucesso) {
        // Vai directamente para o app — sem precisar de fazer login separado
        Navigator.pushReplacementNamed(context, '/homescreen');
      } else {
        _snack(auth.mensagemErro ?? 'Ocorreu um erro.', erro: true);
      }
    }
  }

  // Diálogo de recuperação de senha
  void _abrirRecuperacaoSenha() {
    final campo = TextEditingController(text: _campoEmail.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.lock_reset, color: Color(0xFF796741)),
          SizedBox(width: 8),
          Text('Recuperar senha', style: TextStyle(fontSize: 17)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Introduz o teu email e enviamos um link para redefinires a senha.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: campo,
              keyboardType: TextInputType.emailAddress,
              decoration: _decoracao(rotulo: 'Email', icone: Icons.email_outlined),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF463B2B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final auth    = context.read<ProviderDeAutenticacao>();
              final sucesso = await auth.recuperarSenha(campo.text.trim());
              if (!mounted) return;
              _snack(
                sucesso
                    ? 'Email enviado! Verifica a tua caixa de entrada.'
                    : auth.mensagemErro ?? 'Erro ao enviar email.',
                erro: !sucesso,
              );
            },
            child: const Text('Enviar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _snack(String texto, {bool erro = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          erro ? Icons.error_outline : Icons.check_circle_outline,
          color: Colors.white, size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(texto)),
      ]),
      backgroundColor: erro ? Colors.redAccent : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 4),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ProviderDeAutenticacao>();

    return Scaffold(
      backgroundColor: const Color(0xFFFAEBCB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(children: [

              // Logo e título
              const Icon(Icons.menu_book, size: 72, color: Color(0xFF796741)),
              const SizedBox(height: 6),
              const Text('BUKA+',
                  style: TextStyle(
                      fontSize: 32, fontWeight: FontWeight.w900,
                      color: Color(0xFF463B2B), letterSpacing: 4)),
              const Text('Biblioteca Virtual',
                  style: TextStyle(fontSize: 13, color: Color(0xFF796741))),
              const SizedBox(height: 32),

              // Título do formulário
              Text(
                _modo == 0 ? 'Entrar na conta' : 'Criar conta',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold,
                    color: Color(0xFF463B2B)),
              ),
              const SizedBox(height: 20),

              // Campo nome — só no registo
              if (_modo == 1) ...[
                TextField(
                  controller: _campoNome,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decoracao(rotulo: 'Nome completo', icone: Icons.person_outline),
                ),
                const SizedBox(height: 14),
              ],

              // Campo email
              TextField(
                controller: _campoEmail,
                keyboardType: TextInputType.emailAddress,
                decoration: _decoracao(rotulo: 'Email', icone: Icons.email_outlined),
              ),
              const SizedBox(height: 14),

              // Campo senha
              TextField(
                controller: _campoSenha,
                obscureText: !_verSenha,
                decoration: _decoracao(
                  rotulo: 'Senha',
                  icone: Icons.lock_outline,
                  sufixo: IconButton(
                    icon: Icon(
                      _verSenha ? Icons.visibility_off : Icons.visibility,
                      color: const Color(0xFF796741),
                    ),
                    onPressed: () => setState(() => _verSenha = !_verSenha),
                  ),
                ),
              ),

              // Link "Esqueci a senha" — só no login
              if (_modo == 0)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _abrirRecuperacaoSenha,
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32)),
                    child: const Text('Esqueci a senha',
                        style: TextStyle(
                            color: Color(0xFF796741), fontSize: 13,
                            decoration: TextDecoration.underline)),
                  ),
                ),
              const SizedBox(height: 20),

              // Botão principal
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: auth.carregando ? null : _confirmar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF463B2B),
                    disabledBackgroundColor:
                        const Color(0xFF463B2B).withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: auth.carregando
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : Text(
                          _modo == 0 ? 'Entrar' : 'Criar conta',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16,
                              fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),

              // Alternar entre login e registo
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _modo == 0 ? 'Não tens conta? ' : 'Já tens conta? ',
                    style: const TextStyle(color: Color(0xFF796741)),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _modo = _modo == 0 ? 1 : 0;
                      _campoNome.clear();
                      _campoEmail.clear();
                      _campoSenha.clear();
                    }),
                    child: Text(
                      _modo == 0 ? 'Criar conta' : 'Entrar',
                      style: const TextStyle(
                          color: Color(0xFF463B2B),
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, '/homescreen'),
                child: const Text(
                  'Explorar sem conta',
                  style: TextStyle(
                    color: Color(0xFF796741),
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoracao({
    required String rotulo,
    required IconData icone,
    Widget? sufixo,
  }) {
    return InputDecoration(
      labelText: rotulo,
      prefixIcon: Icon(icone, color: const Color(0xFF796741)),
      suffixIcon: sufixo,
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
          borderSide: const BorderSide(color: Color(0xFF796741), width: 2)),
    );
  }
}
