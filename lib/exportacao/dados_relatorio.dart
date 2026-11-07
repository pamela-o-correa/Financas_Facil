import '../modelos/contabilizacao.dart';

String dataIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String dataBr(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
String moeda(int centavos) {
  final partes = (centavos.abs() / 100).toStringAsFixed(2).split('.');
  final inteiro = partes[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]}.',
  );
  return '${centavos < 0 ? '-' : ''}R\$ $inteiro,${partes[1]}';
}

class FiltroRelatorio {
  const FiltroRelatorio({
    this.inicio,
    this.fim,
    this.tipo,
    this.conta,
    this.contaRotulo,
    this.categoria,
    this.origem = 'movimentacoes',
  });
  final DateTime? inicio, fim;
  final String? tipo, conta, contaRotulo, categoria;
  final String origem;
  bool aceita(LinhaRelatorio l) =>
      (inicio == null ||
          !l.data.isBefore(
            DateTime(inicio!.year, inicio!.month, inicio!.day),
          )) &&
      (fim == null ||
          l.data.isBefore(DateTime(fim!.year, fim!.month, fim!.day + 1))) &&
      (tipo == null || l.tipo == tipo) &&
      (conta == null || l.chaveConta == conta) &&
      (categoria == null || l.categoria == categoria) &&
      (origem == 'ambos' || (origem == 'agenda') == l.prevista);
  String get periodo => inicio == null
      ? 'Todo o período'
      : '${dataBr(inicio!)} a ${dataBr(fim!)}';
  String get descricao => [
    periodo,
    tipo == null
        ? 'Receitas e despesas'
        : tipo == 'receita'
        ? 'Apenas receitas'
        : 'Apenas despesas',
    if (conta != null) 'Conta: ${contaRotulo ?? conta}',
    if (categoria != null) 'Categoria: $categoria',
    origem == 'agenda'
        ? 'Previsões da agenda'
        : origem == 'ambos'
        ? 'Realizadas e previstas'
        : 'Movimentações realizadas',
  ].join(' • ');
}

class LinhaRelatorio {
  LinhaRelatorio({
    required this.perfil,
    required this.dados,
    this.prevista = false,
  }) {
    final valor = dados[prevista ? 'centavos' : 'valor'];
    if (valor is! num || !valor.isFinite) {
      throw const FormatException('Valor financeiro inválido.');
    }
    centavos = prevista ? valor.round() : (valor * 100).round();
    data = DateTime.parse(dados['data'] as String);
  }
  final String perfil;
  final Map<String, Object?> dados;
  final bool prevista;
  late final int centavos;
  late final DateTime data;
  String get tipo => dados['tipo'] as String;
  String get descricao =>
      (dados[prevista ? 'titulo' : 'descricao'] ?? '').toString();
  String get categoria => (dados['categoria'] ?? 'Sem categoria').toString();
  String get conta =>
      (dados['conta_nome'] ?? dados['conta'] ?? 'Sem conta identificada')
          .toString();
  String get chaveConta =>
      dados['conta_id'] != null ? 'id:${dados['conta_id']}' : 'nome:$conta';
  String get rotuloConta =>
      dados['banco_nome'] == null ? conta : '$conta (${dados['banco_nome']})';
  bool get ativa => dados['ativa'] != 0;
  bool get transferencia => dados['transferencia_par'] != null;
  bool get contabilizavel =>
      !prevista && deveContabilizar(ativa: ativa, transferencia: transferencia);
  String get status => prevista
      ? {
              'pendente': 'Pendente',
              'realizado': 'Realizado',
              'cancelado': 'Cancelado',
            }[dados['status']] ??
            'Pendente'
      : 'Realizado';
  String get contabilizacao => prevista
      ? 'Previsão - fora dos totais realizados'
      : !ativa
      ? 'Desativada'
      : transferencia
      ? 'Transferência interna'
      : 'Ativa';
}

class GrupoCategoria {
  GrupoCategoria(this.nome);
  final String nome;
  int quantidade = 0, total = 0;
}

class PontoEvolucao {
  PontoEvolucao(this.rotulo);
  final String rotulo;
  int receitas = 0, despesas = 0;
}

class DadosRelatorio {
  DadosRelatorio({
    required this.perfil,
    required this.filtro,
    required List<LinhaRelatorio> linhas,
    DateTime? geradoEm,
  }) : linhas = List.unmodifiable(
         linhas.where(filtro.aceita).toList()
           ..sort((a, b) => a.data.compareTo(b.data)),
       ),
       geradoEm = geradoEm ?? DateTime.now();
  final String perfil;
  final FiltroRelatorio filtro;
  final List<LinhaRelatorio> linhas;
  final DateTime geradoEm;
  List<LinhaRelatorio> get financeiras =>
      linhas.where((l) => l.contabilizavel).toList();
  int get receitas => financeiras
      .where((l) => l.tipo == 'receita')
      .fold(0, (s, l) => s + l.centavos);
  int get despesas => financeiras
      .where((l) => l.tipo == 'despesa')
      .fold(0, (s, l) => s + l.centavos);
  int get saldo => receitas - despesas;
  double? get taxaEconomia => receitas > 0 ? saldo / receitas * 100 : null;
  List<GrupoCategoria> get categorias {
    final grupos = <String, GrupoCategoria>{};
    for (final l in financeiras.where((l) => l.tipo == 'despesa')) {
      final g = grupos.putIfAbsent(
        l.categoria,
        () => GrupoCategoria(l.categoria),
      );
      g.quantidade++;
      g.total += l.centavos;
    }
    return grupos.values.toList()..sort((a, b) => b.total.compareTo(a.total));
  }

  List<LinhaRelatorio> get maiores =>
      (financeiras.where((l) => l.tipo == 'despesa').toList()
            ..sort((a, b) => b.centavos.compareTo(a.centavos)))
          .take(5)
          .toList();
  List<PontoEvolucao> get evolucao {
    final base = financeiras;
    if (base.isEmpty) return [];
    final ini = filtro.inicio ?? base.first.data,
        fim = filtro.fim ?? base.last.data;
    final diario = ini.year == fim.year && ini.month == fim.month;
    final grupos = <String, PontoEvolucao>{};
    for (final l in base) {
      final chave = dataIso(l.data).substring(0, diario ? 10 : 7);
      final g = grupos.putIfAbsent(
        chave,
        () => PontoEvolucao(
          diario
              ? dataBr(l.data)
              : '${l.data.month.toString().padLeft(2, '0')}/${l.data.year}',
        ),
      );
      if (l.tipo == 'receita') {
        g.receitas += l.centavos;
      } else {
        g.despesas += l.centavos;
      }
    }
    return grupos.length < 2 ? [] : grupos.values.toList();
  }

  String nomeArquivo(String extensao) {
    final periodo = filtro.inicio == null
        ? 'todo_periodo'
        : '${dataIso(filtro.inicio!)}_${dataIso(filtro.fim!)}';
    return '${extensao == 'pdf' ? 'relatorio_' : ''}financas_facil_${periodo}_${geradoEm.microsecondsSinceEpoch}.$extensao';
  }
}
