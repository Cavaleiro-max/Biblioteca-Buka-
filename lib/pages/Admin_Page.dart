// pages/Admin_Page.dart
//
// CORRECÇÕES:
// 1. BUG ONLINE FALSO: A query de "online agora" agora também verifica
//    ultimaVezVisto nos últimos 5 minutos — dupla verificação para evitar
//    falsos positivos de utilizadores que fecharam o app sem marcar offline.
// 2. Downloads: usa o campo 'downloads' que já existe no Firestore.
// 3. UI melhorada com indicador de actualização em tempo real.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with WidgetsBindingObserver {
  final _firestore = FirebaseFirestore.instance;
  final _auth      = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _marcarOnline();
  }

  @override
  void dispose() {
    _marcarOffline();
    super.dispose();
  }

  Future<void> _marcarOnline() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    _firestore.collection('utilizadores').doc(uid).update({
      'online':         true,
      'ultimaVezVisto': FieldValue.serverTimestamp(),
    }).catchError((_) {});
  }

  Future<void> _marcarOffline() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    _firestore.collection('utilizadores').doc(uid).update({
      'online':         false,
      'ultimaVezVisto': FieldValue.serverTimestamp(),
    }).catchError((_) {});
  }

  /// Conta utilizadores REALMENTE online:
  /// online == true E ultimaVezVisto nos últimos 5 minutos.
  /// Isto evita falsos positivos de apps fechados que não marcaram offline.
  int _contarOnlineReal(List<QueryDocumentSnapshot> docs) {
    final cincoMinutosAtras = DateTime.now().subtract(const Duration(minutes: 5));
    int count = 0;
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final online = data['online'] == true;
      if (!online) continue;

      // Verifica ultimaVezVisto
      final ultimaVez = data['ultimaVezVisto'];
      if (ultimaVez == null) {
        // Sem timestamp — não conta como online
        continue;
      }
      DateTime? dt;
      if (ultimaVez is Timestamp) {
        dt = ultimaVez.toDate();
      }
      if (dt != null && dt.isAfter(cincoMinutosAtras)) {
        count++;
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final nomeAdmin =
        _auth.currentUser?.displayName ?? _auth.currentUser?.email ?? 'Administrador';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5D4037),
        foregroundColor: Colors.white,
        title: const Text('Painel do Administrador'),
        actions: [
          // Indicador de stream activo
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text('ao vivo',
                    style: TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('utilizadores').snapshots(),
        builder: (context, snapshotUtilizadores) {
          if (snapshotUtilizadores.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF5D4037)));
          }

          final todos  = snapshotUtilizadores.data?.docs ?? [];
          final total  = todos.length;
          // CORRECÇÃO: dupla verificação — online:true E visto nos últimos 5 min
          final onlineAgora = _contarOnlineReal(todos);

          return StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('Livros')
                .orderBy('downloads', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshotLivros) {
              final livros = snapshotLivros.data?.docs ?? [];

              return RefreshIndicator(
                onRefresh: () async {},
                color: const Color(0xFF5D4037),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Saudação
                      Text('Olá, $nomeAdmin 👋',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3E2723))),
                      const Text('Resumo da aplicação Buka+',
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 20),

                      // Cartões de estatística
                      Row(children: [
                        Expanded(
                          child: _cartao(
                            icone: Icons.group,
                            numero: '$total',
                            titulo: 'Total',
                            subtitulo: 'Utilizadores registados',
                            cor: const Color(0xFF5D4037),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _cartao(
                            icone: Icons.wifi,
                            numero: '$onlineAgora',
                            titulo: 'Online agora',
                            subtitulo: 'Activos nos últimos 5 min',
                            cor: Colors.green,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),

                      // Explicação do "online agora"
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(children: [
                          Icon(Icons.info_outline,
                              color: Colors.green.shade700, size: 16),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Online = app aberto e activo nos últimos 5 minutos. '
                              'Actualiza automaticamente em tempo real.',
                              style: TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 24),

                      // Lista de utilizadores online
                      if (onlineAgora > 0) ...[
                        const Text('👥 Utilizadores online agora',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3E2723))),
                        const SizedBox(height: 8),
                        ..._listaOnline(todos),
                        const SizedBox(height: 20),
                      ],

                      // Livros mais baixados
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('📚 Livros mais baixados',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3E2723))),
                          Text('Top ${livros.length}',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                      const Text('Ordenados por número de downloads',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 12),

                      livros.isEmpty
                          ? _semDados()
                          : Column(
                              children: livros.asMap().entries.map((e) {
                                final dados =
                                    e.value.data() as Map<String, dynamic>;
                                return _itemLivro(
                                  posicao:   e.key + 1,
                                  titulo:    dados['titulo']    ?? 'Sem título',
                                  autor:     dados['autor']     ?? '',
                                  downloads: dados['downloads'] ?? 0,
                                );
                              }).toList(),
                            ),

                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(children: [
                          Icon(Icons.info_outline,
                              color: Colors.blue.shade700, size: 16),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Os downloads são contados automaticamente quando os utilizadores baixam livros.',
                              style: TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Lista de utilizadores que estão online agora
  List<Widget> _listaOnline(List<QueryDocumentSnapshot> docs) {
    final cincoMinutosAtras =
        DateTime.now().subtract(const Duration(minutes: 5));
    final onlines = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['online'] != true) return false;
      final ultimaVez = data['ultimaVezVisto'];
      if (ultimaVez == null) return false;
      if (ultimaVez is Timestamp) {
        return ultimaVez.toDate().isAfter(cincoMinutosAtras);
      }
      return false;
    }).toList();

    return onlines.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final nome  = data['nome']  ?? 'Utilizador';
      final email = data['email'] ?? '';
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.shade100),
        ),
        child: Row(children: [
          Container(
            width: 10, height: 10,
            decoration: const BoxDecoration(
              color: Colors.green, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF5D4037),
            child: Text(
              nome.isNotEmpty ? nome[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nome,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF3E2723))),
              Text(email,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      );
    }).toList();
  }

  Widget _cartao({
    required IconData icone,
    required String   numero,
    required String   titulo,
    required String   subtitulo,
    required Color    cor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icone, color: cor, size: 28),
        const SizedBox(height: 8),
        Text(numero,
            style: TextStyle(
                fontSize: 32, fontWeight: FontWeight.bold, color: cor)),
        Text(titulo,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14,
                color: Color(0xFF3E2723))),
        Text(subtitulo,
            style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ]),
    );
  }

  Widget _semDados() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: const Column(children: [
        Icon(Icons.bar_chart, size: 48, color: Colors.grey),
        SizedBox(height: 8),
        Text('Ainda não há dados de downloads.',
            style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
        Text('Quando os utilizadores baixarem livros, aparecerão aqui.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _itemLivro({
    required int    posicao,
    required String titulo,
    required String autor,
    required int    downloads,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 4, offset: const Offset(0, 1),
        )],
      ),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
              color: const Color(0xFF5D4037),
              borderRadius: BorderRadius.circular(6)),
          child: Center(
            child: Text('$posicao',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Color(0xFF3E2723)),
                  overflow: TextOverflow.ellipsis),
              Text(autor,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        Column(children: [
          const Icon(Icons.download, color: Color(0xFF5D4037), size: 16),
          Text('$downloads',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
        ]),
      ]),
    );
  }
}
