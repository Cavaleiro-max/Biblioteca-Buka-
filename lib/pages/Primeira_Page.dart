// pages/Primeira_Page.dart
// Ecrã de boas-vindas — agora redireciona para o login

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/provider_de_autenticacao.dart';

class PrimeiraPage extends StatefulWidget {
  const PrimeiraPage({super.key});

  @override
  State<PrimeiraPage> createState() => _PrimeiraPageState();
}

class _PrimeiraPageState extends State<PrimeiraPage> {
  @override
  void initState() {
    super.initState();
    // Verificar se já há uma sessão activa ao abrir o app
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<ProviderDeAutenticacao>();
      await auth.verificarSessao();

      if (!mounted) return;

      if (auth.estaLogado) {
        // Já tem sessão → ir directamente para o ecrã principal
        Navigator.pushReplacementNamed(context, '/homescreen');
      }
      // Caso contrário, fica nesta página para o utilizador escolher entrar
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAEBCB),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Logo ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.menu_book, size: 60, color: Color(0xFF463B2B)),
                    SizedBox(width: 8),
                    Text(
                      'BUKA+',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF463B2B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              const Text(
                'B I B L I O T E C A  V I R T U A L  -  B U K A +',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Divider(
                  indent: 20,
                  endIndent: 20,
                  color: Color(0xFF463B2B),
                  thickness: 1.5,
                  height: 6),
              const Divider(
                  indent: 8,
                  endIndent: 10,
                  color: Color(0xFF463B2B),
                  thickness: 4,
                  height: 6),
              const Divider(
                  indent: 20,
                  endIndent: 20,
                  color: Color(0xFF463B2B),
                  thickness: 1.5,
                  height: 6),
              const SizedBox(height: 40),

              const Text(
                'Pesquise e baixe gratuitamente livros, artigos científicos e muito mais. Tudo a seu gosto!',
                style: TextStyle(fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // ── Botão Entrar ──────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/login'),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF463B2B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: const Center(
                      child: Text(
                        'Entrar / Criar conta',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Entrar sem conta (apenas explorar) ────────────
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
            ],
          ),
        ),
      ),
    );
  }
}
