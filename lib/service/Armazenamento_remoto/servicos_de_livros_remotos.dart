import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/modelo_de_livros.dart';

class ServicosLivrosRemotos {

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<modelo_de_livros>> fetchBooks() async {
    final snapshot = await _firestore.collection("Livros").get();

    return snapshot.docs
        .map((doc) => modelo_de_livros.fromMap(doc.data(), doc.id))
        .toList();
  }
}
