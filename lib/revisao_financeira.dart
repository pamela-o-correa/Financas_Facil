part of 'main.dart';

class OperacoesFinanceiras {
  OperacoesFinanceiras(this.database);
  final Future<Database> database;

  static Future<void> migrar(DatabaseExecutor db) async {
    final colunas = await db.rawQuery('PRAGMA table_info(movimentacoes)');
    if (!colunas.any((c) => c['name'] == 'transferencia_par')) {
      await db.execute(
        'ALTER TABLE movimentacoes ADD COLUMN transferencia_par INTEGER',
      );
    }
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_transferencia_par ON movimentacoes(transferencia_par) WHERE transferencia_par IS NOT NULL',
    );
    await db.execute('''CREATE TRIGGER IF NOT EXISTS remover_par_transferencia
      AFTER DELETE ON movimentacoes BEGIN
      UPDATE movimentacoes SET transferencia_par = NULL WHERE transferencia_par = OLD.id;
      END''');
    await db.execute('''CREATE TRIGGER IF NOT EXISTS editar_par_transferencia
      AFTER UPDATE OF valor, tipo, data, conta_id ON movimentacoes
      WHEN OLD.transferencia_par IS NOT NULL AND
        (OLD.valor IS NOT NEW.valor OR OLD.tipo IS NOT NEW.tipo OR OLD.data IS NOT NEW.data OR OLD.conta_id IS NOT NEW.conta_id)
      BEGIN UPDATE movimentacoes SET transferencia_par = NULL
        WHERE id = OLD.id OR transferencia_par = OLD.id; END''');
  }

  Future<void> confirmarTransferencia(int saidaId, int entradaId) async {
    final db = await database;
    await db.transaction((txn) async {
      final dados = await txn.query(
        'movimentacoes',
        where: 'id IN (?, ?)',
        whereArgs: [saidaId, entradaId],
      );
      if (dados.length != 2) {
        throw StateError('Os lançamentos não estão mais disponíveis.');
      }
      final saida = Movimentacao.fromMap(
        dados.firstWhere((m) => m['id'] == saidaId),
      );
      final entrada = Movimentacao.fromMap(
        dados.firstWhere((m) => m['id'] == entradaId),
      );
      if (!compativeisTransferencia(saida, entrada)) {
        throw StateError('Esse par não pode ser confirmado. Atualize a lista.');
      }
      final contas = await txn.query(
        'contas',
        where: 'id IN (?, ?)',
        whereArgs: [saida.contaId, entrada.contaId],
      );
      if (contas.length != 2) {
        throw StateError('As contas devem existir neste perfil.');
      }
      await txn.update(
        'movimentacoes',
        {'transferencia_par': entradaId},
        where: 'id = ?',
        whereArgs: [saidaId],
      );
      await txn.update(
        'movimentacoes',
        {'transferencia_par': saidaId},
        where: 'id = ?',
        whereArgs: [entradaId],
      );
    });
  }

  Future<void> desfazerTransferencia(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE movimentacoes SET transferencia_par = NULL WHERE id = ? OR transferencia_par = ?',
        [id, id],
      );
    });
  }

  Future<void> categorizar(
    List<int> ids,
    Categoria categoria, {
    String? regra,
  }) async {
    if (ids.isEmpty || categoria.id == null) {
      throw const FormatException('Selecione lançamentos e uma categoria.');
    }
    final db = await database;
    await db.transaction((txn) async {
      final categorias = await txn.query(
        'categorias',
        where: 'id = ?',
        whereArgs: [categoria.id],
      );
      if (categorias.isEmpty ||
          categorias.single['tipo'] != categoria.tipo.name) {
        throw StateError('Categoria indisponível.');
      }
      final nome = categorias.single['nome'] as String;
      for (final id in ids.toSet()) {
        final quantidade = await txn.update(
          'movimentacoes',
          {'categoria': nome},
          where: 'id = ? AND tipo = ? AND transferencia_par IS NULL',
          whereArgs: [id, categoria.tipo.name],
        );
        if (quantidade != 1) {
          throw StateError(
            'Um lançamento mudou ou não é compatível com a categoria. Atualize a lista.',
          );
        }
      }
      if (regra != null) {
        final texto = regra.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (texto.length < 3 || texto.length > 120) {
          throw const FormatException('Use de 3 a 120 caracteres na regra.');
        }
        final existentes = await txn.query(
          'regras_importacao',
          where: 'tipo = ?',
          whereArgs: [categoria.tipo.name],
        );
        final repetidas = existentes.where(
          (r) =>
              (r['texto'] as String).trim().toLowerCase().replaceAll(
                RegExp(r'\s+'),
                ' ',
              ) ==
              texto.toLowerCase(),
        );
        if (repetidas.any((r) => r['categoria_id'] != categoria.id)) {
          throw StateError(
            'Já existe uma regra diferente para esse texto. Revise em Regras de importação.',
          );
        }
        if (repetidas.isEmpty) {
          await txn.insert('regras_importacao', {
            'texto': texto,
            'tipo': categoria.tipo.name,
            'categoria_id': categoria.id,
          });
        }
      }
    });
  }
}

