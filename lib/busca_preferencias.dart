part of 'main.dart';

int? valorPesquisadoEmCentavos(String pesquisa) {
  var texto = pesquisa
      .trim()
      .toLowerCase()
      .replaceFirst(RegExp(r'^r\$\s*'), '')
      .replaceAll(RegExp(r'\s+'), '');
  texto = texto.replaceFirst(RegExp(r'^[+-]'), '');
  if (RegExp(r'^(?:\d{1,3}(?:\.\d{3})+|\d+)(?:,\d{1,2})?$').hasMatch(texto)) {
    texto = texto.replaceAll('.', '').replaceAll(',', '.');
  } else if (!RegExp(r'^\d+\.\d{1,2}$').hasMatch(texto)) {
    return null;
  }
  final valor = double.tryParse(texto);
  return valor == null || !valor.isFinite || !(valor * 100).isFinite ? null : (valor * 100).round();
}

List<Movimentacao> filtrarHistorico(
  List<Movimentacao> itens, {
  String pesquisa = '',
  TipoMovimentacao? tipo,
  String? categoria,
  bool? ativa,
  int? contaId,
}) {
  final texto = pesquisa.trim().toLowerCase();
  final centavos = valorPesquisadoEmCentavos(pesquisa);
  return itens
      .where(
        (m) =>
            (tipo == null || m.tipo == tipo) &&
            (categoria == null || m.categoria == categoria) &&
            (ativa == null || m.ativa == ativa) &&
            (contaId == null ||
                (contaId == -1 ? m.contaId == null : m.contaId == contaId)) &&
            (texto.isEmpty ||
                m.descricao.toLowerCase().contains(texto) ||
                (centavos != null && (m.valor * 100).round() == centavos)),
      )
      .toList();
}

String normalizarDescricaoPreferencia(String descricao) =>
    descricao.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

class PreferenciaContabilizacao {
  const PreferenciaContabilizacao({
    required this.contaId,
    required this.tipo,
    required this.descricao,
    required this.ativa,
    this.habilitada = true,
  });
  final int contaId;
  final TipoMovimentacao tipo;
  final String descricao;
  final bool ativa, habilitada;
  String get chave =>
      'contabilizacao:${base64Url.encode(utf8.encode(jsonEncode([contaId, tipo.name, normalizarDescricaoPreferencia(descricao)])))}';
  Map<String, Object?> get mapa => {
    'conta_id': contaId,
    'tipo': tipo.name,
    'descricao': descricao,
    'ativa': ativa,
    'habilitada': habilitada,
  };
  factory PreferenciaContabilizacao.deMapa(Map<String, dynamic> m) =>
      PreferenciaContabilizacao(
        contaId: m['conta_id'] as int,
        tipo: TipoMovimentacao.values.byName(m['tipo'] as String),
        descricao: m['descricao'] as String,
        ativa: m['ativa'] as bool,
        habilitada: m['habilitada'] as bool,
      );
  PreferenciaContabilizacao copiar({bool? ativa, bool? habilitada}) =>
      PreferenciaContabilizacao(
        contaId: contaId,
        tipo: tipo,
        descricao: descricao,
        ativa: ativa ?? this.ativa,
        habilitada: habilitada ?? this.habilitada,
      );
}

class MudancaPreferencia {
  MudancaPreferencia(this.chave, this.antes, this.depois);
  final String chave, depois;
  final String? antes;
  Future<void> desfazer(DatabaseExecutor db) async {
    final rows = await db.query(
      'preferencias',
      where: 'chave = ?',
      whereArgs: [chave],
    );
    if (rows.isEmpty || rows.single['valor'] != depois) {
      throw StateError('A preferência foi alterada novamente.');
    }
    if (antes == null) {
      await db.delete('preferencias', where: 'chave = ?', whereArgs: [chave]);
    } else {
      await db.update(
        'preferencias',
        {'valor': antes},
        where: 'chave = ?',
        whereArgs: [chave],
      );
    }
  }
}

class PreferenciasContabilizacao {
  PreferenciasContabilizacao(this.database);
  final Future<Database> database;

  Future<List<PreferenciaContabilizacao>> listar() async {
    final db = await database;
    final contas = (await db.query(
      'contas',
      columns: ['id'],
    )).map((c) => c['id']).toSet();
    final rows = await db.query(
      'preferencias',
      where: 'chave LIKE ?',
      whereArgs: ['contabilizacao:%'],
    );
    final resultado = <PreferenciaContabilizacao>[];
    for (final row in rows) {
      try {
        final item = PreferenciaContabilizacao.deMapa(
          jsonDecode(row['valor'] as String) as Map<String, dynamic>,
        );
        if (contas.contains(item.contaId)) resultado.add(item);
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      } on ArgumentError {
        continue;
      }
    }
    resultado.sort((a, b) => a.descricao.compareTo(b.descricao));
    return resultado;
  }

