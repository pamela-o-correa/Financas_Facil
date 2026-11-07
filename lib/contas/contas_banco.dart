import 'dart:convert';
import 'lixeira_banco.dart';

import 'package:sqflite/sqflite.dart';

import '../importacao/item_extrato.dart';

const bancosImportacao = {
  '001': 'Banco do Brasil',
  '748': 'Sicredi',
  '077': 'Inter',
  '260': 'Nubank',
  '341': 'Itaú',
  '237': 'Bradesco',
  '104': 'Caixa',
  '033': 'Santander',
  '290': 'PagBank',
  '323': 'Mercado Pago',
  'generico': 'Outro banco / carteira',
};

class ContaOrigem {
  const ContaOrigem({
    this.id,
    required this.nome,
    required this.bancoCodigo,
    this.nomeBanco,
  });
  final int? id;
  final String nome, bancoCodigo;
  final String? nomeBanco;
  String get bancoNome =>
      nomeBanco ?? bancosImportacao[bancoCodigo] ?? bancoCodigo;
  String get rotulo => '$bancoNome • $nome';
  String get chave => nome.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  factory ContaOrigem.deMapa(Map<String, Object?> m) => ContaOrigem(
    id: m['id'] as int,
    nome: m['nome'] as String,
    bancoCodigo: m['banco_codigo'] as String,
    nomeBanco: m['banco_nome'] as String?,
  );
}

class ContasBanco {
  ContasBanco(this.database);
  final Future<Database> database;

