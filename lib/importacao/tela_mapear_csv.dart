import 'package:flutter/material.dart';

import 'motor_importacao.dart';

class ConfiguracaoCsv {
  const ConfiguracaoCsv(this.separador, this.mapa);
  final String separador;
  final MapeamentoCsv mapa;
}

class TelaMapearCsv extends StatefulWidget {
  const TelaMapearCsv({
    super.key,
    required this.conteudo,
    required this.resultado,
  });
  final String conteudo;
  final ResultadoImportacao resultado;
  @override
  State<TelaMapearCsv> createState() => _TelaMapearCsvState();
}

class _TelaMapearCsvState extends State<TelaMapearCsv> {
  late DocumentoCsv _doc = widget.resultado.documento;
  late String _separador = _doc.separador;
  late int _cabecalho = _doc.sugestao?.cabecalho ?? 0;
  int? _data, _descricao, _valor, _debito, _credito, _tipo, _detalhes;
  String _decimal = ',', _formato = 'dma';
  bool _separados = false;
  bool _possuiCabecalho = true;
  String? _erro;
  @override
  void initState() {
    super.initState();
    _sugerir();
  }

  void _sugerir() {
    final m = _doc.sugestao;
    _data = m?.data;
    _descricao = m?.descricao;
    _valor = m?.valor;
    _debito = m?.debito;
    _credito = m?.credito;
    _tipo = m?.tipo;
    _detalhes = m?.detalhes;
    _separados = m != null && m.valor == null;
  }

  Widget _coluna(
    String nome,
    int? valor,
    ValueChanged<int?> mudar, {
    bool obrigatoria = false,
  }) {
    final cabecalho = _doc.linhas.isEmpty
        ? <String>[]
        : _doc.linhas[_cabecalho].celulas;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<int>(
        key: ValueKey('$nome:$_separador:$_cabecalho:$valor'),
        initialValue: valor ?? -1,
        isExpanded: true,
        decoration: InputDecoration(labelText: nome),
        items: [
          DropdownMenuItem(
            value: -1,
            child: Text(obrigatoria ? 'Selecione' : 'Não usar'),
          ),
          for (var i = 0; i < cabecalho.length; i++)
            DropdownMenuItem(
              value: i,
              child: Text(
                '${i + 1}: ${cabecalho[i].isEmpty ? "Sem título" : cabecalho[i]}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (v) => setState(() => mudar(v == -1 ? null : v)),
      ),
    );
  }

  void _continuar() {
    try {
      if (_data == null ||
          _descricao == null ||
          (_separados ? _debito == null || _credito == null : _valor == null)) {
        throw const FormatException('Selecione todas as colunas obrigatórias.');
      }
      final mapa = MapeamentoCsv(
        cabecalho: _cabecalho,
        data: _data!,
        descricao: _descricao!,
        valor: _separados ? null : _valor,
        debito: _separados ? _debito : null,
        credito: _separados ? _credito : null,
        tipo: _tipo,
        detalhes: _detalhes,
        decimal: _decimal,
        formatoData: _formato,
        possuiCabecalho: _possuiCabecalho,
      );
      Navigator.pop(context, ConfiguracaoCsv(_separador, mapa));
    } on FormatException catch (e) {
      setState(() => _erro = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Interpretar arquivo CSV')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: esquema.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: esquema.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.table_rows_outlined,
                  size: 20,
                  color: esquema.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.resultado.motivoMapeamento.isEmpty
                        ? 'Ajuste as colunas e confira o resultado na revisão.'
                        : widget.resultado.motivoMapeamento,
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
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _separador,
            decoration: const InputDecoration(labelText: 'Separador de colunas'),
            items: const [
              DropdownMenuItem(value: ';', child: Text('Ponto e vírgula ;')),
              DropdownMenuItem(value: ',', child: Text('Vírgula ,')),
              DropdownMenuItem(value: '\t', child: Text('Tabulação')),
              DropdownMenuItem(value: '|', child: Text('Barra |')),
            ],
            onChanged: (v) {
              try {
                final doc = DocumentoCsv.detectar(widget.conteudo, separador: v);
                setState(() {
                  _separador = v!;
                  _doc = doc;
                  _cabecalho = doc.sugestao?.cabecalho ?? 0;
                  _sugerir();
                  _erro = null;
                });
              } on FormatException catch (e) {
                setState(() => _erro = e.message);
              }
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            key: ValueKey('cabecalho:$_separador:$_cabecalho'),
            initialValue: _doc.linhas.isEmpty ? null : _cabecalho,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: _possuiCabecalho
                  ? 'Linha do cabeçalho'
                  : 'Primeira linha de movimentações',
            ),
            items: [
              for (var i = 0; i < _doc.linhas.length && i < 100; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    '${_doc.linhas[i].numero}: ${_doc.linhas[i].celulas.join(" | ")}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => setState(() {
              _cabecalho = v!;
              _data = _descricao = _valor = _debito = _credito = _tipo =
                  _detalhes = null;
            }),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('O arquivo tem uma linha com títulos de colunas'),
            value: _possuiCabecalho,
            onChanged: (v) => setState(() => _possuiCabecalho = v),
          ),
          const SizedBox(height: 8),
          _coluna('Data', _data, (v) => _data = v, obrigatoria: true),
          _coluna(
            'Descrição',
            _descricao,
            (v) => _descricao = v,
            obrigatoria: true,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Entradas e saídas em colunas separadas'),
            value: _separados,
            onChanged: (v) => setState(() => _separados = v),
          ),
          const SizedBox(height: 8),
          if (_separados) ...[
            _coluna(
              'Débito / saída',
              _debito,
              (v) => _debito = v,
              obrigatoria: true,
            ),
            _coluna(
              'Crédito / entrada',
              _credito,
              (v) => _credito = v,
              obrigatoria: true,
            ),
          ] else
            _coluna('Valor', _valor, (v) => _valor = v, obrigatoria: true),
          _coluna('Tipo (entrada/saída ou C/D)', _tipo, (v) => _tipo = v),
          _coluna('Complemento da descrição', _detalhes, (v) => _detalhes = v),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _decimal,
            decoration: const InputDecoration(labelText: 'Formato do valor'),
            items: const [
              DropdownMenuItem(value: ',', child: Text('1.234,56')),
              DropdownMenuItem(value: '.', child: Text('1,234.56')),
            ],
            onChanged: (v) => setState(() => _decimal = v!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _formato,
            decoration: const InputDecoration(labelText: 'Formato da data'),
            items: const [
              DropdownMenuItem(value: 'dma', child: Text('Dia/mês/ano')),
              DropdownMenuItem(value: 'mda', child: Text('Mês/dia/ano')),
              DropdownMenuItem(value: 'amd', child: Text('Ano/mês/dia')),
            ],
            onChanged: (v) => setState(() => _formato = v!),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: esquema.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: esquema.outlineVariant.withValues(alpha: 0.65),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prévia do arquivo',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                for (final linha
                    in _doc.linhas
                        .skip(_cabecalho + (_possuiCabecalho ? 1 : 0))
                        .take(3))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      linha.celulas.join(' | '),
                      style: TextStyle(
                        fontSize: 13,
                        color: esquema.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_erro != null) ...[
            const SizedBox(height: 12),
            Text(
              _erro!,
              style: TextStyle(
                color: esquema.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _doc.linhas.isEmpty ? null : _continuar,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Conferir movimentações'),
          ),
        ],
      ),
    );
  }
}
