import 'dart:async';

import 'package:financas_facil/main.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

Previsto compromisso({
  DateTime? data,
  String status = 'pendente',
  String tipo = 'despesa',
  int centavos = 12345,
}) => Previsto(
  id: 1,
  serie: 'teste',
  titulo: 'Compromisso com descrição longa para verificar a leitura',
  tipo: tipo,
  centavos: centavos,
  categoria: 'Categoria com nome longo',
  data: data ?? diaAgenda(DateTime.now()),
  frequencia: 'mensal',
  lembrete: null,
  hora: 9,
  minuto: 0,
  status: status,
  conta: 'Minha carteira',
  observacoes: 'Observação do compromisso',
);

class AgendaTeste extends AgendaBanco {
  AgendaTeste(this.itens) : super(Completer<Database>().future);
  final List<Previsto> itens;
  @override
  Future<List<Previsto>> listar() async => itens;
}

Widget app(Widget child, {double escala = 1}) => MaterialApp(
  locale: const Locale('pt', 'BR'),
  supportedLocales: const [Locale('pt', 'BR')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: Brightness.dark,
    ),
  ),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(escala)),
    child: child!,
  ),
  home: Scaffold(body: child),
);

void main() {
  test('Recorrência mensal preserva a âncora e anos bissextos', () {
    expect(datasRecorrentes(DateTime(2024, 1, 31), 'mensal', 3), [
      DateTime(2024, 1, 31),
      DateTime(2024, 2, 29),
      DateTime(2024, 3, 31),
    ]);
    expect(datasRecorrentes(DateTime(2024, 2, 29), 'anual', 2), [
      DateTime(2024, 2, 29),
      DateTime(2025, 2, 28),
    ]);
    expect(
      datasRecorrentes(DateTime(2026, 12, 28), 'semanal', 2).last,
      DateTime(2027, 1, 4),
    );
  });

  test('Status distingue previsão, vencimento, atraso e pagamento', () {
    final hoje = DateTime(2026, 9, 8);
    expect(
      compromisso(data: DateTime(2026, 9, 9)).rotuloStatus(hoje),
      'Previsto',
    );
    expect(compromisso(data: hoje).rotuloStatus(hoje), 'Pendente');
    expect(
      compromisso(data: DateTime(2026, 9, 7)).rotuloStatus(hoje),
      'Vencido • pendente',
    );
    expect(compromisso(status: 'realizado').rotuloStatus(hoje), 'Pago');
    expect(
      compromisso(status: 'realizado', tipo: 'receita').rotuloStatus(hoje),
      'Recebido',
    );
  });

  for (final largura in [320.0, 390.0, 600.0]) {
    for (final escala in [1.0, 2.0]) {
      testWidgets('Rosca e legenda sem overflow em $largura, escala $escala', (
        tester,
      ) async {
        tester.view.physicalSize = Size(largura, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        String? selecionada;
        await tester.pumpWidget(
          app(
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: GraficoRoscaCategorias(
                  totais: const [
                    MapEntry('Moradia e despesas da casa', 750),
                    MapEntry('Transporte', 250),
                  ],
                  total: 1000,
                  cores: const {
                    'Moradia e despesas da casa': Colors.purple,
                    'Transporte': Colors.green,
                  },
                  onCategoria: (nome) => selecionada = nome,
                ),
              ),
            ),
            escala: escala,
          ),
        );
        expect(find.text('R\$ 1.000,00'), findsOneWidget);
        expect(find.textContaining('75,0%'), findsOneWidget);
        await tester.ensureVisible(find.text('Transporte'));
        await tester.tap(find.text('Transporte'));
        expect(selecionada, 'Transporte');
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'Gráfico recalcula valor e percentuais após alteração dos dados',
    (tester) async {
      Widget grafico(double valor) => app(
        GraficoRoscaCategorias(
          totais: [MapEntry('Casa', valor), const MapEntry('Saúde', 100)],
          total: valor + 100,
          cores: const {},
          onCategoria: (_) {},
        ),
      );
      await tester.pumpWidget(grafico(100));
      expect(find.text('R\$ 200,00'), findsOneWidget);
      await tester.pumpWidget(grafico(300));
      expect(find.text('R\$ 400,00'), findsOneWidget);
      expect(find.textContaining('75,0%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Calendário mostra dia, resumo e próximos sem overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(
        TelaAgenda(
          banco: AgendaTeste([compromisso()]),
          perfil: 1,
          nomePerfil: 'Teste',
          categorias: const {
            'despesa': ['Outros'],
          },
          onRealizado: () async {},
        ),
        escala: 2,
      ),
    );
    await tester.pumpAndSettle();
    var encontrouProximos = false;
    for (var i = 0; i < 18; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -350));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      encontrouProximos |= find
          .text('Próximos vencimentos')
          .evaluate()
          .isNotEmpty;
    }
    expect(encontrouProximos, isTrue);
  });

  testWidgets('Formulário tem conta e observações e preserva edição', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(
        FormularioAgenda(
          banco: AgendaTeste([]),
          categorias: const {
            'despesa': ['Outros'],
          },
          dataInicial: DateTime.now(),
          existente: compromisso(),
        ),
        escala: 1.5,
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 10; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Salvar compromisso'), findsOneWidget);
  });

  testWidgets(
    'Detalhes do compromisso exibem metadados semânticos e formulário aceita separador de milhar',
    (tester) async {
      var centavosSalvos = 0;
      final banco = _AgendaGravavelTeste(
        itens: [compromisso()],
        aoSalvar: (centavos) => centavosSalvos = centavos,
      );
      await tester.pumpWidget(
        app(
          TelaAgenda(
            banco: banco,
            perfil: 1,
            nomePerfil: 'Teste',
            categorias: const {
              'despesa': ['Outros'],
              'receita': ['Outros'],
            },
            onRealizado: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      while (find
          .text('Compromisso com descrição longa para verificar a leitura')
          .evaluate()
          .isEmpty) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -250));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(
        find
            .text('Compromisso com descrição longa para verificar a leitura')
            .first,
      );
      await tester.tap(
        find
            .text('Compromisso com descrição longa para verificar a leitura')
            .first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Despesa prevista'), findsOneWidget);
      expect(find.text('Conta: Minha carteira'), findsOneWidget);
      expect(find.text('Observação do compromisso'), findsOneWidget);

      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor (R\$)'),
        '1.250,50',
      );
      await tester.scrollUntilVisible(
        find.text('Salvar compromisso'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Salvar compromisso'));
      await tester.pumpAndSettle();

      expect(centavosSalvos, 125050);
    },
  );
}

class _AgendaGravavelTeste extends AgendaTeste {
  _AgendaGravavelTeste({required List<Previsto> itens, required this.aoSalvar})
    : super(itens);

  final void Function(int centavos) aoSalvar;

  @override
  Future<void> salvar({
    Previsto? existente,
    required String titulo,
    required String tipo,
    required int centavos,
    required String categoria,
    required DateTime data,
    required String frequencia,
    required int quantidade,
    required int? lembrete,
    required int hora,
    required int minuto,
    String conta = '',
    String observacoes = '',
  }) async {
    aoSalvar(centavos);
  }
}
