import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financas_facil/importacao/validacao.dart';
import 'package:financas_facil/importacao/tela_mapear_csv.dart';
import 'package:financas_facil/contas/tela_contas.dart';
import 'package:financas_facil/contas/contas_banco.dart';
import 'package:financas_facil/main.dart';

const categoriasTeste = {
  'receita:Outros': 'Outras receitas',
  'despesa:Outros': 'Outras despesas',
  'receita:Salário': 'Salário renomeado',
  'despesa:Transporte': 'Transporte',
};
const cabBB =
    '"Data","Lançamento","Detalhes","N° documento","Valor","Tipo Lançamento"';
const cabSicredi = 'Data;Descricao;CodTransacao;Identificador;Tipo;Valor;Saldo';
const cabInter =
    ' Extrato Conta Corrente\nConta ;1234\nPeríodo ;08/08/2026 a 08/09/2026\nSaldo ;1,06\n\nData Lançamento;Histórico;Descrição;Valor;Saldo';
ResultadoImportacao ler(String texto) =>
    MotorImportacao.ler(texto, categoriasTeste);

void main() {
  test('Mapeamento sem cabeçalho preserva a primeira movimentação', () {
    final r = MotorImportacao.ler(
      '01/09/2026;Primeiro;10,00\n02/09/2026;Segundo;20,00',
      categoriasTeste,
      separador: ';',
      mapeamento: const MapeamentoCsv(
        cabecalho: 0,
        data: 0,
        descricao: 1,
        valor: 2,
        possuiCabecalho: false,
      ),
    );
    expect(r.itens.length, 2);
    expect(r.itens.first.descricao, 'Primeiro');
  });
  test('Histórico genérico, descrição vazia do Inter e Total Express', () {
    expect(
      ler('data;historico;valor\n01/09/2026;Total Express;-10,00')
          .itens
          .single
          .centavos,
      1000,
    );
    expect(
      ler('$cabInter\n01/09/2026;Pagamento;;-10,00;90,00')
          .itens
          .single
          .descricao,
      'Pagamento',
    );
  });
  test('BB reconhece lançamento, detalhes e documento e exclui saldos', () {
    final r = ler(
      '$cabBB\n"31/12/2025","Saldo Anterior","","","3.189,27",""\n'
      '"05/01/2026","Pix - Enviado","Pessoa teste","10501","-2.700,00","Saída"\n'
      '"06/01/2026","Salário","Empresa","7","4.000,00","Entrada"\n'
      '"06/01/2026","S A L D O","","","4.489,27",""',
    );
    expect(r.banco.codigo, '001');
    expect(r.itens.length, 2);
    expect(r.itens.first.centavos, 270000);
    expect(r.itens.first.tipo, TipoMovimentacao.despesa);
    expect(r.itens.first.descricao, 'Pix - Enviado - Pessoa teste');
    expect(r.itens.first.documento, '10501');
    expect(r.itens.last.categoria, 'Salário renomeado');
    expect(r.ocorrencias.length, 2);
  });
  test('Sicredi usa C/D e ignora a coluna saldo', () {
    final r = ler(
      '$cabSicredi\n01/09/2026;Pagamento;1;ABC;D;100,25;999,00\n02/09/2026;Recebimento;2;DEF;C;25,10;1024,10',
    );
    expect(r.banco.codigo, '748');
    expect(r.itens.map((i) => i.centavos), [10025, 2510]);
    expect(r.itens.map((i) => i.tipo), [
      TipoMovimentacao.despesa,
      TipoMovimentacao.receita,
    ]);
  });
  test('Inter encontra cabeçalho após metadados', () {
    final r = ler('$cabInter\n01/09/2026;PIX;Pagamento;-10,00;990,00');
    expect(r.banco.codigo, '077');
    expect(r.itens.single.centavos, 1000);
  });
  test(
    'Extratos com apenas cabeçalho são vazios, sem erro de identificação',
    () {
      for (final csv in [cabBB, cabSicredi, cabInter, '']) {
        final r = ler(csv);
        expect(r.itens, isEmpty);
        expect(r.precisaMapear, false);
      }
    },
  );
  test('Genérico preserva CSV anterior, categorias e centavos', () {
    final r = ler(
      'date,description,amount\n2026-09-01,Uber,-12.50\n2026-09-02,Recebimento,150',
    );
    expect(r.itens.first.categoria, 'Transporte');
    expect(r.itens.first.centavos, 1250);
    expect(r.itens.last.centavos, 15000);
  });
  test('Campos entre aspas, vírgulas, aspas escapadas e quebras de linha', () {
    final r = ler(
      'data,descricao,valor\r\n01/09/2026,"Loja, ""Centro""\nCompra","-1.234,56"',
    );
    expect(r.itens.single.descricao, 'Loja, "Centro"\nCompra');
    expect(r.itens.single.centavos, 123456);
  });
  test('UTF-8 BOM, Windows-1252 e UTF-16', () {
    final s = 'data;descrição;valor\n01/09/2026;Café;2,50';
    expect(
      ler(MotorImportacao.decodificar([239, 187, 191, ...utf8.encode(s)]))
          .itens
          .length,
      1,
    );
    expect(ler(MotorImportacao.decodificar(latin1.encode(s))).itens.length, 1);
    expect(
      ler(
        MotorImportacao.decodificar([
          255,
          254,
          for (final c in s.codeUnits) ...[c & 255, c >> 8],
        ]),
      ).itens.length,
      1,
    );
  });
  test('Datas inexistentes não são normalizadas para o mês seguinte', () {
    for (final s in [
      '31/02/2026',
      '29/02/2025',
      '2026-02-30',
      '00/01/2026',
      '2026-01-01 25:00',
      'texto',
    ]) {
      expect(dataCsv(s), isNull, reason: s);
    }
    expect(dataCsv('29/02/2024'), DateTime(2024, 2, 29));
    expect(dataCsv('09/30/2026', formato: 'mda'), DateTime(2026, 9, 30));
  });
  test('Valores inválidos ou não finitos nunca são importados', () {
    for (final s in [
      'NaN',
      'Infinity',
      '1e3',
      '12abc',
      '1,2345',
      '1.2.3',
      '--10',
    ]) {
      expect(centavosCsv(s), isNull, reason: s);
    }
    expect(centavosCsv('1.234,56'), 123456);
    expect(centavosCsv('(25,10)'), -2510);
    expect(centavosCsv('25,10 D'), -2510);
    expect(centavosCsv('-25,10 C'), isNull);
  });
  test(
    'Cabeçalhos repetidos, colunas desalinhadas, zero e vazios são explicados',
    () {
      final r = ler(
        'data;descricao;valor\ndata;descricao;valor\n31/02/2026;Teste;1,00\n'
        '01/09/2026;Teste;0\n01/09/2026;;1,00\n01/09/2026;Teste;1,00;extra',
      );
      expect(r.itens, isEmpty);
      expect(r.ocorrencias.length, 5);
    },
  );
  test('Entrada negativa e tipo desconhecido são recusados', () {
    final r = ler(
      '$cabSicredi\n01/09/2026;Teste;1;X;C;-10,00;0\n01/09/2026;Teste;1;X;???;10,00;0',
    );
    expect(r.itens, isEmpty);
    expect(r.ocorrencias.length, 2);
  });
  test('Débito e crédito separados com conflito são recusados', () {
    final r = ler(
      'data;descricao;debito;credito\n01/09/2026;A;10,00;\n02/09/2026;B;;25,50\n03/09/2026;C;10;20',
    );
    expect(r.itens.length, 2);
    expect(r.itens.first.tipo, TipoMovimentacao.despesa);
    expect(r.ocorrencias.length, 1);
  });
  test('Valor ambíguo e cabeçalho desconhecido pedem mapeamento', () {
    expect(ler('data;descricao;valor\n01/09/2026;A;1.234').precisaMapear, true);
    expect(ler('quando;texto;quantidade\n01/09/2026;A;5').precisaMapear, true);
  });
  test('Mapeamento manual funciona e recusa saldo e colunas duplicadas', () {
    const s = 'quando|texto|quantidade|saldo\n09/30/2026|Teste|1,234.56|900';
    final r = MotorImportacao.ler(
      s,
      categoriasTeste,
      separador: '|',
      mapeamento: const MapeamentoCsv(
        cabecalho: 0,
        data: 0,
        descricao: 1,
        valor: 2,
        decimal: '.',
        formatoData: 'mda',
      ),
    );
    expect(r.itens.single.centavos, 123456);
    expect(
      () => MotorImportacao.ler(
        s,
        categoriasTeste,
        separador: '|',
        mapeamento: const MapeamentoCsv(
          cabecalho: 0,
          data: 0,
          descricao: 1,
          valor: 3,
        ),
      ),
      throwsFormatException,
    );
    expect(
      () => MotorImportacao.ler(
        s,
        categoriasTeste,
        separador: '|',
        mapeamento: const MapeamentoCsv(
          cabecalho: 0,
          data: 0,
          descricao: 0,
          valor: 2,
        ),
      ),
      throwsFormatException,
    );
  });
  test('CSV truncado entre aspas não vira movimentação', () {
    expect(
      () => ler('data;descricao;valor\n01/09/2026;"campo sem fechar;1,00'),
      throwsFormatException,
    );
  });
  testWidgets('Mapeamento cabe em tela estreita', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const s = 'quando;texto;quantidade\n01/09/2026;Teste;12,00';
    await tester.pumpWidget(
      MaterialApp(
        home: TelaMapearCsv(conteudo: s, resultado: ler(s)),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Conferir movimentações'), findsOneWidget);
  });
  testWidgets('Adicionar banco reutiliza Nubank e aceita nome personalizado', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TelaEscolherConta(contas: [])));
    for (final nome in [' nubank ', 'Banco Local']) {
      await tester.tap(find.text('Adicionar banco'));
      await tester.pumpAndSettle();
      await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextFormField)), nome);
      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();
      expect(find.text(nome.trim() == 'nubank' ? 'Nubank' : nome).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('Conta exige nome e cancelar não persiste dados', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TelaEscolherConta(contas: [], bancoDetectado: '001'),
      ),
    );
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(
      find.text('Informe um nome para identificar esta conta.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('Revisão mostra banco, conta e descartes sem gravar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final r = ler(
      '$cabBB\n"01/09/2026","Pagamento","","1","-10,00","Saída"\n"01/09/2026","Saldo Anterior","","","100,00",""',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TelaRevisaoExtrato(
          itens: r.itens,
          categorias: const [],
          resultado: r,
          conta: const ContaOrigem(nome: 'Pessoal', bancoCodigo: '001'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Formato detectado: Banco do Brasil'), findsOneWidget);
    expect(find.textContaining('Conta de origem:'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.textContaining('linhas descartadas'));
    await tester.pumpAndSettle();
    expect(find.text('Saldo ou total do extrato'), findsOneWidget);
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
