part of 'main.dart';

/// Recebe os totais do mesmo período usado nos demais relatórios.
/// Todas as categorias continuam acessíveis para consultar suas movimentações.
class GraficoRoscaCategorias extends StatelessWidget {
  const GraficoRoscaCategorias({
    super.key,
    required this.totais,
    required this.total,
    required this.cores,
    required this.onCategoria,
  });
  final List<MapEntry<String, double>> totais;
  final double total;
  final Map<String, Color> cores;
  final ValueChanged<String> onCategoria;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final coresFatias = [
      for (final item in totais) cores[item.key] ?? esquema.primary,
    ];
    final legenda = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < totais.length; i++)
          InkWell(
            onTap: () => onCategoria(totais[i].key),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Icon(Icons.circle, size: 10, color: coresFatias[i]),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          totais[i].key,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${(total <= 0 ? 0 : totais[i].value / total * 100).toStringAsFixed(1).replaceAll('.', ',')}% • ${dinheiroAgenda((totais[i].value * 100).round())}',
                          style: TextStyle(
                            fontSize: 12,
                            color: esquema.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
      ),
      child: LayoutBuilder(
        builder: (context, limites) {
          final ladoALado =
              limites.maxWidth >= 300 &&
              MediaQuery.textScalerOf(context).scale(14) <= 18;
          final tamanho = ladoALado
              ? math.min(190.0, limites.maxWidth * .45)
              : math.min(220.0, limites.maxWidth);
          final grafico = Semantics(
            label:
                'Total de despesas: ${dinheiroAgenda((total * 100).round())}. Distribuição na legenda.',
            child: SizedBox(
              width: tamanho,
              height: tamanho,
              child: CustomPaint(
                painter: _PintorRoscaCategorias(
                  valores: totais.map((e) => e.value).toList(),
                  cores: coresFatias,
                  vazio: esquema.outlineVariant,
                ),
                child: Center(
                  child: SizedBox(
                    width: tamanho * .64,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            dinheiroAgenda((total * 100).round()),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Despesas'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          if (ladoALado) {
            return Row(
              children: [
                grafico,
                const SizedBox(width: 16),
                Expanded(child: legenda),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: grafico),
              const SizedBox(height: 16),
              legenda,
            ],
          );
        },
      ),
    );
  }
}

class _PintorRoscaCategorias extends CustomPainter {
  _PintorRoscaCategorias({
    required this.valores,
    required this.cores,
    required this.vazio,
  });
  final List<double> valores;
  final List<Color> cores;
  final Color vazio;
  @override
  void paint(Canvas canvas, Size size) {
    final largura = size.shortestSide * .12;
    final retangulo = (Offset.zero & size).deflate(largura / 2 + 2);
    final pincel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = largura;
    canvas.drawOval(retangulo, pincel..color = vazio);
    final total = valores.fold(0.0, (s, v) => s + v);
    if (total <= 0) return;
    var inicio = -math.pi / 2;
    for (var i = 0; i < valores.length; i++) {
      final angulo = valores[i] / total * 2 * math.pi;
      canvas.drawArc(
        retangulo,
        inicio,
        angulo,
        false,
        pincel..color = cores[i],
      );
      inicio += angulo;
    }
  }

  @override
  bool shouldRepaint(covariant _PintorRoscaCategorias oldDelegate) =>
      oldDelegate.valores != valores ||
      oldDelegate.cores != cores ||
      oldDelegate.vazio != vazio;
}

List<MapEntry<String, double>> totaisCategorias(Iterable<Movimentacao> itens) {
  final totaisCentavos = <String, int>{};
  for (final item in itens.where((m) => m.contabilizavel && m.tipo == TipoMovimentacao.despesa)) {
    totaisCentavos[item.categoria] = (totaisCentavos[item.categoria] ?? 0) + item.centavos;
  }
  return [
    for (final e in totaisCentavos.entries) MapEntry(e.key, e.value / 100),
  ]..sort((a, b) => b.value.compareTo(a.value));
}
