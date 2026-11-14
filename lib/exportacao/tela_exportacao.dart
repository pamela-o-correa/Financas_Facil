import 'package:material_ui/material_ui.dart';
import 'package:sqflite/sqflite.dart';

import '../perfis.dart';
import 'dados_relatorio.dart';
import 'repositorio_relatorio.dart';
import 'servico_exportacao.dart';

class TelaExportacao extends StatefulWidget {
  const TelaExportacao({
    super.key,
    required this.database,
    required this.perfil,
    this.perfis,
    this.abrirPerfil,
    this.servico,
  });
  final Future<Database> database;
  final String perfil;
  final Future<List<PerfilFinanceiro>> Function()? perfis;
  final Future<Database> Function(PerfilFinanceiro)? abrirPerfil;
  final ServicoExportacao? servico;
  @override
  State<TelaExportacao> createState() => _TelaExportacaoState();
}

class _TelaExportacaoState extends State<TelaExportacao> {
  late final ServicoExportacao _servico = widget.servico ?? ServicoExportacao();
  late Future<Database> _db = widget.database;
  late String _nomePerfil = widget.perfil;
  List<PerfilFinanceiro> _perfis = [];
  int? _perfilId;
  List<LinhaRelatorio> _linhas = [];
  String _periodo = 'mes', _origem = 'movimentacoes';
  String? _tipo, _conta, _categoria;
  FormatoRelatorio _formato = FormatoRelatorio.pdf;
  DateTimeRange? _personalizado;
  bool _carregando = true, _ocupado = false, _detalhar = false;
  String? _erro;
  ArquivoRelatorio? _arquivo;
  int _consulta = 0;
  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    try {
      final perfis = await widget.perfis?.call() ?? <PerfilFinanceiro>[];
      if (!mounted) return;
      setState(() {
        _perfis = perfis;
        _perfilId = perfis
            .where((p) => p.nome == widget.perfil)
            .firstOrNull
            ?.id;
      });
      await _carregar();
    } catch (_) {
      if (mounted) {
        setState(() {
          _erro = 'Não foi possível carregar os perfis.';
          _carregando = false;
        });
      }
    }
  }

  Future<void> _carregar() async {
    final consulta = ++_consulta;
    setState(() {
      _carregando = true;
      _erro = null;
      _arquivo = null;
    });
    try {
      final linhas = await RepositorioRelatorio(_db, _nomePerfil).carregar();
      if (mounted && consulta == _consulta) setState(() => _linhas = linhas);
    } catch (_) {
      if (mounted && consulta == _consulta) {
        setState(
          () => _erro = 'Não foi possível carregar os dados. Tente novamente.',
        );
      }
    } finally {
      if (mounted && consulta == _consulta) setState(() => _carregando = false);
    }
  }

  DateTimeRange? get _intervalo {
    final hoje = DateTime.now();
    final mes = DateTime(hoje.year, hoje.month);
    return switch (_periodo) {
      'mes' => DateTimeRange(
        start: mes,
        end: DateTime(hoje.year, hoje.month + 1, 0),
      ),
      'anterior' => DateTimeRange(
        start: DateTime(hoje.year, hoje.month - 1),
        end: DateTime(hoje.year, hoje.month, 0),
      ),
      '3' => DateTimeRange(
        start: DateTime(hoje.year, hoje.month - 2),
        end: DateTime(hoje.year, hoje.month + 1, 0),
      ),
      '6' => DateTimeRange(
        start: DateTime(hoje.year, hoje.month - 5),
        end: DateTime(hoje.year, hoje.month + 1, 0),
      ),
      'ano' => DateTimeRange(
        start: DateTime(hoje.year),
        end: DateTime(hoje.year, 12, 31),
      ),
      'personalizado' => _personalizado,
      _ => null,
    };
  }

  FiltroRelatorio get _filtro => FiltroRelatorio(
    inicio: _intervalo?.start,
    fim: _intervalo?.end,
    tipo: _tipo,
    conta: _conta,
    contaRotulo: _linhas
        .where((l) => l.chaveConta == _conta)
        .firstOrNull
        ?.rotuloConta,
    categoria: _categoria,
    origem: _origem,
  );
  void _mudar(VoidCallback acao) => setState(() {
    acao();
    _arquivo = null;
  });
  void _aviso(String texto) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(texto)));
    }
  }

  Future<void> _gerar() async {
    if (_ocupado) return;
    if (_periodo == 'personalizado' && _personalizado == null) {
      _aviso('Escolha a data inicial e a data final.');
      return;
    }
    setState(() {
      _ocupado = true;
      _arquivo = null;
    });
    try {
      final linhas = await RepositorioRelatorio(_db, _nomePerfil).carregar();
      final dados = DadosRelatorio(
        perfil: _nomePerfil,
        filtro: _filtro,
        linhas: linhas,
      );
      final arquivo = await _servico.gerar(
        dados,
        _formato,
        detalhar: _detalhar,
      );
      if (mounted) {
        setState(() {
          _arquivo = arquivo;
          _linhas = linhas;
        });
        _aviso('Relatório gerado com sucesso');
      }
    } catch (_) {
      _aviso(
        'Não foi possível gerar o relatório. Confira os filtros e tente novamente.',
      );
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _entregar(bool compartilhar, BuildContext origem) async {
    if (_ocupado || _arquivo == null) return;
    final box = origem.findRenderObject() as RenderBox?;
    final retangulo = box == null
        ? const Rect.fromLTWH(0, 0, 1, 1)
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _ocupado = true);
    try {
      if (compartilhar) {
        await _servico.compartilhar(_arquivo!, retangulo);
      } else if (await _servico.salvar(_arquivo!)) {
        _aviso('Arquivo salvo com sucesso.');
      }
    } catch (_) {
      _aviso(
        compartilhar
            ? 'Não foi possível abrir o compartilhamento. Tente salvar o arquivo.'
            : 'Não foi possível salvar. Tente outro local.',
      );
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Widget _secao(String titulo, List<Widget> filhos) {
    final cores = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: cores.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cores.outlineVariant.withValues(alpha: 0.65)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              titulo,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            ...filhos,
          ],
        ),
      ),
    );
  }

  Widget _campo(
    String rotulo,
    String valor,
    Map<String, String> opcoes,
    ValueChanged<String?> mudar,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$rotulo-$valor-$_perfilId'),
      initialValue: valor,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: rotulo,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final e in opcoes.entries)
          DropdownMenuItem(
            value: e.key,
            child: Text(e.value, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: mudar,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final contas = <String, String>{
      for (final l in _linhas) l.chaveConta: l.rotuloConta,
    };
    final categorias =
        _linhas
            .where((l) => _tipo == null || l.tipo == _tipo)
            .map((l) => l.categoria)
            .toSet()
            .toList()
          ..sort();
    final quantidade = _linhas.where(_filtro.aceita).length;
    return PopScope(
      canPop: !_ocupado,
      child: Scaffold(
        appBar: AppBar(title: const Text('Exportar e Relatórios')),
        body: _carregando
            ? const Center(child: CircularProgressIndicator())
            : _erro != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_erro!),
                    TextButton(
                      onPressed: _inicializar,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              )
            : AbsorbPointer(
                absorbing: _ocupado,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: cores.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: cores.outlineVariant.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: cores.primaryContainer.withValues(
                                alpha: 0.65,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.description_outlined,
                              color: cores.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Suas finanças, em detalhes',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Escolha os dados e o formato. Depois, salve ou compartilhe.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: cores.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _secao('1. Período e perfil', [
                      if (_perfis.isNotEmpty && widget.abrirPerfil != null)
                        _campo(
                          'Perfil',
                          '${_perfilId ?? _perfis.first.id}',
                          {for (final p in _perfis) '${p.id}': p.nome},
                          (v) {
                            final p = _perfis.firstWhere((p) => '${p.id}' == v);
                            _mudar(() {
                              _perfilId = p.id;
                              _nomePerfil = p.nome;
                              _db = widget.abrirPerfil!(p);
                              _conta = null;
                              _categoria = null;
                            });
                            _carregar();
                          },
                        )
                      else
                        Text('Perfil: $_nomePerfil'),
                      _campo('Período', _periodo, {
                        'mes': 'Este mês',
                        'anterior': 'Mês anterior',
                        '3': 'Últimos 3 meses',
                        '6': 'Últimos 6 meses',
                        'ano': 'Este ano',
                        'personalizado': 'Período personalizado',
                        'todos': 'Todo o período',
                      }, (v) => _mudar(() => _periodo = v!)),
                      if (_periodo == 'personalizado')
                        OutlinedButton.icon(
                          onPressed: () async {
                            final p = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(1900),
                              lastDate: DateTime(2340, 12, 31),
                              initialDateRange: _personalizado,
                            );
                            if (p != null && mounted) {
                              _mudar(() => _personalizado = p);
                            }
                          },
                          icon: const Icon(Icons.date_range),
                          label: Text(
                            _personalizado == null
                                ? 'Escolher datas'
                                : '${dataBr(_personalizado!.start)} a ${dataBr(_personalizado!.end)}',
                          ),
                        ),
                      if (_periodo != 'personalizado')
                        Text(
                          _filtro.periodo,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ]),
                    _secao('2. Dados e filtros', [
                      _campo('Dados para exportar', _origem, {
                        'movimentacoes': 'Movimentações realizadas',
                        'agenda': 'Previsões da agenda',
                        'ambos': 'Realizadas e previstas',
                      }, (v) => _mudar(() => _origem = v!)),
                      _campo(
                        'Tipo de movimentação',
                        _tipo ?? 'todos',
                        {
                          'todos': 'Receitas e despesas',
                          'receita': 'Apenas receitas',
                          'despesa': 'Apenas despesas',
                        },
                        (v) => _mudar(() {
                          _tipo = v == 'todos' ? null : v;
                          _categoria = null;
                        }),
                      ),
                      _campo('Conta', _conta ?? 'todas', {
                        'todas': 'Todas as contas',
                        ...contas,
                      }, (v) => _mudar(() => _conta = v == 'todas' ? null : v)),
                      _campo(
                        'Categoria',
                        _categoria ?? 'todas',
                        {
                          'todas': 'Todas as categorias',
                          for (final c in categorias) c: c,
                        },
                        (v) =>
                            _mudar(() => _categoria = v == 'todas' ? null : v),
                      ),
                      Text(
                        '$quantidade registros nos filtros selecionados',
                        style: TextStyle(
                          color: cores.primary,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Totais consideram apenas movimentações ativas, sem transferências internas. Previsões ficam separadas dos valores realizados.',
                        style: TextStyle(
                          fontSize: 12,
                          color: cores.onSurfaceVariant,
                        ),
                      ),
                    ]),
                    _secao('3. Formato', [
                      for (final formato in FormatoRelatorio.values)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: _formato == formato
                                ? cores.primaryContainer.withValues(alpha: 0.45)
                                : cores.surface,
                            borderRadius: BorderRadius.circular(14),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: _formato == formato
                                      ? cores.primary
                                      : cores.outlineVariant.withValues(
                                          alpha: 0.7,
                                        ),
                                  width: _formato == formato ? 1.5 : 1,
                                ),
                              ),
                              leading: Icon(
                                formato == FormatoRelatorio.pdf
                                    ? Icons.picture_as_pdf_outlined
                                    : formato == FormatoRelatorio.xlsx
                                    ? Icons.table_chart_outlined
                                    : Icons.grid_on_outlined,
                                color: _formato == formato
                                    ? cores.primary
                                    : cores.onSurfaceVariant,
                              ),
                              title: Text(
                                formato.titulo,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(formato.descricao),
                              trailing: Icon(
                                _formato == formato
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: _formato == formato
                                    ? cores.primary
                                    : cores.onSurfaceVariant,
                              ),
                              onTap: () => _mudar(() => _formato = formato),
                            ),
                          ),
                        ),
                      if (_formato == FormatoRelatorio.pdf)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Incluir movimentações detalhadas'),
                          subtitle: const Text(
                            'Acrescenta a lista completa após o resumo.',
                          ),
                          value: _detalhar,
                          onChanged: (v) => _mudar(() => _detalhar = v),
                        ),
                      if (_formato == FormatoRelatorio.csv)
                        Text(
                          'CSV preserva os dados exportados para consulta. A restauração completa do aplicativo por esse arquivo ainda não está disponível.',
                          style: TextStyle(
                            fontSize: 12,
                            color: cores.onSurfaceVariant,
                          ),
                        ),
                    ]),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _ocupado ? null : _gerar,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _ocupado
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.description_outlined),
                      label: Text(
                        _ocupado ? 'Gerando relatório...' : 'Gerar relatório',
                      ),
                    ),
                    if (_arquivo != null) ...[
                      const SizedBox(height: 16),
                      _secao('Relatório gerado com sucesso', [
                        Text(
                          _arquivo!.nome,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _entregar(false, context),
                              icon: const Icon(Icons.save_alt),
                              label: const Text('Salvar'),
                            ),
                            Builder(
                              builder: (ctx) => FilledButton.icon(
                                onPressed: () => _entregar(true, ctx),
                                icon: const Icon(Icons.share_outlined),
                                label: const Text('Compartilhar'),
                              ),
                            ),
                          ],
                        ),
                      ]),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}
