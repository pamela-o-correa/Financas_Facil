import 'dart:convert';

import '../modelos/tipo_movimentacao.dart';
import 'adaptadores.dart';
import 'categorias_importacao.dart';
import 'csv_documento.dart';
import 'item_extrato.dart';
import 'validacao.dart';
export 'csv_documento.dart';

class OcorrenciaImportacao {
  const OcorrenciaImportacao(this.linha, this.motivo);
  final int linha;
  final String motivo;
}

class ResultadoImportacao {
  const ResultadoImportacao({
    required this.documento,
    required this.banco,
    required this.itens,
    required this.ocorrencias,
    this.precisaMapear = false,
    this.motivoMapeamento = '',
    this.decimal = ',',
    this.formatoData = 'dma',
  });
  final DocumentoCsv documento;
  final AdaptadorExtrato banco;
  final List<ItemExtrato> itens;
  final List<OcorrenciaImportacao> ocorrencias;
  final bool precisaMapear;
  final String motivoMapeamento, decimal, formatoData;
}

class MotorImportacao {
  static String decodificar(List<int> bytes) {
    if (bytes.length >= 2 &&
        ((bytes[0] == 255 && bytes[1] == 254) ||
            (bytes[0] == 254 && bytes[1] == 255))) {
      if (bytes.length.isOdd) {
        throw const FormatException('Arquivo UTF-16 incompleto.');
      }
      final pequeno = bytes[0] == 255;
      return String.fromCharCodes([
        for (var i = 2; i < bytes.length; i += 2)
          pequeno ? bytes[i] | bytes[i + 1] << 8 : bytes[i] << 8 | bytes[i + 1],
      ]);
    }
    try {
      return utf8.decode(bytes).replaceFirst(RegExp('^\ufeff'), '');
    } on FormatException {
      // Windows-1252 preserva também aspas tipográficas e travessões do extrato.
      const especiais = {
        128: 8364,
        130: 8218,
        131: 402,
        132: 8222,
        133: 8230,
        134: 8224,
        135: 8225,
        136: 710,
        137: 8240,
        138: 352,
        139: 8249,
        140: 338,
        142: 381,
        145: 8216,
        146: 8217,
        147: 8220,
        148: 8221,
        149: 8226,
        150: 8211,
        151: 8212,
        152: 732,
        153: 8482,
        154: 353,
        155: 8250,
        156: 339,
        158: 382,
        159: 376,
      };
      return String.fromCharCodes(bytes.map((b) => especiais[b] ?? b));
    }
  }

