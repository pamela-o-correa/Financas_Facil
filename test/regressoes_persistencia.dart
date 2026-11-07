import 'package:flutter_test/flutter_test.dart';
import 'package:financas_facil/main.dart';
import 'package:financas_facil/contas/contas_banco.dart';

Future<void> verificarRegressoesPersistencia(BancoDados banco) async {
  final db = await banco.database;
  final contas = ContasBanco(Future.value(db));
  await contas.salvar(
    const ContaOrigem(nome: 'Regressão origem', bancoCodigo: '001'),
  );
  await contas.salvar(
    const ContaOrigem(nome: 'Regressão destino', bancoCodigo: '260'),
  );
  final origem = (await contas.listar()).firstWhere(
    (c) => c.nome == 'Regressão origem',
  );
  final destino = (await contas.listar()).firstWhere(
    (c) => c.nome == 'Regressão destino',
  );
  Movimentacao movimento(
    TipoMovimentacao tipo,
    int? conta, {
    double valor = 25,
  }) => Movimentacao(
    tipo: tipo,
    contaId: conta,
    valor: valor,
    categoria: 'Outros',
    descricao: 'Regressão',
    data: DateTime(2026, 9, 28),
  );
  final saida = await banco.inserir(
    movimento(TipoMovimentacao.despesa, origem.id),
  );
  final entrada = await banco.inserir(
    movimento(TipoMovimentacao.receita, destino.id),
  );
  await OperacoesFinanceiras(Future.value(db))
      .confirmarTransferencia(saida, entrada);
  await contas.excluir(origem.id!);
  final par = (await banco.listar())
      .where((m) => m.id == saida || m.id == entrada)
      .toList();
  expect(
    par.every((m) => m.transferencia && !m.contabilizavel),
    true,
    reason: 'Excluir somente cadastro não pode transformar transferência em receita/despesa',
  );
  expect(par.firstWhere((m) => m.id == saida).contaId, isNull);

  for (final valor in [
    double.nan,
    double.infinity,
    double.negativeInfinity,
    1e308,
    0.0,
    -1.0,
  ]) {
    await expectLater(
      banco.inserir(movimento(TipoMovimentacao.despesa, null, valor: valor)),
      throwsArgumentError,
    );
    await expectLater(
      banco.atualizar(
        movimento(
          TipoMovimentacao.despesa,
          null,
          valor: valor,
        ).copyWith(id: saida),
      ),
      throwsArgumentError,
    );
  }
  await expectLater(
    banco.atualizar(
      movimento(TipoMovimentacao.despesa, null).copyWith(id: 999999),
    ),
    throwsStateError,
  );

  await contas.salvar(
    const ContaOrigem(nome: 'Regressão mesclar', bancoCodigo: '001'),
  );
  final mesclar = (await contas.listar()).firstWhere(
    (c) => c.nome == 'Regressão mesclar',
  );
  final s2 = await banco.inserir(
    movimento(TipoMovimentacao.despesa, mesclar.id),
  );
  final e2 = await banco.inserir(
    movimento(TipoMovimentacao.receita, destino.id),
  );
  await OperacoesFinanceiras(Future.value(db)).confirmarTransferencia(s2, e2);
  await contas.reunir(mesclar.id!, destino);
  expect(
    (await banco.listar())
        .where((m) => m.id == s2 || m.id == e2)
        .every((m) => m.transferencia),
    true,
  );

  final categoria = Categoria(
    id: await banco.inserirCategoria(
      const Categoria(
        nome: 'Regressão categoria',
        tipo: TipoMovimentacao.despesa,
        codigoIcone: 0,
        codigoCor: 0,
      ),
    ),
    nome: 'Regressão categoria',
    tipo: TipoMovimentacao.despesa,
    codigoIcone: 0,
    codigoCor: 0,
  );
  final usado = await banco.inserir(
    movimento(
      TipoMovimentacao.despesa,
      null,
    ).copyWith(categoria: categoria.nome),
  );
  await expectLater(
    banco.excluirCategoria(
      categoria: categoria,
      destino: const Categoria(
        id: 999999,
        nome: 'Não existe',
        tipo: TipoMovimentacao.despesa,
        codigoIcone: 0,
        codigoCor: 0,
      ),
    ),
    throwsStateError,
  );
  expect(
    (await db.query(
      'movimentacoes',
      where: 'id = ?',
      whereArgs: [usado],
    )).single['categoria'],
    categoria.nome,
  );
  await banco.salvarRegraImportacao(
    texto: 'regressão',
    tipo: categoria.tipo,
    categoriaId: categoria.id!,
  );
  final outra = (await banco.listarCategorias()).firstWhere(
    (c) => c.tipo == categoria.tipo && c.nome == 'Outros',
  );
  await banco.excluirCategoria(categoria: categoria, destino: outra);
  expect(
    (await banco.listarRegrasImportacao()).firstWhere(
      (r) => r['texto'] == 'regressão',
    )['categoria_id'],
    outra.id,
  );

  await AgendaBanco(Future.value(db)).salvar(
    titulo: 'Regressão agenda',
    tipo: 'despesa',
    centavos: 1234,
    categoria: 'Outros',
    data: DateTime(2026, 9, 28),
    frequencia: 'mensal',
    quantidade: 3,
    lembrete: 0,
    hora: 8,
    minuto: 0,
  );
  await banco.restaurarAplicativo();
  for (final tabela in [
    'agenda',
    'movimentacoes',
    'importacoes',
    'contas',
    'preferencias',
    'regras_importacao',
    'lixeira',
  ]) {
    expect(
      await db.query(tabela),
      isEmpty,
      reason: 'Restaurar o perfil precisa limpar $tabela na mesma transação',
    );
  }
  expect(await banco.listarCategorias(), isNotEmpty);
}
