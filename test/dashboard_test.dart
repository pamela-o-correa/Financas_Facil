import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financas_facil/main.dart';

void main() {
  testWidgets('Cards preservam adição separada e valores grandes em celular estreito', (tester) async {

    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var receitas = 0;
    var despesas = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Padding(
      padding: const EdgeInsets.all(20), child: Row(children: [
        Expanded(child: CardResumo(titulo: 'Receitas', valor: 'R\$ 1.000.000,00', icone: Icons.arrow_upward, cor: Colors.green, comparacao: '↑ 12,4% vs. mês anterior', onAdicionar: () => receitas++)),
        const SizedBox(width: 12),
        Expanded(child: CardResumo(titulo: 'Despesas', valor: 'R\$ 1.000.000,00', icone: Icons.arrow_downward, cor: Colors.red, onAdicionar: () => despesas++)),
      ])))));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Adicionar receita'));
    await tester.tap(find.byTooltip('Adicionar despesa'));
    expect(receitas, 1);
    expect(despesas, 1);
  });
  testWidgets('Rosca mantém acesso às categorias em largura pequena', (tester) async {
    String? categoria;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 280,
      child: GraficoRoscaCategorias(totais: const [MapEntry('Alimentação', 1000000)], total: 1000000, cores: const {}, onCategoria: (v) => categoria = v)))));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Alimentação'));
    expect(categoria, 'Alimentação');
  });
}

