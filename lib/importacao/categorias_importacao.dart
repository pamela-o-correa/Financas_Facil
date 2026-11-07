import '../modelos/tipo_movimentacao.dart';

String sugerirCategoria(String descricao, TipoMovimentacao tipo) {
  final texto = descricao.toLowerCase();

  if (tipo == TipoMovimentacao.receita) {
    if (texto.contains('salario') ||
        texto.contains('salário') ||
        texto.contains('folha de pagamento')) {
      return 'Salário';
    }

    return 'Outros';
  }

  // TRANSPORTE
  if (texto.contains('uber') ||
      texto.contains('99 tecnologia') ||
      texto.contains('99app') ||
      texto.contains('99 app')) {
    return 'Transporte';
  }

  // DELIVERY
  if (texto.contains('ifood') ||
      texto.contains('i-food') ||
      texto.contains('zé delivery') ||
      texto.contains('ze delivery') ||
      texto.contains('zedelivery')) {
    return 'Delivery';
  }

  // ALIMENTAÇÃO
  if (texto.contains('supermercado') ||
      texto.contains('mercado') ||
      texto.contains('padaria') ||
      texto.contains('restaurante') ||
      texto.contains('lanchonete')) {
    return 'Alimentação';
  }

  // EDUCAÇÃO
  if (texto.contains('faculdade') ||
      texto.contains('universidade') ||
      texto.contains('univest') ||
      texto.contains('mensalidade escolar') ||
      texto.contains('curso')) {
    return 'Educação';
  }

  // SAÚDE
  if (texto.contains('farmacia') ||
      texto.contains('farmácia') ||
      texto.contains('drogaria') ||
      texto.contains('clinica') ||
      texto.contains('clínica') ||
      texto.contains('hospital') ||
      texto.contains('laboratorio') ||
      texto.contains('laboratório')) {
    return 'Saúde';
  }

  // MORADIA
  if (texto.contains('aluguel') ||
      texto.contains('condominio') ||
      texto.contains('condomínio') ||
      texto.contains('imobiliaria') ||
      texto.contains('imobiliária')) {
    return 'Moradia';
  }

  // CONTAS
  if (texto.contains('energia') ||
      texto.contains('energisa') ||
      texto.contains('internet') ||
      texto.contains('telefone') ||
      texto.contains('celular') ||
      texto.contains('agua') ||
      texto.contains('água') ||
      texto.contains('seguradora') ||
      texto.contains('seguro')) {
    return 'Contas';
  }

  // LAZER
  if (texto.contains('netflix') ||
      texto.contains('disney') ||
      texto.contains('spotify') ||
      texto.contains('cinema') ||
      texto.contains('prime video') ||
      texto.contains('hbo') ||
      texto.contains('max.com')) {
    return 'Lazer';
  }

  // COMPRAS
  if (texto.contains('amazon') ||
      texto.contains('shopee') ||
      texto.contains('shein') ||
      texto.contains('mercado livre')) {
    return 'Compras';
  }

  return 'Outros';
}
