import 'csv_documento.dart';

abstract class AdaptadorExtrato {
  const AdaptadorExtrato();
  String get codigo;
  String get nome;
  bool reconhece(Set<String> colunas);
  String descricao(List<String> linha, MapeamentoCsv mapa) {
    final principal = linha[mapa.descricao].trim();
    final detalhe = mapa.detalhes == null ? '' : linha[mapa.detalhes!].trim();
    if (principal.isEmpty) return detalhe;
    return detalhe.isEmpty || detalhe == principal
        ? principal
        : '$principal - $detalhe';
  }
}

class AdaptadorBancoBrasil extends AdaptadorExtrato {
  const AdaptadorBancoBrasil();
  @override
  String get codigo => '001';
  @override
  String get nome => 'Banco do Brasil';
  @override
  bool reconhece(Set<String> c) => c.containsAll({
    'data',
    'lancamento',
    'detalhes',
    'valor',
    'tipo lancamento',
  });
}

class AdaptadorSicredi extends AdaptadorExtrato {
  const AdaptadorSicredi();
  @override
  String get codigo => '748';
  @override
  String get nome => 'Sicredi';
  @override
  bool reconhece(Set<String> c) => c.containsAll({
    'data',
    'descricao',
    'codtransacao',
    'identificador',
    'tipo',
    'valor',
  });
}

class AdaptadorInter extends AdaptadorExtrato {
  const AdaptadorInter();
  @override
  String get codigo => '077';
  @override
  String get nome => 'Inter';
  @override
  bool reconhece(Set<String> c) => c.containsAll({
    'data lancamento',
    'historico',
    'descricao',
    'valor',
    'saldo',
  });
}

class AdaptadorGenerico extends AdaptadorExtrato {
  const AdaptadorGenerico();
  @override
  String get codigo => 'generico';
  @override
  String get nome => 'Banco não identificado';
  @override
  bool reconhece(Set<String> c) => true;
}

AdaptadorExtrato detectarBanco(List<String> cabecalho) {
  final c = cabecalho.map(normalizarCsv).toSet();
  return const <AdaptadorExtrato>[
    AdaptadorBancoBrasil(),
    AdaptadorSicredi(),
    AdaptadorInter(),
    AdaptadorGenerico(),
  ].firstWhere((a) => a.reconhece(c));
}