  Future<MudancaPreferencia> salvar(PreferenciaContabilizacao item) async {
    if (item.descricao.trim().isEmpty) {
      throw StateError('Informe uma descrição.');
    }
    final db = await database;
    return db.transaction((txn) async {
      if ((await txn.query(
        'contas',
        where: 'id = ?',
        whereArgs: [item.contaId],
      )).isEmpty) {
        throw StateError('Esta conta não está mais disponível.');
      }
      final anterior = await txn.query(
        'preferencias',
        where: 'chave = ?',
        whereArgs: [item.chave],
      );
      final valor = jsonEncode(item.mapa);
      await txn.insert('preferencias', {
        'chave': item.chave,
        'valor': valor,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return MudancaPreferencia(
        item.chave,
        anterior.isEmpty ? null : anterior.single['valor'] as String,
        valor,
      );
    });
  }

  Future<void> excluir(PreferenciaContabilizacao item) async => (await database)
      .delete('preferencias', where: 'chave = ?', whereArgs: [item.chave]);

  Future<void> sugerir(List<ItemExtrato> itens, ContaOrigem conta) async {
    final db = await database;
    final contas = await db.query(
      'contas',
      where: 'banco_codigo = ? AND nome_chave = ?',
      whereArgs: [conta.bancoCodigo, conta.chave],
    );
    final id = conta.id ?? (contas.isEmpty ? null : contas.single['id'] as int);
    final regras = {
      for (final r in await listar())
        if (r.habilitada && r.contaId == id)
          '${r.tipo.name}:${normalizarDescricaoPreferencia(r.descricao)}': r,
    };
    for (final item in itens) {
      item.contabilizacaoSugerida =
          regras['${item.tipo.name}:${normalizarDescricaoPreferencia(item.descricao)}']
              ?.ativa;
      // A sugestão não altera a escolha do usuário.
    }
  }
}

class TelaPreferenciasContabilizacao extends StatefulWidget {
  const TelaPreferenciasContabilizacao({super.key, required this.banco});
  final BancoDados banco;
  @override
  State<TelaPreferenciasContabilizacao> createState() =>
      _TelaPreferenciasContabilizacaoState();
}

class _TelaPreferenciasContabilizacaoState
    extends State<TelaPreferenciasContabilizacao> {
  late final _repo = PreferenciasContabilizacao(widget.banco.database);
  late Future<(List<PreferenciaContabilizacao>, List<ContaOrigem>)> _dados =
      _carregar();
  bool _ocupado = false;
  Future<(List<PreferenciaContabilizacao>, List<ContaOrigem>)>
  _carregar() async =>
      (await _repo.listar(), await ContasBanco(widget.banco.database).listar());
  Future<void> _alterar(PreferenciaContabilizacao item, String acao) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      if (acao == 'excluir') {
        await _repo.excluir(item);
      } else {
        await _repo.salvar(
          acao == 'pausar'
              ? item.copiar(habilitada: !item.habilitada)
              : item.copiar(ativa: !item.ativa),
        );
      }
      final dados = await _carregar();
      if (mounted) setState(() => _dados = Future.value(dados));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível atualizar a preferência.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final semantica = CoresSemanticas.de(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Preferências de contabilização')),
      body: FutureBuilder<(List<PreferenciaContabilizacao>, List<ContaOrigem>)>(
        future: _dados,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: () => setState(() => _dados = _carregar()),
                child: const Text('Tentar novamente'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final (regras, contas) = snapshot.data!;
          final nomes = {for (final c in contas) c.id: c.rotulo};
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: esquema.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(RaioBorda.cartao),
                  border: Border.all(
                    color: esquema.outlineVariant.withValues(alpha: 0.7),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.fact_check_outlined,
                      size: 20,
                      color: esquema.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'As preferências geram sugestões na importação. Você decide se deseja aplicá-las. A correspondência usa a mesma conta, tipo e descrição completa.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: esquema.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (regras.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Nenhuma preferência salva. Ao ativar ou desativar uma movimentação com conta identificada, escolha Lembrar preferência.',
                  ),
                ),
              for (final r in regras)
                Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  color: esquema.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RaioBorda.cartao),
                    side: BorderSide(
                      color: esquema.outlineVariant.withValues(alpha: 0.65),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: r.tipo == TipoMovimentacao.receita
                            ? semantica.receitaFundo
                            : semantica.despesaFundo,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        r.tipo == TipoMovimentacao.receita
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 20,
                        color: r.tipo == TipoMovimentacao.receita
                            ? semantica.receita
                            : semantica.despesa,
                      ),
                    ),
                    title: Text(
                      r.descricao,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${nomes[r.contaId]} • ${r.tipo == TipoMovimentacao.receita ? 'Receita' : 'Despesa'}\n${r.habilitada ? 'Sugerir contabilização ${r.ativa ? 'ativa' : 'desativada'}' : 'Preferência pausada'}',
                      style: TextStyle(color: esquema.onSurfaceVariant),
                    ),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Descrição da preferência'),
                        content: SingleChildScrollView(
                          child: SelectableText(r.descricao),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Fechar'),
                          ),
                        ],
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      enabled: !_ocupado,
                      tooltip: 'Editar preferência',
                      onSelected: (acao) => _alterar(r, acao),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'pausar',
                          child: Text(
                            r.habilitada
                                ? 'Pausar preferência'
                                : 'Reativar preferência',
                          ),
                        ),
                        PopupMenuItem(
                          value: 'inverter',
                          child: Text(
                            r.ativa ? 'Sugerir desativação' : 'Sugerir ativação',
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'excluir',
                          child: Text('Excluir preferência'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

