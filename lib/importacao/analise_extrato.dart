import 'package:flutter/foundation.dart';

import 'motor_importacao.dart';

typedef PedidoAnalise = ({
  String texto,
  Map<String, String> categorias,
  String? separador,
  MapeamentoCsv? mapeamento,
});

ResultadoImportacao _analisar(PedidoAnalise pedido) => MotorImportacao.ler(
  pedido.texto,
  pedido.categorias,
  separador: pedido.separador,
  mapeamento: pedido.mapeamento,
);

Future<ResultadoImportacao> analisarExtrato(
  String texto,
  Map<String, String> categorias, {
  String? separador,
  MapeamentoCsv? mapeamento,
}) => compute(_analisar, (
  texto: texto,
  categorias: categorias,
  separador: separador,
  mapeamento: mapeamento,
));
