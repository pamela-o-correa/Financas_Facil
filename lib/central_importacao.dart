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
            content: Text('Não foi possível selecionar os arquivos: $e'),
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
            item.status = 'Erro: $e';
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
            const Text(
              'Selecione os arquivos, escolha a conta de destino e revise cada extrato. Arquivos concluídos são salvos individualmente; um erro não apaga os anteriores.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _ocupado ? null : _adicionar,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar arquivos CSV'),
            ),
            OutlinedButton.icon(
              onPressed: _ocupado ? null : _escolherConta,
              icon: const Icon(Icons.account_balance),
              label: Text(_conta?.rotulo ?? 'Escolher conta de destino'),
            ),
            const Text(
              'A conta escolhida será usada nos arquivos pendentes. Para arquivos de outra conta, altere o destino antes de revisar.',
            ),
            const SizedBox(height: 16),
            Text(
              '${concluidos.length} arquivos importados • ${pendentes.length} pendentes\n$quantidade lançamentos salvos • $duplicatas possíveis duplicatas sinalizadas',
            ),
            if (_arquivos.isNotEmpty)
              const Text(
                'As possíveis duplicatas são conferidas na revisão; não são excluídas automaticamente. Ao sair, os arquivos pendentes precisarão ser selecionados novamente.',
              ),
            const SizedBox(height: 12),
            for (final item in _arquivos)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.arquivo.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(item.status),
                      Text(
                        'Destino: ${item.resultado != null ? item.conta!.rotulo : _conta?.rotulo ?? 'Escolha uma conta'}',
                      ),
                      if (item.resultado != null)
                        Text(
                          '${item.resultado!.quantidade} lançamentos salvos • ${item.resultado!.duplicatas} possíveis duplicatas • ${item.resultado!.descartadas} linhas descartadas pelo leitor',
                        ),
                      if (item.resultado == null)
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
                  ),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _ocupado || _conta == null || pendentes.isEmpty
                  ? null
                  : () => _processar(pendentes),
              child: Text(
                _ocupado ? 'Processando…' : 'Revisar todos os pendentes',
              ),
            ),
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