bool compativeisTransferencia(Movimentacao saida, Movimentacao entrada) =>
    saida.id != null &&
    entrada.id != null &&
    saida.id != entrada.id &&
    !saida.transferencia &&
    !entrada.transferencia &&
    saida.tipo == TipoMovimentacao.despesa &&
    entrada.tipo == TipoMovimentacao.receita &&
    saida.contaId != null &&
    entrada.contaId != null &&
    saida.contaId != entrada.contaId &&
    saida.valor > 0 &&
    (saida.valor * 100).round() == (entrada.valor * 100).round() &&
    DateTime.utc(saida.data.year, saida.data.month, saida.data.day)
            .difference(
              DateTime.utc(
                entrada.data.year,
                entrada.data.month,
                entrada.data.day,
              ),
            )
            .inDays
            .abs() <=
        3;

List<(Movimentacao, Movimentacao)> sugerirTransferencias(
  List<Movimentacao> itens,
) {
  final entradas = <int, List<Movimentacao>>{};
  for (final m in itens.where(
    (m) => !m.transferencia && m.tipo == TipoMovimentacao.receita,
  )) {
    (entradas[(m.valor * 100).round()] ??= []).add(m);
  }
  return [
    for (final s in itens.where(
      (m) => !m.transferencia && m.tipo == TipoMovimentacao.despesa,
    ))
      for (final e in entradas[(s.valor * 100).round()] ?? <Movimentacao>[])
        if (compativeisTransferencia(s, e)) (s, e),
  ];
}

class TelaTransferencias extends StatefulWidget {
  const TelaTransferencias({
    super.key,
    required this.banco,
    required this.periodo,
    required this.noPeriodo,
  });
  final BancoDados banco;
  final String periodo;
  final bool Function(DateTime) noPeriodo;
  @override
  State<TelaTransferencias> createState() => _TelaTransferenciasState();
}

class _TelaTransferenciasState extends State<TelaTransferencias> {
  late Future<(List<Movimentacao>, List<ContaOrigem>)> _consulta = _carregar();
  bool _ocupado = false;
  Future<(List<Movimentacao>, List<ContaOrigem>)> _carregar() async => (
    await widget.banco.listar(),
    await ContasBanco(widget.banco.database).listar(),
  );
  Future<void> _confirmar(
    Movimentacao s,
    Movimentacao e,
    String origem,
    String destino,
  ) async {
    final sim = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar transferência'),
        content: Text(
          'Você transferiu ${dinheiroAgenda((s.valor * 100).round())} de $origem para $destino?\n\nOs dois lançamentos continuam no histórico e na movimentação bancária, mas deixam de contar como receita e despesa. Datas próximas e valores iguais são apenas uma sugestão.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (sim == true) {
      await _executar(
        () =>
            OperacoesFinanceiras(widget.banco.database)
                .confirmarTransferencia(s.id!, e.id!),
      );
    }
  }

