// service/Armazenamento_Local/servicos_de_livros_locais.dart
//
// ISOLAMENTO POR UTILIZADOR — VERSÃO CORRIGIDA E COMPLETA
//
// Usa chave composta "userId_livroId" para que dois utilizadores no mesmo
// dispositivo nunca partilhem dados de transferências ou favoritos.
//
// ATENÇÃO: Se a base de dados local já tinha dados com a chave antiga
// (só o livroId), esses dados ficam "órfãos" — não aparecem a nenhum
// utilizador com a nova lógica. Isso é intencional e seguro.

import 'package:hive/hive.dart';
import '../../models/livros_locais.dart';

class ServicosLivrosLocais {
  Box<LivrosLocais> get _box => Hive.box<LivrosLocais>('caixa_livros');

  // ── Chave composta ────────────────────────────────────────────────
  String _chave(String userId, String livroId) => '${userId}_$livroId';
  String _prefixo(String userId) => '${userId}_';

  // ── Obter ou criar registo local ──────────────────────────────────
  LivrosLocais getOrCreate(
    String userId,
    String livroId, {
    String? titulo,
    String? autor,
  }) {
    final chave = _chave(userId, livroId);
    var livro = _box.get(chave);

    if (livro == null) {
      livro = LivrosLocais(
        id: livroId,
        titulo: titulo,
        autor: autor,
      );
      _box.put(chave, livro);
    } else {
      // Actualiza titulo/autor se ainda não estiverem preenchidos
      bool changed = false;
      if (titulo != null && livro.titulo == null) {
        livro.titulo = titulo;
        changed = true;
      }
      if (autor != null && livro.autor == null) {
        livro.autor = autor;
        changed = true;
      }
      if (changed) livro.save();
    }

    return livro;
  }

  /// Obtém o registo local — null se não existir
  LivrosLocais? get(String userId, String livroId) {
    return _box.get(_chave(userId, livroId));
  }

  /// Devolve APENAS os livros deste utilizador
  List<LivrosLocais> getAll(String userId) {
    final prefixo = _prefixo(userId);
    return _box.keys
        .where((k) => k.toString().startsWith(prefixo))
        .map((k) => _box.get(k)!)
        .toList();
  }

  /// Devolve os livros baixados deste utilizador
  List<LivrosLocais> getBaixados(String userId) {
    return getAll(userId).where((l) => l.esta_baixado).toList();
  }

  /// Devolve os favoritos deste utilizador
  List<LivrosLocais> getFavoritos(String userId) {
    return getAll(userId).where((l) => l.esta_favorito).toList();
  }

  /// Guarda alterações no registo local
  Future<void> save(LivrosLocais livro) async {
    await livro.save();
  }

  /// Remove o registo local do livro deste utilizador
  Future<void> delete(String userId, String livroId) async {
    await _box.delete(_chave(userId, livroId));
  }

  /// Remove TODOS os registos locais deste utilizador
  Future<void> deleteAll(String userId) async {
    final prefixo = _prefixo(userId);
    final chaves = _box.keys
        .where((k) => k.toString().startsWith(prefixo))
        .toList();
    await _box.deleteAll(chaves);
  }
}