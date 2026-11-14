/// Limite que mantém centavos inteiros representáveis também em plataformas web.
const maximoCentavosExatos = 9007199254740991;

int centavosDeValor(num valor) {
  final escalado = valor * 100;
  if (!valor.isFinite ||
      !escalado.isFinite ||
      escalado.abs() > maximoCentavosExatos) {
    throw ArgumentError('Informe um valor dentro do limite suportado.');
  }
  return escalado.round();
}
