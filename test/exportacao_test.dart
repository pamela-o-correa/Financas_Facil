import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:excel_plus/excel_plus.dart';
import 'package:financas_facil/exportacao/dados_relatorio.dart';
import 'package:financas_facil/exportacao/exportador_csv.dart';
import 'package:financas_facil/exportacao/exportador_excel.dart';
import 'package:financas_facil/exportacao/exportador_pdf.dart';

LinhaRelatorio exemplo({
  String tipo = 'despesa',
  double valor = 120,
  String descricao = 'Alimentação - São João',
  String categoria = 'Alimentação',
  int ativa = 1,
  int? par,
  int? conta = 1,
  int dia = 10,
  bool prevista = false,
}) => LinhaRelatorio(
  perfil: 'Pessoal',
  prevista: prevista,
  dados: {
    'id': dia,
    'tipo': tipo,
    'valor': valor,
    'centavos': valor.isFinite ? (valor * 100).round() : 0,
    'descricao': descricao,
    'titulo': descricao,
    'categoria': categoria,
    'data': '2026-09-${dia.toString().padLeft(2, '0')}T23:59:00.000',
    'ativa': ativa,
    'transferencia_par': par,
    'conta_id': conta,
    'conta_nome': conta == 1 ? 'Nubank' : 'Inter',
    'banco_nome': conta == 1 ? 'Nubank' : 'Inter',
    'status': 'pendente',
    'observacoes': 'Revisão; acentuação e "aspas"\nOutra linha',
  },
);
DadosRelatorio relatorio(
  List<LinhaRelatorio> linhas, {
  FiltroRelatorio filtro = const FiltroRelatorio(origem: 'ambos'),
}) => DadosRelatorio(
  perfil: 'Pessoal',
  filtro: filtro,
  linhas: linhas,
  geradoEm: DateTime(2026, 9, 10, 16, 30),
);

