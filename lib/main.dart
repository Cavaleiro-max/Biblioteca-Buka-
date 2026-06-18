// main.dart — ACTUALIZADO
// MUDANÇA: initialRoute agora é '/splash' (SplashScreen)
// A SplashScreen navega automaticamente para '/primeira' após 2.5 s

import 'package:buka/firebase_options.dart';
import 'package:buka/models/livros_locais.dart';
import 'package:buka/models/modelo_de_nota.dart';
import 'package:buka/models/modelo_de_utilizador.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'providers/book_provider.dart';
import 'providers/provider_de_autenticacao.dart';
import 'pages/Splash_Screen.dart';        // ← novo
import 'pages/Primeira_Page.dart';
import 'pages/Home_Screen.dart';
import 'pages/Transferencias_page.dart';
import 'pages/Leitura_Do_Livro_Page.dart';
import 'pages/Configuracoes_Page.dart';
import 'pages/Login_Page.dart';
import 'pages/Admin_Page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(LivrosLocaisAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(ModeloDeNotaAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(ModeloDeUtilizadorAdapter());
  }

  await Hive.openBox<LivrosLocais>('caixa_livros');
  await Hive.openBox<ModeloDeNota>('caixa_notas');

  runApp(const MeuApp());
}

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BookProvider()),
        ChangeNotifierProvider(create: (_) => ProviderDeAutenticacao()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Buka+',
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Roboto',
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF796741),
          ),
        ),
        initialRoute: '/splash',          // ← era '/primeira'
        routes: {
          '/splash':         (context) => const SplashScreen(),   // ← novo
          '/primeira':       (context) => const PrimeiraPage(),
          '/login':          (context) => const LoginPage(),
          '/homescreen':     (context) => const HomePage(),
          '/transferencias': (context) => const TransferenciasPage(),
          '/configuracoes':  (context) => const ConfiguracoesPage(),
          '/admin':          (context) => const AdminPage(),
          '/leitura_do_livro': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            if (args == null || args is! Map<String, dynamic>) {
              return const Scaffold(
                body: Center(child: Text('Erro: livro não encontrado.')),
              );
            }
            return LeituraDoLivroPage(livro: args);
          },
        },
        builder: (context, child) {
          ErrorWidget.builder = (FlutterErrorDetails details) {
            return Scaffold(
              body: Center(
                child: Text(
                  'Ocorreu um erro:\n${details.exception}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          };
          return child!;
        },
      ),
    );
  }
}