  static Future<void> migrar(DatabaseExecutor db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS bancos (codigo TEXT PRIMARY KEY, nome TEXT NOT NULL)',
    );
    for (final banco in bancosImportacao.entries) {
      await db.insert('bancos', {
        'codigo': banco.key,
        'nome': banco.value,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await db.execute('''CREATE TABLE IF NOT EXISTS contas (
      id INTEGER PRIMARY KEY AUTOINCREMENT, nome TEXT NOT NULL,
      nome_chave TEXT NOT NULL, banco_codigo TEXT NOT NULL REFERENCES bancos(codigo),
      UNIQUE(banco_codigo, nome_chave))''');
    for (final tabela in ['movimentacoes', 'importacoes']) {
      final colunas = (await db.rawQuery('PRAGMA table_info($tabela)'))
          .map((m) => m['name'])
          .toSet();
      if (!colunas.contains('conta_id')) {
        await db.execute(
          'ALTER TABLE $tabela ADD COLUMN conta_id INTEGER REFERENCES contas(id)',
        );
      }
      if (tabela == 'movimentacoes') {
        for (final coluna in {
          'ativa': 'INTEGER NOT NULL DEFAULT 1',
          'documento_origem': 'TEXT',
          'linha_origem': 'INTEGER',
        }.entries) {
          if (!colunas.contains(coluna.key)) {
            await db.execute(
              'ALTER TABLE $tabela ADD COLUMN ${coluna.key} ${coluna.value}',
            );
          }
        }
      } else if (!colunas.contains('banco_detectado')) {
        await db.execute(
          'ALTER TABLE importacoes ADD COLUMN banco_detectado TEXT',
        );
      }
    }
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_movimentacoes_conta ON movimentacoes(conta_id)',
    );
    // Registros antigos continuam sem conta identificada; não se inventa a origem.
  }

  Future<Map<String, String>> listarBancos() async => {
    for (final b in await (await database).query('bancos', orderBy: 'nome'))
      b['codigo'] as String: b['nome'] as String,
  };

  Future<List<ContaOrigem>> listar() async => (await (await database).rawQuery(
    'SELECT c.*, b.nome AS banco_nome FROM contas c JOIN bancos b ON b.codigo = c.banco_codigo ORDER BY b.nome, c.nome',
  )).map(ContaOrigem.deMapa).toList();

  Future<void> editar(int id, ContaOrigem nova) async {
    final db = await database;
    await db.transaction((txn) async {
      if ((await txn.query(
        'contas',
        where: 'id = ?',
        whereArgs: [id],
      )).isEmpty) {
        throw StateError('Esta conta não existe neste perfil.');
      }
      final duplicadas = await txn.query(
        'contas',
        where: 'banco_codigo = ? AND nome_chave = ? AND id != ?',
        whereArgs: [nova.bancoCodigo, nova.chave, id],
      );
      if (duplicadas.isNotEmpty) {
        throw StateError(
          'Já existe uma conta com esse banco e nome. Use Reunir com outra conta.',
        );
      }
      await _validarBanco(txn, nova);
      await txn.update(
        'contas',
        {
          'nome': nova.nome.trim(),
          'nome_chave': nova.chave,
          'banco_codigo': nova.bancoCodigo,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  static Future<void> _moverVinculos(DatabaseExecutor txn, int origem, int? destino) async {
    final colunas = await txn.rawQuery('PRAGMA table_info(movimentacoes)');
    final temTransferencias = colunas.any((c) => c['name'] == 'transferencia_par');
    final pares = !temTransferencias ? <Map<String, Object?>>[] : await txn.rawQuery('SELECT m.id, m.transferencia_par FROM movimentacoes m JOIN movimentacoes p ON p.id = m.transferencia_par WHERE m.conta_id = ? AND p.transferencia_par = m.id', [origem]);
    for (final tabela in ['movimentacoes', 'importacoes']) {
      await txn.update(tabela, {'conta_id':destino}, where:'conta_id = ?', whereArgs:[origem]);
    }
    // Existing triggers deliberately break a pair when editing financial facts.
    // Here only account registration changes; restore the same confirmed pair.
    for (final par in pares) {
      await txn.update('movimentacoes', {'transferencia_par':par['transferencia_par']}, where:'id = ?', whereArgs:[par['id']]);
      await txn.update('movimentacoes', {'transferencia_par':par['id']}, where:'id = ?', whereArgs:[par['transferencia_par']]);
    }
  }

  Future<void> reunir(int origem, ContaOrigem destino) async {
    final db = await database;
    await db.transaction((txn) async {
      final id = await resolver(txn, destino);
      if (id == origem) return;
      await _moverVinculos(txn, origem, id);
      await txn.delete('contas', where: 'id = ?', whereArgs: [origem]);
    });
  }

  Future<(int, int)> contarVinculos(int contaId) async {
    final db = await database;
    final movimentos =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM movimentacoes WHERE conta_id = ? OR importacao_id IN (SELECT id FROM importacoes WHERE conta_id = ?)',
            [contaId, contaId],
          ),
        ) ??
        0;
    final importacoes =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM importacoes WHERE conta_id = ?',
            [contaId],
          ),
        ) ??
        0;
    return (movimentos, importacoes);
  }

  Future<void> excluir(int contaId, {bool apagarDados = false}) async {
    final db = await database;
    await db.transaction((txn) async {
      final conta = await txn.query(
        'contas',
        where: 'id = ?',
        whereArgs: [contaId],
      );
      if (conta.isEmpty) {
        throw StateError('Esta conta não existe neste perfil.');
      }
      if (apagarDados) {
        await LixeiraBanco.arquivar(txn, 'conta_id = ? OR importacao_id IN (SELECT id FROM importacoes WHERE conta_id = ?)', [contaId, contaId]);
        await txn.delete(
          'movimentacoes',
          where: 'conta_id = ? OR importacao_id IN (SELECT id FROM importacoes WHERE conta_id = ?)',
          whereArgs: [contaId, contaId],
        );
        await txn.delete(
          'importacoes',
          where: 'conta_id = ?',
          whereArgs: [contaId],
        );
      } else {
        await _moverVinculos(txn, contaId, null);
      }
      await txn.delete('contas', where: 'id = ?', whereArgs: [contaId]);
    });
  }

  Future<List<Map<String, Object?>>> resumo(
    DateTime inicio,
    DateTime fim,
  ) async => (await database).rawQuery(
    """
      SELECT b.codigo, COALESCE(b.nome, 'Origem não identificada') AS banco_nome,
        COUNT(*) AS quantidade,
        SUM(CASE WHEN m.tipo = 'receita' THEN m.valor ELSE 0 END) AS entradas,
        SUM(CASE WHEN m.tipo = 'despesa' THEN m.valor ELSE 0 END) AS saidas,
        SUM(m.valor) AS volume
      FROM movimentacoes m LEFT JOIN contas c ON c.id = m.conta_id
      LEFT JOIN bancos b ON b.codigo = c.banco_codigo
      WHERE m.ativa = 1 AND m.data >= ? AND m.data < ?
      GROUP BY b.codigo, b.nome ORDER BY volume DESC
    """,
    [inicio.toIso8601String(), fim.toIso8601String()],
  );

  static Future<void> _validarBanco(
    DatabaseExecutor db,
    ContaOrigem conta,
  ) async {
    if (conta.nome.trim().isEmpty ||
        conta.nome.trim().length > 80 ||
        conta.bancoCodigo.trim().isEmpty) {
      throw const FormatException(
        'Informe um banco e um nome de conta de até 80 caracteres.',
      );
    }
    final bancos = await db.query(
      'bancos',
      where: 'codigo = ?',
      whereArgs: [conta.bancoCodigo],
    );
    if (bancos.isEmpty) {
      final nome = conta.nomeBanco?.trim() ?? '';
      final chave = nome.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      if (nome.isEmpty ||
          nome.length > 80 ||
          conta.bancoCodigo != 'personalizado:$chave') {
        throw const FormatException(
          'Banco inválido. Adicione o banco pelo nome.',
        );
      }
      await db.insert('bancos', {'codigo': conta.bancoCodigo, 'nome': nome});
    }
  }

  static Future<int> resolver(DatabaseExecutor db, ContaOrigem conta) async {
    await _validarBanco(db, conta);
    if (conta.id != null) {
      final registro = await db.query(
        'contas',
        where: 'id = ? AND banco_codigo = ?',
        whereArgs: [conta.id, conta.bancoCodigo],
      );
      if (registro.isEmpty) {
        throw StateError('A conta selecionada não existe neste perfil.');
      }
      return conta.id!;
    }
    await db.insert('contas', {
      'nome': conta.nome.trim(),
      'nome_chave': conta.chave,
      'banco_codigo': conta.bancoCodigo,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    final contaSalva = await db.query(
      'contas',
      where: 'banco_codigo = ? AND nome_chave = ?',
      whereArgs: [conta.bancoCodigo, conta.chave],
    );
    return contaSalva.single['id'] as int;
  }

  Future<void> salvar(ContaOrigem conta) async {
    final db = await database;
    await db.transaction((txn) => resolver(txn, conta));
  }

  Future<void> identificarDuplicatas(
    List<ItemExtrato> itens,
    ContaOrigem conta,
  ) async {
    final db = await database;

    int? contaId = conta.id;

    if (contaId == null) {
      final contasExistentes = await db.query(
        'contas',
        columns: ['id'],
        where: 'banco_codigo = ? AND nome_chave = ?',
        whereArgs: [conta.bancoCodigo, conta.chave],
      );

      if (contasExistentes.isNotEmpty) {
        contaId = contasExistentes.single['id'] as int;
      }
    }

    List<Map<String, Object?>> existentes = [];

    // Só comparamos com movimentações existentes quando
    // sabemos exatamente qual é a conta.
    if (contaId != null) {
      existentes = await db.query(
        'movimentacoes',
        where: 'conta_id = ?',
        whereArgs: [contaId],
      );
    }

    String chave(DateTime data, int centavos, String tipo, String descricao) {
      return jsonEncode([
        data.year,
        data.month,
        data.day,
        centavos,
        tipo,
        descricao.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' '),
      ]);
    }

    final chaves = existentes.map((movimentacao) {
      return chave(
        DateTime.parse(movimentacao['data'] as String),
        ((movimentacao['valor'] as num) * 100).round(),
        movimentacao['tipo'] as String,
        movimentacao['descricao'] as String,
      );
    }).toSet();

    // Também identifica duplicações dentro do próprio arquivo.
    for (final item in itens) {
      final chaveItem = chave(
        item.data,
        item.centavos,
        item.tipo.name,
        item.descricao,
      );

      item.possivelDuplicata = chaves.contains(chaveItem);

      chaves.add(chaveItem);
    }
  }

  Future<int> importar({
    required String nomeArquivo,
    required List<ItemExtrato> itens,
    required ContaOrigem conta,
    required String bancoDetectado,
  }) async {
    if (bancoDetectado != 'generico' && bancoDetectado != conta.bancoCodigo) {
      throw const FormatException(
        'A conta selecionada deve pertencer ao banco detectado.',
      );
    }
    if (itens.isEmpty ||
        itens.any(
          (i) =>
              i.centavos <= 0 ||
              i.descricao.trim().isEmpty ||
              i.categoria.trim().isEmpty,
        )) {
      throw const FormatException(
        'A importação contém movimentações inválidas.',
      );
    }
    final db = await database;
    return db.transaction((txn) async {
      final contaId = await resolver(txn, conta);
      final id = await txn.insert('importacoes', {
        'nome_arquivo': nomeArquivo,
        'importado_em': DateTime.now().toIso8601String(),
        'quantidade_original': itens.length,
        'conta_id': contaId,
        'banco_detectado': bancoDetectado,
      });
      final lote = txn.batch();
      for (final item in itens) {
        lote.insert('movimentacoes', {
          'tipo': item.tipo.name,
          'valor': item.valor,
          'categoria': item.categoria,
          'descricao': item.descricao,
          'data': item.data.toIso8601String(),
          'importacao_id': id,
          'conta_id': contaId,
          'documento_origem': item.documento,
          'linha_origem': item.linhaOrigem,
          'ativa': item.ativa ? 1 : 0,
        });
      }
      await lote.commit(noResult: true);
      return id;
    });
  }
}