  Future<void> _executar(Future<void> Function() acao) async {
    if (_ocupado || !mounted) return;
    setState(() {
      _ocupado = true;
    });
    try {
      await acao();
      if (mounted) {
        final consulta = _carregar();
        setState(() {
          _consulta = consulta;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _ocupado = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Transferências entre contas')),
    body: FutureBuilder<(List<Movimentacao>, List<ContaOrigem>)>(
      future: _consulta,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () {
                final consulta = _carregar();
                setState(() {
                  _consulta = consulta;
                });
              },
              child: const Text('Tentar novamente'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final (itens, contas) = snapshot.data!;
        String conta(Movimentacao m) =>
            contas.where((c) => c.id == m.contaId).firstOrNull?.rotulo ??
            'Sem conta identificada';
        String data(Movimentacao m) =>
            '${m.data.day}/${m.data.month}/${m.data.year}';
        final pares = sugerirTransferencias(itens)
            .where(
              (p) => widget.noPeriodo(p.$1.data) || widget.noPeriodo(p.$2.data),
            )
            .toList();
        final confirmadas = itens
            .where(
              (m) =>
                  m.transferencia &&
                  m.tipo == TipoMovimentacao.despesa &&
                  (widget.noPeriodo(m.data) ||
                      itens.any(
                        (e) =>
                            e.id == m.transferenciaPar &&
                            widget.noPeriodo(e.data),
                      )),
            )
            .toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(widget.periodo),
            const Text(
              'Sugestões com valores iguais, contas diferentes e até 3 dias de diferença. Um dos lados deve estar no período; o outro pode estar fora dele. Confirme somente transferências entre suas próprias contas.',
            ),
            const SizedBox(height: 16),
            Text(
              'Sugestões (${pares.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (pares.isEmpty) const Text('Nenhuma sugestão neste período.'),
            for (final (s, e) in pares)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dinheiroAgenda((s.valor * 100).round()),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('${conta(s)} → ${conta(e)}'),
                      Text(
                        '${data(s)} • ${s.descricao}\n${data(e)} • ${e.descricao}',
                      ),
                      TextButton(
                        onPressed: _ocupado
                            ? null
                            : () => _confirmar(s, e, conta(s), conta(e)),
                        child: const Text('Revisar transferência'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Confirmadas (${confirmadas.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final m in confirmadas)
              ListTile(
                title: Text(
                  '${conta(m)} • ${dinheiroAgenda((m.valor * 100).round())}',
                ),
                subtitle: Text('${data(m)} • ${m.descricao}'),
                trailing: TextButton(
                  onPressed: _ocupado
                      ? null
                      : () => _executar(
                          () =>
                              OperacoesFinanceiras(widget.banco.database)
                                  .desfazerTransferencia(m.id!),
                        ),
                  child: const Text('Desfazer'),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class TelaRevisarCategorias extends StatefulWidget {
  const TelaRevisarCategorias({
    super.key,
    required this.banco,
    required this.periodo,
    required this.noPeriodo,
  });
  final BancoDados banco;
  final String periodo;
  final bool Function(DateTime) noPeriodo;
  @override
  State<TelaRevisarCategorias> createState() => _TelaRevisarCategoriasState();
}

class _TelaRevisarCategoriasState extends State<TelaRevisarCategorias> {
  late Future<(List<Movimentacao>, List<Categoria>)> _consulta = _carregar();
  final _selecionados = <int>{};
  String _busca = '';
  bool _soOutros = true, _ocupado = false;
  TipoMovimentacao _tipo = TipoMovimentacao.despesa;
  Future<(List<Movimentacao>, List<Categoria>)> _carregar() async =>
      (await widget.banco.listar(), await widget.banco.listarCategorias());
  Future<void> _classificar(List<Categoria> categorias) async {
    Categoria? categoria;
    bool criarRegra = false;
    String texto = '';
    final form = GlobalKey<FormState>();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, atualizar) => AlertDialog(
          title: Text('Classificar ${_selecionados.length} lançamentos'),
          content: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Categoria>(
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: categorias
                        .where((c) => c.tipo == _tipo)
                        .map(
                          (c) =>
                              DropdownMenuItem(value: c, child: Text(c.nome)),
                        )
                        .toList(),
                    onChanged: (c) => categoria = c,
                    validator: (v) =>
                        v == null ? 'Escolha uma categoria.' : null,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Usar também nas próximas importações semelhantes',
                    ),
                    value: criarRegra,
                    onChanged: (v) => atualizar(() {
                      criarRegra = v ?? false;
                    }),
                  ),
                  if (criarRegra)
                    TextFormField(
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Texto contido na descrição',
                        hintText: 'Ex.: nome do estabelecimento',
                      ),
                      onChanged: (v) => texto = v,
                      validator: (v) => (v ?? '').trim().length < 3
                          ? 'Digite pelo menos 3 caracteres.'
                          : null,
                    ),
                  if (criarRegra)
                    const Text(
                      'A regra valerá para futuras importações deste tipo. Confira o texto para não classificar compras diferentes.',
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() {
      _ocupado = true;
    });
    try {
      await OperacoesFinanceiras(widget.banco.database).categorizar(
        _selecionados.toList(),
        categoria!,
        regra: criarRegra ? texto : null,
      );
      if (mounted) {
        final consulta = _carregar();
        setState(() {
          _selecionados.clear();
          _consulta = consulta;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Categorias atualizadas.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _ocupado = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Revisar categorias')),
    body: FutureBuilder<(List<Movimentacao>, List<Categoria>)>(
      future: _consulta,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Não foi possível carregar as categorias.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final itens = snapshot.data!.$1
            .where(
              (m) =>
                  m.id != null &&
                  !m.transferencia &&
                  widget.noPeriodo(m.data) &&
                  m.tipo == _tipo &&
                  (!_soOutros || m.categoria.toLowerCase() == 'outros') &&
                  m.descricao.toLowerCase().contains(_busca.toLowerCase()),
            )
            .toList();
        return Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(widget.periodo),
                          TextField(
                            enabled: !_ocupado,
                            decoration: const InputDecoration(
                              labelText: 'Buscar descrição',
                            ),
                            onChanged: (v) => setState(() {
                              _busca = v;
                              _selecionados.clear();
                            }),
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final tipo in TipoMovimentacao.values)
                                ChoiceChip(
                                  label: Text(
                                    tipo == TipoMovimentacao.receita
                                        ? 'Receitas'
                                        : 'Despesas',
                                  ),
                                  selected: _tipo == tipo,
                                  onSelected: _ocupado
                                      ? null
                                      : (_) => setState(() {
                                          _tipo = tipo;
                                          _selecionados.clear();
                                        }),
                                ),
                            ],
                          ),
                          SwitchListTile(
                            title: const Text('Somente “Outros”'),
                            value: _soOutros,
                            onChanged: _ocupado
                                ? null
                                : (v) => setState(() {
                                    _soOutros = v;
                                    _selecionados.clear();
                                  }),
                          ),
                          Wrap(
                            spacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              TextButton(
                                onPressed: _ocupado
                                    ? null
                                    : () => setState(() {
                                        if (_selecionados.length ==
                                            itens.length) {
                                          _selecionados.clear();
                                        } else {
                                          _selecionados.addAll(
                                            itens.map((m) => m.id!),
                                          );
                                        }
                                      }),
                                child: Text(
                                  _selecionados.isEmpty
                                      ? 'Selecionar todos'
                                      : 'Limpar seleção',
                                ),
                              ),
                              Text('${_selecionados.length} selecionados'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (itens.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Nenhum lançamento para revisar neste filtro.',
                        ),
                      ),
                    ),
                  SliverList.builder(
                    itemCount: itens.length,
                    itemBuilder: (ctx, i) {
                      final m = itens[i];
                      return CheckboxListTile(
                        value: _selecionados.contains(m.id),
                        title: Text(m.descricao),
                        subtitle: Text(
                          '${m.data.day}/${m.data.month}/${m.data.year} • ${m.categoria} • ${dinheiroAgenda((m.valor * 100).round())}',
                        ),
                        onChanged: _ocupado
                            ? null
                            : (v) => setState(() {
                                if (v == true) {
                                  _selecionados.add(m.id!);
                                } else {
                                  _selecionados.remove(m.id);
                                }
                              }),
                      );
                    },
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: _ocupado || _selecionados.isEmpty
                      ? null
                      : () => _classificar(snapshot.data!.$2),
                  child: const Text('Escolher categoria'),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
