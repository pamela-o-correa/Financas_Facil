import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financas_facil/main.dart';

void main() {
  test(
    'Busca por valor aceita reais, centavos e separadores sem aproximação',
    () {
      for (final texto in ['150', '150,00', 'R\$ 150,00', '150.00']) {
        expect(valorPesquisadoEmCentavos(texto), 15000, reason: texto);
      }
      expect(valorPesquisadoEmCentavos('R\$ 1.500,35'), 150035);
      expect(valorPesquisadoEmCentavos('1.500'), 150000);
      expect(valorPesquisadoEmCentavos('0,01'), 1);
      expect(valorPesquisadoEmCentavos('12,345'), isNull);
      expect(valorPesquisadoEmCentavos('Uber'), isNull);
      expect(valorPesquisadoEmCentavos(''), isNull);
    },
  );

  test('Busca combina valor, conta, tipo, categoria e contabilização', () {
    Movimentacao item(
      int id,
      int? conta, {
      double valor = 150,
      bool ativa = true,
      TipoMovimentacao tipo = TipoMovimentacao.despesa,
    }) => Movimentacao(
      id: id,
      contaId: conta,
      tipo: tipo,
      valor: valor,
      ativa: ativa,
      categoria: 'Transporte',
      descricao: 'Uber',
      data: DateTime(2026, 9, 9),
    );
    final itens = [
      item(1, 1),
      item(2, 2),
      item(3, null),
      item(4, 1, valor: 150.01),
      item(5, 1, ativa: false),
      item(6, 1, tipo: TipoMovimentacao.receita),
    ];
    final filtrados = filtrarHistorico(
      itens,
      pesquisa: 'R\$ 150,00',
      contaId: 1,
      tipo: TipoMovimentacao.despesa,
      categoria: 'Transporte',
      ativa: true,
    );
    expect(filtrados.map((m) => m.id), [1]);
    expect(filtrarHistorico(itens, contaId: -1).single.id, 3);
    expect(filtrarHistorico(itens, pesquisa: 'uBeR').length, 6);
    expect(filtrarHistorico(itens, pesquisa: '150,01').single.id, 4);
    expect(filtrarHistorico(itens, categoria: 'Outros'), isEmpty);
  });

  test(
    'Preferência diferencia conta e tipo e normaliza somente caixa e espaços',
    () {
      PreferenciaContabilizacao regra(
        int conta,
        TipoMovimentacao tipo,
        String descricao,
      ) => PreferenciaContabilizacao(
        contaId: conta,
        tipo: tipo,
        descricao: descricao,
        ativa: false,
      );
      final r = regra(1, TipoMovimentacao.despesa, 'Aplicação RDB');
      expect(
        r.chave,
        regra(1, TipoMovimentacao.despesa, '  APLICAÇÃO   RDB ').chave,
      );
      expect(
        r.chave,
        isNot(regra(2, TipoMovimentacao.despesa, 'Aplicação RDB').chave),
      );
      expect(
        r.chave,
        isNot(regra(1, TipoMovimentacao.receita, 'Aplicação RDB').chave),
      );
      expect(
        r.chave,
        isNot(
          regra(1, TipoMovimentacao.despesa, 'Aplicação RDB adicional').chave,
        ),
      );
    },
  );

  testWidgets(
    'Importação só muda contabilização depois de aplicar a sugestão',
    (tester) async {
      final item = ItemExtrato(
        data: DateTime(2026),
        descricao: 'Aplicação RDB',
        valor: 5000,
        tipo: TipoMovimentacao.despesa,
      )..contabilizacaoSugerida = false;
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
      expect(item.ativa, true);
      await Scrollable.ensureVisible(
        tester.element(find.text('Aplicar sugestão')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar sugestão'));
      await tester.pumpAndSettle();
      expect(item.ativa, false);
      expect(item.selecionado, true);
      await Scrollable.ensureVisible(
        tester.element(find.text('Contabilizar')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Contabilizar'));
      await tester.pumpAndSettle();
      expect(item.ativa, true);
      expect(tester.takeException(), isNull);
    },
  );
}
