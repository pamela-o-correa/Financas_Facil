import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financas_facil/main.dart';

void main() {
  final item = Movimentacao(id: 1, tipo: TipoMovimentacao.despesa,
    valor: 5000, categoria: 'Outros', descricao: 'Aplicação RDB',
    data: DateTime(2026, 9, 9), contaId: 2, importacaoId: 3);

  test('Desativação preserva dados e exclui valores dos agrupamentos', () {
    final desativada = item.copyWith(ativa: false);
    final restaurada = Movimentacao.fromMap(desativada.toMap());
    expect(restaurada.ativa, false);
    expect(restaurada.copyWith(descricao: 'Editada').ativa, false);
    expect(restaurada.contaId, 2);
    expect(restaurada.importacaoId, 3);
    expect(totaisCategorias([restaurada]), isEmpty);
    expect(agruparDespesas([restaurada], const [], AgrupamentoDespesa.categoria), isEmpty);
    expect(totaisCategorias([restaurada.copyWith(ativa: true)]).single.value, 5000);
    final antigo = item.toMap()..remove('ativa');
    expect(Movimentacao.fromMap(antigo).ativa, true);
    expect(item.copyWith(ativa: false).contabilizavel, false);
  });

  testWidgets('Menu permite desativar e reativar sem remover o cartão', (tester) async {
    var atual = item;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(
      builder: (context, setState) => CardMovimentacao(
        movimentacao: atual, dinheiro: (v) => 'R\$ 5.000,00',
        dataFormatada: (_) => '09/09/2026', onEditar: () {}, onExcluir: () {},
        onAlternarContabilizacao: () => setState(() { atual = atual.copyWith(ativa: !atual.ativa); }),
      ),
    ))));
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Excluir'), findsOneWidget);
    await tester.tap(find.text('Desativar contabilização'));
    await tester.pumpAndSettle();
    expect(atual.ativa, false);
    expect(find.textContaining('Contabilização desativada'), findsOneWidget);
    expect(find.text('Aplicação RDB'), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reativar contabilização'));
    await tester.pumpAndSettle();
    expect(atual.ativa, true);
    expect(tester.takeException(), isNull);
  });
}
