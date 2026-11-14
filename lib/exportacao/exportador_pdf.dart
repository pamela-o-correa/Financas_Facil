import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'dados_relatorio.dart';

Future<Uint8List> gerarPdf(
  DadosRelatorio d,
  Uint8List regular,
  Uint8List negrito, {
  bool detalhar = false,
}) async {
  final verde = PdfColor.fromHex('#176B5B'),
      azul = PdfColor.fromHex('#244365'),
      vermelho = PdfColor.fromHex('#B34C55'),
      fundo = PdfColor.fromHex('#F1F5F4');
  final doc = pw.Document(
    title: 'Finanças Fácil - Relatório Financeiro',
    author: 'Finanças Fácil',
  );
  final tema = pw.ThemeData.withFont(
    base: pw.Font.ttf(ByteData.sublistView(regular)),
    bold: pw.Font.ttf(ByteData.sublistView(negrito)),
  );
  pw.Widget titulo(String t) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 16, bottom: 10),
    child: pw.Text(
      t,
      style: pw.TextStyle(
        fontSize: 15,
        fontWeight: pw.FontWeight.bold,
        color: azul,
      ),
    ),
  );
  String curto(String s, [int n = 95]) =>
      s.runes.length <= n ? s : '${String.fromCharCodes(s.runes.take(n))}…';
  pw.Widget tabela(
    List<String> colunas,
    List<List<String>> linhas, {
    Map<int, pw.TableColumnWidth>? larguras,
  }) => pw.TableHelper.fromTextArray(
    headers: colunas,
    data: linhas,
    columnWidths: larguras,
    headerDecoration: pw.BoxDecoration(color: verde),
    headerStyle: pw.TextStyle(
      color: PdfColors.white,
      fontWeight: pw.FontWeight.bold,
      fontSize: 9,
    ),
    cellStyle: const pw.TextStyle(fontSize: 8),
    cellPadding: const pw.EdgeInsets.all(7),
    oddRowDecoration: pw.BoxDecoration(color: fundo),
    border: null,
    cellAlignment: pw.Alignment.centerLeft,
    headerAlignment: pw.Alignment.centerLeft,
  );
  pw.Widget rodape(pw.Context c) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 12),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Finanças Fácil • ${curto(d.perfil, 40)}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
        pw.Text(
          '${c.pageNumber} / ${c.pagesCount}',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ],
    ),
  );
  pw.Widget cabecalho(pw.Context c) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 12),
    child: pw.Text(
      'RELATÓRIO FINANCEIRO  /  ${d.filtro.periodo}',
      style: pw.TextStyle(fontSize: 8, color: verde),
    ),
  );
  void paginas(List<pw.Widget> widgets) => doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      theme: tema,
      maxPages: 100000,
      header: cabecalho,
      footer: rodape,
      build: (_) => widgets,
    ),
  );
  pw.Widget card(String nome, int valor, PdfColor cor) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(13),
      decoration: pw.BoxDecoration(
        color: fundo,
        borderRadius: pw.BorderRadius.circular(7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(nome, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 8),
          pw.FittedBox(
            child: pw.Text(
              moeda(valor),
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 18,
                color: cor,
              ),
            ),
          ),
        ],
      ),
    ),
  );
  final primeiros = d.categorias.take(7).toList();
  if (d.categorias.length > 7) {
    final outros = GrupoCategoria('Outras categorias');
    for (final g in d.categorias.skip(7)) {
      outros.total += g.total;
      outros.quantidade += g.quantidade;
    }
    primeiros.add(outros);
  }
  paginas([
    pw.Text(
      'Finanças Fácil',
      style: pw.TextStyle(
        fontSize: 27,
        fontWeight: pw.FontWeight.bold,
        color: verde,
      ),
    ),
    pw.SizedBox(height: 5),
    pw.Text(
      'Relatório Financeiro',
      style: pw.TextStyle(fontSize: 17, color: azul),
    ),
    pw.SizedBox(height: 12),
    pw.Text(
      'Perfil: ${d.perfil}',
      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
    ),
    pw.SizedBox(height: 4),
    pw.Text(d.filtro.descricao, style: const pw.TextStyle(fontSize: 9)),
    pw.SizedBox(height: 4),
    pw.Text(
      'Gerado em ${dataBr(d.geradoEm)} às ${d.geradoEm.hour.toString().padLeft(2, '0')}:${d.geradoEm.minute.toString().padLeft(2, '0')}',
      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
    ),
    titulo('Resumo financeiro'),
    pw.Row(
      children: [
        card('Receitas', d.receitas, verde),
        pw.SizedBox(width: 8),
        card('Despesas', d.despesas, vermelho),
        pw.SizedBox(width: 8),
        card('Saldo', d.saldo, d.saldo < 0 ? vermelho : azul),
      ],
    ),
    pw.SizedBox(height: 10),
    pw.Text(
      'Taxa de economia: ${d.taxaEconomia == null ? 'não se aplica (receitas iguais a zero)' : '${d.taxaEconomia!.toStringAsFixed(1)}%'}',
      style: const pw.TextStyle(fontSize: 10),
    ),
    pw.SizedBox(height: 5),
    pw.Text(
      '${d.financeiras.length} movimentações contabilizadas • ${d.linhas.length} registros selecionados',
      style: const pw.TextStyle(fontSize: 9),
    ),
    pw.SizedBox(height: 6),
    pw.Text(
      'Totais de movimentações ativas, sem transferências internas. Previsões e registros desativados ficam fora do resumo realizado.',
      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
    ),
    if (d.linhas.isEmpty)
      titulo('Nenhuma movimentação nos filtros selecionados.'),
    titulo('Despesas por categoria'),
    if (primeiros.isEmpty)
      pw.Text(
        'Não há despesas contabilizadas neste período.',
        style: const pw.TextStyle(fontSize: 10),
      ),
    for (final g in primeiros)
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 9),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    curto(g.nome, 45),
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
                pw.Text(
                  '${moeda(g.total)}  •  ${d.despesas == 0 ? '0' : (100 * g.total / d.despesas).toStringAsFixed(1)}%',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Container(
              height: 5,
              width: math.max(
                1,
                510 * (d.despesas == 0 ? 0 : g.total / d.despesas),
              ),
              color: verde,
            ),
          ],
        ),
      ),
    if (d.categorias.length > 7)
      pw.Text(
        'O detalhamento de todas as categorias está nas próximas páginas.',
        style: const pw.TextStyle(fontSize: 8),
      ),
  ]);
  if (d.maiores.isNotEmpty ||
      d.categorias.isNotEmpty ||
      d.evolucao.isNotEmpty) {
    paginas([
      if (d.maiores.isNotEmpty) ...[
        titulo('Maiores despesas do período'),
        tabela(
          ['Data', 'Descrição', 'Categoria', 'Valor'],
          [
            for (final l in d.maiores)
              [
                dataBr(l.data),
                curto(l.descricao),
                curto(l.categoria, 40),
                moeda(l.centavos),
              ],
          ],
          larguras: {
            0: const pw.FixedColumnWidth(62),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FixedColumnWidth(96),
          },
        ),
      ],
      if (d.categorias.isNotEmpty) ...[
        titulo('Resumo por categoria'),
        tabela(
          ['Categoria', 'Quantidade', 'Total', '% das despesas'],
          [
            for (final g in d.categorias)
              [
                curto(g.nome, 100),
                '${g.quantidade}',
                moeda(g.total),
                '${d.despesas == 0 ? '0' : (100 * g.total / d.despesas).toStringAsFixed(1)}%',
              ],
          ],
        ),
      ],
      if (d.evolucao.isNotEmpty) titulo('Evolução financeira'),
      if (d.evolucao.isNotEmpty)
        pw.Text(
          'Receitas (verde) x Despesas (vermelho) • somente períodos com movimentações',
          style: const pw.TextStyle(fontSize: 9),
        ),
      for (final e in d.evolucao)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                e.rotulo,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              for (final v in [(e.receitas, verde), (e.despesas, vermelho)])
                pw.Row(
                  children: [
                    pw.Container(
                      width: math.max(
                        1,
                        340 *
                            v.$1 /
                            math.max(
                              1,
                              d.evolucao.fold<int>(
                                0,
                                (m, e) => math.max(
                                  m,
                                  math.max(e.receitas, e.despesas),
                                ),
                              ),
                            ),
                      ),
                      height: 6,
                      color: v.$2,
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      moeda(v.$1),
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
            ],
          ),
        ),
    ]);
  }
  if (detalhar && d.linhas.isNotEmpty) {
    // Each continuation row is bounded so even very long bank descriptions paginate.
    final linhas = <List<String>>[];
    for (final l in d.linhas) {
      final texto =
          '${l.descricao}\n${l.categoria} • ${l.conta}\n${l.prevista ? 'Previsão' : 'Movimentação'} • ${l.status} • ${l.contabilizacao}';
      final caracteres = texto.runes.toList();
      for (var i = 0; i < caracteres.length; i += 220) {
        linhas.add([
          i == 0 ? dataBr(l.data) : '',
          String.fromCharCodes(caracteres.skip(i).take(220)),
          i == 0 ? (l.tipo == 'receita' ? 'Receita' : 'Despesa') : '',
          i == 0 ? moeda(l.centavos) : '',
        ]);
      }
    }
    paginas([
      titulo('Movimentações detalhadas'),
      pw.Text(
        'Relação dos registros selecionados. Consulte a contabilização antes de somar os valores.',
        style: const pw.TextStyle(fontSize: 9),
      ),
      pw.SizedBox(height: 10),
      tabela(
        ['Data', 'Descrição / classificação', 'Tipo', 'Valor'],
        linhas,
        larguras: {
          0: const pw.FixedColumnWidth(62),
          1: const pw.FlexColumnWidth(1),
          2: const pw.FixedColumnWidth(53),
          3: const pw.FixedColumnWidth(103),
        },
      ),
    ]);
  }
  return doc.save();
}
