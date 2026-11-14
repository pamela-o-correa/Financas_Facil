import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '../perfis.dart';
import 'backup_integral.dart';

class ArquivoBackup {
  const ArquivoBackup(this.nome, this.bytes);
  final String nome;
  final Uint8List bytes;
}

/// Nao inicializa, migra ou purga bancos ao criar uma copia.
Future<Database?> abrirPerfilParaBackup(PerfilFinanceiro perfil) async {
  final caminho = p.join(await getDatabasesPath(), perfil.arquivoBanco);
  if (!await databaseExists(caminho)) return null;
  return openReadOnlyDatabase(caminho, singleInstance: false);
}

class ServicoBackup {
  ServicoBackup({
    required this.catalogo,
    required this.abrirPerfil,
    this.fecharPerfis = false,
  });
  final Future<Database> catalogo;
  final Future<Database?> Function(PerfilFinanceiro) abrirPerfil;
  final bool fecharPerfis;

  Future<ArquivoBackup> gerar() async {
    final db = await catalogo;
    final agora = DateTime.now().toUtc();
    final conteudo = await db.transaction((txn) async {
      final perfis = await txn.query('perfis', orderBy: 'id');
      final snapshots = <Map<String, Object?>>[];
      for (final registro in perfis) {
        final perfil = PerfilFinanceiro.deMapa(registro);
        final financeiro = await abrirPerfil(perfil);
        try {
          snapshots.add({
            'id': perfil.id,
            'nome': perfil.nome,
            'tipo': perfil.tipo,
            'inicializado': financeiro != null,
            'banco': financeiro == null
                ? null
                : await capturarBanco(financeiro),
          });
        } finally {
          if (fecharPerfis && financeiro != null) await financeiro.close();
        }
      }
      return <String, Object?>{
        'gerado_em': agora.toIso8601String(),
        'catalogo': await capturarEstrutura(txn),
        'perfis': snapshots,
      };
    });
    final bytes = await compute(codificarBackup, conteudo);
    return ArquivoBackup(
      'financas_facil_backup_${agora.microsecondsSinceEpoch}.ffbackup',
      bytes,
    );
  }

  Future<bool> salvar(ArquivoBackup arquivo) async =>
      await FilePicker.saveFile(
        fileName: arquivo.nome,
        bytes: arquivo.bytes,
        mimeType: 'application/json',
        dialogTitle: 'Salvar backup integral',
      ) !=
      null;

  Future<void> compartilhar(ArquivoBackup arquivo, Rect origem) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(arquivo.bytes, mimeType: 'application/json')],
        fileNameOverrides: [arquivo.nome],
        subject: 'Finanças Fácil - Backup integral',
        sharePositionOrigin: origem,
      ),
    );
  }
}
