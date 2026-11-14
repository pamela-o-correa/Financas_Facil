import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:financas_facil/importacao/leitura_limitada.dart';
import 'package:financas_facil/importacao/analise_extrato.dart';

void main() {
  test('lê até o limite exato, incluindo fluxo vazio', () async {
    expect(
      await lerBytesLimitados(
        Stream.fromIterable([
          [1, 2],
          [3],
        ]),
        limite: 3,
      ),
      [1, 2, 3],
    );
    expect(await lerBytesLimitados(const Stream.empty(), limite: 0), isEmpty);
  });
  test(
    'cancela fluxo ao exceder o limite, sem consumir arquivo inteiro',
    () async {
      var cancelado = false;
      final controller = StreamController<List<int>>(
        onCancel: () => cancelado = true,
      );
      final leitura = lerBytesLimitados(controller.stream, limite: 3);
      final verificacao = expectLater(leitura, throwsFormatException);
      controller.add([1, 2]);
      controller.add([3, 4]);
      await verificacao;
      expect(cancelado, isTrue);
      await controller.close();
    },
  );
  test('propaga falha de leitura e rejeita limite inválido', () async {
    await expectLater(
      lerBytesLimitados(Stream.error(StateError('Leitura interrompida'))),
      throwsStateError,
    );
    await expectLater(
      lerBytesLimitados(const Stream.empty(), limite: -1),
      throwsArgumentError,
    );
  });
  test('análise em isolate mantém valores, tipos e erros do leitor', () async {
    const categorias = {'receita:Outros': 'Outros', 'despesa:Outros': 'Outros'};
    final resultado = await analisarExtrato(
      'Data;Descricao;Valor\n14/11/2026;Compra;-12,34',
      categorias,
    );
    expect(resultado.itens.single.centavos, 1234);
    expect(resultado.itens.single.tipo.name, 'despesa');
    await expectLater(
      analisarExtrato('Data;Descricao;Valor\n14/11/2026;Compra;-12,34', {}),
      throwsFormatException,
    );
  });
}
