part of 'main.dart';

enum AgrupamentoDespesa {
  categoria('Por categoria'),
  banco('Por banco'),
  conta('Por conta');

  const AgrupamentoDespesa(this.rotulo);
  final String rotulo;
}

class GrupoDespesa {
  GrupoDespesa(this.chave, this.nome);
  final String chave;
  String nome;
  final List<Movimentacao> itens = [];
  int get totalCentavos => itens.fold<int>(0, (s, m) => s + m.centavos);
  double get total => totalCentavos / 100;
}

List<GrupoDespesa> agruparDespesas(
  List<Movimentacao> movimentos,
  List<ContaOrigem> contas,
  AgrupamentoDespesa modo,
) {
  final porId = {for (final c in contas) c.id: c};
  final grupos = <String, GrupoDespesa>{};
  for (final m in movimentos.where(
    (m) => m.contabilizavel && m.tipo == TipoMovimentacao.despesa,
  )) {
    final conta = m.contaId == null ? null : porId[m.contaId];
    final String chave;
    final String nome;
    switch (modo) {
      case AgrupamentoDespesa.categoria:
        chave = m.categoria;
        nome = m.categoria;
      case AgrupamentoDespesa.banco:
        chave = conta == null ? 'sem-conta' : 'banco:${conta.bancoCodigo}';
        nome = conta?.bancoNome ?? 'Sem conta identificada';
      case AgrupamentoDespesa.conta:
        chave = conta == null ? 'sem-conta' : 'conta:${conta.id}';
        nome = conta?.rotulo ?? 'Sem conta identificada';
    }
    (grupos[chave] ??= GrupoDespesa(chave, nome)).itens.add(m);
  }
  final nomes = <String>{};
  for (final grupo in grupos.values) {
    while (!nomes.add(grupo.nome)) {
      grupo.nome = '${grupo.nome} (${grupo.chave})';
    }
  }
  return grupos.values.toList()..sort((a, b) {
    final ordem = b.total.compareTo(a.total);
    return ordem == 0 ? a.chave.compareTo(b.chave) : ordem;
  });
}

class GraficoDespesasAlternavel extends StatelessWidget {
  const GraficoDespesasAlternavel({
    super.key,
    this.periodo = 'Todo o período',
    required this.movimentos,
    required this.contas,
    required this.coresCategorias,
    required this.modo,
    required this.onModo,
    this.compacto = false,
    this.onVerTudo,
  });
  final String periodo;
  final List<Movimentacao> movimentos;
  final List<ContaOrigem> contas;
  final Map<String, Color> coresCategorias;
  final AgrupamentoDespesa modo;
  final ValueChanged<AgrupamentoDespesa> onModo;
  final bool compacto;
  final VoidCallback? onVerTudo;

  @override
  Widget build(BuildContext context) {
    final grupos = agruparDespesas(movimentos, contas, modo);
    final visiveis = compacto ? grupos.take(4).toList() : grupos;
    final totais = visiveis.map((g) => MapEntry(g.nome, g.total)).toList();
    String restante = 'Demais grupos';
    while (grupos.any((g) => g.nome == restante)) {
      restante = '$restante •';
    }
    if (compacto && grupos.length > 4) {
      final restanteCentavos = grupos
          .skip(4)
          .fold<int>(0, (s, g) => s + g.totalCentavos);
      totais.add(MapEntry(restante, restanteCentavos / 100));
    }
    final paleta = CoresSemanticas.de(context).paletaGrafico;
    Color cor(GrupoDespesa grupo) {
      if (modo == AgrupamentoDespesa.categoria) {
        return coresCategorias[grupo.nome] ?? paleta.last;
      }
      final indice = grupo.chave.codeUnits.fold(
        0,
        (s, c) => (s * 31 + c) % paleta.length,
      );
      return paleta[indice];
    }

    final totalGeralCentavos = grupos.fold<int>(
      0,
      (s, g) => s + g.totalCentavos,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final opcao in AgrupamentoDespesa.values)
              ChoiceChip(
                label: Text(opcao.rotulo),
                selected: modo == opcao,
                onSelected: (_) => onModo(opcao),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (grupos.isEmpty)
          const EstadoVazio(
            icone: Icons.pie_chart_outline,
            titulo: 'Sem despesas',
            subtitulo: 'Não há despesas no período selecionado.',
          )
        else
          GraficoRoscaCategorias(
            totais: totais,
            total: totalGeralCentavos / 100,
            cores: {
              for (final g in grupos) g.nome: cor(g),
              restante: paleta.last,
            },
            onCategoria: (nome) {
              if (nome == restante) {
                onVerTudo?.call();
                return;
              }
              final grupo = grupos.firstWhere((g) => g.nome == nome);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TelaDetalhesCategoria(
                    categoria: grupo.nome,
                    periodo: periodo,
                    agrupamento: modo.rotulo,
                    movimentacoes: grupo.itens,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
