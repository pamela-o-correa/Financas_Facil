part of '../main.dart';

class BancoDados {
  BancoDados._(this.perfil);
  final PerfilFinanceiro perfil;
  static final Map<int, BancoDados> _instancias = {};
  static BancoDados paraPerfil(PerfilFinanceiro perfil) =>
      _instancias.putIfAbsent(perfil.id, () => BancoDados._(perfil));
  static BancoDados get instancia => paraPerfil(CadastroPerfis.atual.value);
  Future<void> _criarTabelaCategorias(Database db) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS categorias (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nome TEXT NOT NULL,
      tipo TEXT NOT NULL,
      codigo_icone INTEGER NOT NULL,
      codigo_cor INTEGER NOT NULL,
      padrao INTEGER NOT NULL DEFAULT 0,
      UNIQUE(nome, tipo)
    )
  ''');
  }

  Future<void> _inserirCategoriasPadrao(DatabaseExecutor db) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS categorias_csv (
      nome_padrao TEXT NOT NULL,
      tipo TEXT NOT NULL,
      categoria_id INTEGER NOT NULL,
      PRIMARY KEY (nome_padrao, tipo)
    )
  ''');
    final categoriasPadrao = [
      {
        'nome': 'Alimentação',
        'tipo': TipoMovimentacao.despesa.name,
        'codigo_icone': Icons.restaurant_outlined.codePoint,
        'codigo_cor': const Color(0xFFE57373).toARGB32(),
        'padrao': 1,
      },
      {
        'nome': 'Delivery',
        'tipo': TipoMovimentacao.despesa.name,
        'codigo_icone': Icons.delivery_dining_outlined.codePoint,
        'codigo_cor': const Color(0xFFFF8A65).toARGB32(),
        'padrao': 1,
      },
      {
        'nome': 'Transporte',
        'tipo': TipoMovimentacao.despesa.name,
        'codigo_icone': Icons.directions_car_outlined.codePoint,
        'codigo_cor': const Color(0xFF64B5F6).toARGB32(),
        'padrao': 1,
      },
      {
        'nome': 'Moradia',
        'tipo': TipoMovimentacao.despesa.name,
        'codigo_icone': Icons.home_outlined.codePoint,
        'codigo_cor': const Color(0xFF9575CD).toARGB32(),
        'padrao': 1,
      },
      {
        'nome': 'Saúde',
        'tipo': TipoMovimentacao.despesa.name,
        'codigo_icone': Icons.health_and_safety_outlined.codePoint,
        'codigo_cor': const Color(0xFF4DB6AC).toARGB32(),
        'padrao': 1,
      },
      {
        'nome': 'Educação',
        'tipo': TipoMovimentacao.despesa.name,
        'codigo_icone': Icons.school_outlined.codePoint,
        'codigo_cor': const Color(0xFF7986CB).toARGB32(),
        'padrao': 1,
      },
      {
        'nome': 'Lazer',
        'tipo': TipoMovimentacao.despesa.name,
        'codigo_icone': Icons.sports_esports_outlined.codePoint,
        'codigo_cor': const Color(0xFFBA68C8).toARGB32(),
        'padrao': 1,
      },
      {
        'nome': 'Compras',
        'tipo': TipoMovimentacao.despesa.name,
        'codigo_icone': Icons.shopping_bag_outlined.codePoint,
        'codigo_cor': const Color(0xFFF06292).toARGB32(),
        'padrao': 1,
      },
      {
        'nome': 'Contas',
        'tipo': TipoMovimentacao.despesa.name,
        'codigo_icone': Icons.receipt_long_outlined.codePoint,
        'codigo_cor': const Color(0xFFFFB74D).toARGB32(),
        'padrao': 1,
      },
      {
        'nome': 'Outros',
        'tipo': TipoMovimentacao.despesa.name,
        'codigo_icone': Icons.more_horiz.codePoint,
        'codigo_cor': const Color(0xFF90A4AE).toARGB32(),
        'padrao': 1,
      },
      {
        'nome': 'Salário',
        'tipo': TipoMovimentacao.receita.name,
        'codigo_icone': Icons.payments_outlined.codePoint,
        'codigo_cor': const Color(0xFF66BB6A).toARGB32(),
        'padrao': 1,
      },
      {
        'nome': 'Outros',
        'tipo': TipoMovimentacao.receita.name,
        'codigo_icone': Icons.add_circle_outline.codePoint,
        'codigo_cor': const Color(0xFF81C784).toARGB32(),
        'padrao': 1,
      },
    ];

    for (final categoria in categoriasPadrao) {
      final nomePadrao = categoria['nome'] as String;
      final tipo = categoria['tipo'] as String;

      final vinculos = await db.query(
        'categorias_csv',
        where: 'nome_padrao = ? AND tipo = ?',
        whereArgs: [nomePadrao, tipo],
      );

      if (vinculos.isNotEmpty) {
        continue;
      }

      await db.insert(
        'categorias',
        categoria,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      final existentes = await db.query(
        'categorias',
        columns: ['id'],
        where: 'nome = ? AND tipo = ? AND padrao = 1',
        whereArgs: [nomePadrao, tipo],
      );

      if (existentes.length == 1) {
        await db.insert('categorias_csv', {
          'nome_padrao': nomePadrao,
          'tipo': tipo,
          'categoria_id': existentes.single['id'],
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
  }

  Future<Database>? _abertura;
  Future<Database> get database => _abertura ??= _inicializarBanco();

  Future<Database> _inicializarBanco() async {
    Database? db;
    try {
      db = await _abrirBanco();
      await _inserirCategoriasPadrao(db);
      return db;
    } catch (_) {
      _abertura = null;
      if (db != null) {
        try {
          await db.close();
        } catch (_) {
          debugPrint(
            'Não foi possível encerrar a conexão após falha na abertura.',
          );
        }
      }
      rethrow;
    }
  }

  Future<void> _criarEstruturaImportacoes(Database db) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS importacoes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nome_arquivo TEXT NOT NULL,
      importado_em TEXT NOT NULL,
      quantidade_original INTEGER NOT NULL,
      conta_id INTEGER,
      banco_detectado TEXT
    )
  ''');

    final colunasMovimentacoes = await db.rawQuery(
      'PRAGMA table_info(movimentacoes)',
    );

    final possuiImportacaoId = colunasMovimentacoes.any(
      (coluna) => coluna['name'] == 'importacao_id',
    );

    if (!possuiImportacaoId) {
      await db.execute(
        'ALTER TABLE movimentacoes '
        'ADD COLUMN importacao_id INTEGER',
      );
    }

    final possuiContaId = colunasMovimentacoes.any(
      (coluna) => coluna['name'] == 'conta_id',
    );

    if (!possuiContaId) {
      await db.execute(
        'ALTER TABLE movimentacoes '
        'ADD COLUMN conta_id INTEGER',
      );
    }

    final colunasImportacoes = await db.rawQuery(
      'PRAGMA table_info(importacoes)',
    );

    final possuiContaImportacao = colunasImportacoes.any(
      (coluna) => coluna['name'] == 'conta_id',
    );

    if (!possuiContaImportacao) {
      await db.execute(
        'ALTER TABLE importacoes '
        'ADD COLUMN conta_id INTEGER',
      );
    }

    final possuiBancoDetectado = colunasImportacoes.any(
      (coluna) => coluna['name'] == 'banco_detectado',
    );

    if (!possuiBancoDetectado) {
      await db.execute(
        'ALTER TABLE importacoes '
        'ADD COLUMN banco_detectado TEXT',
      );
    }

    await db.execute(
      'CREATE INDEX IF NOT EXISTS '
      'idx_movimentacoes_importacao '
      'ON movimentacoes(importacao_id)',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS '
      'idx_movimentacoes_conta '
      'ON movimentacoes(conta_id)',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS '
      'idx_importacoes_conta '
      'ON importacoes(conta_id)',
    );
  }

  Future<void> _criarTabelaRegrasImportacao(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS regras_importacao (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        texto TEXT NOT NULL,
        tipo TEXT NOT NULL,
        categoria_id INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_regras_importacao_categoria '
      'ON regras_importacao(categoria_id)',
    );
  }

  Future<void> _criarTabelaPreferencias(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS preferencias (
        chave TEXT PRIMARY KEY,
        valor TEXT NOT NULL
      )
    ''');
  }

  Future<String?> lerPreferencia(String chave) async {
    final db = await database;

    final registros = await db.query(
      'preferencias',
      columns: ['valor'],
      where: 'chave = ?',
      whereArgs: [chave],
    );

    if (registros.isEmpty) return null;

    return registros.single['valor'] as String;
  }

  Future<void> salvarPreferencia(String chave, String valor) async {
    final db = await database;

    await db.insert('preferencias', {
      'chave': chave,
      'valor': valor,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Database> _abrirBanco() async {
    final caminhoBanco = await getDatabasesPath();

    final caminhoCompleto = p.join(caminhoBanco, perfil.arquivoBanco);

    return openDatabase(
      caminhoCompleto,
      version: 14,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onOpen: (db) async {
        await LixeiraBanco.migrar(db);
        await LixeiraBanco.purgar(db);
        await _criarIndicesDesempenho(db);
      },
      onCreate: (db, version) async {
        await AgendaBanco.criar(db);
        await db.execute('''
        CREATE TABLE movimentacoes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo TEXT NOT NULL,
        valor REAL NOT NULL,
        categoria TEXT NOT NULL,
        descricao TEXT NOT NULL,
        data TEXT NOT NULL,
        conta_id INTEGER,
        importacao_id INTEGER,
        ativa INTEGER NOT NULL DEFAULT 1
        )
      ''');
        await _criarTabelaCategorias(db);
        await _inserirCategoriasPadrao(db);
        await _criarEstruturaImportacoes(db);
        await _criarTabelaPreferencias(db);
        await _criarTabelaRegrasImportacao(db);
        await AgendaBanco.migrarPlanejamento(db);
        await ContasBanco.migrar(db);
        await OperacoesFinanceiras.migrar(db);
        await LixeiraBanco.migrar(db);
        await _criarIndicesDesempenho(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 8 && oldVersion >= 7) {
          await AgendaBanco.migrarPlanejamento(db);
        }
        if (oldVersion < 7) await AgendaBanco.criar(db);
        if (oldVersion < 6) {
          await _criarTabelaRegrasImportacao(db);
        }
        if (oldVersion < 5) {
          await _criarTabelaPreferencias(db);
        }
        if (oldVersion < 4) {
          await _criarEstruturaImportacoes(db);
        }
        if (oldVersion < 2) {
          await _criarTabelaCategorias(db);
          await _inserirCategoriasPadrao(db);
        } else if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE categorias '
            'ADD COLUMN padrao INTEGER NOT NULL DEFAULT 0',
          );

          final categoriasPadrao = [
            ['Alimentação', TipoMovimentacao.despesa.name],
            ['Delivery', TipoMovimentacao.despesa.name],
            ['Transporte', TipoMovimentacao.despesa.name],
            ['Moradia', TipoMovimentacao.despesa.name],
            ['Saúde', TipoMovimentacao.despesa.name],
            ['Educação', TipoMovimentacao.despesa.name],
            ['Lazer', TipoMovimentacao.despesa.name],
            ['Compras', TipoMovimentacao.despesa.name],
            ['Contas', TipoMovimentacao.despesa.name],
            ['Outros', TipoMovimentacao.despesa.name],
            ['Salário', TipoMovimentacao.receita.name],
            ['Outros', TipoMovimentacao.receita.name],
          ];

          for (final categoria in categoriasPadrao) {
            await db.update(
              'categorias',
              {'padrao': 1},
              where: 'nome = ? AND tipo = ?',
              whereArgs: [categoria[0], categoria[1]],
            );
          }
        }
        if (oldVersion < 7) await AgendaBanco.migrarPlanejamento(db);
        if (oldVersion < 11) await ContasBanco.migrar(db);
        if (oldVersion < 10) {
          final colunas = await db.rawQuery('PRAGMA table_info(movimentacoes)');

          final possuiContaId = colunas.any(
            (coluna) => coluna['name'] == 'conta_id',
          );

          if (!possuiContaId) {
            await db.execute(
              'ALTER TABLE movimentacoes '
              'ADD COLUMN conta_id INTEGER',
            );
          }

          await db.execute(
            'CREATE INDEX IF NOT EXISTS '
            'idx_movimentacoes_conta '
            'ON movimentacoes(conta_id)',
          );
        }
        if (oldVersion < 12) await OperacoesFinanceiras.migrar(db);
        if (oldVersion < 13) {
          final colunas = await db.rawQuery('PRAGMA table_info(movimentacoes)');
          if (!colunas.any((c) => c['name'] == 'ativa')) {
            await db.execute(
              'ALTER TABLE movimentacoes ADD COLUMN ativa INTEGER NOT NULL DEFAULT 1',
            );
          }
        }
        if (oldVersion < 14) {
          await LixeiraBanco.migrar(db);
          await _criarIndicesDesempenho(db);
        }
      },
    );
  }

  static Future<void> _criarIndicesDesempenho(DatabaseExecutor db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_movimentacoes_data ON movimentacoes(data)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_movimentacoes_importacao ON movimentacoes(importacao_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_agenda_movimentacao ON agenda(movimentacao_id)',
    );
  }

  Future<Map<String, String>> nomesCategoriasCsv() async {
    final db = await database;

    final registros = await db.rawQuery('''
    SELECT
      vinculo.nome_padrao,
      vinculo.tipo,
      categoria.nome
    FROM categorias_csv AS vinculo
    INNER JOIN categorias AS categoria
      ON categoria.id = vinculo.categoria_id
    WHERE categoria.tipo = vinculo.tipo
  ''');

    return {
      for (final registro in registros)
        '${registro['tipo']}:${registro['nome_padrao']}':
            registro['nome'] as String,
    };
  }

  Future<List<Map<String, dynamic>>> listarRegrasImportacao() async {
    final db = await database;

    return db.rawQuery('''
      SELECT
        r.id,
        r.texto,
        r.tipo,
        r.categoria_id,
        c.nome AS categoria_nome,
        c.tipo AS categoria_tipo
      FROM regras_importacao AS r
      LEFT JOIN categorias AS c
        ON c.id = r.categoria_id
      ORDER BY r.texto COLLATE NOCASE ASC, r.id ASC
    ''');
  }

  Future<void> salvarRegraImportacao({
    int? id,
    required String texto,
    required TipoMovimentacao tipo,
    required int categoriaId,
  }) async {
    final textoLimpo = texto.trim().replaceAll(RegExp(r'\s+'), ' ');

    if (textoLimpo.isEmpty) {
      throw Exception('Digite o texto que deve aparecer na descrição.');
    }

    final db = await database;

    await db.transaction((txn) async {
      final categorias = await txn.query(
        'categorias',
        columns: ['id', 'tipo'],
        where: 'id = ?',
        whereArgs: [categoriaId],
      );

      if (categorias.isEmpty) {
        throw Exception('A categoria escolhida não existe mais.');
      }

      if (categorias.single['tipo'] != tipo.name) {
        throw Exception(
          'Escolha uma categoria compatível com '
          'o tipo da movimentação.',
        );
      }

      final outrasRegras = await txn.query(
        'regras_importacao',
        columns: ['id', 'texto'],
        where: 'tipo = ?',
        whereArgs: [tipo.name],
      );

      final textoComparacao = textoLimpo.toLowerCase();

      final repetida = outrasRegras.any((regra) {
        final textoExistente = (regra['texto'] as String)
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), ' ');

        return regra['id'] != id && textoExistente == textoComparacao;
      });

      if (repetida) {
        throw Exception(
          'Já existe uma regra com esse texto e tipo. '
          'Edite a regra existente.',
        );
      }

      final dados = {
        'texto': textoLimpo,
        'tipo': tipo.name,
        'categoria_id': categoriaId,
      };

      if (id == null) {
        await txn.insert('regras_importacao', dados);
      } else {
        final quantidade = await txn.update(
          'regras_importacao',
          dados,
          where: 'id = ?',
          whereArgs: [id],
        );

        if (quantidade == 0) {
          throw Exception('Esta regra não existe mais. Atualize a lista.');
        }
      }
    });
  }

  Future<void> excluirRegraImportacao(int id) async {
    final db = await database;

    await db.delete('regras_importacao', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Categoria>> listarCategorias() async {
    final db = await database;

    final mapas = await db.query(
      'categorias',
      orderBy: 'tipo ASC, nome COLLATE NOCASE ASC',
    );

    return mapas.map((mapa) => Categoria.deMapa(mapa)).toList();
  }

  Future<int> inserirCategoria(Categoria categoria) async {
    final db = await database;

    final dados = categoria.paraMapa();
    dados.remove('id');

    return db.insert(
      'categorias',
      dados,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> atualizarCategoria({
    required Categoria antiga,
    required Categoria atualizada,
  }) async {
    final db = await database;

    if (antiga.id == null) {
      throw Exception('Categoria sem ID.');
    }

    await db.transaction((txn) async {
      final atuais = await txn.query(
        'categorias',
        where: 'id = ?',
        whereArgs: [antiga.id],
      );
      if (atuais.isEmpty) {
        throw StateError('Esta categoria não existe mais. Atualize a lista.');
      }
      final nomeMudou = antiga.nome != atualizada.nome;
      final tipoMudou = antiga.tipo != atualizada.tipo;

      if (tipoMudou) {
        final ehPadrao = antiga.padrao || atuais.single['padrao'] == 1;
        final vinculosCsv =
            Sqflite.firstIntValue(
              await txn.rawQuery(
                'SELECT COUNT(*) FROM categorias_csv WHERE categoria_id = ?',
                [antiga.id],
              ),
            ) ??
            0;
        final totalMovs =
            Sqflite.firstIntValue(
              await txn.rawQuery(
                'SELECT COUNT(*) FROM movimentacoes WHERE categoria = ? AND tipo = ?',
                [antiga.nome, antiga.tipo.name],
              ),
            ) ??
            0;
        final totalAgenda =
            Sqflite.firstIntValue(
              await txn.rawQuery(
                'SELECT COUNT(*) FROM agenda WHERE categoria = ? AND tipo = ?',
                [antiga.nome, antiga.tipo.name],
              ),
            ) ??
            0;
        if (ehPadrao || vinculosCsv > 0 || totalMovs > 0 || totalAgenda > 0) {
          throw StateError(
            'Não é possível alterar o tipo de uma categoria padrão ou que já possui lançamentos.',
          );
        }
      }

      final dados = atualizada.paraMapa();
      dados.remove('id');

      final quantidade = await txn.update(
        'categorias',
        dados,
        where: 'id = ?',
        whereArgs: [antiga.id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      if (quantidade != 1) {
        throw StateError('Esta categoria não existe mais. Atualize a lista.');
      }

      if (nomeMudou) {
        await txn.update(
          'movimentacoes',
          {'categoria': atualizada.nome},
          where: 'categoria = ? AND tipo = ?',
          whereArgs: [antiga.nome, antiga.tipo.name],
        );
        await txn.update(
          'agenda',
          {'categoria': atualizada.nome},
          where: 'categoria = ? AND tipo = ?',
          whereArgs: [antiga.nome, antiga.tipo.name],
        );
      }
      if (tipoMudou) {
        await txn.update(
          'regras_importacao',
          {'tipo': atualizada.tipo.name},
          where: 'categoria_id = ?',
          whereArgs: [antiga.id],
        );
      }
    });
  }

  Future<int> contarMovimentacoesCategoria(Categoria categoria) async {
    final db = await database;

    final resultado = await db.rawQuery(
      '''
    SELECT COUNT(*) 
    FROM movimentacoes
    WHERE categoria = ? AND tipo = ?
    ''',
      [categoria.nome, categoria.tipo.name],
    );

    final previstos = await db.rawQuery(
      'SELECT COUNT(*) FROM agenda WHERE categoria = ? AND tipo = ?',
      [categoria.nome, categoria.tipo.name],
    );
    return (Sqflite.firstIntValue(resultado) ?? 0) +
        (Sqflite.firstIntValue(previstos) ?? 0);
  }

  Future<void> excluirCategoria({
    required Categoria categoria,
    Categoria? destino,
  }) async {
    final db = await database;

    if (categoria.id == null) {
      throw Exception('Categoria sem ID.');
    }

    if (categoria.padrao) {
      throw Exception('Categorias padrão não podem ser excluídas.');
    }

    await db.transaction((txn) async {
      final atuais = await txn.query(
        'categorias',
        where: 'id = ? AND nome = ? AND tipo = ?',
        whereArgs: [categoria.id, categoria.nome, categoria.tipo.name],
      );
      if (atuais.isEmpty || atuais.single['padrao'] == 1) {
        throw StateError('Categoria indisponível. Atualize a lista.');
      }
      if (destino != null) {
        final destinos = await txn.query(
          'categorias',
          where: 'id = ? AND nome = ? AND tipo = ?',
          whereArgs: [destino.id, destino.nome, categoria.tipo.name],
        );
        if (destinos.isEmpty || destino.id == categoria.id) {
          throw StateError(
            'Categoria de destino indisponível. Atualize a lista.',
          );
        }
      }
      final resultado = await txn.rawQuery(
        '''
      SELECT COUNT(*)
      FROM movimentacoes
      WHERE categoria = ? AND tipo = ?
      ''',
        [categoria.nome, categoria.tipo.name],
      );

      final previstos = await txn.rawQuery(
        'SELECT COUNT(*) FROM agenda WHERE categoria = ? AND tipo = ?',
        [categoria.nome, categoria.tipo.name],
      );
      final quantidade =
          (Sqflite.firstIntValue(resultado) ?? 0) +
          (Sqflite.firstIntValue(previstos) ?? 0);

      if (quantidade > 0) {
        if (destino == null) {
          throw Exception('Escolha uma categoria para mover as movimentações.');
        }

        if (destino.id == categoria.id) {
          throw Exception('A categoria de destino deve ser diferente.');
        }

        if (destino.tipo != categoria.tipo) {
          throw Exception('A categoria de destino deve ser do mesmo tipo.');
        }

        await txn.update(
          'movimentacoes',
          {'categoria': destino.nome},
          where: 'categoria = ? AND tipo = ?',
          whereArgs: [categoria.nome, categoria.tipo.name],
        );
      }

      if (destino != null) {
        await txn.update(
          'agenda',
          {'categoria': destino.nome},
          where: 'categoria = ? AND tipo = ?',
          whereArgs: [categoria.nome, categoria.tipo.name],
        );
      }
      if (destino != null) {
        await txn.update(
          'regras_importacao',
          {'categoria_id': destino.id},
          where: 'categoria_id = ?',
          whereArgs: [categoria.id],
        );
      } else {
        await txn.delete(
          'regras_importacao',
          where: 'categoria_id = ?',
          whereArgs: [categoria.id],
        );
      }
      await txn.delete(
        'categorias',
        where: 'id = ?',
        whereArgs: [categoria.id],
      );
    });
  }

  Future<void> aplicarRegrasImportacao(List<ItemExtrato> itens) async {
    final regras = await listarRegrasImportacao();

    String normalizar(String texto) {
      return texto.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    }

    final regrasValidas = regras.where((regra) {
      return regra['categoria_nome'] != null &&
          regra['categoria_tipo'] == regra['tipo'] &&
          normalizar(regra['texto'] as String).isNotEmpty;
    }).toList();

    for (final item in itens) {
      final descricao = normalizar(item.descricao);
      final destinos = <int, String>{};

      for (final regra in regrasValidas) {
        if (regra['tipo'] != item.tipo.name) {
          continue;
        }

        final textoRegra = normalizar(regra['texto'] as String);

        if (descricao.contains(textoRegra)) {
          destinos[regra['categoria_id'] as int] =
              regra['categoria_nome'] as String;
        }
      }

      item.conflitoDeRegras = destinos.length > 1;

      if (destinos.length == 1) {
        item.categoria = destinos.values.single;
      }
    }
  }

  Future<int> inserirImportacao({
    required String nomeArquivo,
    required List<ItemExtrato> itens,
    required ContaOrigem conta,
    required String bancoDetectado,
  }) => ContasBanco(database).importar(
    nomeArquivo: nomeArquivo,
    itens: itens,
    conta: conta,
    bancoDetectado: bancoDetectado,
  );
  Future<List<Map<String, dynamic>>> listarImportacoes() async {
    final db = await database;

    return db.rawQuery('''
      SELECT
        i.id,
        i.nome_arquivo,
        i.importado_em,
        i.quantidade_original,
        c.nome AS conta_nome,
        b.nome AS banco_nome,
        COUNT(m.id) AS quantidade_atual
      FROM importacoes AS i
      LEFT JOIN movimentacoes AS m
        ON m.importacao_id = i.id
      LEFT JOIN contas AS c ON c.id = i.conta_id
      LEFT JOIN bancos AS b ON b.codigo = c.banco_codigo
      GROUP BY
        i.id,
        i.nome_arquivo,
        i.importado_em,
        i.quantidade_original
      ORDER BY i.importado_em DESC, i.id DESC
    ''');
  }

  Future<void> restaurarAplicativo() async {
    final db = await database;

    await db.transaction((txn) async {
      // Clear planning before movements: the deletion trigger must not reopen it.
      await txn.delete('agenda');
      await txn.delete('lixeira');
      await txn.delete('movimentacoes');
      await txn.delete('importacoes');
      await txn.delete('contas');
      await txn.delete('categorias_csv');
      await txn.delete('regras_importacao');
      await txn.delete('categorias');
      await txn.delete('preferencias');

      await _inserirCategoriasPadrao(txn);
    });
  }

  Future<void> excluirImportacao(int importacaoId) async {
    final db = await database;

    await db.transaction((txn) async {
      final importacoes = await txn.query(
        'importacoes',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [importacaoId],
      );

      if (importacoes.isEmpty) {
        throw Exception('Esta importação não foi encontrada.');
      }

      await LixeiraBanco.arquivar(txn, 'importacao_id = ?', [importacaoId]);
      await txn.delete(
        'movimentacoes',
        where: 'importacao_id = ?',
        whereArgs: [importacaoId],
      );

      await txn.delete(
        'importacoes',
        where: 'id = ?',
        whereArgs: [importacaoId],
      );
    });
  }

  static void _validarMovimentacao(Movimentacao movimentacao) {
    if (!movimentacao.valor.isFinite ||
        !(movimentacao.valor * 100).isFinite ||
        (movimentacao.valor * 100).abs() > maximoCentavosExatos ||
        (movimentacao.valor * 100).round() <= 0 ||
        movimentacao.valor <= 0) {
      throw ArgumentError('Informe um valor válido.');
    }
  }

  Future<int> inserir(Movimentacao movimentacao) async {
    _validarMovimentacao(movimentacao);
    final db = await database;

    final dados = movimentacao.toMap();
    dados.remove('id');

    return db.transaction((txn) async {
      await _validarVinculos(txn, movimentacao);
      return txn.insert('movimentacoes', dados);
    });
  }

  static Future<void> _validarVinculos(
    DatabaseExecutor db,
    Movimentacao movimentacao,
  ) async {
    for (final vinculo in {
      'contas': movimentacao.contaId,
      'importacoes': movimentacao.importacaoId,
    }.entries) {
      if (vinculo.value == null) continue;
      final existentes = await db.query(
        vinculo.key,
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [vinculo.value],
      );
      if (existentes.isEmpty) {
        throw StateError(
          'A conta ou importação vinculada não existe mais. Atualize a lista.',
        );
      }
    }
  }

  Future<List<Movimentacao>> listar() async {
    final db = await database;

    final resultado = await db.query(
      'movimentacoes',
      orderBy: 'data DESC, id DESC',
    );

    return resultado.map((map) => Movimentacao.fromMap(map)).toList();
  }

  Future<int> atualizar(Movimentacao movimentacao) async {
    _validarMovimentacao(movimentacao);
    final db = await database;

    if (movimentacao.id == null) {
      throw Exception('Movimentação sem ID.');
    }

    final dados = movimentacao.toMap();
    dados.remove('id');

    return db.transaction((txn) async {
      await _validarVinculos(txn, movimentacao);
      final quantidade = await txn.update(
        'movimentacoes',
        dados,
        where: 'id = ?',
        whereArgs: [movimentacao.id],
      );
      if (quantidade != 1) {
        throw StateError(
          'Esta movimentação não existe mais. Atualize a lista.',
        );
      }
      return quantidade;
    });
  }

  Future<int> excluir(int id) async {
    final db = await database;

    return db.transaction((txn) async {
      await LixeiraBanco.arquivar(txn, 'id = ?', [id]);
      return txn.delete('movimentacoes', where: 'id = ?', whereArgs: [id]);
    });
  }
}
