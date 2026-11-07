import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financas_facil/main.dart';

void main() {
  test('Categoria mantém os dados e o ícone após salvar e carregar', () {
    for (final tipo in TipoMovimentacao.values) {
      final original = Categoria(
        id: 7,
        nome: 'Categoria renomeada',
        tipo: tipo,
        codigoIcone: Icons.work_outline.codePoint,
        codigoCor: 0xFF6750A4,
        padrao: true,
      );
      final restaurada = Categoria.deMapa(original.paraMapa());
      expect(restaurada.paraMapa(), original.paraMapa());
      expect(restaurada.icone, Icons.work_outline);
      expect(restaurada.cor, const Color(0xFF6750A4));
    }
  });

  test('Categoria com código de ícone desconhecido usa ícone de categoria', () {
    const categoria = Categoria(
      nome: 'Importada',
      tipo: TipoMovimentacao.despesa,
      codigoIcone: -1,
      codigoCor: 0xFF6750A4,
    );
    expect(categoria.icone, Icons.category_outlined);
    expect(categoria.paraMapa()['codigo_icone'], -1);
  });
}