part of 'main.dart';

String _tituloDiaCalendario(DateTime dia) {
  const semana = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];
  const meses = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];
  return '${semana[dia.weekday - 1]}, ${dia.day} de ${meses[dia.month - 1]}';
}

class _ResumoCalendario extends StatelessWidget {
  const _ResumoCalendario({
    required this.receber,
    required this.pagar,
    required this.cores,
  });
  final int receber, pagar;
  final ColorScheme cores;
  @override
  Widget build(BuildContext context) {
    final semantica = CoresSemanticas.de(context);
    final saldoPrevisto = receber - pagar;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cores.surfaceContainerLow,
        borderRadius: BorderRadius.circular(RaioBorda.cartao),
        border: Border.all(color: cores.outlineVariant.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Resumo do mês',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              Tooltip(
                message:
                    'Inclui compromissos pagos e em aberto; exclui cancelados. '
                    'Previsões só alteram o saldo real após confirmação.',
                triggerMode: TooltipTriggerMode.tap,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Icon(
                    Icons.info_outline,
                    size: 17,
                    color: cores.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, limites) {
              final empilhar =
                  limites.maxWidth < 265 ||
                  MediaQuery.textScalerOf(context).scale(12) > 17;
              final itens = [
                (
                  'Receitas previstas',
                  receber,
                  Icons.north_east,
                  semantica.receita,
                ),
                (
                  'Despesas previstas',
                  pagar,
                  Icons.south_east,
                  semantica.despesa,
                ),
                (
                  'Saldo previsto',
                  saldoPrevisto,
                  Icons.account_balance_wallet_outlined,
                  saldoPrevisto < 0 ? semantica.despesa : cores.primary,
                ),
              ];
              Widget bloco((String, int, IconData, Color) item) => Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cores.surface,
                  borderRadius: BorderRadius.circular(RaioBorda.sm),
                  border: Border.all(
                    color: cores.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                child: empilhar
                    ? Row(
                        children: [
                          Icon(item.$3, size: 18, color: item.$4),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              item.$1,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              dinheiroAgenda(item.$2),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: item.$4,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 24,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(item.$3, size: 16, color: item.$4),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    item.$1,
                                    style: TextStyle(
                                      fontSize: 10,
                                      height: 1.1,
                                      color: cores.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              dinheiroAgenda(item.$2),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: item.$4,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              );
              if (empilhar) {
                return Column(
                  children: [
                    for (final item in itens)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: bloco(item),
                      ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < itens.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(child: bloco(itens[i])),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _IconeCategoriaCalendario extends StatelessWidget {
  const _IconeCategoriaCalendario({
    required this.item,
    this.categoria,
    this.tamanho = 34,
  });
  final Previsto item;
  final Categoria? categoria;
  final double tamanho;
  @override
  Widget build(BuildContext context) {
    final semantica = CoresSemanticas.de(context);
    final cor =
        categoria?.cor ??
        (item.receita ? semantica.receita : semantica.despesa);
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        color: cor.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(
        categoria?.icone ?? Icons.category_outlined,
        size: tamanho * .58,
        color: cor,
      ),
    );
  }
}

class _StatusCalendario extends StatelessWidget {
  const _StatusCalendario({required this.item, this.resumo = false});
  final Previsto item;
  final bool resumo;
  @override
  Widget build(BuildContext context) {
    final semantica = CoresSemanticas.de(context);
    final esquema = Theme.of(context).colorScheme;
    final hoje = diaAgenda(DateTime.now());
    final vencido = item.pendente && item.data.isBefore(hoje);
    final (Color fundo, Color texto) = vencido && !resumo
        ? (semantica.despesaFundo, semantica.despesa)
        : item.pendente
        ? (semantica.alertaFundo, semantica.alerta)
        : item.status == 'realizado'
        ? (semantica.receitaFundo, semantica.receita)
        : (esquema.surfaceContainerHighest, esquema.onSurfaceVariant);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: texto.withValues(alpha: 0.24)),
      ),
      child: Text(
        resumo && item.pendente
            ? 'Pendente'
            : item.rotuloStatus(DateTime.now()),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: texto,
        ),
      ),
    );
  }
}

class _CompromissoDiaCalendario extends StatelessWidget {
  const _CompromissoDiaCalendario({
    required this.item,
    required this.cores,
    required this.menu,
    required this.onDetalhes,
    required this.onRealizar,
    this.categoria,
  });
  final Previsto item;
  final Categoria? categoria;
  final ColorScheme cores;
  final Widget menu;
  final VoidCallback onDetalhes;
  final VoidCallback? onRealizar;
  @override
  Widget build(BuildContext context) {
    final semantica = CoresSemanticas.de(context);
    final corValor = item.receita ? semantica.receita : cores.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cores.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RaioBorda.md),
          side: BorderSide(color: cores.outlineVariant.withValues(alpha: 0.55)),
        ),
        child: InkWell(
          onTap: onDetalhes,
          borderRadius: BorderRadius.circular(RaioBorda.md),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
            child: LayoutBuilder(
              builder: (context, limites) {
                final ampliado =
                    MediaQuery.textScalerOf(context).scale(12) > 17 ||
                    limites.maxWidth < 280;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _IconeCategoriaCalendario(
                          item: item,
                          categoria: categoria,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.titulo,
                                      maxLines: ampliado ? 2 : 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (!ampliado) ...[
                                    const SizedBox(width: 6),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 118,
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          dinheiroAgenda(item.centavos),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: corValor,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${item.categoria} • ${item.receita ? 'Receita' : 'Despesa'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cores.onSurfaceVariant,
                                ),
                              ),
                              if (ampliado)
                                Text(
                                  dinheiroAgenda(item.centavos),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: corValor,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(width: 32, height: 34, child: menu),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 7,
                            runSpacing: 3,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _StatusCalendario(item: item),
                              if (item.frequencia != 'unica')
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.repeat,
                                      size: 11,
                                      color: cores.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        item.rotuloFrequencia,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: cores.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        if (item.pendente) ...[
                          const SizedBox(width: 5),
                          Flexible(
                            child: TextButton(
                              onPressed: onRealizar,
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 28),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                item.receita
                                    ? 'Marcar recebido'
                                    : 'Marcar pago',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _VencimentoCalendario extends StatelessWidget {
  const _VencimentoCalendario({
    required this.item,
    required this.cores,
    required this.onTap,
    this.categoria,
  });
  final Previsto item;
  final ColorScheme cores;
  final Categoria? categoria;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final semantica = CoresSemanticas.de(context);
    final corValor = item.receita ? semantica.receita : cores.onSurface;
    const meses = [
      'jan',
      'fev',
      'mar',
      'abr',
      'mai',
      'jun',
      'jul',
      'ago',
      'set',
      'out',
      'nov',
      'dez',
    ];
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: cores.outlineVariant.withValues(alpha: .5),
            ),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, limites) {
            final ampliado =
                MediaQuery.textScalerOf(context).scale(12) > 17 ||
                limites.maxWidth < 275;
            return Row(
              children: [
                SizedBox(
                  width: ampliado ? 45 : 38,
                  child: Text(
                    '${item.data.day.toString().padLeft(2, '0')} ${meses[item.data.month - 1]}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: cores.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (!ampliado) ...[
                  _IconeCategoriaCalendario(
                    item: item,
                    categoria: categoria,
                    tamanho: 28,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        item.categoria,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: cores.onSurfaceVariant,
                        ),
                      ),
                      if (ampliado)
                        Text(
                          dinheiroAgenda(item.centavos),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: corValor,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (!ampliado)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              dinheiroAgenda(item.centavos),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: corValor,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 3),
                        _StatusCalendario(item: item, resumo: true),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
