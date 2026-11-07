import 'item_extrato.dart';
import 'motor_importacao.dart';
export 'motor_importacao.dart';

class LeitorExtrato {
  static List<ItemExtrato> lerCsv(
    String conteudo,
    Map<String, String> categorias,
  ) {
    final resultado = MotorImportacao.ler(conteudo, categorias);
    if (resultado.precisaMapear) {
      throw const FormatException(
        'Não foi possível identificar as colunas. Mapeie o arquivo para continuar.',
      );
    }
    return resultado.itens;
  }
}
