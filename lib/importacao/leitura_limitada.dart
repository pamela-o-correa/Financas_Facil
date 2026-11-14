import 'dart:typed_data';

const limiteArquivoCsv = 10 * 1024 * 1024;

/// O await-for cancela a assinatura se o limite for excedido ou houver erro.
Future<Uint8List> lerBytesLimitados(
  Stream<List<int>> fluxo, {
  int limite = limiteArquivoCsv,
}) async {
  if (limite < 0) throw ArgumentError.value(limite, 'limite');
  final dados = BytesBuilder(copy: false);
  await for (final parte in fluxo) {
    if (dados.length + parte.length > limite) {
      throw const FormatException(
        'O arquivo selecionado excede o limite de 10 MB.',
      );
    }
    dados.add(parte);
  }
  return dados.takeBytes();
}
