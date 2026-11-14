String normalizarCsv(String texto) {
  var resultado = texto.trim().toLowerCase().replaceAll('\ufeff', '');
  const grupos = {
    'a': 'áàâãä',
    'e': 'éèêë',
    'i': 'íìîï',
    'o': 'óòôõö',
    'u': 'úùûü',
    'c': 'ç',
  };
  for (final grupo in grupos.entries) {
    resultado = resultado.replaceAll(RegExp('[${grupo.value}]'), grupo.key);
  }
  return resultado.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

class LinhaCsv {
  const LinhaCsv(this.numero, this.celulas);
  final int numero;
  final List<String> celulas;
  bool get vazia => celulas.every((c) => c.trim().isEmpty);
}

/// Leitura estrita, incluindo aspas escapadas e campos multilinha.
List<LinhaCsv> separarCsv(String conteudo, String separador) {
  final texto = conteudo
      .replaceFirst(RegExp('^\ufeff'), '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  final linhas = <LinhaCsv>[];
  var campos = <String>[];
  var campo = StringBuffer();
  var aspas = false, fechado = false;
  var numero = 1, inicio = 1;
  for (var i = 0; i < texto.length; i++) {
    final c = texto[i];
    if (aspas) {
      if (c == '"') {
        if (i + 1 < texto.length && texto[i + 1] == '"') {
          campo.write('"');
          i++;
        } else {
          aspas = false;
          fechado = true;
        }
      } else {
        campo.write(c);
        if (c == '\n') numero++;
      }
    } else if (c == separador || c == '\n') {
      campos.add(campo.toString().trim());
      campo = StringBuffer();
      fechado = false;
      if (c == '\n') {
        linhas.add(LinhaCsv(inicio, campos));
        campos = [];
        inicio = ++numero;
      }
    } else if (c == '"' && campo.toString().trim().isEmpty && !fechado) {
      campo = StringBuffer();
      aspas = true;
    } else if ((fechado && c.trim().isNotEmpty) || c == '"') {
      throw FormatException('Aspas ou separador inválidos na linha $numero.');
    } else if (!fechado) {
      campo.write(c);
    }
  }
  if (aspas) {
    throw FormatException(
      'Campo entre aspas não foi fechado na linha $inicio.',
    );
  }
  campos.add(campo.toString().trim());
  if (campos.length > 1 || campos.single.isNotEmpty) {
    linhas.add(LinhaCsv(inicio, campos));
  }
  return linhas;
}

class MapeamentoCsv {
  const MapeamentoCsv({
    required this.cabecalho,
    required this.data,
    required this.descricao,
    this.valor,
    this.debito,
    this.credito,
    this.tipo,
    this.detalhes,
    this.documento,
    this.formatoData = 'dma',
    this.decimal = 'auto',
    this.possuiCabecalho = true,
  });
  final int cabecalho, data, descricao;
  final int? valor, debito, credito, tipo, detalhes, documento;
  final String formatoData, decimal;
  final bool possuiCabecalho;
  int get inicioDados => cabecalho + (possuiCabecalho ? 1 : 0);
  bool get completo => valor != null || (debito != null && credito != null);
}

const aliasesData = [
  'data',
  'date',
  'data da transacao',
  'data transacao',
  'data lancamento',
  'data de lancamento',
  'dt lancamento',
];
const aliasesDescricao = [
  'descricao',
  'description',
  'title',
  'titulo',
  'estabelecimento',
  'lancamento',
  'historico',
  'memo',
];
const aliasesValor = [
  'valor',
  'amount',
  'value',
  'quantia',
  'valor r',
  'valor da transacao',
  'valor lancamento',
];
int? colunaCsv(List<String> cabecalho, List<String> nomes) {
  final encontrados = <int>[];
  for (var i = 0; i < cabecalho.length; i++) {
    if (nomes.contains(normalizarCsv(cabecalho[i]))) encontrados.add(i);
  }
  return encontrados.length == 1 ? encontrados.single : null;
}

int? _colunaPrioritariaCsv(List<String> cabecalho, List<String> nomes) {
  final unica = colunaCsv(cabecalho, nomes);
  if (unica != null) return unica;
  for (final nome in nomes) {
    final indice = colunaCsv(cabecalho, [nome]);
    if (indice != null) return indice;
  }
  return null;
}

class DocumentoCsv {
  const DocumentoCsv(this.linhas, this.separador, this.sugestao);
  final List<LinhaCsv> linhas;
  final String separador;
  final MapeamentoCsv? sugestao;
  static DocumentoCsv detectar(String texto, {String? separador}) {
    DocumentoCsv? melhor;
    var melhorNota = -1;
    for (final delimitador
        in separador == null ? [';', ',', '\t', '|'] : [separador]) {
      List<LinhaCsv> linhas;
      try {
        linhas = separarCsv(texto, delimitador);
      } on FormatException {
        continue;
      }
      var nota = linhas.isEmpty
          ? 0
          : linhas
                .map((l) => l.celulas.length)
                .reduce((a, b) => a > b ? a : b)
                .clamp(0, 10);
      MapeamentoCsv? sugestao;
      for (var i = 0; i < linhas.length && i < 100; i++) {
        final c = linhas[i].celulas;
        final data = colunaCsv(c, aliasesData);
        final descricao =
            colunaCsv(c, ['descricao', 'description']) ??
            _colunaPrioritariaCsv(c, const [
              'lancamento',
              'titulo',
              'title',
              'estabelecimento',
              'historico',
              'memo',
            ]);
        final valor = colunaCsv(c, aliasesValor);
        final debito = colunaCsv(c, ['debito', 'debitos', 'saida', 'saidas']);
        final credito = colunaCsv(c, [
          'credito',
          'creditos',
          'entrada',
          'entradas',
        ]);
        if (data != null &&
            descricao != null &&
            (valor != null || (debito != null && credito != null))) {
          sugestao = MapeamentoCsv(
            cabecalho: i,
            data: data,
            descricao: descricao,
            valor: valor,
            debito: debito,
            credito: credito,
            tipo: colunaCsv(c, [
              'tipo',
              'tipo lancamento',
              'natureza',
              'c d',
              'd c',
            ]),
            detalhes: colunaCsv(c, ['detalhes', 'historico']) == descricao
                ? null
                : colunaCsv(c, ['detalhes', 'historico']),
            documento: colunaCsv(c, [
              'documento',
              'n documento',
              'numero documento',
              'identificador',
              'id',
            ]),
          );
          nota += 100;
          break;
        }
      }
      if (nota > melhorNota) {
        melhorNota = nota;
        melhor = DocumentoCsv(linhas, delimitador, sugestao);
      }
    }
    if (melhor == null) {
      throw const FormatException(
        'O CSV contém aspas inválidas. Exporte o arquivo novamente.',
      );
    }
    return melhor;
  }
}
