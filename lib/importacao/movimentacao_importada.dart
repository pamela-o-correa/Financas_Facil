import '../modelos/tipo_movimentacao.dart';

/// Modelo único de importação e revisão, com dinheiro em centavos.
class MovimentacaoImportada {
  MovimentacaoImportada({
    required this.data,
    required this.descricao,
    required double valor,
    required this.tipo,
    this.bancoCodigo = 'generico',
    this.documento = '',
    this.linhaOrigem = 0,
    this.categoria = 'Outros',
    this.selecionado = true,
    this.ativa = true,
  }) : centavos = (valor * 100).round();
  final DateTime data;
  final String descricao;
  final int centavos;
  double get valor => centavos / 100;
  final TipoMovimentacao tipo;
  final String bancoCodigo, documento;
  final int linhaOrigem;
  String categoria;
  bool selecionado;
  bool ativa;
  bool? contabilizacaoSugerida;
  bool get possivelInvestimento => RegExp(
    r'\b(aplica[cç][aã]o|resgate)\b(?:\s+(?:de|em|do|da))?\s+(?:rdb|cdb|lci|lca|poupan[cç]a|fundo|fundos|investimento|investimentos)\b',
    caseSensitive: false,
  ).hasMatch(descricao);

  bool possivelDuplicata = false;
  bool conflitoDeRegras = false;
}
