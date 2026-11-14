import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sqflite/sqflite.dart';
import 'package:financas_facil/backup/backup_integral.dart';
import 'package:financas_facil/backup/servico_backup.dart';
import 'package:financas_facil/backup/tela_backup.dart';

final class BancoCopia implements Database, Transaction {
  BancoCopia(this.schema, this.tabelas);
  final int schema;
  final Map<String, List<Map<String, Object?>>> tabelas;
  bool emTransacao = false;
  bool falhar = false;
  int fechamentos = 0;
  @override
  Future<void> close() async {
    fechamentos++;
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction) action, {
    bool? exclusive,
  }) async {
    emTransacao = true;
    try {
      return await action(this);
    } finally {
      emTransacao = false;
    }
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    expect(
      emTransacao,
      isTrue,
      reason: 'Cada banco deve ser lido em uma transação consistente',
    );
    if (falhar) throw StateError('Leitura indisponível');
    if (sql == 'PRAGMA user_version') {
      return [
        {'user_version': schema},
      ];
    }
    if (sql.startsWith('SELECT type')) {
      return [
        {
          'type': 'table',
          'name': tabelas.keys.first,
          'tbl_name': tabelas.keys.first,
          'sql': 'CREATE TABLE exemplo (id INTEGER)',
        },
      ];
    }
    return [
      for (final nome in tabelas.keys) {'name': nome},
    ];
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    expect(emTransacao, isTrue);
    return tabelas[table.replaceAll('"', '')]!
        .map((r) => Map<String, Object?>.from(r))
        .toList();
  }

  // Nenhum método de gravação é implementado: gravações fazem o teste falhar.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BancoCopia financeiro() => BancoCopia(14, {
  for (final nome in [
    'movimentacoes',
    'categorias',
    'categorias_csv',
    'importacoes',
    'contas',
    'bancos',
    'preferencias',
    'regras_importacao',
    'agenda',
    'lixeira',
  ])
    nome: [],
  'movimentacoes': [
    {
      'id': 42,
      'ativa': 0,
      'transferencia_par': 43,
      'valor': 12.34,
      'categoria': 'Personalizada',
    },
  ],
  'preferencias': [
    {'chave': 'ocultar_valores', 'valor': '1'},
  ],
  'agenda': [
    {'id': 4, 'status': 'pendente', 'lembrete': 1},
  ],
  'lixeira': [
    {'id': 7, 'dados': '{"id": 99}'},
  ],
});
BancoCopia catalogo() => BancoCopia(1, {
  'perfis': [
    {'id': 1, 'nome': 'Pessoal', 'tipo': 'pessoal'},
    {'id': 2, 'nome': 'Empresa', 'tipo': 'profissional'},
  ],
  'estado': [
    {'chave': 'ativo', 'valor': 2},
  ],
});
ServicoBackup servico(BancoCopia cat, List<BancoCopia> bancos) => ServicoBackup(
  catalogo: Future.value(cat),
  abrirPerfil: (perfil) async => bancos[perfil.id - 1],
);

class EntregaTeste extends ServicoBackup {
  EntregaTeste(this.arquivo)
    : super(
        catalogo: Future.value(catalogo()),
        abrirPerfil: (_) async => financeiro(),
      );
  final ArquivoBackup arquivo;
  bool falhar = true;
  int salvos = 0;
  @override
  Future<ArquivoBackup> gerar() async {
    if (falhar) throw StateError('Detalhe privado');
    return arquivo;
  }

  @override
  Future<bool> salvar(ArquivoBackup arquivo) async {
    salvos++;
    return false;
  }
}

