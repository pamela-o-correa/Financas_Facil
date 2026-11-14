import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financas_facil/main.dart';

void main() {
  test('Categoria mantém os dados e o ícone após salvar e carregar', () {
    for (final tipo in TipoMovimentacao.values) {
      final original = Categoria(
        id: 7,
        nome: 'Categoria renomeada',
        tipo: tipo,
        codigoIcone: Icons.work_outline.codePoint,
        codigoCor: 0xFF6750A4,
        padrao: true,
      );
      final restaurada = Categoria.deMapa(original.paraMapa());
      expect(restaurada.paraMapa(), original.paraMapa());
      expect(restaurada.icone, Icons.work_outline);
      expect(restaurada.cor, const Color(0xFF6750A4));
    }
  });

  test('Categoria com código de ícone desconhecido usa ícone de categoria', () {
    const categoria = Categoria(
      nome: 'Importada',
      tipo: TipoMovimentacao.despesa,
      codigoIcone: -1,
      codigoCor: 0xFF6750A4,
    );
    expect(categoria.icone, Icons.category_outlined);
    expect(categoria.paraMapa()['codigo_icone'], -1);
  });

  test('Design System constrói os 4 temas (Noir, Espresso, Sage, Amethyst) com tokens exatos', () {
    final noir = construirTemaPremium(
      nomeTema: 'Noir',
      brilhoSolicitado: Brightness.light,
    );
    expect(noir.brightness, Brightness.dark);
    expect(noir.scaffoldBackgroundColor, const Color(0xFF101114));
    expect(noir.colorScheme.surfaceContainerLow, const Color(0xFF1C1D21));
    expect(noir.colorScheme.surfaceContainerHighest, const Color(0xFF282A2F));
    expect(noir.colorScheme.onSurface, const Color(0xFFF7F7F5));
    expect(noir.colorScheme.onSurfaceVariant, const Color(0xFFA8ABB2));
    expect(noir.colorScheme.primary, const Color(0xFFE4E4E4));

    final espresso = construirTemaPremium(
      nomeTema: 'Espresso',
      brilhoSolicitado: Brightness.light,
    );
    expect(espresso.scaffoldBackgroundColor, const Color(0xFFFAF6F0));
    expect(espresso.colorScheme.surfaceContainerLow, const Color(0xFFFFFFFF));
    expect(espresso.colorScheme.surfaceContainerHighest, const Color(0xFFE8D7C3));
    expect(espresso.colorScheme.primary, const Color(0xFF35271F));
    expect(espresso.colorScheme.secondary, const Color(0xFF795D49));

    final sage = construirTemaPremium(
      nomeTema: 'Sage',
      brilhoSolicitado: Brightness.light,
    );
    expect(sage.scaffoldBackgroundColor, const Color(0xFFF4F7F2));
    expect(sage.colorScheme.surfaceContainerHighest, const Color(0xFFE1EBDF));
    expect(sage.colorScheme.primary, const Color(0xFF183C30));
    expect(sage.colorScheme.secondary, const Color(0xFF47735E));
    expect(sage.colorScheme.onSurface, const Color(0xFF193B30));

    final amethyst = construirTemaPremium(
      nomeTema: 'Amethyst',
      brilhoSolicitado: Brightness.light,
    );
    expect(amethyst.scaffoldBackgroundColor, const Color(0xFFF7F4FA));
    expect(amethyst.colorScheme.surfaceContainerHighest, const Color(0xFFEBE4F3));
    expect(amethyst.colorScheme.primary, const Color(0xFF392B53));
    expect(amethyst.colorScheme.secondary, const Color(0xFF775C9E));
    expect(amethyst.colorScheme.onSurface, const Color(0xFF35284A));

    expect(normalizarNomeTema('Roxo'), 'Amethyst');
    expect(normalizarNomeTema('Verde'), 'Sage');
    expect(normalizarNomeTema('Azul'), 'Noir');
    expect(amethyst.extension<CoresSemanticas>(), isNotNull);
  });

  testWidgets('SeletorTemaVisual exibe os 4 temas e permite seleção imediata', (tester) async {
    String tema = 'Amethyst';
    await tester.pumpWidget(
      MaterialApp(
        theme: construirTemaPremium(
          nomeTema: tema,
          brilhoSolicitado: Brightness.light,
        ),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SeletorTemaVisual(
              temaSelecionado: tema,
              onSelecionar: (novo) => setState(() => tema = novo),
            ),
          ),
        ),
      ),
    );
    for (final nome in ['Noir', 'Espresso', 'Sage', 'Amethyst']) {
      expect(find.text(nome), findsOneWidget);
    }
    await tester.tap(find.text('Sage'));
    await tester.pumpAndSettle();
    expect(tema, 'Sage');
    expect(tester.takeException(), isNull);
  });

  test('Movimentacao preserva conta e observacoes em toMap e fromMap', () {
    final original = Movimentacao(
      id: 42,
      tipo: TipoMovimentacao.despesa,
      valor: 125.50,
      categoria: 'Moradia',
      descricao: 'Aluguel mensal',
      data: DateTime(2026, 10, 5),
      contaId: 3,
      conta: 'Conta Principal',
      observacoes: 'Pago via Pix',
    );
    final restaurada = Movimentacao.fromMap(original.toMap());
    expect(restaurada.conta, 'Conta Principal');
    expect(restaurada.observacoes, 'Pago via Pix');
    expect(restaurada.centavos, 12550);
  });

  testWidgets('CardResumo renderiza sem overflow nos 4 temas minimalistas', (tester) async {
    for (final nomeTema in ['Noir', 'Espresso', 'Sage', 'Amethyst']) {
      final tema = construirTemaPremium(
        nomeTema: nomeTema,
        brilhoSolicitado: Brightness.light,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: tema,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: CardResumo(
                      titulo: 'Receitas',
                      valor: 'R\$ 5.420,00',
                      comparacao: '↑ 12,0% vs. mês anterior',
                      icone: Icons.arrow_upward,
                      cor: tema.extension<CoresSemanticas>()!.receita,
                      onAdicionar: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CardResumo(
                      titulo: 'Despesas',
                      valor: 'R\$ 2.180,50',
                      comparacao: '↓ 4,5% vs. mês anterior',
                      icone: Icons.arrow_downward,
                      cor: tema.extension<CoresSemanticas>()!.despesa,
                      onAdicionar: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('Receitas'), findsOneWidget);
      expect(find.text('Despesas'), findsOneWidget);
      expect(find.text('R\$ 5.420,00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('TelaFormulario permite alternar atalhos de data Hoje e Ontem e preserva conta/observacoes', (tester) async {
    Movimentacao? salva;
    final existente = Movimentacao(
      id: 10,
      tipo: TipoMovimentacao.despesa,
      valor: 89.90,
      categoria: 'Outros',
      descricao: 'Internet',
      data: DateTime(2026, 5, 10),
      conta: 'Carteira Nubank',
      observacoes: 'Débito automático',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: construirTemaPremium(
          nomeTema: 'Espresso',
          brilhoSolicitado: Brightness.light,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                salva = await Navigator.push<Movimentacao>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TelaFormulario(
                      categorias: const [
                        Categoria(
                          nome: 'Outros',
                          tipo: TipoMovimentacao.despesa,
                          codigoIcone: 0,
                          codigoCor: 0xFF35271F,
                        ),
                      ],
                      movimentacao: existente,
                    ),
                  ),
                );
              },
              child: const Text('Editar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(find.text('Valor da despesa'), findsOneWidget);
    await tester.tap(find.text('Hoje'));
    await tester.pumpAndSettle();
    final botaoSalvar = find.text('Salvar alterações');
    await tester.ensureVisible(botaoSalvar);
    await tester.tap(botaoSalvar);
    await tester.pumpAndSettle();
    expect(salva, isNotNull);
    expect(salva!.conta, 'Carteira Nubank');
    expect(salva!.observacoes, 'Débito automático');
    expect(salva!.data, DateUtils.dateOnly(DateTime.now()));
    expect(tester.takeException(), isNull);
  });
}