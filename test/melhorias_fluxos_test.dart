import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:financas_facil/main.dart';
import 'package:financas_facil/contas/contas_banco.dart';

final class ArquivoTeste extends PlatformFile {
  ArquivoTeste(this.name);
  @override
  final String name;
  @override
  String? get path => name;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class BancoFluxoTeste implements BancoDados {
  @override
  Future<List<Movimentacao>> listar() async => [
    mov(1, false, 1, DateTime(2026, 9, 30)),
    mov(2, true, 2, DateTime(2026, 10, 1)),
  ];
  @override
  Future<List<Categoria>> listarCategorias() async => const [
    Categoria(
      id: 1,
      nome: 'Alimentação',
      tipo: TipoMovimentacao.despesa,
      codigoIcone: 0,
      codigoCor: 0,
    ),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Movimentacao mov(
  int id,
  bool entrada,
  int? conta,
  DateTime data, {
  double valor = 100,
  int? par,
}) => Movimentacao(
  id: id,
  tipo: entrada ? TipoMovimentacao.receita : TipoMovimentacao.despesa,
  valor: valor,
  categoria: 'Outros',
  descricao: 'PIX $id',
  data: data,
  contaId: conta,
  transferenciaPar: par,
);

void main() {
  test('Sugestões validam valor, tipo, contas e distância de datas sem classificar automaticamente', () {
    final s = mov(1, false, 1, DateTime(2026, 9, 30));
    final e = mov(2, true, 2, DateTime(2026, 10, 1));
    expect(compativeisTransferencia(s, e), true);
    expect(compativeisTransferencia(s, mov(3, true, 1, e.data)), false);
    expect(compativeisTransferencia(s, mov(3, true, null, e.data)), false);
    expect(
      compativeisTransferencia(s, mov(3, true, 2, DateTime(2026, 10, 4))),
      false,
    );
    expect(
      compativeisTransferencia(s, mov(3, true, 2, e.data, valor: 100.01)),
      false,
    );
    expect(compativeisTransferencia(s, mov(3, true, 2, e.data, par: 5)), false);
    expect(sugerirTransferencias([s, e]).length, 1);
    expect(s.transferencia, false);
    expect(totaisCategorias([s, e]).single.value, 100);
    expect(totaisCategorias([mov(1, false, 1, s.data, par: 2)]), isEmpty);
    expect(
      agruparDespesas(
        [mov(1, false, 1, s.data, par: 2)],
        const [],
        AgrupamentoDespesa.banco,
      ),
      isEmpty,
    );
  });

  testWidgets(
    'Central preserva arquivos concluídos após erro e permite tentar pendente de novo',
    (tester) async {
      final chamadas = <String>[];
      var falhar = true;
      await tester.pumpWidget(
        MaterialApp(
          home: TelaCentralImportacao(
            banco: BancoFluxoTeste(),
            contaInicial: const ContaOrigem(
              id: 1,
              nome: 'Pessoal',
              bancoCodigo: '260',
            ),
            arquivosIniciais: [ArquivoTeste('a.csv'), ArquivoTeste('b.csv')],
            processar: (arquivo, conta) async {
              chamadas.add(arquivo.name);
              if (arquivo.name == 'b.csv' && falhar) {
                throw const FormatException('CSV inválido');
              }
              return const ResultadoArquivoImportado(3, 1, 0);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Revisar todos os pendentes'),
        200,
      );
      await tester.tap(find.text('Revisar todos os pendentes'));
      await tester.pumpAndSettle();
      expect(chamadas, ['a.csv', 'b.csv']);
      await tester.scrollUntilVisible(
        find.textContaining('1 arquivos importados'),
        -200,
      );
      expect(
        find.textContaining('1 arquivos importados • 1 pendentes'),
        findsOneWidget,
      );
      falhar = false;
      await tester.scrollUntilVisible(
        find.text('Revisar todos os pendentes'),
        200,
      );
      await tester.tap(find.text('Revisar todos os pendentes'));
      await tester.pumpAndSettle();
      expect(chamadas, ['a.csv', 'b.csv', 'b.csv']);
      await tester.scrollUntilVisible(
        find.textContaining('2 arquivos importados'),
        -200,
      );
      expect(find.textContaining('6 lançamentos salvos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Revisão de categorias respeita período e cabe em celular estreito',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: TelaRevisarCategorias(
            banco: BancoFluxoTeste(),
            periodo: '01/09/2026 a 30/09/2026',
            noPeriodo: (d) => d.month == 9,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('PIX 1'), findsOneWidget);
      expect(find.text('PIX 2'), findsNothing);
      await tester.tap(find.text('PIX 1'));
      await tester.pumpAndSettle();
      expect(find.text('1 selecionados'), findsOneWidget);
      await tester.tap(find.text('Escolher categoria'));
      await tester.pumpAndSettle();
      expect(find.text('Classificar 1 lançamentos'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Detalhe do gráfico conserva período e agrupamento', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GraficoDespesasAlternavel(
            movimentos: [mov(1, false, 1, DateTime(2026, 9, 1))],
            contas: const [
              ContaOrigem(id: 1, nome: 'Pessoal', bancoCodigo: '260'),
            ],
            coresCategorias: const {},
            modo: AgrupamentoDespesa.banco,
            onModo: (_) {},
            periodo: '01/09/2026 a 30/09/2026',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nubank'));
    await tester.pumpAndSettle();
    expect(find.text('Por banco • Nubank'), findsOneWidget);
    expect(find.text('01/09/2026 a 30/09/2026'), findsOneWidget);
  });
}
