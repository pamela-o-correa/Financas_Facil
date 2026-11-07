import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financas_facil/contas/contas_banco.dart';
import 'package:financas_facil/contas/tela_contas.dart';

class BancoTeste extends ContasBanco {
  BancoTeste() : super(Future.error('Não utilizado')..ignore());
  List<ContaOrigem> contas = [
    const ContaOrigem(id: 1, nome: 'Antiga', bancoCodigo: 'generico'),
    const ContaOrigem(id: 2, nome: 'Pessoal', bancoCodigo: '260'),
  ];
  @override
  Future<List<ContaOrigem>> listar() async => List.of(contas);
  @override
  Future<Map<String, String>> listarBancos() async => bancosImportacao;
  @override
  Future<void> reunir(int origem, ContaOrigem destino) async {
    contas.removeWhere((c) => c.id == origem);
  }

  @override
  Future<void> salvar(ContaOrigem conta) async {
    contas.add(conta);
  }

  @override
  Future<void> editar(int id, ContaOrigem nova) async {
    contas = contas
        .map(
          (c) => c.id == id
              ? ContaOrigem(
                  id: id,
                  nome: nova.nome,
                  bancoCodigo: nova.bancoCodigo,
                )
              : c,
        )
        .toList();
  }

  bool? apagouDados;
  @override
  Future<(int, int)> contarVinculos(int contaId) async => (4, 2);
  @override
  Future<void> excluir(int contaId, {bool apagarDados = false}) async {
    apagouDados = apagarDados;
    contas.removeWhere((c) => c.id == contaId);
  }
}

void main() {
  testWidgets('Editar conta mantém identidade e mostra campos preenchidos', (
    tester,
  ) async {
    final banco = BancoTeste();
    await tester.pumpWidget(MaterialApp(home: TelaContas(banco: banco)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Opções da conta').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar nome/banco'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    expect(find.text('Antiga'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Renomeada');
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();
    expect(banco.contas.first.id, 1);
    expect(find.text('Renomeada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Excluir exige confirmação e preserva dados por padrão', (
    tester,
  ) async {
    final banco = BancoTeste();
    await tester.pumpWidget(MaterialApp(home: TelaContas(banco: banco)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Opções da conta').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir conta'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('2 importações e 4 lançamentos'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(banco.contas.length, 2);
    expect(banco.apagouDados, isNull);
    await tester.tap(find.byTooltip('Opções da conta').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir só o cadastro'));
    await tester.pumpAndSettle();
    expect(banco.apagouDados, false);
    expect(find.text('Antiga'), findsNothing);
    await tester.tap(find.byTooltip('Opções da conta').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir conta e dados'));
    await tester.pumpAndSettle();
    expect(banco.apagouDados, true);
    expect(banco.contas, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Corrigir banco atualiza a lista sem erro após salvar', (
    tester,
  ) async {
    final banco = BancoTeste();
    await tester.pumpWidget(MaterialApp(home: TelaContas(banco: banco)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Opções da conta').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reunir com outra conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nubank • Pessoal').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reunir'));
    await tester.pumpAndSettle();
    expect(find.text('Antiga'), findsNothing);
    expect(find.text('Nubank'), findsOneWidget);
    expect(find.textContaining('Não foi possível'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Nova');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Nova'), findsOneWidget);
    expect(find.textContaining('Não foi possível'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
