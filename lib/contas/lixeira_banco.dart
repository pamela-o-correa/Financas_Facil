import 'dart:convert';

import 'package:sqflite/sqflite.dart';

class DuplicataNaRecuperacao implements Exception {
  const DuplicataNaRecuperacao();

  @override
  String toString() =>
      'Já existe um lançamento com a mesma data, valor, descrição e conta.';
}

class LixeiraBanco {
  LixeiraBanco(this.database);

  final Future<Database> database;

  static Future<void> migrar(DatabaseExecutor db) async {
    await db.execute(
      '''CREATE TABLE IF NOT EXISTS lixeira (

      id INTEGER PRIMARY KEY AUTOINCREMENT,

      dados TEXT NOT NULL, excluido_em TEXT NOT NULL, expira_em TEXT NOT NULL)''',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_lixeira_expira ON lixeira(expira_em)',
    );
  }

  static Future<void> purgar(DatabaseExecutor db) async {
    await db.delete(
      'lixeira',
      where: 'expira_em <= ?',
      whereArgs: [DateTime.now().toUtc().toIso8601String()],
    );
  }

  static Future<bool> _temTabela(DatabaseExecutor db, String tabela) async =>
      (await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        [tabela],
      )).isNotEmpty;

  /// Deve ser chamada na mesma transação que remove os lançamentos.

  static Future<List<int>> arquivar(
    DatabaseExecutor db,
    String where,
    List<Object?> args,
  ) async {
    await migrar(db);

    final itens = await db.query(
      'movimentacoes',
      where: where,
      whereArgs: args,
    );

    final ids = <int>[];

    final agora = DateTime.now().toUtc();

    final temAgenda = await _temTabela(db, 'agenda');

    for (final m in itens) {
      final contas = m['conta_id'] == null
          ? <Map<String, Object?>>[]
          : await db.rawQuery(
              'SELECT c.nome, b.nome AS banco_nome FROM contas c LEFT JOIN bancos b ON b.codigo = c.banco_codigo WHERE c.id = ?',
              [m['conta_id']],
            );

      final agenda = temAgenda
          ? await db.query(
              'agenda',
              where: 'movimentacao_id = ?',
              whereArgs: [m['id']],
            )
          : <Map<String, Object?>>[];

      ids.add(
        await db.insert('lixeira', {
          'dados': jsonEncode({
            'movimentacao': m,
            'conta': contas.isEmpty ? null : contas.first,
            'agenda': agenda,
          }),

          'excluido_em': agora.toIso8601String(),

          'expira_em': agora.add(const Duration(days: 30)).toIso8601String(),
        }),
      );
    }

    return ids;
  }

  Future<List<Map<String, Object?>>> listar() async {
    final db = await database;

    return db.transaction((txn) async {
      await purgar(txn);

      return txn.query('lixeira', orderBy: 'excluido_em DESC, id DESC');
    });
  }

  Future<void> restaurar(int id, {bool permitirDuplicata = false}) async {
    final db = await database;

    await db.transaction((txn) async {
      final registros = await txn.query(
        'lixeira',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (registros.isEmpty) {
        throw StateError('Este item não está mais na lixeira.');
      }

      if (!DateTime.parse(registros.single['expira_em'] as String)
          .isAfter(DateTime.now().toUtc())) {
        throw StateError('O prazo de recuperação de 30 dias terminou.');
      }

      final pacote = jsonDecode(
        registros.single['dados'] as String,
      ) as Map<String, dynamic>;

      final m = Map<String, Object?>.from(pacote['movimentacao'] as Map)
        ..remove('id');

      // Recuperar uma transação não confirma novamente um par financeiro.

      if (m['transferencia_par'] != null) m['ativa'] = 0;

      m.remove('transferencia_par');

      for (final vinculo in {
        'conta_id': 'contas',
        'importacao_id': 'importacoes',
      }.entries) {
        if (m[vinculo.key] != null &&
            (await txn.query(
              vinculo.value,
              where: 'id = ?',
              whereArgs: [m[vinculo.key]],
            )).isEmpty) {
          m[vinculo.key] = null;
        }
      }

      String normalizar(Object? v) =>
          (v as String).trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

      final semelhantes = await txn.query(
        'movimentacoes',

        where:
            'tipo = ? AND ROUND(valor * 100) = ? AND data = ? AND ${m['conta_id'] == null ? 'conta_id IS NULL' : 'conta_id = ?'}',

        whereArgs: [
          m['tipo'],
          ((m['valor'] as num) * 100).round(),
          m['data'],
          if (m['conta_id'] != null) m['conta_id'],
        ],
      );

      if (!permitirDuplicata &&
          semelhantes.any(
            (e) => normalizar(e['descricao']) == normalizar(m['descricao']),
          )) {
        throw const DuplicataNaRecuperacao();
      }

      final agendas = <Map<String, Object?>>[];

      for (final item in (pacote['agenda'] as List? ?? [])) {
        final original = Map<String, Object?>.from(item as Map);

        final atuais = await txn.query(
          'agenda',
          where: 'id = ?',
          whereArgs: [original['id']],
        );

        if (atuais.isEmpty) continue;

        final atual = atuais.single;

        final intacta =
            atual['status'] == 'pendente' &&
            atual['movimentacao_id'] == null &&
            original.entries
                .where((e) => e.key != 'status' && e.key != 'movimentacao_id')
                .every((e) => atual[e.key] == e.value);

        if (!intacta) {
          throw StateError(
            'O compromisso do calendário foi alterado após a exclusão. Confira esse compromisso antes de recuperar o lançamento.',
          );
        }

        agendas.add(original);
      }

      final novoId = await txn.insert('movimentacoes', m);

      for (final agenda in agendas) {
        await txn.update(
          'agenda',
          {'status': agenda['status'], 'movimentacao_id': novoId},
          where: 'id = ?',
          whereArgs: [agenda['id']],
        );
      }

      await txn.delete('lixeira', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> apagarDefinitivamente(int id) async {
    await (await database).delete('lixeira', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> esvaziar() async {
    await (await database).delete('lixeira');
  }
}
