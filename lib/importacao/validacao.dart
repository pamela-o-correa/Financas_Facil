import 'csv_documento.dart';

DateTime? dataCsv(String texto, {String formato = 'dma'}) {
  final iso = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2})(?::(\d{2}))?)?$',
  ).firstMatch(texto.trim());
  int dia, mes, ano;
  if (iso != null) {
    ano = int.parse(iso[1]!);
    mes = int.parse(iso[2]!);
    dia = int.parse(iso[3]!);
    if (int.parse(iso[4] ?? '0') > 23 ||
        int.parse(iso[5] ?? '0') > 59 ||
        int.parse(iso[6] ?? '0') > 59) {
      return null;
    }
  } else {
    final padrao = formato == 'amd'
        ? r'^(\d{4})[/.\-](\d{1,2})[/.\-](\d{1,2})$'
        : r'^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})$';
    final m = RegExp(padrao).firstMatch(texto.trim());
    if (m == null) return null;
    final p = [int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!)];
    ano = formato == 'amd' ? p[0] : p[2];
    mes = formato == 'mda' ? p[0] : p[1];
    dia = formato == 'amd'
        ? p[2]
        : formato == 'mda'
        ? p[1]
        : p[0];
  }
  if (ano < 1900 || ano > 2200 || mes < 1 || mes > 12 || dia < 1 || dia > 31) {
    return null;
  }
  final data = DateTime(ano, mes, dia);
  return data.day == dia && data.month == mes && data.year == ano ? data : null;
}

int? centavosCsv(String texto, {String decimal = ','}) {
  var t = texto
      .trim()
      .replaceAll('\u00a0', ' ')
      .replaceAll(RegExp(r'^R\$\s*'), '')
      .trim();
  var negativo = false;
  if (t.startsWith('(') && t.endsWith(')')) {
    negativo = true;
    t = t.substring(1, t.length - 1).trim();
  }
  final sufixo = RegExp(r'\s*([CD])$', caseSensitive: false).firstMatch(t);
  if (sufixo != null) {
    if (negativo && sufixo[1]!.toUpperCase() == 'C') return null;
    negativo = sufixo[1]!.toUpperCase() == 'D';
    t = t.substring(0, sufixo.start).trim();
  }
  if (t.startsWith('-')) {
    if (sufixo != null && !negativo) return null;
    negativo = true;
    t = t.substring(1);
  } else if (t.startsWith('+')) {
    if (negativo) return null;
    t = t.substring(1);
  }
  if (t.endsWith('-')) {
    if (sufixo != null && sufixo[1]!.toUpperCase() == 'C') return null;
    negativo = true;
    t = t.substring(0, t.length - 1);
  }
  final milhar = decimal == ',' ? '.' : ',';
  final d = RegExp.escape(decimal), m = RegExp.escape(milhar);
  if (!RegExp('^(?:[0-9]+|[0-9]{1,3}(?:$m[0-9]{3})+)(?:$d[0-9]{1,2})?\$')
      .hasMatch(t)) {
    return null;
  }
  final partes = t.replaceAll(milhar, '').split(decimal);
  final inteiro = int.tryParse(partes[0]);
  if (inteiro == null || inteiro > 999999999999) return null;
  final valor =
      inteiro * 100 +
      (partes.length == 1 ? 0 : int.parse(partes[1].padRight(2, '0')));
  return negativo ? -valor : valor;
}

int? sinalTipo(String tipo) {
  final t = normalizarCsv(tipo);
  if (['d', 'debito', 'saida', 'despesa', 'debit'].contains(t)) return -1;
  if (['c', 'credito', 'entrada', 'receita', 'credit'].contains(t)) return 1;
  return null;
}

bool linhaDeSaldo(String texto) {
  final t = normalizarCsv(texto);
  return RegExp(r'^(saldo|saldos)( |$)').hasMatch(t) ||
      RegExp(
        r'^(total|totais)( (de|do|da|dos|das|geral|credito|debito|entrada|saida|r)( |$)|$)',
      ).hasMatch(t) ||
      t == 's a l d o' ||
      t.startsWith('s a l d o ');
}
