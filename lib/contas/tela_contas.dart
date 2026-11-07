import 'package:flutter/material.dart';

import 'contas_banco.dart';

/// Retorna uma conta existente ou um rascunho: cancelar não grava no banco.
class TelaEscolherConta extends StatefulWidget {
  const TelaEscolherConta({
    super.key,
    required this.contas,
    this.bancoDetectado = 'generico',
    this.bancos = bancosImportacao,
    this.editarConta,
  });
  final ContaOrigem? editarConta;
  final List<ContaOrigem> contas;
  final Map<String, String> bancos;
  final String bancoDetectado;
  @override
  State<TelaEscolherConta> createState() => _TelaEscolherContaState();
}

class _TelaEscolherContaState extends State<TelaEscolherConta> {
  final _form = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.editarConta?.nome);
  int? _id;
  late final Map<String, String> _bancos = {...widget.bancos};
  late String _banco = widget.editarConta?.bancoCodigo ?? widget.bancoDetectado;
  Future<void> _adicionarBanco() async {
    String nome = '';
    final form = GlobalKey<FormState>();
    final valor = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar banco'),
        content: Form(
          key: form,
          child: TextFormField(
            autofocus: true,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Nome do banco'),
            onChanged: (v) => nome = v.trim(),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Informe o nome do banco.' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(ctx, nome);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    if (valor == null || !mounted) return;
    String normalizar(String v) =>
        v.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final existentes = _bancos.entries.where(
      (b) => normalizar(b.value) == normalizar(valor),
    );
    setState(() {
      _banco = existentes.isEmpty
          ? 'personalizado:${normalizar(valor)}'
          : existentes.first.key;
      _bancos[_banco] = existentes.isEmpty ? valor : existentes.first.value;
    });
  }

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.editarConta == null ? 'Conta de origem' : 'Editar conta',
      ),
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.editarConta == null
                ? 'Escolha a conta de origem. Reutilize uma conta já cadastrada para novos arquivos.'
                : 'Altere o nome ou banco desta conta. Os lançamentos e importações permanecem vinculados.',
          ),
          const SizedBox(height: 20),
          if (widget.editarConta == null)
            DropdownButtonFormField<int>(
              initialValue: _id ?? -1,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Conta'),
              items: [
                const DropdownMenuItem(
                  value: -1,
                  child: Text('Cadastrar nova conta'),
                ),
                ...widget.contas
                    .where(
                      (c) =>
                          widget.bancoDetectado == 'generico' ||
                          c.bancoCodigo == widget.bancoDetectado,
                    )
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.rotulo, overflow: TextOverflow.ellipsis),
                      ),
                    ),
              ],
              onChanged: (v) => setState(() => _id = v == -1 ? null : v),
            ),
          if (_id == null) ...[
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              key: ValueKey(_banco),
              initialValue: _banco,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Banco'),
              items: _bancos.entries
                  .map(
                    (b) => DropdownMenuItem(value: b.key, child: Text(b.value)),
                  )
                  .toList(),
              onChanged: widget.bancoDetectado == 'generico'
                  ? (v) => setState(() => _banco = v!)
                  : null,
            ),
            const SizedBox(height: 20),
            if (widget.bancoDetectado == 'generico')
              TextButton.icon(
                onPressed: _adicionarBanco,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar banco'),
              ),
            TextFormField(
              controller: _nome,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Nome da conta',
                hintText: 'Ex.: Conta pessoal • final 1234',
              ),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? 'Informe um nome para identificar esta conta.'
                  : null,
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              final conta = _id == null
                  ? ContaOrigem(
                      nome: _nome.text.trim(),
                      bancoCodigo: _banco,
                      nomeBanco: _bancos[_banco],
                    )
                  : widget.contas.firstWhere((c) => c.id == _id);
              Navigator.pop(context, conta);
            },
            child: Text(
              widget.editarConta == null ? 'Continuar' : 'Salvar alterações',
            ),
          ),
        ],
      ),
    ),
  );
}

