// pages/Splash_Screen.dart
//
// CORRECÇÕES:
// 1. Removido erro de sintaxe que causava "Expected ',' before this" —
//    o ficheiro original tinha um caractere inválido (provavelmente colado
//    do terminal do hot-restart) que o compilador interpretava como código.
// 2. Image.asset com fallback para Icon caso o asset não exista —
//    resolve o "Asset not found: assets/icon/buka_icon.png" sem crashar.
// 3. Animação limpa e sem dependências externas.

import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scaleAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();

    // Navega para a primeira página após 2.5 s
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/primeira');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const corPrincipal = Color(0xFF463B2B);

    return Scaffold(
      backgroundColor: const Color(0xFFFAEBCB),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Logo com fallback para icon nativo ───────────────
                //_LogoOuIcone(cor: corPrincipal),
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
                //const SizedBox(height: 18),

                // ── Três linhas decorativas ──────────────────────────
                //_LinhasDecorativas(cor: corPrincipal),

                //const SizedBox(height: 16),

                // ── Nome da app ──────────────────────────────────────
                /*Text(
                  'Buka+',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: corPrincipal,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                

                // ── Subtítulo ────────────────────────────────────────
                Text(
                  'B I B L I O T E C A  V I R T U A L  -  B U K A +',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF463B2B),
                    letterSpacing: 2.5,
                  ),
                ),*/
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Logo: tenta carregar o asset; se falhar usa o ícone nativo ───────────────
class _LogoOuIcone extends StatelessWidget {
  final Color cor;
  const _LogoOuIcone({required this.cor});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icon/buka_icon.png',
      width: 110,
      height: 110,
      // CORRECÇÃO: errorBuilder evita crash quando o asset não está declarado
      // no pubspec.yaml ou o ficheiro não existe no projecto.
      // Mostra um ícone de livro da Material Design como substituto.
      errorBuilder: (_, __, ___) => Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: cor.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.menu_book_rounded, size: 64, color: cor),
      ),
    );
  }
}

// ── Widget das três linhas decorativas ───────────────────────────────────────
class _LinhasDecorativas extends StatelessWidget {
  final Color cor;
  const _LinhasDecorativas({required this.cor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
      ],
    );
  }
}
