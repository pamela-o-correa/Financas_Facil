import 'dart:typed_data';

import 'package:excel_plus/excel_plus.dart';

import 'dados_relatorio.dart';
import 'exportador_csv.dart';

String _textoSeguroExcel(String texto) =>
    RegExp(r'^\s*[=+@\-\t\r\n]').hasMatch(texto) ? "'$texto" : texto;

Uint8List gerarExcel(DadosRelatorio d) {
  final livro = Excel.createExcel();
  livro.rename('Sheet1', 'Resumo');
  final resumo = livro['Resumo'];
  final titulo = CellStyle(
    bold: true,
    fontColorHex: ExcelColor.white,
    backgroundColorHex: ExcelColor.fromHexString('#176B5B'),
    textWrapping: TextWrapping.WrapText,
  );
  final dinheiro = CellStyle(
    numberFormat: CustomNumericNumFormat(
      formatCode: r'"R$" #,##0.00;[Red]-"R$" #,##0.00',
    ),
  );
  void linha(Sheet sheet, List<Object?> valores, {bool cabecalho = false}) {
    final r = sheet.maxRows;
    sheet.appendRow(
      valores
          .map<CellValue?>(
            (v) => v == null
                ? null
                : v is int
                ? IntCellValue(v)
                : v is double
                ? DoubleCellValue(v)
                : TextCellValue(_textoSeguroExcel(v.toString())),
          )
          .toList(),
    );
    if (cabecalho) {
      for (var c = 0; c < valores.length; c++) {
        sheet
                .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
                .cellStyle =
            titulo;
      }
      sheet.setRowHeight(r, 28);
    }
  }

  linha(resumo, ['Finanças Fácil', 'Relatório Financeiro'], cabecalho: true);
  linha(resumo, ['Perfil', d.perfil]);
  linha(resumo, ['Filtros', d.filtro.descricao]);
  linha(resumo, [
    'Gerado em',
    '${dataBr(d.geradoEm)} ${d.geradoEm.hour.toString().padLeft(2, '0')}:${d.geradoEm.minute.toString().padLeft(2, '0')}',
  ]);
  linha(resumo, ['Receitas', d.receitas / 100]);
  linha(resumo, ['Despesas', d.despesas / 100]);
  linha(resumo, ['Saldo', d.saldo / 100]);
  for (var r = 4; r <= 6; r++) {
    resumo
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
            .cellStyle =
        dinheiro;
  }
  linha(resumo, [
    'Taxa de economia',
    d.taxaEconomia == null
        ? 'Não se aplica: receitas iguais a zero'
        : '${d.taxaEconomia!.toStringAsFixed(1)}%',
  ]);
  linha(resumo, ['Registros exportados', d.linhas.length]);
  linha(resumo, ['Movimentações contabilizadas', d.financeiras.length]);
  linha(resumo, [
    'Critério',
    'Totais somente de movimentações ativas e sem transferência interna. Previsões não entram nos totais realizados.',
  ]);
  linha(resumo, []);
  linha(resumo, [
    'Categoria',
    'Quantidade',
    'Total',
    '% das despesas',
  ], cabecalho: true);
  for (final g in d.categorias) {
    final r = resumo.maxRows;
    linha(resumo, [
      g.nome,
      g.quantidade,
      g.total / 100,
      d.despesas == 0 ? 0.0 : g.total / d.despesas,
    ]);
    resumo
            .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
            .cellStyle =
        dinheiro;
    resumo
        .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r))
        .cellStyle = CellStyle(
      numberFormat: CustomNumericNumFormat(formatCode: '0.0%'),
    );
  }
  resumo.setColumnWidth(0, 32);
  resumo.setColumnWidth(1, 60);
  resumo.setColumnWidth(2, 22);
  resumo.setColumnWidth(3, 20);
  for (final r in [2, 10]) {
    resumo
        .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
        .cellStyle = CellStyle(
      textWrapping: TextWrapping.WrapText,
    );
    resumo.setRowHeight(r, 48);
  }
  final tabela = livro['Movimentações'];
  linha(tabela, colunasExportacao, cabecalho: true);
  tabela.freezePanes(rows: 1);
  for (final l in d.linhas) {
    final r = tabela.maxRows;
    linha(tabela, valoresExportacao(l));
    final data = tabela.cell(
      CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: r),
    );
    data.value = DateCellValue(
      year: l.data.year,
      month: l.data.month,
      day: l.data.day,
    );
    data.cellStyle = CellStyle(
      numberFormat: CustomDateTimeNumFormat(formatCode: 'dd/mm/yyyy'),
    );
    tabela
            .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: r))
            .cellStyle =
        dinheiro;
  }
  for (var c = 0; c < colunasExportacao.length; c++) {
    tabela.setColumnWidth(c, c == 3 || c == 9 || c == 19 ? 55 : 23);
  }
  final evolucao = livro['Evolução'];
  linha(evolucao, [
    'Período',
    'Receitas',
    'Despesas',
    'Saldo',
  ], cabecalho: true);
  for (final p in d.evolucao) {
    final r = evolucao.maxRows;
    linha(evolucao, [
      p.rotulo,
      p.receitas / 100,
      p.despesas / 100,
      (p.receitas - p.despesas) / 100,
    ]);
    for (var c = 1; c < 4; c++) {
      evolucao
              .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
              .cellStyle =
          dinheiro;
    }
  }
  if (d.evolucao.isEmpty) {
    linha(evolucao, ['Sem períodos suficientes para comparação']);
  }
  for (var c = 0; c < 4; c++) {
    evolucao.setColumnWidth(c, 26);
  }
  livro.setDefaultSheet('Resumo');
  return Uint8List.fromList(livro.encode()!);
}
