import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:financas_facil/main.dart';
import 'package:financas_facil/contas/contas_banco.dart';
import 'package:financas_facil/contas/lixeira_banco.dart';
import 'package:financas_facil/backup/backup_integral.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'SQLite Android: importação, duplicatas, rollback e snapshot sem dados de usuário',
    (tester) async {
      // Banco apenas em memória: nunca usa nomes ou caminhos dos perfis reais.
      final db = await openDatabase(
        inMemoryDatabasePath,
        singleInstance: false,
      );
      addTearDown(db.close);
      await db.execute('PRAGMA foreign_keys = ON');
      await db.execute(
        'CREATE TABLE movimentacoes (id INTEGER PRIMARY KEY AUTOINCREMENT, tipo TEXT NOT NULL, valor REAL NOT NULL, categoria TEXT NOT NULL, descricao TEXT NOT NULL, data TEXT NOT NULL, importacao_id INTEGER)',
      );
      await db.execute(
        'CREATE TABLE importacoes (id INTEGER PRIMARY KEY AUTOINCREMENT, nome_arquivo TEXT NOT NULL, importado_em TEXT NOT NULL, quantidade_original INTEGER NOT NULL)',
      );
      await db.execute(
        'CREATE TABLE categorias (id INTEGER PRIMARY KEY, nome TEXT, tipo TEXT)',
      );
      await ContasBanco.migrar(db);
      await AgendaBanco.criar(db);
      await AgendaBanco.migrarPlanejamento(db);
      await OperacoesFinanceiras.migrar(db);
      await LixeiraBanco.migrar(db);
      final repo = ContasBanco(Future.value(db));
      const conta = ContaOrigem(nome: 'Teste em memória', bancoCodigo: '001');
      ItemExtrato item(String descricao) => ItemExtrato(
        data: DateTime(2026, 11, 14),
        descricao: descricao,
        valor: 12.34,
        tipo: TipoMovimentacao.despesa,
        categoria: 'Outros',
      );
      await repo.importar(
        nomeArquivo: 'teste.csv',
        itens: [item('Compra')],
        conta: conta,
        bancoDetectado: 'generico',
      );
      final duplicata = item('  COMPRA  ');
      await repo.identificarDuplicatas([duplicata], conta);
      expect(duplicata.possivelDuplicata, isTrue);
      await db.execute(
        "CREATE TRIGGER impedir_lote BEFORE INSERT ON movimentacoes WHEN NEW.descricao = 'Falhar' BEGIN SELECT RAISE(ABORT, 'falha simulada'); END",
      );
      await expectLater(
        repo.importar(
          nomeArquivo: 'falha.csv',
          itens: [item('Outra'), item('Falhar')],
          conta: conta,
          bancoDetectado: 'generico',
        ),
        throwsA(isA<Exception>()),
      );
      expect((await db.query('movimentacoes')).length, 1);
      expect((await db.query('importacoes')).length, 1);
      await db.execute('DROP TRIGGER impedir_lote');
      final antes = await db.query('movimentacoes');
      final snapshot = await capturarBanco(db);
      expect((snapshot['tabelas'] as Map)['movimentacoes'], antes);
      expect(await db.query('movimentacoes'), antes);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      expect(
        (await db.rawQuery('PRAGMA integrity_check')).single.values.single,
        'ok',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
