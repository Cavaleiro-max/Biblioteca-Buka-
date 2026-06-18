// service/Armazenamento_Local/servicos_de_notas_locais.dart
//
// NOVO FICHEIRO — ISOLAMENTO DE NOTAS POR UTILIZADOR
//
// Problema anterior: as notas eram guardadas na 'caixa_notas' do Hive
// usando apenas o índice automático (put sem chave explícita), o que
// significa que TODOS os utilizadores do mesmo dispositivo partilhavam
// as mesmas notas.
//
// Solução: chave composta "userId_livroId_timestamp" para isolar
// completamente as notas de cada utilizador.
//
// COMO USAR:
//   final svc = ServicosNotasLocais();
//   final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonimo';
//
//   // Adicionar nota
//   await svc.adicionarNota(uid, livroId, nota);
//
//   // Obter todas as notas de um livro para este utilizador
//   final notas = svc.getNotasDoLivro(uid, livroId);
//
//   // Eliminar uma nota
//   await svc.eliminarNota(uid, chaveNota);

import 'package:hive/hive.dart';
import '../../models/modelo_de_nota.dart';

class ServicosNotasLocais {
  Box<ModeloDeNota> get _box => Hive.box<ModeloDeNota>('caixa_notas');

  // ── Chave composta ────────────────────────────────────────────────
  // Formato: "userId_livroId_timestampMs"
  // O timestamp garante unicidade mesmo para notas no mesmo livro/página.
  String _gerarChave(String userId, String livroId) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '${userId}_${livroId}_$ts';
  }

  String _prefixoUtilizador(String userId) => '${userId}_';
  String _prefixoLivro(String userId, String livroId) =>
      '${userId}_${livroId}_';

  // ── Adicionar nota ────────────────────────────────────────────────
  Future<String> adicionarNota(
      String userId, String livroId, ModeloDeNota nota) async {
    final chave = _gerarChave(userId, livroId);
    await _box.put(chave, nota);
    return chave; // devolve a chave para eventual eliminação
  }

  // ── Actualizar nota existente ─────────────────────────────────────
  // Substitui o conteúdo da nota guardada na 'chave', mantendo a mesma
  // chave (para que continue associada a este utilizador e livro).
  Future<void> atualizarNota(
      String userId, String chave, ModeloDeNota novaNota) async {
    // Verifica que a chave pertence a este utilizador (segurança)
    if (!chave.startsWith(_prefixoUtilizador(userId))) return;
    await _box.put(chave, novaNota);
  }

  // ── Obter notas de um livro (deste utilizador) ────────────────────
  List<MapEntry<String, ModeloDeNota>> getNotasDoLivro(
      String userId, String livroId) {
    final prefixo = _prefixoLivro(userId, livroId);
    return _box.keys
        .where((k) => k.toString().startsWith(prefixo))
        .map((k) => MapEntry(k.toString(), _box.get(k)!))
        .toList()
      ..sort((a, b) =>
          a.value.dataCriacao.compareTo(b.value.dataCriacao));
  }

  // ── Obter TODAS as notas deste utilizador (todos os livros) ───────
  List<MapEntry<String, ModeloDeNota>> getTodasAsNotas(String userId) {
    final prefixo = _prefixoUtilizador(userId);
    return _box.keys
        .where((k) => k.toString().startsWith(prefixo))
        .map((k) => MapEntry(k.toString(), _box.get(k)!))
        .toList()
      ..sort((a, b) =>
          b.value.dataCriacao.compareTo(a.value.dataCriacao));
  }

  // ── Eliminar uma nota pela chave ──────────────────────────────────
  Future<void> eliminarNota(String userId, String chaveNota) async {
    // Verifica que a chave pertence a este utilizador (segurança)
    if (!chaveNota.startsWith(_prefixoUtilizador(userId))) return;
    await _box.delete(chaveNota);
  }

  // ── Eliminar TODAS as notas de um livro (deste utilizador) ────────
  Future<void> eliminarNotasDoLivro(String userId, String livroId) async {
    final prefixo = _prefixoLivro(userId, livroId);
    final chaves = _box.keys
        .where((k) => k.toString().startsWith(prefixo))
        .toList();
    await _box.deleteAll(chaves);
  }

  // ── Eliminar TODAS as notas deste utilizador ──────────────────────
  // Útil no logout se quiser limpar dados locais
  Future<void> eliminarTodasAsNotas(String userId) async {
    final prefixo = _prefixoUtilizador(userId);
    final chaves = _box.keys
        .where((k) => k.toString().startsWith(prefixo))
        .toList();
    await _box.deleteAll(chaves);
  }

  // ── Contagem de notas de um livro ─────────────────────────────────
  int contarNotasDoLivro(String userId, String livroId) {
    final prefixo = _prefixoLivro(userId, livroId);
    return _box.keys
        .where((k) => k.toString().startsWith(prefixo))
        .length;
  }
}