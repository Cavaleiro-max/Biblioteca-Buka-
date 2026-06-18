// service/servico_de_presenca.dart
//
// BUG CORRIGIDO: utilizadores ficavam marcados como "online: true" para sempre
// porque o app nunca chamava marcarOffline() quando era fechado.
// SOLUÇÃO: usar WidgetsBindingObserver para detectar quando o app vai para
// segundo plano ou é fechado, e marcar offline automaticamente.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

class ServicodePresenca with WidgetsBindingObserver {
  final _firestore = FirebaseFirestore.instance;
  final _auth      = FirebaseAuth.instance;

  // Chama este método UMA VEZ no início (ex: no ProviderDeAutenticacao.inicializar)
  // Regista o observer para detectar quando o app fecha/abre
  void iniciar() {
    WidgetsBinding.instance.addObserver(this);
  }

  // Chama quando o provider é destruído
  void parar() {
    WidgetsBinding.instance.removeObserver(this);
  }

  // Chamado automaticamente pelo Flutter quando o estado do app muda
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App voltou ao primeiro plano
        marcarOnline();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App foi para segundo plano ou fechado
        marcarOffline();
        break;
    }
  }

  // Marca o utilizador como online
  Future<void> marcarOnline() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore.collection('utilizadores').doc(uid).update({
        'online':          true,
        'ultimaVezVisto':  FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // Marca o utilizador como offline
  Future<void> marcarOffline() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore.collection('utilizadores').doc(uid).update({
        'online':         false,
        'ultimaVezVisto': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<int> contarOnlineAgora() async {
    try {
      final resultado = await _firestore
          .collection('utilizadores')
          .where('online', isEqualTo: true)
          .get();
      return resultado.docs.length;
    } catch (_) {
      return 0;
    }
  }
}
