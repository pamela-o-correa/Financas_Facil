import 'dart:convert';
import 'dart:typed_data';

import 'dados_relatorio.dart';

const colunasExportacao = [
  'Perfil',
  'Origem',
  'Tipo',
  'Descrição',
  'Categoria',
  'Data',
  'Valor (R\$)',
  'Status',
  'Conta',
  'Observações',
  'Contabilização',
  'Banco',
  'Arquivo de origem',
  'ID',
  'ID da conta',
  'ID da importação',
  'Par de transferência',
  'Data ISO',
  'Versão do formato',
  'Dados originais',
];
List<Object?> valoresExportacao(LinhaRelatorio l) => [
  l.perfil,
  l.prevista ? 'Previsão' : 'Movimentação',
  l.tipo == 'receita' ? 'Receita' : 'Despesa',
  l.descricao,
  l.categoria,
  dataBr(l.data),
  l.centavos / 100,
  l.status,
  l.conta,
  l.dados['observacoes'] ?? '',
  l.contabilizacao,
  l.dados['banco_nome'] ?? '',
  l.dados['arquivo_origem'] ?? (l.prevista ? 'Agenda' : 'Manual'),
  l.dados['id'],
  l.dados['conta_id'],
  l.dados['importacao_id'],
  l.dados['transferencia_par'],
  dataIso(l.data),
  2,
  jsonEncode(l.dados),
];
String _celula(Object? valor, {bool numero = false}) {
  var texto = valor?.toString() ?? '';
  if (!numero && RegExp(r'^\s*[=+@\-\t\r\n]').hasMatch(texto)) {
    texto = "'$texto";
  }
  return '"${texto.replaceAll('"', '""')}"';
}

Uint8List gerarCsv(DadosRelatorio dados) {
  final linhas = <String>[colunasExportacao.map(_celula).join(';')];
  for (final l in dados.linhas) {
    final valores = valoresExportacao(l);
    valores[6] = (l.centavos / 100).toStringAsFixed(2).replaceAll('.', ',');
    linhas.add(
      [
        for (var i = 0; i < valores.length; i++)
          _celula(valores[i], numero: i == 6),
      ].join(';'),
    );
  }
  return Uint8List.fromList(utf8.encode('\uFEFF${linhas.join('\r\n')}\r\n'));
}
