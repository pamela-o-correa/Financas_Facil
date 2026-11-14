import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financas_facil/main.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Aparência desenha opções sem exceção em $brightness', (
      tester,
    ) async {
      final modoAnterior = modoTema.value;
      final corAnterior = corTema.value;
      final ocultoAnterior = ocultarValores.value;
      addTearDown(() {
        modoTema.value = modoAnterior;
        corTema.value = corAnterior;
        ocultarValores.value = ocultoAnterior;
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: const TelaAparencia(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Ocultar valores monetários'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Tamanho do texto'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(modoTema.value, modoAnterior);
      expect(corTema.value, corAnterior);
      expect(ocultarValores.value, ocultoAnterior);
    });
  }
}
