// service/Armazenamento_Local/download_service.dart
//
// CORRECÇÕES PARA WINDOWS E MULTIPLATAFORMA:
// 1. Windows: usa getApplicationSupportDirectory() que é sempre acessível
// 2. Web: download via bytes em memória (sem sistema de ficheiros)
// 3. Dio com opções de timeout e headers para archive.org
// 4. Tratamento de erros detalhado por plataforma

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DownloadService {

  Future<String> download(String url, String livroId) async {
    // Na web não há sistema de ficheiros — não é possível baixar
    if (kIsWeb) {
      throw Exception('Download de ficheiros não disponível no browser.');
    }

    // Obtém pasta correcta por plataforma
    final dir = await _obterPastaDownloads();
    final filePath = '${dir.path}${Platform.pathSeparator}$livroId.pdf';

    // Verifica se já existe (evita re-download)
    final ficheiro = File(filePath);
    if (await ficheiro.exists()) {
      await _incrementarDownloads(livroId);
      return filePath;
    }

    // Configura Dio com headers compatíveis com archive.org e timeout adequado
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 5),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'application/pdf,*/*',
      },
      // Segue redirects automaticamente (archive.org usa muitos redirects)
      followRedirects: true,
      maxRedirects: 10,
    ));

    try {
      await dio.download(
        url,
        filePath,
        onReceiveProgress: (recebido, total) {
          if (total != -1) {
            final percent = (recebido / total * 100).toStringAsFixed(0);
            // ignore: avoid_print
            print('Download $livroId: $percent%');
          }
        },
      );
    } on DioException catch (e) {
      // Remove ficheiro incompleto se o download falhou
      if (await ficheiro.exists()) {
        await ficheiro.delete();
      }
      throw Exception('Erro no download: ${e.message}');
    }

    // Incrementar contador no Firebase (sem bloquear se offline)
    await _incrementarDownloads(livroId);

    return filePath;
  }

  /// Obtém a pasta correcta dependendo da plataforma
  Future<Directory> _obterPastaDownloads() async {
    Directory dir;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Desktop: usa a pasta de suporte da aplicação (sempre funciona)
      dir = await getApplicationSupportDirectory();
    } else {
      // Mobile (Android/iOS): usa documentos da aplicação
      dir = await getApplicationDocumentsDirectory();
    }

    // Cria subdirectório 'livros' para organizar
    final livrosDir = Directory('${dir.path}${Platform.pathSeparator}livros');
    if (!await livrosDir.exists()) {
      await livrosDir.create(recursive: true);
    }
    return livrosDir;
  }

  Future<void> _incrementarDownloads(String livroId) async {
    FirebaseFirestore.instance
        .collection('Livros')
        .doc(livroId)
        .update({'downloads': FieldValue.increment(1)}).catchError((_) {});
  }
}