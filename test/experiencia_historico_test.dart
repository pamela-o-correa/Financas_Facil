import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financas_facil/main.dart';

void main() {
  const original =
      'Transferência enviada pelo Pix - THAIS ALMEIDA - •••.947.661-•• - NU PAGAMENTOS - Agência: 1 Conta: 29960989-2';
  Movimentacao movimento() => Movimentacao(
    id: 1,
    tipo: TipoMovimentacao.despesa,
    valor: 2150,
    categoria: 'Outros',
    descricao: original,
    data: DateTime(2026, 9, 9),
  );

  test('Resumo remove detalhes bancários sem modificar a origem', () {
    expect(resumirDescricao(original), 'Pix para THAIS ALMEIDA');
    expect(
      resumirDescricao('Transferência recebida pelo Pix - ANA - 123'),
      'Pix de ANA',
    );
    expect(resumirDescricao('Compra no débito via NuPay - iFood'), 'iFood');
    expect(resumirDescricao('Aplicação RDB'), 'Aplicação RDB');
    expect(movimento().descricao, original);
  });

  test(
    'Sugestão de investimento exige contexto e mantém contabilização ativa',
    () {
      for (final texto in [
        'Aplicação RDB',
        'Resgate RDB',
        'APLICACAO EM CDB',
        'Resgate de fundos',
      ]) {
        final item = ItemExtrato(
          data: DateTime(2026),
          descricao: texto,
          valor: 100,
          tipo: TipoMovimentacao.receita,
        );
        expect(item.possivelInvestimento, true, reason: texto);
        expect(item.ativa, true);
        expect(item.selecionado, true);
      }
      final compra = ItemExtrato(
        data: DateTime(2026),
        descricao: 'Compra no débito - loja',
        valor: 100,
        tipo: TipoMovimentacao.despesa,
      );
      expect(compra.possivelInvestimento, false);
    },
  );

  testWidgets(
    'Cartão estreito abre descrição original e permite seleção por toque longo',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selecionada = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => CardMovimentacao(
                movimentacao: movimento(),
                dinheiro: (_) => 'R\$ 2.150,00',
                dataFormatada: (_) => '09/09/2026',
                onEditar: () {},
                onExcluir: () {},
                selecionada: selecionada,
                emSelecao: selecionada,
                onSelecionar: () => setState(() => selecionada = !selecionada),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Pix para THAIS ALMEIDA'), findsOneWidget);
      expect(find.text(original), findsNothing);
      await tester.tap(find.text('Pix para THAIS ALMEIDA'));
      await tester.pumpAndSettle();
      expect(find.text(original), findsOneWidget);
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Pix para THAIS ALMEIDA'));
      await tester.pumpAndSettle();
      expect(selecionada, true);
      expect(find.byType(Checkbox), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Aviso dos totais abre a revisão e desaparece quando não há desativadas',
    (tester) async {
      var abriu = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AvisoDesativadas(quantidade: 3, onVer: () => abriu = true),
          ),
        ),
      );
      await tester.tap(find.text('3 movimentações desativadas neste período'));
      expect(abriu, true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AvisoDesativadas(quantidade: 0, onVer: () {})),
        ),
      );
      expect(find.byType(ListTile), findsNothing);
    },
  );

  testWidgets(
    'Revisão permite importar aplicação desativada sem desmarcar o registro',
    (tester) async {
      final item = ItemExtrato(
        data: DateTime(2026),
        descricao: 'Aplicação RDB',
        valor: 5000,
        tipo: TipoMovimentacao.despesa,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TelaRevisaoExtrato(
            itens: [item],
            categorias: const [
              Categoria(
                nome: 'Outros',
                tipo: TipoMovimentacao.despesa,
                codigoIcone: 0,
                codigoCor: 0,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Contabilizar'));
      await tester.tap(find.text('Contabilizar'));
      await tester.pumpAndSettle();
      expect(item.ativa, false);
      expect(item.selecionado, true);
      expect(find.textContaining('Será importada desativada'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
