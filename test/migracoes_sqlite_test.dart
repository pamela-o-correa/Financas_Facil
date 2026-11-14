import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:financas_facil/main.dart';
import 'package:financas_facil/perfis.dart';
import 'package:financas_facil/contas/contas_banco.dart';
import 'package:financas_facil/contas/lixeira_banco.dart';

import 'support/sqlite_real.dart';

Future<Database> bancoLegado(int versao) async {
  final db = await openDatabase(inMemoryDatabasePath, singleInstance: false);
  await db.execute(
    'CREATE TABLE movimentacoes (id INTEGER PRIMARY KEY AUTOINCREMENT, tipo TEXT NOT NULL, valor REAL NOT NULL, categoria TEXT NOT NULL, descricao TEXT NOT NULL, data TEXT NOT NULL'
    '${versao >= 4 ? ', importacao_id INTEGER' : ''})',
  );
  await db.insert('movimentacoes', {
    'id': 77,
    'tipo': 'despesa',
    'valor': 45.67,
    'categoria': 'Legada',
    'descricao': 'Preservar migração',
    'data': '2024-02-29',
  });
  if (versao >= 2) {
    await db.execute(
      'CREATE TABLE categorias (id INTEGER PRIMARY KEY AUTOINCREMENT, nome TEXT NOT NULL, tipo TEXT NOT NULL, codigo_icone INTEGER NOT NULL, codigo_cor INTEGER NOT NULL'
      '${versao >= 3 ? ', padrao INTEGER NOT NULL DEFAULT 0' : ''}, UNIQUE(nome,tipo))',
    );
    await db.insert('categorias', {
      'id': 20,
      'nome': 'Legada',
      'tipo': 'despesa',
      'codigo_icone': 0,
      'codigo_cor': 0,
    });
  }
  if (versao >= 4) {
    await db.execute(
      'CREATE TABLE importacoes (id INTEGER PRIMARY KEY AUTOINCREMENT, nome_arquivo TEXT NOT NULL, importado_em TEXT NOT NULL, quantidade_original INTEGER NOT NULL)',
    );
  }
  if (versao >= 5) {
    await db.execute(
      'CREATE TABLE preferencias (chave TEXT PRIMARY KEY, valor TEXT NOT NULL)',
    );
  }
  if (versao >= 6) {
    await db.execute(
      'CREATE TABLE regras_importacao (id INTEGER PRIMARY KEY AUTOINCREMENT, texto TEXT NOT NULL, tipo TEXT NOT NULL, categoria_id INTEGER NOT NULL)',
    );
  }
  if (versao >= 7) await AgendaBanco.criar(db);
  if (versao >= 8) await AgendaBanco.migrarPlanejamento(db);
  if (versao >= 10) {
    await db.execute('ALTER TABLE movimentacoes ADD COLUMN conta_id INTEGER');
  }
  if (versao >= 11) await ContasBanco.migrar(db);
  if (versao >= 12) await OperacoesFinanceiras.migrar(db);
  if (versao >= 14) await LixeiraBanco.migrar(db);
  await db.setVersion(versao);
  await db.close();
  return db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactorySqflitePlugin;
  final ignorar = Platform.environment['VALIDACAO_PYTHON'] == null
      ? 'Configure VALIDACAO_PYTHON para validar migrações com SQLite real.'
      : false;
  for (var versao = 1; versao <= 14; versao++) {
    test('schema $versao → 14 preserva dados, IDs e integridade', () async {
      final ponte = await SQLiteReal.abrir();
      addTearDown(ponte.fechar);
      await bancoLegado(versao);
      final banco = BancoDados.paraPerfil(
        PerfilFinanceiro(id: 5000 + versao, nome: 'Migração', tipo: 'pessoal'),
      );
      final db = await banco.database;
      expect(await db.getVersion(), 14);
      final movimento = (await db.query('movimentacoes')).single;
      expect(movimento['id'], 77);
      expect(movimento['descricao'], 'Preservar migração');
      expect(movimento['valor'], 45.67);
      expect(movimento['data'], '2024-02-29');
      expect(movimento['ativa'], 1);
      if (versao >= 2) {
        expect(
          (await db.query('categorias', where: 'id = 20')).single['nome'],
          'Legada',
        );
      }
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      expect(
        (await db.rawQuery('PRAGMA integrity_check')).single.values.single,
        'ok',
      );
      expect(await banco.database, same(db));
      await db.close();
    }, skip: ignorar);
  }
  test(
    'falha intermediária faz rollback da migração e permite nova tentativa',
    () async {
      final ponte = await SQLiteReal.abrir();
      addTearDown(ponte.fechar);
      await bancoLegado(8);
      // Conexão de inspeção compartilha apenas o banco em memória deste teste.
      final leitura = await openDatabase(
        inMemoryDatabasePath,
        singleInstance: false,
      );
      final colunas = await leitura.rawQuery(
        'PRAGMA table_info(movimentacoes)',
      );
      final banco = BancoDados.paraPerfil(
        const PerfilFinanceiro(id: 6000, nome: 'Rollback', tipo: 'pessoal'),
      );
      ponte.falharSql =
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_transferencia_par';
      await expectLater(banco.database, throwsA(isA<Exception>()));
      expect(await leitura.getVersion(), 8);
      expect(
        await leitura.rawQuery('PRAGMA table_info(movimentacoes)'),
        colunas,
      );
      expect((await leitura.query('movimentacoes')).single['id'], 77);
      ponte.falharSql = null;
      final recuperado = await banco.database;
      expect(await recuperado.getVersion(), 14);
      expect((await recuperado.query('movimentacoes')).single['valor'], 45.67);
      await recuperado.close();
      await leitura.close();
    },
    skip: ignorar,
  );
}
