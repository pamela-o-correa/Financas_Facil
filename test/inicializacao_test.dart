import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financas_facil/main.dart';

void main() {
  testWidgets('abertura lenta exibe progresso e depois inicia o app', (
    tester,
  ) async {
    final abertura = Completer<void>();
    await tester.pumpWidget(
      InicializacaoApp(
        inicializar: () => abertura.future,
        aplicativo: const Directionality(
          textDirection: TextDirection.ltr,
          child: Text('Aberto'),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    abertura.complete();
    await tester.pumpAndSettle();
    expect(find.text('Aberto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('falha de abertura permite tentar novamente sem limpar dados', (
    tester,
  ) async {
    var tentativas = 0;
    await tester.pumpWidget(
      InicializacaoApp(
        inicializar: () async {
          if (++tentativas == 1) throw StateError('Erro privado do banco');
        },
        aplicativo: const Directionality(
          textDirection: TextDirection.ltr,
          child: Text('Aberto'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Nenhum dado foi apagado'), findsOneWidget);
    expect(find.textContaining('Erro privado'), findsNothing);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(tentativas, 2);
    expect(find.text('Aberto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