class TelaContas extends StatefulWidget {
  const TelaContas({super.key, required this.banco});
  final ContasBanco banco;
  @override
  State<TelaContas> createState() => _TelaContasState();
}

class _TelaContasState extends State<TelaContas> {
  late Future<List<ContaOrigem>> _consulta = widget.banco.listar();
  bool _ocupado = false;
  Future<void> _adicionar() async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      final bancos = await widget.banco.listarBancos();
      if (!mounted) return;
      final conta = await Navigator.push<ContaOrigem>(
        context,
        MaterialPageRoute(
          builder: (_) => TelaEscolherConta(contas: const [], bancos: bancos),
        ),
      );
      if (conta == null) return;
      await widget.banco.salvar(conta);
      if (mounted) {
        final consulta = widget.banco.listar();
        setState(() {
          _consulta = consulta;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar a conta: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _editar(ContaOrigem conta) async {
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
    });
    try {
      final bancos = await widget.banco.listarBancos();
      if (!mounted) return;
      final nova = await Navigator.push<ContaOrigem>(
        context,
        MaterialPageRoute(
          builder: (_) => TelaEscolherConta(
            contas: const [],
            bancos: bancos,
            editarConta: conta,
          ),
        ),
      );
      if (nova == null) return;
      await widget.banco.editar(conta.id!, nova);
      if (!mounted) return;
      final consulta = widget.banco.listar();
      setState(() {
        _consulta = consulta;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Conta atualizada.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Não foi possível editar: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _ocupado = false;
        });
      }
    }
  }

