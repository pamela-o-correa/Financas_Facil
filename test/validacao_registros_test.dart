import 'package:flutter_test/flutter_test.dart';
import 'package:financas_facil/modelos/data_registro.dart';
import 'package:financas_facil/modelos/dinheiro.dart';
import 'package:financas_facil/exportacao/dados_relatorio.dart';

void main() {
  test('tipo financeiro desconhecido não vira despesa silenciosamente', () {
    expect(
      () => LinhaRelatorio(
        perfil: 'Teste',
        dados: {'tipo': 'inválido', 'valor': 1, 'data': '2026-11-14'},
      ),
      throwsFormatException,
    );
  });
  group('Datas persistidas', () {
    for (final texto in [
      '2024-02-29',
      '29/02/2024',
      '2024-02-29T23:59:59.123456',
      '2024-02-29T23:59:59Z',
      '2024-02-29T23:59:59-04:00',
    ]) {
      test(
        'preserva data válida $texto',
        () => expect(dataRegistro(texto), isNotNull),
      );
    }
    for (final texto in [
      '2026-02-31',
      '2026-02-29',
      '31/04/2026',
      '2026-13-01',
      '2026-00-10',
      '2026-01-00',
      '2026-01-32',
      '0000-01-01',
      '',
      '2026-01-01lixo',
      '2026-01-01T24:00:00',
      '2026-01-01T23:60:00',
      '2026-01-01T23:59:60',
      '2026-01-01T00:00:00+24:00',
      '2026-01-01T00:00:00-04:60',
    ]) {
      test(
        'rejeita sem normalizar $texto',
        () => expect(dataRegistro(texto), isNull),
      );
    }
    test('preserva instante e fuso ISO', () {
      expect(
        dataRegistro('2026-11-14T09:30:00-04:00'),
        DateTime.utc(2026, 11, 14, 13, 30),
      );
    });
    test('relatório rejeita calendário inválido', () {
      expect(
        () => LinhaRelatorio(
          perfil: 'Teste',
          dados: {'tipo': 'despesa', 'valor': 1, 'data': '2026-02-31'},
        ),
        throwsFormatException,
      );
    });
  });
  group('Precisão monetária', () {
    test('centavos e arredondamento usam a mesma regra', () {
      expect(centavosDeValor(0.1 + 0.2), 30);
      expect(centavosDeValor(10.235), 1024);
      expect(centavosDeValor(-10.235), -1024);
      expect(centavosDeValor(999999999.99), 99999999999);
    });
    for (final valor in [
      double.nan,
      double.infinity,
      double.negativeInfinity,
      1e308,
      1e100,
    ]) {
      test('rejeita valor sem representação segura $valor', () {
        expect(() => centavosDeValor(valor), throwsArgumentError);
        expect(
          () => LinhaRelatorio(
            perfil: 'Teste',
            dados: {'tipo': 'despesa', 'valor': valor, 'data': '2026-11-14'},
          ),
          throwsFormatException,
        );
      });
    }
    test('previsão rejeita centavos fracionários', () {
      expect(
        () => LinhaRelatorio(
          perfil: 'Teste',
          prevista: true,
          dados: {'tipo': 'despesa', 'centavos': 1.5, 'data': '2026-11-14'},
        ),
        throwsFormatException,
      );
    });
    test('limites parciais não quebram a descrição do filtro', () {
      final inicio = FiltroRelatorio(inicio: DateTime(2026, 11, 1));
      final fim = FiltroRelatorio(fim: DateTime(2026, 11, 30));
      expect(inicio.periodo, 'A partir de 01/11/2026');
      expect(fim.periodo, 'Até 30/11/2026');
      expect(
        DadosRelatorio(
          perfil: 'Teste',
          filtro: inicio,
          linhas: [],
        ).nomeArquivo('csv'),
        contains('sem_fim'),
      );
    });
  });
}