void main() {
  test(
    'Totais respeitam desativação, transferência e previsão sem dupla contagem',
    () {
      final d = relatorio([
        exemplo(tipo: 'receita', valor: 500),
        exemplo(valor: 120),
        exemplo(valor: 900, ativa: 0),
        exemplo(tipo: 'receita', valor: 700, par: 2),
        exemplo(valor: 800, prevista: true),
      ]);
      expect(d.receitas, 50000);
      expect(d.despesas, 12000);
      expect(d.saldo, 38000);
      expect(d.taxaEconomia, 76);
      expect(d.financeiras.length, 2);
      expect(d.linhas.length, 5);
      expect(d.categorias.single.total, 12000);
    },
  );
  test(
    'Filtros de tipo, conta, categoria e datas inclusivas alteram os registros',
    () {
      final linhas = [
        exemplo(dia: 9),
        exemplo(dia: 10),
        exemplo(dia: 11),
        exemplo(tipo: 'receita'),
        exemplo(conta: 2),
        exemplo(categoria: 'Casa'),
      ];
      final d = relatorio(
        linhas,
        filtro: FiltroRelatorio(
          inicio: DateTime(2026, 9, 10),
          fim: DateTime(2026, 9, 10),
          tipo: 'despesa',
          conta: 'id:1',
          categoria: 'Alimentação',
        ),
      );
      expect(d.linhas.length, 1);
      expect(d.despesas, 12000);
    },
  );
  test(
    'Sem dados, zero receitas, saldo negativo e valores altos são finitos',
    () {
      expect(relatorio([]).taxaEconomia, isNull);
      expect(relatorio([]).categorias, isEmpty);
      final despesas = relatorio([exemplo(valor: 999999999.99)]);
      expect(despesas.saldo, -99999999999);
      expect(despesas.taxaEconomia, isNull);
      expect(moeda(despesas.saldo), '-R\$ 999.999.999,99');
      final receitas = relatorio([exemplo(tipo: 'receita')]);
      expect(receitas.despesas, 0);
      expect(receitas.taxaEconomia, 100);
      expect(receitas.categorias, isEmpty);
      expect(() => exemplo(valor: double.nan), throwsFormatException);
      expect(() => exemplo(valor: double.infinity), throwsFormatException);
    },
  );
  test(
    'CSV preserva colunas anteriores, UTF-8, flags e neutraliza fórmulas',
    () {
      final texto = utf8.decode(
        gerarCsv(
          relatorio([
            exemplo(descricao: '=1+2', ativa: 0),
            exemplo(prevista: true),
          ]),
        ),
      );
      expect(texto.startsWith('"Perfil";"Origem"'), isTrue);
      expect(texto, contains('"\'=1+2"'));
      expect(texto, contains('"120,00"'));
      expect(texto, contains('Desativada'));
      expect(texto, contains('Previsão'));
      expect(texto, contains('acentuação'));
      expect(texto, contains('Dados originais'));
    },
  );
  test('Excel contém resumo, datas numéricas, moeda, neutraliza fórmulas e aceita data dd/MM/yyyy', () {
    final d = relatorio([
      exemplo(descricao: '=1+2'),
      exemplo(tipo: 'receita', valor: 1000),
      LinhaRelatorio(
        perfil: 'Pessoal',
        prevista: false,
        dados: {
          'id': 99,
          'tipo': 'despesa',
          'valor': 50.0,
          'centavos': 5000,
          'descricao': 'Data BR',
          'categoria': 'Outros',
          'data': '15/09/2026',
          'ativa': 1,
        },
      ),
    ]);
    final bytes = gerarExcel(d);
    final livro = Excel.decodeBytes(bytes);
    expect(
      livro.tables.keys,
      containsAll(['Resumo', 'Movimentações', 'Evolução']),
    );
    expect(livro['Movimentações'].maxRows, 4);
    expect(
      livro['Movimentações']
          .cell(CellIndex.indexByString('D2'))
          .value
          .toString(),
      "'=1+2",
    );
    expect(
      livro['Movimentações'].cell(CellIndex.indexByString('F2')).value,
      isA<DateCellValue>(),
    );
    expect(
      livro['Movimentações']
          .cell(CellIndex.indexByString('G2'))
          .value
          .toString(),
      '120',
    );
    expect(
      livro['Resumo'].cell(CellIndex.indexByString('B7')).value.toString(),
      '830',
    );
  });
  test(
    'PDF gera resumo e pagina 650 registros, inclusive descrição longa',
    () async {
      final regular = await File('assets/fontes/Roboto-Regular.ttf')
          .readAsBytes();
      final bold = await File('assets/fontes/Roboto-Bold.ttf').readAsBytes();
      final linhas = [
        exemplo(tipo: 'receita', valor: 7500, descricao: 'Salário'),
        exemplo(valor: 1800, categoria: 'Moradia', descricao: 'Aluguel'),
        exemplo(valor: 650, categoria: 'Mercado'),
        exemplo(valor: 240, categoria: 'Transporte', dia: 12),
        exemplo(valor: 120, categoria: 'Saúde', dia: 15),
        exemplo(valor: 950, ativa: 0, descricao: 'Aplicação RDB'),
      ];
      final d = relatorio(
        linhas,
        filtro: FiltroRelatorio(
          inicio: DateTime(2026, 9),
          fim: DateTime(2026, 9, 30),
          origem: 'ambos',
        ),
      );
      final pdf = await gerarPdf(d, regular, bold, detalhar: true);
      expect(ascii.decode(pdf.take(5).toList()), '%PDF-');
      final muitos = relatorio([
        for (var i = 0; i < 650; i++)
          exemplo(
            dia: i % 28 + 1,
            descricao: i == 0
                ? 'Descrição muito longa com acentuação. ' * 100
                : 'Compra número $i',
            valor: 12.34,
          ),
      ]);
      final extenso = await gerarPdf(muitos, regular, bold, detalhar: true);
      expect(extenso.length, greaterThan(pdf.length));
      for (final base in [
        relatorio([]),
        relatorio([exemplo()]),
        relatorio([exemplo(tipo: 'receita')]),
      ]) {
        expect((await gerarPdf(base, regular, bold)).length, greaterThan(1000));
      }
      final destino = Platform.environment['EXPORTACAO_QA'];
      if (destino != null) {
        await Directory(destino).create(recursive: true);
        await File('$destino/relatorio_exemplo.pdf').writeAsBytes(pdf);
        await File('$destino/relatorio_extenso.pdf').writeAsBytes(extenso);
        await File('$destino/analise_exemplo.xlsx').writeAsBytes(gerarExcel(d));
        await File('$destino/dados_exemplo.csv').writeAsBytes(gerarCsv(d));
        await File('$destino/relatorio_vazio.pdf')
            .writeAsBytes(await gerarPdf(relatorio([]), regular, bold));
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
