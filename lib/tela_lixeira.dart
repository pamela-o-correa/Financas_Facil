part of 'main.dart';

class TelaLixeira extends StatefulWidget {
  const TelaLixeira({super.key, required this.banco});
  final LixeiraBanco banco;
  @override
  State<TelaLixeira> createState() => _TelaLixeiraState();
}

class _TelaLixeiraState extends State<TelaLixeira> {
  late Future<List<Map<String, Object?>>> _consulta = widget.banco.listar();
  bool _ocupado = false;
  void _recarregar() {
    final consulta = widget.banco.listar();
    setState(() {
      _consulta = consulta;
    });
  }

  Future<void> _recuperar(int id) async {
    await _executar(() async {
      try {
        await widget.banco.restaurar(id);
      } on DuplicataNaRecuperacao {
        if (!mounted) return;
        final sim = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Possível duplicata'),
            content: const Text(
              'Já existe um lançamento com a mesma data, valor, descrição e conta. Recuperar mesmo assim aumentará os totais novamente.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Recuperar mesmo assim'),
              ),
            ],
          ),
        );
        if (sim != true) return;
        await widget.banco.restaurar(id, permitirDuplicata: true);
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Lançamento recuperado.')));
      }
    });
  }

  Future<void> _apagar({int? id, String? descricao}) async {
    final sim = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          id == null ? 'Esvaziar lixeira?' : 'Apagar definitivamente?',
        ),
        content: Text(
          id == null
              ? 'Todos os lançamentos da lixeira deste perfil serão apagados. Esta ação não pode ser desfeita.'
              : '“$descricao” será apagado definitivamente. Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apagar definitivamente'),
          ),
        ],
      ),
    );
    if (sim == true) {
      await _executar(
        () => id == null
            ? widget.banco.esvaziar()
            : widget.banco.apagarDefinitivamente(id),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensagemErroSegura(e))));
      }
    } finally {
      if (mounted) {
        setState(() {
          _ocupado = false;
        });
        _recarregar();
      }
    }
  }

  String _data(Object? valor) {
    final d = DateTime.parse(valor as String).toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final semantica = CoresSemanticas.de(context);
    return PopScope(
      canPop: !_ocupado,
      child: Scaffold(
        appBar: AppBar(title: const Text('Lixeira')),
        body: FutureBuilder<List<Map<String, Object?>>>(
          future: _consulta,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: TextButton(
                  onPressed: _recarregar,
                  child: const Text('Tentar novamente'),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final itens = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: itens.length + 1,
              itemBuilder: (context, indice) {
                if (indice == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: esquema.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(RaioBorda.cartao),
                          border: Border.all(
                            color: esquema.outlineVariant.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.restore_from_trash_outlined,
                                  size: 20,
                                  color: esquema.primary,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Recuperação por 30 dias',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Os lançamentos ficam aqui por 30 dias e não entram nos totais. Depois desse prazo, não podem ser recuperados; a limpeza ocorre ao abrir o app ou esta tela.',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: esquema.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Se a conta ou importação original não existir mais, o lançamento será recuperado sem esse vínculo. Transferências são recuperadas com a contabilização desativada para revisão.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: esquema.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (itens.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Lixeira vazia.'),
                        )
                      else ...[
                        OutlinedButton.icon(
                          onPressed: _ocupado ? null : () => _apagar(),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.delete_forever),
                          label: Text('Esvaziar lixeira (${itens.length})'),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                }
                final item = itens[indice - 1];
                final pacote = jsonDecode(item['dados'] as String) as Map;
                final m = pacote['movimentacao'] as Map;
                final conta = pacote['conta'] as Map?;
                final ehReceita = m['tipo'] == 'receita';
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  color: esquema.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RaioBorda.cartao),
                    side: BorderSide(
                      color: esquema.outlineVariant.withValues(alpha: 0.65),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: ehReceita
                                    ? semantica.receitaFundo
                                    : semantica.despesaFundo,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                ehReceita
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                size: 18,
                                color: ehReceita
                                    ? semantica.receita
                                    : semantica.despesa,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                m['descricao'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${ehReceita ? 'Receita' : 'Despesa'} • ${dinheiroAgenda(((m['valor'] as num) * 100).round())} • ${_data(m['data'])}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${m['categoria']} • ${conta == null ? 'Sem conta identificada' : '${conta['banco_nome']} • ${conta['nome']}'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: esquema.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Excluído em ${_data(item['excluido_em'])} • Prazo até ${_data(item['expira_em'])}',
                          style: TextStyle(
                            fontSize: 12,
                            color: esquema.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: _ocupado
                                  ? null
                                  : () => _recuperar(item['id'] as int),
                              icon: const Icon(Icons.restore),
                              label: const Text('Recuperar'),
                            ),
                            TextButton(
                              onPressed: _ocupado
                                  ? null
                                  : () => _apagar(
                                      id: item['id'] as int,
                                      descricao: m['descricao'] as String,
                                    ),
                              child: const Text('Apagar definitivamente'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
