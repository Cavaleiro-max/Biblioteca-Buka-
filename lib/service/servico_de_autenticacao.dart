// service/servico_de_autenticacao.dart
// Responsável por: login, registo, logout e recuperação de senha.
// Login por telefone foi REMOVIDO (só funciona em produção, não em dev).
//
// FUNCIONA OFFLINE:
// O Firebase Auth guarda a sessão no dispositivo.
// verificarSessao() usa _auth.currentUser que está guardado localmente —
// não precisa de internet para verificar se já há sessão activa.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/modelo_de_utilizador.dart';

class ServicoDeAutenticacao {
  final FirebaseAuth      _auth      = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get utilizadorAtual => _auth.currentUser;

  bool get emailVerificado => _auth.currentUser?.emailVerified ?? false;

  // ── VERIFICAR SESSÃO (funciona offline) ───────────────────────────
  // _auth.currentUser é guardado localmente pelo Firebase Auth SDK.
  // Se o utilizador já fez login antes e não fez logout,
  // este método devolve os dados mesmo sem internet.
  Future<ModeloDeUtilizador?> verificarSessao() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    // Tenta buscar o perfil no Firestore (precisa internet)
    // Se não há internet, cria um perfil básico com os dados locais do Auth
    try {
      final perfil = await buscarPerfil(user.uid);
      if (perfil != null) return perfil;
    } catch (_) {}

    // Offline: usa os dados guardados localmente pelo Firebase Auth
    return ModeloDeUtilizador(
      id:           user.uid,
      nome:         user.displayName ?? user.email ?? 'Utilizador',
      email:        user.email ?? '',
      tipo:         'utilizador',
      dataCriacao:  DateTime.now().toIso8601String(),
    );
  }

  // ── REGISTO ───────────────────────────────────────────────────────
  // Cria a conta E faz login automático em seguida.
  // Assim o utilizador não precisa de fazer login separado após o registo.
  Future<ModeloDeUtilizador> registar({
    required String nome,
    required String email,
    required String senha,
  }) async {
    // 1. Criar conta no Firebase Auth
    final resultado = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: senha.trim(),
    );

    final uid   = resultado.user!.uid;
    final agora = DateTime.now().toIso8601String();

    // 2. Actualizar nome no perfil do Auth
    await resultado.user!.updateDisplayName(nome.trim());

    // 3. Enviar email de verificação (não obrigatório para entrar)
    resultado.user!.sendEmailVerification().catchError((_) {});

    // 4. Guardar perfil no Firestore (com catchError para funcionar offline)
    _firestore.collection('utilizadores').doc(uid).set({
      'nome':         nome.trim(),
      'email':        email.trim(),
      'tipo':         'utilizador',
      'dataCriacao':  agora,
      'ultimoAcesso': agora,
      'online':       true,
    }).catchError((_) {}); // não bloqueia se não houver internet

    // 5. Devolve o perfil — utilizador já está logado
    return ModeloDeUtilizador(
      id: uid, nome: nome.trim(),
      email: email.trim(), tipo: 'utilizador', dataCriacao: agora,
    );
  }

  // ── LOGIN ─────────────────────────────────────────────────────────
  Future<ModeloDeUtilizador> entrar({
    required String email,
    required String senha,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: senha.trim(),
    );

    final uid  = _auth.currentUser!.uid;
    final user = _auth.currentUser!;

    // Actualizar Firestore (não bloqueia se offline)
    _firestore.collection('utilizadores').doc(uid).update({
      'ultimoAcesso': DateTime.now().toIso8601String(),
      'online':       true,
    }).catchError((_) {});

    // Tenta buscar perfil do Firestore; se falhar usa dados locais
    try {
      final perfil = await buscarPerfil(uid);
      if (perfil != null) return perfil;
    } catch (_) {}

    // Fallback com dados locais do Auth
    return ModeloDeUtilizador(
      id:    uid,
      nome:  user.displayName ?? user.email ?? 'Utilizador',
      email: user.email ?? '',
      tipo:  'utilizador',
      dataCriacao: DateTime.now().toIso8601String(),
    );
  }

  // ── REENVIAR email de verificação ─────────────────────────────────
  Future<void> reenviarEmailVerificacao() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  // ── ALTERAR NOME ────────────────────────────────────────────────
  Future<void> alterarNome(String novoNome) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
      );
    }

    await user.updateDisplayName(novoNome);

    try {
      await _firestore
          .collection('utilizadores')
          .doc(user.uid)
          .update({
        'nome': novoNome,
      });
    } catch (_) {}
  }

  // ── ALTERAR SENHA ───────────────────────────────────────────────
  Future<void> alterarSenha({
    required String senhaActual,
    required String novaSenha,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
      );
    }

    if (user.email == null) {
      throw FirebaseAuthException(
        code: 'invalid-email',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: senhaActual,
    );

    await user.reauthenticateWithCredential(
      credential,
    );

    await user.updatePassword(
      novaSenha,
    );
  }
  // ── LOGOUT ────────────────────────────────────────────────────────
  Future<void> terminarSessao() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      _firestore.collection('utilizadores').doc(uid).update({
        'online':       false,
        'ultimoAcesso': DateTime.now().toIso8601String(),
      }).catchError((_) {});
    }
    await _auth.signOut();
  }

  // ── RECUPERAR SENHA ───────────────────────────────────────────────
  Future<void> recuperarSenha(String email) async {
    if (email.trim().isEmpty) throw Exception('Introduz o teu email.');
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ── BUSCAR PERFIL NO FIRESTORE ────────────────────────────────────
  Future<ModeloDeUtilizador?> buscarPerfil(String uid) async {
    try {
      final doc = await _firestore.collection('utilizadores').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return ModeloDeUtilizador.doFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (_) { return null; }
  }
}
