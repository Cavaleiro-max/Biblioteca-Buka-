// service/servico_de_estatisticas.dart
// Recolhe dados do Firestore para o painel do administrador

import 'package:cloud_firestore/cloud_firestore.dart';

class ServicoDeEstatisticas {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Total de utilizadores registados ─────────────────────────────
  Future<int> totalDeUtilizadores() async {
    try {
      final snapshot = await _firestore
          .collection('utilizadores')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // ── Utilizadores activos nos últimos 5 segundos ───────────────────────
  Future<int> utilizadoresAtivos() async {
    try {
      final cincoSegundosAtras = DateTime.now()
          .subtract(const Duration(seconds:5 ))
          .toIso8601String();

      final snapshot = await _firestore
          .collection('utilizadores')
          .where('ultimoAcesso', isGreaterThan: cincoSegundosAtras)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // ── Top 10 livros mais baixados ───────────────────────────────────
  Future<List<Map<String, dynamic>>> livrosMaisBaixados() async {
    try {
      // Tenta buscar ordenado por downloads
      final snapshot = await _firestore
          .collection('Livros')
          .orderBy('totalDownloads', descending: true)
          .limit(10)
          .get();

      return snapshot.docs.map((doc) {
        final d = doc.data();
        return {
          'id': doc.id,
          'titulo': d['titulo'] ?? 'Sem título',
          'autor': d['autor'] ?? '',
          'totalDownloads': d['totalDownloads'] ?? 0,
          'totalAcessos': d['totalAcessos'] ?? 0,
        };
      }).toList();

    } catch (e) {
      // Se não tiver o campo totalDownloads ainda, busca sem ordenar
      try {
        final snapshot = await _firestore
            .collection('Livros')
            .limit(10)
            .get();

        return snapshot.docs.map((doc) {
          final d = doc.data();
          return {
            'id': doc.id,
            'titulo': d['titulo'] ?? 'Sem título',
            'autor': d['autor'] ?? '',
            'totalDownloads': d['totalDownloads'] ?? 0,
            'totalAcessos': d['totalAcessos'] ?? 0,
          };
        }).toList();
      } catch (_) {
        return [];
      }
    }
  }

  // ── Resumo completo para o painel admin ───────────────────────────
  Future<Map<String, dynamic>> resumoParaAdmin() async {
    // Buscar tudo em paralelo (mais rápido)
    final resultados = await Future.wait([
      totalDeUtilizadores(),
      utilizadoresAtivos(),
      livrosMaisBaixados(),
    ]);

    return {
      'totalUtilizadores': resultados[0] as int,
      'utilizadoresAtivos': resultados[1] as int,
      'livrosMaisBaixados': resultados[2] as List,
    };
  }

  // ── Registar quando um livro é baixado ────────────────────────────
  // Chamar este método no download_service.dart
  Future<void> registarDownload(String livroId) async {
    try {
      await _firestore.collection('Livros').doc(livroId).update({
        'totalDownloads': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  // ── Registar quando um livro é aberto para ler ────────────────────
  // Chamar este método na LeituraDoLivroPage
  Future<void> registarAcesso(String livroId) async {
    try {
      await _firestore.collection('Livros').doc(livroId).update({
        'totalAcessos': FieldValue.increment(1),
      });
    } catch (_) {}
  }
}
