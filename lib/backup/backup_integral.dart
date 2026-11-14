import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../modelos/data_registro.dart';

const formatoBackup = 'financas-facil-backup';
const versaoBackup = 1;
const limiteBackupBytes = 128 * 1024 * 1024;

/// Snapshot consistente de um banco. Apenas SELECT/PRAGMA de leitura.
Future<Map<String, Object?>> capturarBanco(Database db) =>
    db.transaction(capturarEstrutura);

Future<Map<String, Object?>> capturarEstrutura(DatabaseExecutor db) async {
  final versao = await db.rawQuery('PRAGMA user_version');
  final estrutura = await db.rawQuery(
    'SELECT type, name, tbl_name, sql FROM sqlite_master WHERE sql IS NOT NULL ORDER BY type, name',
  );
  final nomes = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
  );
  final tabelas = <String, Object?>{};
  for (final item in nomes) {
    final nome = item['name'] as String;
    final segura = '"${nome.replaceAll('"', '""')}"';
    tabelas[nome] = [
      for (final linha in await db.query(segura))
        {
          for (final campo in linha.entries)
            campo.key: campo.value is Uint8List
                ? {
                    'tipo': 'blob',
                    'base64': base64Encode(campo.value as Uint8List),
                  }
                : campo.value,
        },
    ];
  }
  return {
    'schema': versao.single.values.single,
    'estrutura': estrutura,
    'tabelas': tabelas,
  };
}

Uint8List codificarBackup(Map<String, Object?> conteudo) {
  _validarConteudo(conteudo);
  final texto = jsonEncode(conteudo);
  final bytes = Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'formato': formatoBackup,
        'versao': versaoBackup,
        'sha256': sha256.convert(utf8.encode(texto)).toString(),
        'conteudo': texto,
      }),
    ),
  );
  if (bytes.length > limiteBackupBytes) {
    throw const FormatException('O backup excede o limite de 128 MB.');
  }
  return bytes;
}

/// Verifica integridade e estrutura. Nao executa SQL nem restaura dados.
Map<String, Object?> validarBackup(List<int> bytes) {
  try {
    if (bytes.length > limiteBackupBytes) throw const FormatException();
    final envelope = jsonDecode(utf8.decode(bytes));
    if (envelope is! Map ||
        envelope['formato'] != formatoBackup ||
        envelope['versao'] != versaoBackup ||
        envelope['conteudo'] is! String) {
      throw const FormatException();
    }
    final texto = envelope['conteudo'] as String;
    if (sha256.convert(utf8.encode(texto)).toString() != envelope['sha256']) {
      throw const FormatException(
        'O arquivo de backup está incompleto ou foi alterado.',
      );
    }
    final conteudo = Map<String, Object?>.from(jsonDecode(texto) as Map);
    _validarConteudo(conteudo);
    return conteudo;
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('Estrutura de backup inválida.');
  }
}

void _validarConteudo(Map<String, Object?> dados) {
  void banco(Object? valor, Set<String> obrigatorias, int schemaMaximo) {
    if (valor is! Map ||
        valor['schema'] is! int ||
        (valor['schema'] as int) < 1 ||
        (valor['schema'] as int) > schemaMaximo ||
        valor['estrutura'] is! List ||
        valor['tabelas'] is! Map) {
      throw const FormatException(
        'Versão ou estrutura do banco não suportada.',
      );
    }
    final tabelas = valor['tabelas'] as Map;
    if (!obrigatorias.every(tabelas.containsKey) ||
        tabelas.values.any(
          (linhas) => linhas is! List || linhas.any((linha) => linha is! Map),
        )) {
      throw const FormatException('Tabelas do backup incompletas.');
    }
  }

  banco(dados['catalogo'], {'perfis', 'estado'}, 1);
  if (dados['perfis'] is! List ||
      (dados['perfis'] as List).isEmpty ||
      dados['gerado_em'] is! String ||
      dataRegistro(dados['gerado_em'] as String) == null) {
    throw const FormatException('Lista de perfis ou data do backup inválida.');
  }
  final ids = <int>{};
  for (final item in dados['perfis'] as List) {
    if (item is! Map ||
        item['id'] is! int ||
        (item['id'] as int) < 1 ||
        !ids.add(item['id'] as int) ||
        item['nome'] is! String ||
        !{'pessoal', 'profissional'}.contains(item['tipo'])) {
      throw const FormatException('Perfil inválido ou duplicado no backup.');
    }
    if (item['banco'] == null && item['inicializado'] == false) continue;
    final schema = item['banco'] is Map
        ? (item['banco'] as Map)['schema']
        : null;
    final versao = schema is int ? schema : 0;
    banco(item['banco'], {
      'movimentacoes',
      if (versao >= 2) 'categorias',
      if (versao >= 4) 'importacoes',
      if (versao >= 5) 'preferencias',
      if (versao >= 6) 'regras_importacao',
      if (versao >= 7) 'agenda',
      if (versao >= 11) ...['contas', 'bancos'],
      if (versao >= 14) ...['categorias_csv', 'lixeira'],
    }, 14);
  }
  final catalogo = dados['catalogo'] as Map;
  final perfis = (catalogo['tabelas'] as Map)['perfis'] as List;
  final catalogoIds = perfis.map((p) => (p as Map)['id']).toSet();
  if (catalogoIds.length != ids.length || !ids.every(catalogoIds.contains)) {
    throw const FormatException(
      'O catálogo não corresponde aos perfis do backup.',
    );
  }
}
