/// Lê datas persistidas sem normalizar dias, meses ou horários inválidos.
/// Aceita ISO 8601 e o formato brasileiro usado nos relatórios antigos.
DateTime? dataRegistro(String texto) {
  final valor = texto.trim();
  final br = RegExp(r'^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})$')
      .firstMatch(valor);
  final iso = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})(?:[Tt ](\d{2}):(\d{2})(?::(\d{2})(?:[.,]\d+)?)?(?: ?([Zz]|[+-]\d{2}(?::?\d{2})?))?)?$',
  ).firstMatch(valor);
  if (br == null && iso == null) return null;
  final ano = int.parse(br?[3] ?? iso![1]!);
  final mes = int.parse(br?[2] ?? iso![2]!);
  final dia = int.parse(br?[1] ?? iso![3]!);
  if (ano < 1 || mes < 1 || mes > 12 || dia < 1 || dia > 31) return null;
  final calendario = DateTime(ano, mes, dia);
  if (calendario.year != ano ||
      calendario.month != mes ||
      calendario.day != dia) {
    return null;
  }
  if (br != null) return calendario;
  if (int.parse(iso![4] ?? '0') > 23 ||
      int.parse(iso[5] ?? '0') > 59 ||
      int.parse(iso[6] ?? '0') > 59) {
    return null;
  }
  final fuso = iso[7];
  if (fuso != null && fuso.length > 1) {
    final numeros = fuso.substring(1).replaceAll(':', '');
    if (int.parse(numeros.substring(0, 2)) > 23 ||
        (numeros.length > 2 && int.parse(numeros.substring(2)) > 59)) {
      return null;
    }
  }
  return DateTime.tryParse(valor);
}
