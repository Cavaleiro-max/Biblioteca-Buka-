// models/modelo_de_utilizador.dart
// Representa um utilizador registado na aplicação

import 'package:hive/hive.dart';

part 'modelo_de_utilizador.g.dart';

@HiveType(typeId: 2)
class ModeloDeUtilizador extends HiveObject {
  @HiveField(0)
  String id; // UID do Firebase Authentication

  @HiveField(1)
  String nome;

  @HiveField(2)
  String email;

  @HiveField(3)
  String tipo; // "utilizador" ou "admin"

  @HiveField(4)
  String dataCriacao; // data em que criou a conta

  ModeloDeUtilizador({
    required this.id,
    required this.nome,
    required this.email,
    required this.tipo,
    required this.dataCriacao,
  });

  // Converter de mapa do Firestore para objeto
  factory ModeloDeUtilizador.doFirestore(Map<String, dynamic> dados, String uid) {
    return ModeloDeUtilizador(
      id: uid,
      nome: dados['nome'] ?? '',
      email: dados['email'] ?? '',
      tipo: dados['tipo'] ?? 'utilizador',
      dataCriacao: dados['dataCriacao'] ?? '',
    );
  }

  // Converter objeto para mapa (para guardar no Firestore)
  Map<String, dynamic> paraMapa() {
    return {
      'nome': nome,
      'email': email,
      'tipo': tipo,
      'dataCriacao': dataCriacao,
    };
  }
}
