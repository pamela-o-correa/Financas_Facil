import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:financas_facil/exportacao/dados_relatorio.dart';
import 'package:financas_facil/exportacao/servico_exportacao.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dados = DadosRelatorio(
    perfil: 'Teste',
    filtro: const FiltroRelatorio(),
    linhas: [
      LinhaRelatorio(
        perfil: 'Teste',
        dados: {
          'tipo': 'receita',
          'valor': 100.01,
          'data': '2026-11-14',
          'descricao': 'Salário',
          'categoria': 'Outros',
        },
      ),
      LinhaRelatorio(
        perfil: 'Teste',
        dados: {
          'tipo': 'despesa',
          'valor': 10.02,
          'data': '2026-11-14',
          'descricao': 'Compra',
          'categoria': 'Outros',
        },
      ),
    ],
  );
  for (final formato in FormatoRelatorio.values) {
    test(
      'serviço gera ${formato.name} em isolate com dados e fontes reais',
      () async {
        final arquivo = await ServicoExportacao().gerar(
          dados,
          formato,
          detalhar: true,
        );
        expect(arquivo.nome, endsWith('.${formato.name}'));
        expect(arquivo.formato, formato);
        if (formato == FormatoRelatorio.csv) {
          final texto = utf8.decode(arquivo.bytes);
          expect(texto, contains('100,01'));
          expect(texto, contains('10,02'));
          expect(texto, contains('Salário'));
        } else if (formato == FormatoRelatorio.xlsx) {
          expect(arquivo.bytes.take(2), [80, 75]);
        } else {
          expect(ascii.decode(arquivo.bytes.take(5).toList()), '%PDF-');
        }
      },
    );
  }
}