  static ResultadoImportacao ler(
    String texto,
    Map<String, String> categorias, {
    String? separador,
    MapeamentoCsv? mapeamento,
  }) {
    final documento = DocumentoCsv.detectar(texto, separador: separador);
    final mapa = mapeamento ?? documento.sugestao;
    if (mapa == null) {
      return ResultadoImportacao(
        documento: documento,
        banco: const AdaptadorGenerico(),
        itens: [],
        ocorrencias: [],
        precisaMapear: documento.linhas.any((l) => !l.vazia),
        motivoMapeamento:
            'Escolha o cabeçalho e as colunas de data, descrição e valor.',
      );
    }
    if (mapa.cabecalho < 0 ||
        mapa.cabecalho >= documento.linhas.length ||
        !mapa.completo) {
      throw const FormatException(
        'Escolha um cabeçalho e as colunas obrigatórias.',
      );
    }
    final primeira = documento.linhas[mapa.cabecalho].celulas;
    final cabecalho = mapa.possuiCabecalho
        ? primeira
        : List.generate(primeira.length, (i) => 'Coluna ${i + 1}');
    final indices = [
      mapa.data,
      mapa.descricao,
      if (mapa.valor != null) mapa.valor!,
      if (mapa.valor == null) ...[mapa.debito!, mapa.credito!],
      if (mapa.tipo != null) mapa.tipo!,
      if (mapa.detalhes != null) mapa.detalhes!,
      if (mapa.documento != null) mapa.documento!,
    ];
    if (indices.any((i) => i < 0 || i >= cabecalho.length) ||
        indices.toSet().length != indices.length) {
      throw const FormatException(
        'Cada campo deve usar uma coluna diferente e existente.',
      );
    }
    if ([
      if (mapa.valor != null) mapa.valor!,
      if (mapa.valor == null) ...[mapa.debito!, mapa.credito!],
    ].any((i) => linhaDeSaldo(cabecalho[i]))) {
      throw const FormatException(
        'A coluna de saldo não pode ser usada como valor.',
      );
    }
    final banco = detectarBanco(cabecalho);
    var decimal = mapa.decimal;
    if (decimal == 'auto') {
      final sinais = <String>{};
      var ambiguo = false;
      for (final linha in documento.linhas.skip(mapa.inicioDados)) {
        for (final i in [
          if (mapa.valor != null) mapa.valor!,
          if (mapa.valor == null) ...[mapa.debito!, mapa.credito!],
        ]) {
          if (i >= linha.celulas.length) continue;
          final t = linha.celulas[i].replaceAll(RegExp(r'[^0-9,.]'), '');
          if (RegExp(r',[0-9]{1,2}$').hasMatch(t)) {
            sinais.add(',');
          } else if (RegExp(r'\.[0-9]{1,2}$').hasMatch(t)) {
            sinais.add('.');
          } else if (RegExp(r'[,.][0-9]{3}$').hasMatch(t)) {
            ambiguo = true;
          }
        }
      }
      if (sinais.length > 1 ||
          (sinais.isEmpty && ambiguo && banco.codigo == 'generico')) {
        return ResultadoImportacao(
          documento: documento,
          banco: banco,
          itens: [],
          ocorrencias: [],
          precisaMapear: true,
          motivoMapeamento: 'Confirme o separador decimal dos valores.',
        );
      }
      decimal = sinais.isEmpty ? ',' : sinais.single;
    }
    final itens = <ItemExtrato>[];
    final ocorrencias = <OcorrenciaImportacao>[];
    for (final registro in documento.linhas.skip(mapa.inicioDados)) {
      final linha = registro.celulas;
      void ignorar(String motivo) =>
          ocorrencias.add(OcorrenciaImportacao(registro.numero, motivo));
      if (registro.vazia) continue;
      if ((mapa.descricao < linha.length &&
              linhaDeSaldo(linha[mapa.descricao])) ||
          (banco is AdaptadorInter &&
              mapa.detalhes != null &&
              mapa.detalhes! < linha.length &&
              linhaDeSaldo(linha[mapa.detalhes!])) ||
          (linha.length == 1 && linhaDeSaldo(linha.first))) {
        ignorar('Saldo ou total do extrato');
        continue;
      }
      if (linha.length != cabecalho.length) {
        ignorar('Quantidade de colunas diferente do cabeçalho');
        continue;
      }
      if (List.generate(
        linha.length,
        (i) => normalizarCsv(linha[i]) == normalizarCsv(cabecalho[i]),
      ).every((v) => v)) {
        ignorar('Cabeçalho repetido');
        continue;
      }
      final data = dataCsv(linha[mapa.data], formato: mapa.formatoData);
      if (data == null) {
        ignorar('Data inválida');
        continue;
      }
      if (linha[mapa.descricao].trim().isEmpty &&
          !(banco is AdaptadorInter &&
              mapa.detalhes != null &&
              linha[mapa.detalhes!].trim().isNotEmpty)) {
        ignorar('Descrição vazia');
        continue;
      }
      final descricao = banco.descricao(linha, mapa);
      int? valor;
      if (mapa.valor != null) {
        valor = centavosCsv(linha[mapa.valor!], decimal: decimal);
      } else {
        final d = linha[mapa.debito!].trim().isEmpty
            ? 0
            : centavosCsv(linha[mapa.debito!], decimal: decimal);
        final c = linha[mapa.credito!].trim().isEmpty
            ? 0
            : centavosCsv(linha[mapa.credito!], decimal: decimal);
        if (d != null && c != null && !(d != 0 && c != 0) && c >= 0) {
          valor = c - d.abs();
        }
      }
      if (valor == null || valor == 0) {
        ignorar('Valor inválido, zero ou débito/crédito conflitantes');
        continue;
      }
      if (mapa.tipo != null && linha[mapa.tipo!].trim().isNotEmpty) {
        final sinal = sinalTipo(linha[mapa.tipo!]);
        final textoValor = mapa.valor == null ? '' : linha[mapa.valor!].trim();
        if (sinal == null ||
            (sinal == 1 && valor < 0) ||
            (sinal == -1 && RegExp(r'[Cc]$').hasMatch(textoValor)) ||
            (mapa.valor == null && (valor < 0 ? -1 : 1) != sinal)) {
          ignorar('Tipo de entrada/saída inválido ou incompatível com o valor');
          continue;
        }
        valor = valor.abs() * sinal;
      }
      final tipo = valor < 0
          ? TipoMovimentacao.despesa
          : TipoMovimentacao.receita;
      final padrao = sugerirCategoria(descricao, tipo);
      final categoria =
          categorias['${tipo.name}:$padrao'] ??
          categorias['${tipo.name}:Outros'];
      if (categoria == null) {
        throw FormatException(
          'Não foi encontrada categoria compatível com ${tipo.name}. Confira as categorias.',
        );
      }
      itens.add(
        ItemExtrato(
          data: data,
          descricao: descricao,
          valor: valor.abs() / 100,
          tipo: tipo,
          categoria: categoria,
          bancoCodigo: banco.codigo,
          linhaOrigem: registro.numero,
          documento: mapa.documento == null ? '' : linha[mapa.documento!],
        ),
      );
    }
    return ResultadoImportacao(
      documento: documento,
      banco: banco,
      itens: itens,
      ocorrencias: ocorrencias,
      decimal: decimal,
      formatoData: mapa.formatoData,
    );
  }
}
