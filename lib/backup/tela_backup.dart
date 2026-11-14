import 'package:material_ui/material_ui.dart';

import 'servico_backup.dart';

class TelaBackup extends StatefulWidget {
  const TelaBackup({super.key, required this.servico});
  final ServicoBackup servico;
  @override
  State<TelaBackup> createState() => _TelaBackupState();
}

class _TelaBackupState extends State<TelaBackup> {
  bool _ocupado = false;
  ArquivoBackup? _arquivo;
  String? _erro;

  Future<void> _executar(Future<void> Function() acao) async {
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      await acao();
    } catch (_) {
      if (mounted) {
        setState(
          () => _erro =
              'Não foi possível concluir o backup. Seus dados foram mantidos.',
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext _) => PopScope(
    canPop: !_ocupado,
    child: Scaffold(
      appBar: AppBar(title: const Text('Backup integral')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Uma cópia de todos os seus perfis',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'Inclui lançamentos, contas, categorias, agenda, lixeira e preferências. '
            'O CSV é um relatório separado e não substitui este arquivo.',
          ),
          const SizedBox(height: 16),
          const Text(
            'O arquivo contém dados financeiros sem criptografia. Guarde-o em local seguro. '
            'A restauração pelo aplicativo ainda não está disponível. Criar uma cópia não altera os dados.',
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _ocupado
                ? null
                : () => _executar(() async {
                    final arquivo = await widget.servico.gerar();
                    if (mounted) setState(() => _arquivo = arquivo);
                  }),
            icon: const Icon(Icons.backup_outlined),
            label: const Text('Criar backup'),
          ),
          if (_ocupado)
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
          if (_erro != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_erro!),
            ),
          if (_arquivo != null) ...[
            const SizedBox(height: 24),
            Text(_arquivo!.nome),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _ocupado
                  ? null
                  : () => _executar(() async {
                      final salvo = await widget.servico.salvar(_arquivo!);
                      if (mounted && salvo) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Backup salvo.')),
                        );
                      }
                    }),
              icon: const Icon(Icons.save_alt),
              label: const Text('Salvar backup'),
            ),
            Builder(
              builder: (origem) => OutlinedButton.icon(
                onPressed: _ocupado
                    ? null
                    : () => _executar(() async {
                        final box = origem.findRenderObject() as RenderBox;
                        await widget.servico.compartilhar(
                          _arquivo!,
                          box.localToGlobal(Offset.zero) & box.size,
                        );
                      }),
                icon: const Icon(Icons.share_outlined),
                label: const Text('Compartilhar backup'),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