  Future<void> _reunir(ContaOrigem origem) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      final contas = await widget.banco.listar();
      final bancos = await widget.banco.listarBancos();
      if (!mounted) return;
      final destino = await Navigator.push<ContaOrigem>(
        context,
        MaterialPageRoute(
          builder: (_) => TelaEscolherConta(
            contas: contas.where((c) => c.id != origem.id).toList(),
            bancos: bancos,
          ),
        ),
      );
      if (destino == null || !mounted) return;
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reunir cadastros'),
          content: Text(
            'Mover todos os lançamentos e importações de ${origem.rotulo} para ${destino.rotulo}? O cadastro de origem será removido. Nenhum lançamento será apagado; possíveis duplicatas serão mantidas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reunir'),
            ),
          ],
        ),
      );
      if (confirmar != true) return;
      await widget.banco.reunir(origem.id!, destino);
      if (mounted) {
        final consulta = widget.banco.listar();
        setState(() {
          _consulta = consulta;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Não foi possível reunir: $e')));
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _excluir(ContaOrigem conta) async {
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
    });
    try {
      final (movimentos, importacoes) = await widget.banco.contarVinculos(
        conta.id!,
      );
      if (!mounted) return;
      var apagarDados = false;
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, atualizar) => AlertDialog(
            title: const Text('Excluir conta'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${conta.rotulo}\n\n$importacoes importações e $movimentos lançamentos vinculados.',
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Apagar também importações e lançamentos',
                    ),
                    value: apagarDados,
                    onChanged: (v) => atualizar(() {
                      apagarDados = v ?? false;
                    }),
                  ),
                  Text(
                    apagarDados
                        ? 'O cadastro da conta e suas importações serão removidos. Os lançamentos irão para a lixeira por 30 dias e poderão ser recuperados sem esses vínculos. Os arquivos originais serão preservados.'
                        : 'Somente o cadastro da conta será excluído. Importações e lançamentos serão preservados, sem conta identificada. Os totais financeiros permanecem iguais.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  apagarDados
                      ? 'Excluir conta e dados'
                      : 'Excluir só o cadastro',
                ),
              ),
            ],
          ),
        ),
      );
      if (confirmar != true) return;
      await widget.banco.excluir(conta.id!, apagarDados: apagarDados);
      if (!mounted) return;
      final consulta = widget.banco.listar();
      setState(() {
        _consulta = consulta;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apagarDados
                ? 'Conta e dados vinculados excluídos.'
                : 'Conta excluída. Lançamentos preservados.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível excluir a conta: $e')),
        );
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
    appBar: AppBar(
      title: const Text('Contas/Bancos'),
      actions: [
        IconButton(
          tooltip: 'Relatório por banco',
          icon: const Icon(Icons.bar_chart),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TelaRelatorioBancos(banco: widget.banco),
            ),
          ),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: _ocupado ? null : _adicionar,
      child: const Icon(Icons.add),
    ),
    body: FutureBuilder<List<ContaOrigem>>(
      future: _consulta,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Não foi possível carregar as contas.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            const Text(
              'As contas pertencem ao perfil atual. Movimentações antigas permanecem sem origem identificada.',
            ),
            if (snapshot.data!.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhuma conta cadastrada. Toque em + para adicionar.',
                ),
              ),
            ...snapshot.data!.map(
              (c) => ListTile(
                leading: const Icon(Icons.account_balance_outlined),
                title: Text(c.nome),
                subtitle: Text(c.bancoNome),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Opções da conta',
                  enabled: !_ocupado,
                  onSelected: (acao) {
                    if (acao == 'editar') _editar(c);
                    if (acao == 'reunir') _reunir(c);
                    if (acao == 'excluir') _excluir(c);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'editar',
                      child: Text('Editar nome/banco'),
                    ),
                    PopupMenuItem(
                      value: 'reunir',
                      child: Text('Reunir com outra conta'),
                    ),
                    PopupMenuItem(
                      value: 'excluir',
                      child: Text('Excluir conta'),
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

class TelaRelatorioBancos extends StatefulWidget {
  const TelaRelatorioBancos({super.key, required this.banco});
  final ContasBanco banco;
  @override
  State<TelaRelatorioBancos> createState() => _TelaRelatorioBancosState();
}

class _TelaRelatorioBancosState extends State<TelaRelatorioBancos> {
  DateTimeRange _periodo = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month),
    end: DateTime.now(),
  );
  late Future<List<Map<String, Object?>>> _consulta = _carregar();
  Future<List<Map<String, Object?>>> _carregar() => widget.banco.resumo(
    _periodo.start,
    DateTime(_periodo.end.year, _periodo.end.month, _periodo.end.day + 1),
  );
  String _data(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _valor(Object? n) =>
      'R\$ ${(n as num? ?? 0).toStringAsFixed(2).replaceAll('.', ',')}';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Movimentação por banco')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.date_range),
          label: Text('${_data(_periodo.start)} a ${_data(_periodo.end)}'),
          onPressed: () async {
            final periodo = await showDateRangePicker(
              context: context,
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
              initialDateRange: _periodo,
            );
            if (periodo != null && mounted) {
              setState(() {
                _periodo = periodo;
                _consulta = _carregar();
              });
            }
          },
        ),
        const Text(
          'Ordenado pelo total de entradas + saídas. Transferências registradas também entram na movimentação; este total não representa lucro.',
        ),
        FutureBuilder<List<Map<String, Object?>>>(
          future: _consulta,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Não foi possível carregar o relatório.');
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data!.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nenhuma movimentação neste período.'),
              );
            }
            final total = snapshot.data!.fold<double>(
              0,
              (s, b) => s + (b['volume'] as num).toDouble(),
            );
            return Column(
              children: snapshot.data!
                  .map(
                    (b) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b['banco_nome'] as String,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text('Movimentação: ${_valor(b['volume'])}'),
                            Text(
                              'Entradas: ${_valor(b['entradas'])} • Saídas: ${_valor(b['saidas'])}',
                            ),
                            Text(
                              '${b['quantidade']} transações • ${total == 0 ? '0' : ((b['volume'] as num) / total * 100).toStringAsFixed(1)}% do total',
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    ),
  );
}
