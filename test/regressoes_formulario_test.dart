import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financas_facil/main.dart';

void main() {
  const categoria = Categoria(
    nome: 'Outros',
    tipo: TipoMovimentacao.despesa,
    codigoIcone: 0,
    codigoCor: 0,
  );
  Future<void> abrir(
    WidgetTester tester, {
    List<Categoria> categorias = const [categoria],
    Movimentacao? movimento,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('pt', 'BR')],
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TelaFormulario(
                    categorias: categorias,
                    movimentacao: movimento,
                    tipoInicial: TipoMovimentacao.despesa,
                  ),
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('categorias ainda não carregadas não derrubam formulário', (
    tester,
  ) async {
    await abrir(tester, categorias: []);
    expect(tester.takeException(), isNull);
    await tester.enterText(find.widgetWithText(TextFormField, 'Valor'), '10');
    final salvar = find.text('Adicionar movimentação');
    await tester.ensureVisible(salvar);
    await tester.tap(salvar);
    await tester.pumpAndSettle();
    expect(find.text('Nova movimentação'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('NaN e infinito são rejeitados antes de retornar lançamento', (
    tester,
  ) async {
    for (final valor in [
      'NaN',
      'Infinity',
      '1e999',
      '1e308',
      '1e100',
      '0.001',
    ]) {
      await abrir(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor'),
        valor,
      );
      final salvar = find.text('Adicionar movimentação');
      await tester.ensureVisible(salvar);
      await tester.tap(salvar);
      await tester.pumpAndSettle();
      expect(find.text('Informe um valor válido.'), findsOneWidget);
      expect(find.text('Nova movimentação'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });
  testWidgets('edição de data importada anterior a 2000 abre seletor', (
    tester,
  ) async {
    await abrir(
      tester,
      movimento: Movimentacao(
        id: 1,
        tipo: TipoMovimentacao.despesa,
        valor: 10,
        categoria: 'Outros',
        descricao: 'Anterior',
        data: DateTime(1999, 12, 31),
      ),
    );
    final data = find.text('31/12/1999');
    await tester.ensureVisible(data);
    await tester.tap(data);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });
}