void main() {
  test('fecha conexões próprias também quando a captura falha', () async {
    final bancos = [financeiro(), financeiro()..falhar = true];
    final copia = ServicoBackup(
      catalogo: Future.value(catalogo()),
      abrirPerfil: (p) async => bancos[p.id - 1],
      fecharPerfis: true,
    );
    await expectLater(copia.gerar(), throwsStateError);
    expect(bancos.map((b) => b.fechamentos), [1, 1]);
  });
  test('preserva perfil ainda não inicializado sem criar banco', () async {
    final copia = ServicoBackup(
      catalogo: Future.value(catalogo()),
      abrirPerfil: (p) async => p.id == 1 ? financeiro() : null,
    );
    final dados = validarBackup((await copia.gerar()).bytes);
    final perfil = (dados['perfis'] as List).last as Map;
    expect(perfil['inicializado'], isFalse);
    expect(perfil['banco'], isNull);
  });
  test(
    'backup preserva todos os perfis, flags, vínculos, agenda e preferências',
    () async {
      final cat = catalogo();
      final dbs = [financeiro(), financeiro()];
      final arquivo = await servico(cat, dbs).gerar();
      final dados = validarBackup(arquivo.bytes);
      final perfis = dados['perfis'] as List;
      expect(perfis.length, 2);
      final tabelas = (perfis.first['banco'] as Map)['tabelas'] as Map;
      expect(tabelas['movimentacoes'], dbs.first.tabelas['movimentacoes']);
      expect(tabelas['preferencias'], dbs.first.tabelas['preferencias']);
      expect(tabelas['agenda'], dbs.first.tabelas['agenda']);
      expect(tabelas['lixeira'], dbs.first.tabelas['lixeira']);
      expect(
        ((dados['catalogo'] as Map)['tabelas'] as Map)['estado'],
        cat.tabelas['estado'],
      );
      expect(dbs.first.tabelas['movimentacoes']!.single['ativa'], 0);
      expect(arquivo.nome, endsWith('.ffbackup'));
    },
  );
  test('leitura parcial não produz backup e libera transações', () async {
    final cat = catalogo();
    final dbs = [financeiro(), financeiro()..falhar = true];
    await expectLater(servico(cat, dbs).gerar(), throwsStateError);
    expect(cat.emTransacao, isFalse);
    expect(dbs.every((db) => !db.emTransacao), isTrue);
  });
  test('snapshot preserva blobs sem perder bytes', () async {
    final db = financeiro();
    db.tabelas['anexo'] = [
      {
        'bytes': Uint8List.fromList([0, 127, 255]),
      },
    ];
    final copia = await capturarBanco(db);
    expect(((copia['tabelas'] as Map)['anexo'] as List).single['bytes'], {
      'tipo': 'blob',
      'base64': 'AH//',
    });
  });
  test(
    'checksum detecta corrupção, truncamento e formato inesperado',
    () async {
      final arquivo = await servico(catalogo(), [
        financeiro(),
        financeiro(),
      ]).gerar();
      final envelope =
          jsonDecode(utf8.decode(arquivo.bytes)) as Map<String, dynamic>;
      envelope['conteudo'] = (envelope['conteudo'] as String).replaceFirst(
        'Pessoal',
        'Alterado',
      );
      expect(
        () => validarBackup(utf8.encode(jsonEncode(envelope))),
        throwsFormatException,
      );
      expect(
        () => validarBackup(arquivo.bytes.take(30).toList()),
        throwsFormatException,
      );
      expect(() => validarBackup(utf8.encode('[]')), throwsFormatException);
      expect(
        () => validarBackup(utf8.encode('{"formato":"csv"}')),
        throwsFormatException,
      );
    },
  );
  test(
    'rejeita versões futuras, catálogo inconsistente e tabelas ausentes',
    () async {
      final arquivo = await servico(catalogo(), [
        financeiro(),
        financeiro(),
      ]).gerar();
      final original = validarBackup(arquivo.bytes);
      for (final alterar in <void Function(Map<String, Object?>)>[
        (d) => (d['perfis'] as List).clear(),
        (d) => (d['perfis'] as List).last['id'] = 1,
        (d) => ((d['perfis'] as List).first['banco'] as Map)['schema'] = 99,
        (d) => (((d['perfis'] as List).first['banco'] as Map)['tabelas'] as Map)
            .remove('lixeira'),
        (d) => ((d['catalogo'] as Map)['tabelas'] as Map)['perfis'] = [],
        (d) => d['gerado_em'] = '2026-02-31',
      ]) {
        final copia = Map<String, Object?>.from(
          jsonDecode(jsonEncode(original)) as Map,
        );
        alterar(copia);
        expect(() => codificarBackup(copia), throwsFormatException);
      }
    },
  );
  testWidgets(
    'tela recupera falha sem expor erro privado; cancelar salvar não anuncia sucesso',
    (tester) async {
      final entrega = EntregaTeste(
        ArquivoBackup('teste.ffbackup', Uint8List.fromList([1])),
      );
      await tester.pumpWidget(MaterialApp(home: TelaBackup(servico: entrega)));
      await tester.tap(find.text('Criar backup'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Seus dados foram mantidos'), findsOneWidget);
      expect(find.textContaining('Detalhe privado'), findsNothing);
      entrega.falhar = false;
      await tester.tap(find.text('Criar backup'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Salvar backup'));
      await tester.tap(find.text('Salvar backup'));
      await tester.pumpAndSettle();
      expect(entrega.salvos, 1);
      expect(find.text('Backup salvo.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
