import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financas_facil/main.dart';
import 'package:financas_facil/contas/contas_banco.dart';

const contas = [
  ContaOrigem(id: 1, nome: 'Pessoal', bancoCodigo: '260'),
  ContaOrigem(id: 2, nome: 'Empresa', bancoCodigo: '260'),
  ContaOrigem(id: 3, nome: 'Pessoal', bancoCodigo: '001'),
];
Movimentacao movimento(
  double valor,
  int? conta,
  DateTime data, {
  bool receita = false,
}) => Movimentacao(
  tipo: receita ? TipoMovimentacao.receita : TipoMovimentacao.despesa,
  valor: valor,
  categoria: 'Alimentação',
  descricao: 'Compra',
  data: data,
  contaId: conta,
);

void main() {
  final setembro = DateTime(2026, 9, 1);
  final movimentos = [
    movimento(10, 1, setembro),
    movimento(20, 2, setembro),
    movimento(30, 3, setembro),
    movimento(40, null, setembro),
    movimento(1000, 1, setembro, receita: true),
  ];
  test('Alternar preserva despesas e separa contas do mesmo banco', () {
    for (final modo in AgrupamentoDespesa.values) {
      final grupos = agruparDespesas(movimentos, contas, modo);
      expect(grupos.fold(0.0, (s, g) => s + g.total), 100);
    }
    final bancos = agruparDespesas(
      movimentos,
      contas,
      AgrupamentoDespesa.banco,
    );
    expect(bancos.firstWhere((g) => g.nome == 'Nubank').total, 30);
    expect(
      bancos.firstWhere((g) => g.nome == 'Sem conta identificada').total,
      40,
    );
    expect(
      agruparDespesas(movimentos, contas, AgrupamentoDespesa.conta).length,
      4,
    );
  });
  testWidgets(
    'Seletor em tela estreita respeita dados do período ao atualizar',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var modo = AgrupamentoDespesa.categoria;
      var periodo = movimentos;
      late StateSetter atualizar;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  atualizar = setState;
                  return GraficoDespesasAlternavel(
                    movimentos: periodo,
                    contas: contas,
                    coresCategorias: const {},
                    modo: modo,
                    onModo: (valor) => setState(() {
                      modo = valor;
                    }),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final opcao in AgrupamentoDespesa.values) {
        await tester.tap(find.text(opcao.rotulo));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<GraficoRoscaCategorias>(
                find.byType(GraficoRoscaCategorias),
              )
              .total,
          100,
        );
        expect(tester.takeException(), isNull);
      }
      atualizar(() {
        periodo = [movimento(7, 3, DateTime(2026, 10))];
      });
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<GraficoRoscaCategorias>(find.byType(GraficoRoscaCategorias))
            .total,
        7,
      );
      expect(find.textContaining('Nubank'), findsNothing);
      atualizar(() {
        periodo = [];
      });
      await tester.pumpAndSettle();
      expect(find.text('Sem despesas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
