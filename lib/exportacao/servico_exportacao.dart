
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'dados_relatorio.dart';
import 'exportador_csv.dart';
import 'exportador_excel.dart';
import 'exportador_pdf.dart';

enum FormatoRelatorio {
  csv('CSV', 'Dados e cópia para consulta', 'text/csv'),
  xlsx(
    'Excel',
    'Planilha para análise',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  ),
  pdf('PDF', 'Relatório visual', 'application/pdf');

  const FormatoRelatorio(this.titulo, this.descricao, this.mime);
  final String titulo, descricao, mime;
}

class ArquivoRelatorio {
  const ArquivoRelatorio(this.nome, this.bytes, this.formato);
  final String nome;
  final Uint8List bytes;
  final FormatoRelatorio formato;
}

class PedidoGeracao {
  PedidoGeracao(
    this.dados,
    this.formato,
    this.detalhar,
    this.regular,
    this.negrito,
  );
  final DadosRelatorio dados;
  final FormatoRelatorio formato;
  final bool detalhar;
  final Uint8List? regular, negrito;
}

Future<Uint8List> _gerar(PedidoGeracao p) async => switch (p.formato) {
  FormatoRelatorio.csv => gerarCsv(p.dados),
  FormatoRelatorio.xlsx => gerarExcel(p.dados),
  FormatoRelatorio.pdf => gerarPdf(
    p.dados,
    p.regular!,
    p.negrito!,
    detalhar: p.detalhar,
  ),
};

class ServicoExportacao {
  Future<ArquivoRelatorio> gerar(
    DadosRelatorio dados,
    FormatoRelatorio formato, {
    bool detalhar = false,
  }) async {
    Uint8List? regular, negrito;
    if (formato == FormatoRelatorio.pdf) {
      regular = (await rootBundle.load('assets/fontes/Roboto-Regular.ttf'))
          .buffer
          .asUint8List();
      negrito = (await rootBundle.load('assets/fontes/Roboto-Bold.ttf')).buffer
          .asUint8List();
    }
    final bytes = await compute(
      _gerar,
      PedidoGeracao(dados, formato, detalhar, regular, negrito),
    );
    return ArquivoRelatorio(dados.nomeArquivo(formato.name), bytes, formato);
  }

  Future<bool> salvar(ArquivoRelatorio a) async =>
      await FilePicker.saveFile(
        fileName: a.nome,
        bytes: a.bytes,
        mimeType: a.formato.mime,
        dialogTitle: 'Salvar relatório',
      ) !=
      null;
  Future<void> compartilhar(ArquivoRelatorio a, Rect origem) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(a.bytes, mimeType: a.formato.mime)],
        fileNameOverrides: [a.nome],
        subject: 'Finanças Fácil - Relatório Financeiro',
        sharePositionOrigin: origem,
      ),
    );
  }
}
