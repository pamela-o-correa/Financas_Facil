part of 'main.dart';

class ResultadoArquivoImportado {
  const ResultadoArquivoImportado(
    this.quantidade,
    this.duplicatas,
    this.descartadas,
  );
  final int quantidade, duplicatas, descartadas;
}

class ArquivoNaCentral {
  ArquivoNaCentral(this.arquivo);
  final PlatformFile arquivo;
  String status = 'Aguardando revisão';
  ResultadoArquivoImportado? resultado;
  ContaOrigem? conta;
}

class TelaCentralImportacao extends StatefulWidget {
  const TelaCentralImportacao({
    super.key,
    required this.banco,
    required this.processar,
    this.arquivosIniciais = const [],
    this.contaInicial,
  });
  final BancoDados banco;
  final List<PlatformFile> arquivosIniciais;
  final ContaOrigem? contaInicial;
  final Future<ResultadoArquivoImportado?> Function(PlatformFile, ContaOrigem)
  processar;
  @override
  State<TelaCentralImportacao> createState() => _TelaCentralImportacaoState();
}

class _TelaCentralImportacaoState extends State<TelaCentralImportacao> {
  late final List<ArquivoNaCentral> _arquivos = widget.arquivosIniciais
      .map(ArquivoNaCentral.new)
      .toList();
  late ContaOrigem? _conta = widget.contaInicial;
  bool _ocupado = false;
  Future<void> _adicionar() async {
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
    });
    try {
      final arquivos = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (!mounted) return;
      setState(() {
        for (final arquivo in arquivos) {
          if (!_arquivos.any(
            (a) =>
                a.arquivo.path == arquivo.path &&
                a.arquivo.name == arquivo.name,
          )) {
            _arquivos.add(ArquivoNaCentral(arquivo));
          }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              mensagemErroSegura(e, 'Não foi possível selecionar os arquivos.'),
            ),
          ),
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

  Future<void> _escolherConta() async {
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
    });
    try {
      final repo = ContasBanco(widget.banco.database);
      final contas = await repo.listar();
      final bancos = await repo.listarBancos();
      if (!mounted) return;
      final conta = await Navigator.push<ContaOrigem>(
        context,
        MaterialPageRoute(
          builder: (_) => TelaEscolherConta(contas: contas, bancos: bancos),
        ),
      );
      if (conta != null && mounted) {
        setState(() {
          _conta = conta;
        });
      }
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
      }
    }
  }

  Future<void> _processar(List<ArquivoNaCentral> arquivos) async {
    if (_ocupado || _conta == null) return;
    setState(() {
      _ocupado = true;
    });
    try {
      for (final item in arquivos.where((a) => a.resultado == null)) {
        if (!mounted) return;
        setState(() {
          item.status = 'Em revisão';
          item.conta = _conta;
        });
        try {
          final resultado = await widget.processar(item.arquivo, _conta!);
          if (!mounted) return;
          setState(() {
            item.resultado = resultado;
            item.status = resultado == null
                ? 'Revisão interrompida • pendente'
                : 'Importado';
          });
          if (resultado == null) break;
        } catch (e) {
          if (!mounted) return;
          setState(() {
            item.status =
                'Erro: ${mensagemErroSegura(e, 'falha ao processar arquivo.')}';
          });
        }
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
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final semantica = CoresSemanticas.de(context);
    final concluidos = _arquivos.where((a) => a.resultado != null).toList();
    final pendentes = _arquivos.where((a) => a.resultado == null).toList();
    final quantidade = concluidos.fold(
      0,
      (s, a) => s + a.resultado!.quantidade,
    );
    final duplicatas = concluidos.fold(
      0,
      (s, a) => s + a.resultado!.duplicatas,
    );
    return PopScope(
      canPop: !_ocupado,
      child: Scaffold(
        appBar: AppBar(title: const Text('Central de importação')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
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
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: esquema.primaryContainer.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.upload_file_outlined,
                      size: 20,
                      color: esquema.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Selecione os arquivos, escolha a conta de destino e revise cada extrato. Arquivos concluídos são salvos individualmente; um erro não apaga os anteriores.',
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
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _ocupado ? null : _adicionar,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar arquivos CSV'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _ocupado ? null : _escolherConta,
              icon: const Icon(Icons.account_balance_outlined),
              label: Text(_conta?.rotulo ?? 'Escolher conta de destino'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A conta escolhida será usada nos arquivos pendentes. Para arquivos de outra conta, altere o destino antes de revisar.',
              style: TextStyle(fontSize: 12, color: esquema.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: esquema.surfaceContainerLow,
                borderRadius: BorderRadius.circular(RaioBorda.cartao),
                border: Border.all(
                  color: esquema.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${concluidos.length} arquivos importados • ${pendentes.length} pendentes\n$quantidade lançamentos salvos • $duplicatas possíveis duplicatas sinalizadas',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (_arquivos.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'As possíveis duplicatas são conferidas na revisão; não são excluídas automaticamente. Ao sair, os arquivos pendentes precisarão ser selecionados novamente.',
                      style: TextStyle(
                        fontSize: 12,
                        color: esquema.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final item in _arquivos)
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
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            item.resultado != null
                                ? Icons.check_circle_outline
                                : item.status.startsWith('Erro:')
                                ? Icons.error_outline
                                : Icons.description_outlined,
                            size: 20,
                            color: item.resultado != null
                                ? semantica.receita
                                : item.status.startsWith('Erro:')
                                ? esquema.error
                                : esquema.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.arquivo.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.status,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: item.resultado != null
                              ? semantica.receita
                              : item.status.startsWith('Erro:')
                              ? esquema.error
                              : esquema.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Destino: ${item.resultado != null ? item.conta!.rotulo : _conta?.rotulo ?? 'Escolha uma conta'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: esquema.onSurfaceVariant,
                        ),
                      ),
                      if (item.resultado != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${item.resultado!.quantidade} lançamentos salvos • ${item.resultado!.duplicatas} possíveis duplicatas • ${item.resultado!.descartadas} linhas descartadas pelo leitor',
                          style: TextStyle(
                            fontSize: 12,
                            color: esquema.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                      if (item.resultado == null) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: _ocupado || _conta == null
                                  ? null
                                  : () => _processar([item]),
                              child: const Text('Revisar arquivo'),
                            ),
                            TextButton(
                              onPressed: _ocupado
                                  ? null
                                  : () => setState(() {
                                      _arquivos.remove(item);
                                    }),
                              child: const Text('Remover da lista'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _ocupado || _conta == null || pendentes.isEmpty
                  ? null
                  : () => _processar(pendentes),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _ocupado ? 'Processando…' : 'Revisar todos os pendentes',
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _ocupado
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TelaImportacoes(),
                      ),
                    ),
              child: const Text('Ver histórico de importações'),
            ),
          ],
        ),
      ),
    );
  }
}
