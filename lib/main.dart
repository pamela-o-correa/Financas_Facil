import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'importacao/leitor_extrato.dart';
import 'importacao/item_extrato.dart';
import 'importacao/tela_mapear_csv.dart';
import 'modelos/tipo_movimentacao.dart';
import 'contas/contas_banco.dart';
import 'contas/lixeira_banco.dart';
import 'contas/tela_contas.dart';
import 'exportacao/tela_exportacao.dart';
import 'modelos/contabilizacao.dart';
export 'exportacao/tela_exportacao.dart';

export 'importacao/item_extrato.dart';
export 'importacao/leitor_extrato.dart';
export 'modelos/tipo_movimentacao.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'perfis.dart';

part 'persistencia/banco_dados.dart';
part 'planejamento_widgets.dart';
part 'calendario_visual.dart';
part 'graficos_despesas.dart';
part 'revisao_financeira.dart';
part 'central_importacao.dart';
part 'experiencia_historico.dart';
part 'busca_preferencias.dart';
part 'tela_lixeira.dart';

final modoTema = ValueNotifier<ThemeMode>(ThemeMode.system);

const coresTema = <String, Color>{
  'Roxo': Color(0xFF6750A4),
  'Azul': Color(0xFF1565C0),
  'Verde': Color(0xFF2E7D32),
};

final corTema = ValueNotifier<String>('Roxo');

const tamanhosTexto = <String, double>{
  'Pequeno': 0.9,
  'Padrão': 1.0,
  'Grande': 1.2,
};
final tamanhoTexto = ValueNotifier<String>('Padrão');

class EscalaTextoApp extends TextScaler {
  const EscalaTextoApp(this.sistema, this.fator);
  final TextScaler sistema;
  final double fator;

  @override
  double scale(double fontSize) => sistema.scale(fontSize) * fator;

  @override
  double get textScaleFactor => scale(14) / 14;
}

Future<void> alterarTamanhoTexto(String nome) async {
  if (!tamanhosTexto.containsKey(nome)) {
    throw ArgumentError('Tamanho de texto inválido.');
  }
  await BancoDados.instancia.salvarPreferencia('tamanho_texto', nome);
  tamanhoTexto.value = nome;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CadastroPerfis.inicializar();

  final modoSalvo = await BancoDados.instancia.lerPreferencia(
    'modo_tema',
  );

  modoTema.value = ThemeMode.values.firstWhere(
    (modo) => modo.name == modoSalvo,
    orElse: () => ThemeMode.system,
  );

    final corSalva = await BancoDados.instancia.lerPreferencia(
    'cor_tema',
  );

  corTema.value = corSalva != null && coresTema.containsKey(corSalva)
      ? corSalva
      : 'Roxo';

  final tamanhoSalvo = await BancoDados.instancia.lerPreferencia('tamanho_texto');
  tamanhoTexto.value = tamanhosTexto.containsKey(tamanhoSalvo)
      ? tamanhoSalvo!
      : 'Padrão';

  runApp(const FinancasFacilApp());
}

Future<void> alterarModoTema(ThemeMode modo) async {
  await BancoDados.instancia.salvarPreferencia(
    'modo_tema',
    modo.name,
  );

  modoTema.value = modo;
}

Future<void> alterarCorTema(String nome) async {
  if (!coresTema.containsKey(nome)) {
    throw ArgumentError('Cor de tema inválida.');
  }

  await BancoDados.instancia.salvarPreferencia(
    'cor_tema',
    nome,
  );

  corTema.value = nome;
}

// ============================================================
// MODELOS
// ============================================================

class DataBrInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var numeros = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (numeros.length > 8) {
      numeros = numeros.substring(0, 8);
    }

    final buffer = StringBuffer();

    for (int i = 0; i < numeros.length; i++) {
      if (i == 2 || i == 4) {
        buffer.write('/');
      }

      buffer.write(numeros[i]);
    }

    final texto = buffer.toString();

    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(
        offset: texto.length,
      ),
    );
  }
}

enum PeriodoFiltro {
  esteMes,
  mesPassado,
  esteAno,
  todos,
  personalizado,
}

class Categoria {
  final int? id;
  final String nome;
  final TipoMovimentacao tipo;
  final int codigoIcone;
  final int codigoCor;
  final bool padrao;

  const Categoria({
    this.id,
    required this.nome,
    required this.tipo,
    required this.codigoIcone,
    required this.codigoCor,
    this.padrao = false,
  });

  Map<String, dynamic> paraMapa() {
    return {
      if (id != null) 'id': id,
      'nome': nome,
      'tipo': tipo.name,
      'codigo_icone': codigoIcone,
      'codigo_cor': codigoCor,
      'padrao': padrao ? 1 : 0,
    };
  }

  factory Categoria.deMapa(Map<String, dynamic> mapa) {
    return Categoria(
      id: mapa['id'] as int?,
      nome: mapa['nome'] as String,
      tipo: TipoMovimentacao.values.firstWhere(
        (tipo) => tipo.name == mapa['tipo'],
      ),
      codigoIcone: mapa['codigo_icone'] as int,
      codigoCor: mapa['codigo_cor'] as int,
      padrao: (mapa['padrao'] as int? ?? 0) == 1,
    );
  }

  static final _iconesPorCodigo = <int, IconData>{
    Icons.account_balance_wallet_outlined.codePoint: Icons.account_balance_wallet_outlined,
    Icons.add.codePoint: Icons.add,
    Icons.add_circle_outline.codePoint: Icons.add_circle_outline,
    Icons.arrow_downward.codePoint: Icons.arrow_downward,
    Icons.arrow_upward.codePoint: Icons.arrow_upward,
    Icons.attach_money.codePoint: Icons.attach_money,
    Icons.bar_chart.codePoint: Icons.bar_chart,
    Icons.bar_chart_outlined.codePoint: Icons.bar_chart_outlined,
    Icons.brightness_auto_outlined.codePoint: Icons.brightness_auto_outlined,
    Icons.calendar_month_outlined.codePoint: Icons.calendar_month_outlined,
    Icons.calendar_today_outlined.codePoint: Icons.calendar_today_outlined,
    Icons.card_giftcard_outlined.codePoint: Icons.card_giftcard_outlined,
    Icons.category_outlined.codePoint: Icons.category_outlined,
    Icons.check.codePoint: Icons.check,
    Icons.check_box_outlined.codePoint: Icons.check_box_outlined,
    Icons.chevron_right.codePoint: Icons.chevron_right,
    Icons.close.codePoint: Icons.close,
    Icons.dark_mode_outlined.codePoint: Icons.dark_mode_outlined,
    Icons.date_range_outlined.codePoint: Icons.date_range_outlined,
    Icons.delete_outline.codePoint: Icons.delete_outline,
    Icons.delivery_dining_outlined.codePoint: Icons.delivery_dining_outlined,
    Icons.description_outlined.codePoint: Icons.description_outlined,
    Icons.directions_car_outlined.codePoint: Icons.directions_car_outlined,
    Icons.edit_note.codePoint: Icons.edit_note,
    Icons.edit_outlined.codePoint: Icons.edit_outlined,
    Icons.fact_check_outlined.codePoint: Icons.fact_check_outlined,
    Icons.file_download_done.codePoint: Icons.file_download_done,
    Icons.filter_list.codePoint: Icons.filter_list,
    Icons.flight_outlined.codePoint: Icons.flight_outlined,
    Icons.health_and_safety_outlined.codePoint: Icons.health_and_safety_outlined,
    Icons.home.codePoint: Icons.home,
    Icons.home_outlined.codePoint: Icons.home_outlined,
    Icons.info_outline.codePoint: Icons.info_outline,
    Icons.light_mode_outlined.codePoint: Icons.light_mode_outlined,
    Icons.more_horiz.codePoint: Icons.more_horiz,
    Icons.more_vert.codePoint: Icons.more_vert,
    Icons.palette_outlined.codePoint: Icons.palette_outlined,
    Icons.payments_outlined.codePoint: Icons.payments_outlined,
    Icons.pets_outlined.codePoint: Icons.pets_outlined,
    Icons.pie_chart_outline.codePoint: Icons.pie_chart_outline,
    Icons.radio_button_checked.codePoint: Icons.radio_button_checked,
    Icons.radio_button_unchecked.codePoint: Icons.radio_button_unchecked,
    Icons.receipt_long.codePoint: Icons.receipt_long,
    Icons.receipt_long_outlined.codePoint: Icons.receipt_long_outlined,
    Icons.remove_circle_outline.codePoint: Icons.remove_circle_outline,
    Icons.restart_alt.codePoint: Icons.restart_alt,
    Icons.restaurant_outlined.codePoint: Icons.restaurant_outlined,
    Icons.rule_outlined.codePoint: Icons.rule_outlined,
    Icons.save_outlined.codePoint: Icons.save_outlined,
    Icons.savings_outlined.codePoint: Icons.savings_outlined,
    Icons.school_outlined.codePoint: Icons.school_outlined,
    Icons.search.codePoint: Icons.search,
    Icons.search_off.codePoint: Icons.search_off,
    Icons.settings_outlined.codePoint: Icons.settings_outlined,
    Icons.shopping_bag_outlined.codePoint: Icons.shopping_bag_outlined,
    Icons.sports_esports_outlined.codePoint: Icons.sports_esports_outlined,
    Icons.storage_outlined.codePoint: Icons.storage_outlined,
    Icons.swap_vert.codePoint: Icons.swap_vert,
    Icons.trending_down.codePoint: Icons.trending_down,
    Icons.trending_up.codePoint: Icons.trending_up,
    Icons.upload_file.codePoint: Icons.upload_file,
    Icons.work_outline.codePoint: Icons.work_outline,
  };

  IconData get icone => _iconesPorCodigo[codigoIcone] ?? Icons.category_outlined;

  Color get cor => Color(codigoCor);
}

class Movimentacao {
  Movimentacao({
    this.id,
    required this.tipo,
    required this.valor,
    required this.categoria,
    required this.descricao,
    required this.data,
    this.contaId,
    this.importacaoId,
    this.transferenciaPar,
    this.ativa = true,
  });

  final int? id;
  final TipoMovimentacao tipo;
  final double valor;
  final String categoria;
  final String descricao;
  final DateTime data;

  /// Conta de origem da movimentação.
  ///
  /// Pode ser nulo em movimentações antigas ou adicionadas
  /// manualmente sem uma conta definida.
  final int? contaId;

  /// Importação que originou esta movimentação.
  ///
  /// Nulo para movimentações criadas manualmente.
  final int? importacaoId;
  final bool ativa;
  int get centavos => (valor * 100).round();
  bool get contabilizavel => deveContabilizar(ativa: ativa, transferencia: transferencia);
  final int? transferenciaPar;
  bool get transferencia => transferenciaPar != null;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'tipo': tipo.name,
      'valor': valor,
      'categoria': categoria,
      'descricao': descricao,
      'data': data.toIso8601String(),
      'conta_id': contaId,
      'importacao_id': importacaoId,
      'ativa': ativa ? 1 : 0,
    };
  }

  factory Movimentacao.fromMap(Map<String, dynamic> map) {
    return Movimentacao(
      id: map['id'] as int?,
      tipo: map['tipo'] == 'receita'
          ? TipoMovimentacao.receita
          : TipoMovimentacao.despesa,
      valor: (map['valor'] as num).toDouble(),
      categoria: map['categoria'] as String,
      descricao: map['descricao'] as String,
      data: DateTime.parse(map['data'] as String),
      contaId: map['conta_id'] as int?,
      importacaoId: map['importacao_id'] as int?,
      transferenciaPar: map['transferencia_par'] as int?,
      ativa: (map['ativa'] as int? ?? 1) == 1,
    );
  }

  Movimentacao copyWith({
    int? id,
    TipoMovimentacao? tipo,
    double? valor,
    String? categoria,
    String? descricao,
    DateTime? data,
    int? contaId,
    int? importacaoId,
    bool? ativa,
  }) {
    return Movimentacao(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      valor: valor ?? this.valor,
      categoria: categoria ?? this.categoria,
      descricao: descricao ?? this.descricao,
      data: data ?? this.data,
      contaId: contaId ?? this.contaId,
      importacaoId: importacaoId ?? this.importacaoId,
      transferenciaPar: transferenciaPar,
      ativa: ativa ?? this.ativa,
    );
  }
}

class ResumoMes {
  ResumoMes({
    required this.ano,
    required this.mes,
    required this.receitas,
    required this.despesas,
  });

  final int ano;
  final int mes;
  final double receitas;
  final double despesas;
}

// ============================================================
// SQLITE
// ============================================================

// ============================================================
// APP
// ============================================================

class FinancasFacilApp extends StatelessWidget {
  const FinancasFacilApp({super.key});

  ThemeData _criarTema(Brightness brilho) {
    final cores = ColorScheme.fromSeed(
      seedColor: coresTema[corTema.value]!,
      brightness: brilho,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cores,
      scaffoldBackgroundColor: cores.surface,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cores.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: cores.outlineVariant,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: cores.primary,
            width: 2,
          ),
        ),
      ),
    );
  }

    @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([modoTema, corTema, tamanhoTexto, CadastroPerfis.atual]),
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Finanças Fácil',
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [
            Locale('pt', 'BR'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: _criarTema(Brightness.light),
          darkTheme: _criarTema(Brightness.dark),
          themeMode: modoTema.value,
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: EscalaTextoApp(
                  media.textScaler,
                  tamanhosTexto[tamanhoTexto.value] ?? 1.0,
                ),
              ),
              child: child!,
            );
          },
          home: TelaPrincipal(key: ValueKey(CadastroPerfis.atual.value.id)),
        );
      },
    );
  }
}

// ============================================================
// TELA PRINCIPAL
// ============================================================

class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  final BancoDados _banco = BancoDados.instancia;

  List<Movimentacao> _movimentacoes = [];
  List<ContaOrigem> _contasGrafico = [];
  AgrupamentoDespesa _agrupamentoDespesa = AgrupamentoDespesa.categoria;
  List<Previsto> _previsoesHome = [];

  int _paginaAtual = 0;
  int _anoAnalise = DateTime.now().year;
  bool _acoesAbertas = false;
  bool _trocandoPerfil = false;

  bool _carregando = true;
  int _consultaMovimentos = 0, _consultaCategorias = 0;

  int? _filtroContaHistorico;
  bool? _filtroAtiva;
  final Set<int> _selecionadasHistorico = {};
  bool _ocupadoHistorico = false;
  TipoMovimentacao? _filtroTipo;
  String? _filtroCategoria;

  final _pesquisaHistoricoController = TextEditingController();
  String _pesquisaHistorico = '';

  @override
  void dispose() {
    _pesquisaHistoricoController.dispose();
    super.dispose();
  }

  PeriodoFiltro _periodoFiltro = PeriodoFiltro.todos;

  DateTime? _inicioPersonalizado;
  DateTime? _fimPersonalizado;
  DateTimeRange? _comparacaoA;
  DateTimeRange? _comparacaoB;

  List<String> categorias = [];

  List<Categoria> _categoriasBanco = [];


  @override
  void initState() {
  super.initState();
  _carregarMovimentacoes();
  _carregarCategoriasBanco();
}

  // ==========================================================
  // BANCO
  // ==========================================================

Future<void> _carregarCategoriasBanco() async {
  final consulta = ++_consultaCategorias;
  try {
    final dados = await _banco.listarCategorias();
    if (!mounted || consulta != _consultaCategorias) return;
    setState(() {
      _categoriasBanco = dados;
      categorias = dados.map((categoria) => categoria.nome).toSet().toList();
    });
  } catch (_) {
    if (mounted && consulta == _consultaCategorias) _mostrarErro('Não foi possível carregar as categorias.');
  }
}

  Future<void> _carregarMovimentacoes() async {
    final consulta = ++_consultaMovimentos;
    try {
      final dados = await _banco.listar();
      final contasGrafico = await ContasBanco(_banco.database).listar();
      final previsoes = await AgendaBanco(_banco.database).listar();

      if (!mounted || consulta != _consultaMovimentos) return;

      setState(() {
        _movimentacoes = dados;
        _contasGrafico = contasGrafico;
        _previsoesHome = previsoes;
        _carregando = false;
      });
      // Alterações pelo Histórico também podem reabrir ou cancelar previsões.
      try {
        await LembretesAgenda.atualizarAgendamentos();
      } catch (erro) {
        debugPrint('Não foi possível atualizar os lembretes: $erro');
      }
    } catch (erro) {
      if (!mounted || consulta != _consultaMovimentos) return;

      setState(() {
        _carregando = false;
      });

      _mostrarErro('Não foi possível carregar as movimentações.');
    }
  }

  Future<void> _adicionarMovimentacao(
    Movimentacao movimentacao,
  ) async {
    try {
      await _banco.inserir(movimentacao);
      await _carregarMovimentacoes();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Movimentação adicionada.'),
        ),
      );
    } catch (erro) {
      if (!mounted) return;

      _mostrarErro('Não foi possível salvar a movimentação.');
    }
  }

  Future<void> _atualizarMovimentacao(
    Movimentacao movimentacao,
  ) async {
    try {
      await _banco.atualizar(movimentacao);
      await _carregarMovimentacoes();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Movimentação atualizada.'),
        ),
      );
    } catch (erro) {
      if (!mounted) return;

      _mostrarErro('Não foi possível atualizar a movimentação.');
    }
  }

  Future<void> _removerMovimentacao(Movimentacao item) async {
    if (item.id != null) await _aplicarAcaoHistorico({item.id!}, excluir: true);
  }

  bool _importandoExtrato = false;
  Future<void> _importarExtrato() async {
    if (_importandoExtrato) return;
    _importandoExtrato = true;
    final bancoAtual = _banco;
    try {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => TelaCentralImportacao(
        banco: bancoAtual, processar: (arquivo, conta) => _processarArquivo(arquivo, conta, bancoAtual))));
    } finally {
      _importandoExtrato = false;
      if (mounted) await _carregarMovimentacoes();
    }
  }

  Future<ResultadoArquivoImportado?> _processarArquivo(PlatformFile arquivo, ContaOrigem conta, BancoDados bancoAtual) async {
      final bytes = await arquivo.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) {
        throw const FormatException(
          'O arquivo selecionado excede o limite de 10 MB.',
        );
      }
      final conteudo = MotorImportacao.decodificar(bytes);
      final categorias = await bancoAtual.nomesCategoriasCsv();
      final contas = ContasBanco(bancoAtual.database);
      var resultado = MotorImportacao.ler(conteudo, categorias);

      var mapear = resultado.precisaMapear;
      while (mounted) {
        if (!mounted) return null;
        if (mapear) {
          final configuracao = await Navigator.push<ConfiguracaoCsv>(context,
            MaterialPageRoute(builder: (_) => TelaMapearCsv(conteudo: conteudo, resultado: resultado)));
          if (configuracao == null || !mounted) return null;
          try {
            resultado = MotorImportacao.ler(conteudo, categorias,
              separador: configuracao.separador, mapeamento: configuracao.mapa);

          } on FormatException catch (e) {
            _mostrarErro(e.message); continue;
          }
          mapear = resultado.precisaMapear;
          if (mapear) continue;
        }
        if (resultado.itens.isEmpty) {
          final motivos = resultado.ocorrencias.take(8).map((o) => 'Linha ${o.linha}: ${o.motivo}').join('\n');
          final ajustar = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
            title: const Text('Nenhuma movimentação válida'),
            content: SingleChildScrollView(child: Text('${resultado.banco.nome}\n\n'
              '${resultado.ocorrencias.isEmpty ? "Este arquivo contém somente cabeçalho ou está vazio." : "${resultado.ocorrencias.length} linhas foram descartadas.\n$motivos"}')),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Fechar')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ajustar colunas'))]));
          if (ajustar != true || !mounted) return null;
          mapear = true; continue;
        }
        if (resultado.banco.codigo != 'generico' && resultado.banco.codigo != conta.bancoCodigo) {
          throw FormatException('O arquivo ${arquivo.name} pertence a outro banco. Selecione arquivos da mesma conta.');
        }
        await bancoAtual.aplicarRegrasImportacao(resultado.itens);
        await contas.identificarDuplicatas(resultado.itens, conta);
        await PreferenciasContabilizacao(bancoAtual.database).sugerir(resultado.itens, conta);
        if (!mounted) return null;

        final selecionados = await Navigator.push<List<ItemExtrato>>(context,
          MaterialPageRoute(builder: (_) => TelaRevisaoExtrato(nomeArquivo: arquivo.name, itens: resultado.itens,
            categorias: _categoriasBanco, resultado: resultado, conta: conta)));
        if (selecionados == null || !mounted) {
         return null;
        }

        if (selecionados.isEmpty) {
          _mostrarErro(
          'Selecione pelo menos uma movimentação para importar.',
           );
           continue;
        }
        await bancoAtual.inserirImportacao(nomeArquivo: arquivo.name, itens: selecionados,
          conta: conta, bancoDetectado: resultado.banco.codigo);
        return ResultadoArquivoImportado(selecionados.length,
          resultado.itens.where((i) => i.possivelDuplicata).length, resultado.ocorrencias.length);
      }
      return null;
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
      ),
    );
  }

  // ==========================================================
  // PERÍODOS
  // ==========================================================

  DateTime _inicioDoDia(DateTime data) {
    return DateTime(
      data.year,
      data.month,
      data.day,
    );
  }

  DateTime _fimDoDia(DateTime data) {
    return DateTime(
      data.year,
      data.month,
      data.day,
      23,
      59,
      59,
      999,
    );
  }

  bool _estaNoPeriodo(DateTime data) {
    final hoje = DateTime.now();

    DateTime? inicio;
    DateTime? fim;

    switch (_periodoFiltro) {
      case PeriodoFiltro.esteMes:
        inicio = DateTime(
          hoje.year,
          hoje.month,
          1,
        );

        fim = DateTime(
          hoje.year,
          hoje.month + 1,
          0,
          23,
          59,
          59,
          999,
        );

        break;

      case PeriodoFiltro.mesPassado:
        inicio = DateTime(
          hoje.year,
          hoje.month - 1,
          1,
        );

        fim = DateTime(
          hoje.year,
          hoje.month,
          0,
          23,
          59,
          59,
          999,
        );

        break;

      case PeriodoFiltro.esteAno:
        inicio = DateTime(
          hoje.year,
          1,
          1,
        );

        fim = DateTime(
          hoje.year,
          12,
          31,
          23,
          59,
          59,
          999,
        );

        break;

      case PeriodoFiltro.todos:
        return true;

      case PeriodoFiltro.personalizado:
        if (_inicioPersonalizado == null ||
            _fimPersonalizado == null) {
          return true;
        }

        inicio = _inicioDoDia(
          _inicioPersonalizado!,
        );

        fim = _fimDoDia(
          _fimPersonalizado!,
        );

        break;
    }

    return !data.isBefore(inicio) &&
        !data.isAfter(fim);
  }

  List<Movimentacao> get _movimentacoesPeriodo {
    final lista = _movimentacoes
        .where(
          (item) => _estaNoPeriodo(item.data),
        )
        .toList();

    lista.sort((a, b) {
      final comparacao = b.data.compareTo(a.data);

      if (comparacao != 0) {
        return comparacao;
      }

      return (b.id ?? 0).compareTo(a.id ?? 0);
    });

    return lista;
  }

  List<Movimentacao> get _movimentacoesFinanceirasPeriodo => _movimentacoesPeriodo.where((m) => m.contabilizavel).toList();

  DateTimeRange? get _intervaloAtual {
    final hoje = DateTime.now();
    switch (_periodoFiltro) {
      case PeriodoFiltro.todos: return null;
      case PeriodoFiltro.esteMes: return DateTimeRange(start: DateTime(hoje.year, hoje.month), end: DateTime(hoje.year, hoje.month + 1, 0));
      case PeriodoFiltro.mesPassado: return DateTimeRange(start: DateTime(hoje.year, hoje.month - 1), end: DateTime(hoje.year, hoje.month, 0));
      case PeriodoFiltro.esteAno: return DateTimeRange(start: DateTime(hoje.year), end: DateTime(hoje.year, 12, 31));
      case PeriodoFiltro.personalizado:
        if (_inicioPersonalizado == null || _fimPersonalizado == null) return null;
        return DateTimeRange(start: _inicioDoDia(_inicioPersonalizado!), end: _inicioDoDia(_fimPersonalizado!));
    }
  }
  String get _periodoExplicito {
    final intervalo = _intervaloAtual;
    return intervalo == null ? 'Todo o período' : '${_dataFormatada(intervalo.start)} a ${_dataFormatada(intervalo.end)}';
  }
  void _mudarMes(int direcao) {
    final atual = _intervaloAtual;
    final base = atual?.start ?? DateTime.now();
    final inicio = DateTime(base.year, base.month + direcao);
    setState(() {
      _periodoFiltro = PeriodoFiltro.personalizado;
      _inicioPersonalizado = inicio;
      _fimPersonalizado = DateTime(inicio.year, inicio.month + 1, 0);
    });
  }
  Widget _periodoDoGrafico() => Row(children: [
    IconButton(tooltip: 'Ver mês anterior', onPressed: () => _mudarMes(-1), icon: const Icon(Icons.chevron_left)),
    Expanded(child: TextButton(onPressed: _abrirFiltroPeriodoHistorico, child: Text(_periodoExplicito, textAlign: TextAlign.center))),
    IconButton(tooltip: 'Ver mês seguinte', onPressed: () => _mudarMes(1), icon: const Icon(Icons.chevron_right)),
  ]);
  Future<void> _abrirRevisaoFinanceira(bool transferencias) async {
    final intervalo = _intervaloAtual;
    bool noPeriodo(DateTime data) => intervalo == null || (!data.isBefore(intervalo.start) && data.isBefore(DateTime(intervalo.end.year, intervalo.end.month, intervalo.end.day + 1)));
    await Navigator.push(context, MaterialPageRoute(builder: (_) => transferencias
      ? TelaTransferencias(banco: _banco, periodo: _periodoExplicito, noPeriodo: noPeriodo)
      : TelaRevisarCategorias(banco: _banco, periodo: _periodoExplicito, noPeriodo: noPeriodo)));
    if (mounted) await _carregarMovimentacoes();
  }
  Widget _acoesRevisao() => Wrap(spacing: 8, runSpacing: 4, children: [
    OutlinedButton.icon(onPressed: () => _abrirRevisaoFinanceira(false), icon: const Icon(Icons.category_outlined), label: const Text('Revisar categorias')),
    OutlinedButton.icon(onPressed: () => _abrirRevisaoFinanceira(true), icon: const Icon(Icons.swap_horiz), label: const Text('Transferências entre contas')),
  ]);

  Future<void> _selecionarPeriodoPersonalizado() async {
  final agora = DateTime.now();

  final inicioController = TextEditingController(
    text: _inicioPersonalizado != null
        ? _dataFormatada(_inicioPersonalizado!)
        : '01/${agora.month.toString().padLeft(2, '0')}/${agora.year}',
  );

  final fimController = TextEditingController(
    text: _fimPersonalizado != null
        ? _dataFormatada(_fimPersonalizado!)
        : _dataFormatada(agora),
  );

  DateTime? converterData(String texto) {
    final partes = texto.split('/');

    if (partes.length != 3) {
      return null;
    }

    final dia = int.tryParse(partes[0]);
    final mes = int.tryParse(partes[1]);
    final ano = int.tryParse(partes[2]);

    if (dia == null || mes == null || ano == null) {
      return null;
    }

    if (ano < 2000 || ano > 2100) {
      return null;
    }

    final data = DateTime(ano, mes, dia);

    if (data.day != dia ||
        data.month != mes ||
        data.year != ano) {
      return null;
    }

    return data;
  }

  final rota = DialogRoute<DateTimeRange>(
    context: context,
    builder: (dialogContext) {
      String? mensagemErro;

      return StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Selecionar período'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: inicioController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      DataBrInputFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Data inicial',
                      hintText: 'DD/MM/AAAA',
                      prefixIcon: Icon(
                        Icons.calendar_today_outlined,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextField(
                    controller: fimController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      DataBrInputFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Data final',
                      hintText: 'DD/MM/AAAA',
                      prefixIcon: Icon(
                        Icons.calendar_today_outlined,
                      ),
                    ),
                  ),

                  if (mensagemErro != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      mensagemErro!,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .error,
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  OutlinedButton.icon(
                    onPressed: () async {
                      final atualInicio =
                          converterData(inicioController.text);

                      final atualFim =
                          converterData(fimController.text);

                      final selecionado =
                          await showDateRangePicker(
                        context: context,
                        locale: const Locale('pt', 'BR'),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        initialDateRange:
                            atualInicio != null &&
                                    atualFim != null &&
                                    !atualInicio.isAfter(atualFim)
                                ? DateTimeRange(
                                    start: atualInicio,
                                    end: atualFim,
                                  )
                                : DateTimeRange(
                                    start: DateTime(
                                      agora.year,
                                      agora.month,
                                      1,
                                    ),
                                    end: agora,
                                  ),
                      );

                      if (!context.mounted) return;

                      if (selecionado != null) {
                        inicioController.text =
                            _dataFormatada(
                          selecionado.start,
                        );

                        fimController.text =
                            _dataFormatada(
                          selecionado.end,
                        );

                        setStateDialog(() {
                          mensagemErro = null;
                        });
                      }
                    },
                    icon: const Icon(
                      Icons.date_range_outlined,
                    ),
                    label: const Text(
                      'Escolher no calendário',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Cancelar'),
              ),

              FilledButton(
                onPressed: () {
                  final inicio =
                      converterData(inicioController.text);

                  final fim =
                      converterData(fimController.text);

                  if (inicio == null || fim == null) {
                    setStateDialog(() {
                      mensagemErro =
                          'Digite datas válidas no formato DD/MM/AAAA.';
                    });

                    return;
                  }

                  if (inicio.isAfter(fim)) {
                    setStateDialog(() {
                      mensagemErro =
                          'A data inicial não pode ser posterior à data final.';
                    });

                    return;
                  }

                  Navigator.pop(
                    dialogContext,
                    DateTimeRange(
                      start: inicio,
                      end: fim,
                    ),
                  );
                },
                child: const Text('Aplicar'),
              ),
            ],
          );
        },
      );
    },
  );

  final intervalo = await Navigator.of(context, rootNavigator: true).push(rota);
  // Aguarda a remoção dos campos após a animação de saída.
  await rota.completed;

  inicioController.dispose();
  fimController.dispose();

  if (intervalo == null || !mounted) {
    return;
  }

  setState(() {
    _inicioPersonalizado = intervalo.start;
    _fimPersonalizado = intervalo.end;
    _periodoFiltro = PeriodoFiltro.personalizado;
  });
}

  String get _nomePeriodoAtual {
    switch (_periodoFiltro) {
      case PeriodoFiltro.esteMes:
        return 'Este mês';

      case PeriodoFiltro.mesPassado:
        return 'Mês passado';

      case PeriodoFiltro.esteAno:
        return 'Este ano';

      case PeriodoFiltro.todos:
        return 'Todo o período';

      case PeriodoFiltro.personalizado:
        if (_inicioPersonalizado == null ||
            _fimPersonalizado == null) {
          return 'Período';
        }

        return '${_dataFormatada(_inicioPersonalizado!)}'
            ' até '
            '${_dataFormatada(_fimPersonalizado!)}';
    }
  }

  Future<void> _abrirFiltroPeriodoHistorico() async {
  final selecionado =
      await showModalBottomSheet<PeriodoFiltro>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Período',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            ListTile(
              title: const Text('Todo o período'),
              onTap: () {
                Navigator.pop(
                  context,
                  PeriodoFiltro.todos,
                );
              },
            ),

            ListTile(
              title: const Text('Este mês'),
              onTap: () {
                Navigator.pop(
                  context,
                  PeriodoFiltro.esteMes,
                );
              },
            ),

            ListTile(
              title: const Text('Mês passado'),
              onTap: () {
                Navigator.pop(
                  context,
                  PeriodoFiltro.mesPassado,
                );
              },
            ),

            ListTile(
              title: const Text('Este ano'),
              onTap: () {
                Navigator.pop(
                  context,
                  PeriodoFiltro.esteAno,
                );
              },
            ),

            ListTile(
              title: const Text('Personalizado'),
              onTap: () {
                Navigator.pop(
                  context,
                  PeriodoFiltro.personalizado,
                );
              },
            ),
          ],
        ),
      );
    },
  );

  if (selecionado == null || !mounted) {
    return;
  }

  if (selecionado == PeriodoFiltro.personalizado) {
    await _selecionarPeriodoPersonalizado();
    return;
  }

  setState(() {
    _periodoFiltro = selecionado;
    _inicioPersonalizado = null;
    _fimPersonalizado = null;
  });
}

  Widget _seletorPeriodo() {
  return OutlinedButton.icon(
    onPressed: _abrirFiltroPeriodoHistorico,
    icon: const Icon(
      Icons.date_range_outlined,
      size: 18,
    ),
    label: Text(
      _nomePeriodoAtual,
    ),
  );
}

  // ==========================================================
  // CÁLCULOS
  // ==========================================================

  int get _receitasCentavos {
    return _movimentacoesFinanceirasPeriodo
        .where(
          (item) =>
              item.tipo == TipoMovimentacao.receita,
        )
        .fold<int>(
          0,
          (total, item) => total + item.centavos,
        );
  }

  int get _despesasCentavos {
    return _movimentacoesFinanceirasPeriodo
        .where(
          (item) =>
              item.tipo == TipoMovimentacao.despesa,
        )
        .fold<int>(
          0,
          (total, item) => total + item.centavos,
        );
  }

  double get _receitas => _receitasCentavos / 100;

  double get _despesas => _despesasCentavos / 100;

  double get _saldo => (_receitasCentavos - _despesasCentavos) / 100;

  String _dinheiro(double valor) {
    final negativo = valor < 0;
    final absoluto = valor.abs();

    final partes = absoluto
        .toStringAsFixed(2)
        .split('.');

    final inteira = partes[0];
    final decimal = partes[1];

    final buffer = StringBuffer();

    for (int i = 0; i < inteira.length; i++) {
      final posicaoRestante = inteira.length - i;

      buffer.write(inteira[i]);

      if (posicaoRestante > 1 &&
          posicaoRestante % 3 == 1) {
        buffer.write('.');
      }
    }

    return '${negativo ? '-' : ''}R\$ '
        '${buffer.toString()},$decimal';
  }

  String _dataFormatada(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';
  }

  List<Movimentacao> get _movimentacoesFiltradas => filtrarHistorico(
    _movimentacoesPeriodo, pesquisa: _pesquisaHistorico,
    tipo: _filtroTipo, categoria: _filtroCategoria, ativa: _filtroAtiva, contaId: _filtroContaHistorico,
  );

  String get _rotuloContaHistorico {
    if (_filtroContaHistorico == null) return 'Conta';
    if (_filtroContaHistorico == -1) return 'Sem conta identificada';
    for (final conta in _contasGrafico) {
      if (conta.id == _filtroContaHistorico) return conta.rotulo;
    }
    return 'Conta indisponível';
  }

  Future<void> _escolherContaHistorico() async {
    final escolhida = await showModalBottomSheet<int>(context: context, isScrollControlled: true,
      builder: (ctx) => SafeArea(child: SizedBox(height: MediaQuery.sizeOf(ctx).height * 0.6,
        child: ListView(children: [
          const ListTile(title: Text('Filtrar por conta')),
          ListTile(title: const Text('Todas as contas'), selected: _filtroContaHistorico == null,
            onTap: () => Navigator.pop(ctx, 0)),
          ListTile(title: const Text('Sem conta identificada'), selected: _filtroContaHistorico == -1,
            onTap: () => Navigator.pop(ctx, -1)),
          for (final conta in _contasGrafico) ListTile(title: Text(conta.rotulo),
            selected: conta.id == _filtroContaHistorico, onTap: () => Navigator.pop(ctx, conta.id)),
        ]))));
    if (mounted && escolhida != null) {
      setState(() {
      _filtroContaHistorico = escolhida == 0 ? null : escolhida;
      _selecionadasHistorico.clear();
    });
    }
  }

  // ==========================================================
  // FORMULÁRIO
  // ==========================================================

  Future<void> _abrirFormulario({
    TipoMovimentacao? tipoInicial,
    Movimentacao? movimentacao,
  }) async {
    if (_categoriasBanco.isEmpty) await _carregarCategoriasBanco();
    if (!mounted || _categoriasBanco.isEmpty) return;
    final resultado =
        await Navigator.push<Movimentacao>(
      context,
      MaterialPageRoute(
        builder: (_) => TelaFormulario(
          movimentacao: movimentacao,
          tipoInicial: tipoInicial,
          categorias: _categoriasBanco,
        ),
      ),
    );

    if (resultado == null) return;

    if (movimentacao == null) {
      await _adicionarMovimentacao(resultado);
    } else {
      await _atualizarMovimentacao(resultado);
    }
  }

  Future<MudancaPreferencia?> _oferecerPreferencia(Movimentacao item, bool ativa) async {
    if (item.contaId == null || item.descricao.trim().isEmpty) return null;
    try {
      final repo = PreferenciasContabilizacao(_banco.database);
      final nova = PreferenciaContabilizacao(contaId: item.contaId!, tipo: item.tipo,
        descricao: item.descricao, ativa: ativa);
      if ((await repo.listar()).any((r) => r.chave == nova.chave && r.ativa == ativa && r.habilitada)) return null;
      ContaOrigem? conta;
      for (final c in _contasGrafico) { if (c.id == item.contaId) conta = c; }
      if (!mounted || conta == null) return null;
      final lembrar = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Lembrar esta preferência?'),
        content: SingleChildScrollView(child: Text(
          'A movimentação foi ${ativa ? 'reativada' : 'desativada'}.\n\n'
          'Deseja sugerir contabilização ${ativa ? 'ativa' : 'desativada'} para futuras importações com esta mesma descrição e tipo na conta ${conta!.rotulo}?\n\n'
          '“${item.descricao}”\n\n'
          'Você confirma cada sugestão na revisão do extrato. As preferências ficam em Configurações.',
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Só esta vez')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lembrar preferência')),
        ],
      ));
      if (lembrar == true) return await repo.salvar(nova);
    } catch (_) {
      if (mounted) {
        await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Preferência não salva'),
        content: const Text('A movimentação foi alterada, mas não foi possível salvar a preferência. Tente novamente depois.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar'))],
      ));
      }
    }
    return null;
  }

  Future<void> _alternarContabilizacao(Movimentacao item) async {
    if (item.id != null) await _aplicarAcaoHistorico({item.id!}, ativa: !item.ativa, lembrar: item);
  }

  Future<void> _aplicarAcaoHistorico(Set<int> ids, {bool? ativa, Categoria? categoria, bool excluir = false, Movimentacao? lembrar}) async {
    if (!mounted || _ocupadoHistorico) return;
    setState(() => _ocupadoHistorico = true);
    try {
      final alteracao = await AlteracaoHistorico.executar(await _banco.database, ids,
        ativa: ativa, categoria: categoria, excluir: excluir);
      if (!mounted) return;
      setState(() => _selecionadasHistorico.clear());
      await _carregarMovimentacoes();
      if (!mounted) return;
      final mudancaPreferencia = lembrar == null ? null : await _oferecerPreferencia(lembrar, ativa!);
      if (!mounted) return;
      final mensagem = excluir ? 'Movimentação excluída.' : categoria != null
        ? '${ids.length} movimentações categorizadas.'
        : ativa! ? 'Contabilização reativada.' : 'Contabilização desativada. Movimentações mantidas no histórico.';
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 8), content: Text(mensagem),
        action: SnackBarAction(label: 'Desfazer', onPressed: () async {
          if (_ocupadoHistorico) return;
          setState(() => _ocupadoHistorico = true);
          try {
            await alteracao.desfazer(junto: mudancaPreferencia?.desfazer);
            await _carregarMovimentacoes();
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ação desfeita.')));
          } catch (_) {
            if (mounted) _mostrarErro('Não foi possível desfazer. Os registros podem ter sido alterados novamente.');
          } finally {
            if (mounted) setState(() => _ocupadoHistorico = false);
          }
        }),
      ));
    } catch (_) {
      if (mounted) _mostrarErro('Não foi possível concluir a ação. Atualize o histórico e tente novamente.');
    } finally {
      if (mounted) setState(() => _ocupadoHistorico = false);
    }
  }

  void _selecionarHistorico(int? id) {
    if (id == null || _ocupadoHistorico) return;
    setState(() {
      if (!_selecionadasHistorico.remove(id)) _selecionadasHistorico.add(id);
    });
  }

  Future<void> _categorizarHistorico() async {
    final ids = _movimentacoesFiltradas.where((m) => _selecionadasHistorico.contains(m.id)).map((m) => m.id!).toSet();
    final itens = _movimentacoes.where((m) => ids.contains(m.id)).toList();
    if (itens.isEmpty || _ocupadoHistorico) return;
    if (itens.map((m) => m.tipo).toSet().length != 1) {
      _mostrarErro('Selecione somente receitas ou somente despesas para escolher uma categoria.');
      return;
    }
    final categorias = _categoriasBanco.where((c) => c.tipo == itens.first.tipo).toList();
    final escolhida = await showModalBottomSheet<Categoria>(context: context, isScrollControlled: true,
      builder: (context) => SafeArea(child: SizedBox(height: MediaQuery.sizeOf(context).height * 0.6,
        child: ListView(children: [
          const ListTile(title: Text('Categoria das movimentações selecionadas')),
          for (final c in categorias) ListTile(title: Text(c.nome), leading: Icon(c.icone),
            onTap: () => Navigator.pop(context, c)),
        ]))));
    if (mounted && escolhida != null) await _aplicarAcaoHistorico(ids, categoria: escolhida);
  }

  Widget _avisoDesativadas() => AvisoDesativadas(
    quantidade: _movimentacoesPeriodo.where((m) => !m.ativa).length,
    onVer: () => setState(() {
      _paginaAtual = 1;
      _filtroAtiva = false;
      _filtroContaHistorico = null;
      _filtroTipo = null;
      _filtroCategoria = null;
      _pesquisaHistorico = '';
      _pesquisaHistoricoController.clear();
      _selecionadasHistorico.clear();
    }),
  );

  Future<void> _excluir(
    Movimentacao movimentacao,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir movimentação?'),
          content: Text(
            'Deseja excluir "${movimentacao.descricao}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      await _removerMovimentacao(movimentacao);
    }
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    if (_carregando || _trocandoPerfil) {
  return Scaffold(
    appBar: AppBar(
      title: const Text(
        'Finanças Fácil',
        style: TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    body: const Center(
      child: CircularProgressIndicator(),
    ),
  );
}

    final paginas = [
      _dashboard(),
      _historico(),
      _relatorios(),
      TelaAgenda(key: ValueKey(_banco.perfil.id), banco: AgendaBanco(_banco.database),
        movimentacoes: _movimentacoes.where((m) => m.contabilizavel).toList(), categoriasVisuais: _categoriasBanco,
        perfil: _banco.perfil.id, nomePerfil: CadastroPerfis.atual.value.nome,
        categorias: {for (final tipo in TipoMovimentacao.values) tipo.name: _categoriasBanco.where((c) => c.tipo == tipo).map((c) => c.nome).toList()},
        onRealizado: _carregarMovimentacoes),
    ];

    return Scaffold(
      appBar: AppBar(
  title: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Finanças Fácil', style: TextStyle(fontWeight: FontWeight.bold)),
      InkWell(
        onTap: _trocandoPerfil ? null : _abrirPerfis,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: Text(CadastroPerfis.atual.value.nome,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary))),
          const Icon(Icons.arrow_drop_down, size: 20),
        ]),
      ),
    ],
  ),
  actions: [

  IconButton(
    tooltip: 'Configurações',
    icon: const Icon(Icons.settings_outlined),
    onPressed: () async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const TelaConfiguracoes(),
    ),
  );

  if (!mounted) return;

  await _carregarCategoriasBanco();
  await _carregarMovimentacoes();
},
  ),
  const SizedBox(width: 8),
],
),
body: Stack(
  children: [
    Positioned.fill(child: paginas[_paginaAtual]),
    if (_acoesAbertas)
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _acoesAbertas = false),
          child: const ColoredBox(color: Colors.black26),
        ),
      ),
  ],
),
      floatingActionButton: _paginaAtual == 3 ? null : Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_acoesAbertas) ...[
            FloatingActionButton.extended(
              heroTag: 'acao_importar',
              onPressed: () async {
                setState(() => _acoesAbertas = false);
                await _importarExtrato();
              },
              icon: const Icon(Icons.upload_file),
              label: const Text('Importar extrato'),
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              heroTag: 'acao_adicionar',
              onPressed: () async {
                setState(() => _acoesAbertas = false);
                await _abrirFormulario();
              },
              icon: const Icon(Icons.add),
              label: const Text('Adicionar'),
            ),
            const SizedBox(height: 12),
          ],
          FloatingActionButton(
            heroTag: 'menu_acoes',
            tooltip: _acoesAbertas ? 'Fechar opções' : 'Adicionar ou importar',
            onPressed: () => setState(() => _acoesAbertas = !_acoesAbertas),
            child: Icon(_acoesAbertas ? Icons.close : Icons.add),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _paginaAtual,
        onDestinationSelected: (index) {
          if (index == 0) _carregarMovimentacoes();
          setState(() {
            _paginaAtual = index;
            _acoesAbertas = false;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Histórico',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Relatórios',
          ),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Calendário'),
        ],
      ),
    );
  }

  // ==========================================================
  // DASHBOARD
  // ==========================================================

  Future<void> _abrirPerfis() async {
    if (_trocandoPerfil || _importandoExtrato) return;
    setState(() => _acoesAbertas = false);
    final rota = MaterialPageRoute<PerfilFinanceiro>(builder: (_) => const TelaPerfis());
    final escolhido = await Navigator.push(context, rota);
    await rota.completed;
    if (!mounted || escolhido == null || escolhido.id == CadastroPerfis.atual.value.id) return;
    setState(() => _trocandoPerfil = true);
    try {
      // Abre o novo banco antes de trocar a tela; uma falha mantém o perfil atual.
      final bancoNovo = BancoDados.paraPerfil(escolhido);
      await bancoNovo.database;
      final modo = await bancoNovo.lerPreferencia('modo_tema');
      final cor = await bancoNovo.lerPreferencia('cor_tema');
      final tamanho = await bancoNovo.lerPreferencia('tamanho_texto');
      if (!mounted) return;
      await CadastroPerfis.lembrar(escolhido);
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      modoTema.value = ThemeMode.values.firstWhere((m) => m.name == modo, orElse: () => ThemeMode.system);
      corTema.value = coresTema.containsKey(cor) ? cor! : 'Roxo';
      tamanhoTexto.value = tamanhosTexto.containsKey(tamanho) ? tamanho! : 'Padrão';
      CadastroPerfis.atual.value = escolhido;
    } catch (_) {
      if (mounted) _mostrarErro('Não foi possível abrir o perfil. Seus dados continuam no perfil atual.');
    } finally {
      if (mounted) setState(() => _trocandoPerfil = false);
    }
  }

  Widget _tituloHome(String titulo, String acao, int pagina) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 8),
    child: Row(children: [
      Expanded(child: Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
      TextButton(onPressed: () => setState(() => _paginaAtual = pagina), child: Text('$acao ›')),
    ]),
  );

  List<Widget> _blocosHome() {
    final categorias = totaisCategorias(_movimentacoesPeriodo);
    final hoje = diaAgenda(DateTime.now());
    final fim = DateTime(hoje.year, hoje.month, hoje.day + 7);
    final previstos = _previsoesHome.where((p) => p.pendente && !p.data.isBefore(hoje) && p.data.isBefore(fim)).toList();
    final entradasCentavos = previstos.where((p) => p.receita).fold<int>(0, (s, p) => s + p.centavos);
    final saidasCentavos = previstos.where((p) => !p.receita).fold<int>(0, (s, p) => s + p.centavos);
    final entradas = entradasCentavos / 100;
    final saidas = saidasCentavos / 100;
    final atualCentavos = _movimentacoes
        .where((m) => m.contabilizavel && m.data.isBefore(DateTime(hoje.year, hoje.month, hoje.day + 1)))
        .fold<int>(0, (s, m) => s + (m.tipo == TipoMovimentacao.receita ? m.centavos : -m.centavos));
    final dica = _despesas > _receitas
      ? 'As despesas superaram as receitas neste período em ${_dinheiro(_despesas - _receitas)}. Revise os gastos antes de assumir novos compromissos.'
      : categorias.isNotEmpty && _despesas > 0
        ? '${categorias.first.key} representa ${(categorias.first.value / _despesas * 100).toStringAsFixed(1).replaceAll('.', ',')}% das despesas do período. Definir um limite para essa categoria pode ajudar no planejamento.'
        : 'Registre suas movimentações e categorize seus gastos para acompanhar melhor seu dinheiro.';
    Widget linha(String rotulo, double valor, Color cor) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Wrap(alignment: WrapAlignment.spaceBetween, spacing: 16, runSpacing: 4, children: [
        Text(rotulo), Text(_dinheiro(valor), style: TextStyle(color: cor, fontWeight: FontWeight.w700)),
      ]),
    );
    return [
      _tituloHome('Gastos', 'Ver tudo', 2),
      _graficoDespesas(compacto: true),
      const SizedBox(height: 16),
      _tituloHome('Próximos 7 dias', 'Ver calendário', 3),
      Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${_dataFormatada(hoje)} a ${_dataFormatada(DateTime(hoje.year, hoje.month, hoje.day + 6))}', style: const TextStyle(fontSize: 12)),
          if (previstos.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('Sem movimentações previstas para os próximos 7 dias.')),
          linha('Previsto para entrar', entradas, Colors.green),
          linha('Previsto para sair', saidas, Colors.red),
          const Divider(),
          linha('Saldo projetado', (atualCentavos + entradasCentavos - saidasCentavos) / 100, Theme.of(context).colorScheme.primary),
          const Text('Saldo dos lançamentos até hoje + previsões pendentes. Independente do período selecionado.', style: TextStyle(fontSize: 12)),
        ])),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('💡 Dica financeira', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8), Text(dica),
        ])),
      const SizedBox(height: 16),
    ];
  }

  String? _comparacaoHome(TipoMovimentacao? tipo) {
    final agora = DateTime.now();
    if (_periodoFiltro != PeriodoFiltro.esteMes && _periodoFiltro != PeriodoFiltro.mesPassado) return null;
    final inicio = DateTime(agora.year, agora.month - (_periodoFiltro == PeriodoFiltro.mesPassado ? 1 : 0));
    final anterior = DateTime(inicio.year, inicio.month - 1);
    final base = _movimentacoes.where((m) => m.contabilizavel).where((m) => !m.data.isBefore(anterior) && m.data.isBefore(inicio) && (tipo == null || m.tipo == tipo)).toList();
    if (base.isEmpty) return null;
    double soma(Iterable<Movimentacao> itens) => itens.fold(0.0, (s, m) => s + (tipo == null && m.tipo == TipoMovimentacao.despesa ? -m.valor : m.valor));
    final antes = soma(base);
    if (antes.abs() < .01) return null;
    final atual = soma(_movimentacoesFinanceirasPeriodo.where((m) => tipo == null || m.tipo == tipo));
    final variacao = (atual - antes) / antes.abs() * 100;
    return '${variacao >= 0 ? '↑' : '↓'} ${variacao.abs().toStringAsFixed(1).replaceAll('.', ',')}% vs. mês anterior${_periodoFiltro == PeriodoFiltro.esteMes ? ' • mês atual em andamento' : ''}';
  }

  Widget _dashboard() {
    final recentes = _movimentacoesPeriodo;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Olá!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          'Organize hoje, planeje com tranquilidade.',
          style: const TextStyle(
            color: Colors.grey,
          ),
        ),

        const SizedBox(height: 14),

        _seletorPeriodo(),

        const SizedBox(height: 18),

        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Saldo do período',
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme.onPrimary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                child: Text(_dinheiro(_saldo), style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 32, fontWeight: FontWeight.bold))),
              if (_comparacaoHome(null) case final String comparacao) ...[
                const SizedBox(height: 8),
                Text(comparacao, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 12)),
              ],            ],
          ),
        ),

        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: CardResumo(
                titulo: 'Receitas',
                valor: _dinheiro(_receitas),
                comparacao: _comparacaoHome(TipoMovimentacao.receita),
                icone: Icons.arrow_upward,
                cor: Colors.green,
                onAdicionar: () => _abrirFormulario(tipoInicial: TipoMovimentacao.receita),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CardResumo(
                titulo: 'Despesas',
                valor: _dinheiro(_despesas),
                comparacao: _comparacaoHome(TipoMovimentacao.despesa),
                icone: Icons.arrow_downward,
                cor: Colors.red,
                onAdicionar: () => _abrirFormulario(tipoInicial: TipoMovimentacao.despesa),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        _avisoDesativadas(),
        ..._blocosHome(),
        _tituloHome('Movimentações recentes', 'Ver todas', 1),
        const SizedBox(height: 12),

        if (recentes.isEmpty)
          const EstadoVazio(
            icone: Icons.receipt_long_outlined,
            titulo: 'Nenhuma movimentação',
            subtitulo:
                'Não existem movimentações no período selecionado.',
          )
        else
          ...recentes.take(4).map(
                (item) => CardMovimentacao(
                  movimentacao: item,
                  onAlternarContabilizacao: () => _alternarContabilizacao(item),
                  dinheiro: _dinheiro,
                  dataFormatada: _dataFormatada,
                  onEditar: () {
                    _abrirFormulario(
                      movimentacao: item,
                    );
                  },
                  onExcluir: () {
                    _excluir(item);
                  },
                ),
              ),

        const SizedBox(height: 90),
      ],
    );
  }

  // ==========================================================
  // HISTÓRICO
  // ==========================================================

  Future<void> _abrirFiltroCategoriaHistorico() async {
    final nomes = categorias.toSet().toList()..sort();
    final indiceAtual = _filtroCategoria == null
        ? -1
        : nomes.indexOf(_filtroCategoria!);

    final selecionado = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: RadioGroup<int>(
          groupValue: indiceAtual,
          onChanged: (valor) => Navigator.pop(context, valor),
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text(
                  'Categoria',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Radio<int>(value: -1),
                title: const Text('Todas'),
                onTap: () => Navigator.pop(context, -1),
              ),
              for (var indice = 0; indice < nomes.length; indice++)
                ListTile(
                  leading: Radio<int>(value: indice),
                  title: Text(nomes[indice]),
                  onTap: () => Navigator.pop(context, indice),
                ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || selecionado == null) return;
    setState(() {
      _filtroCategoria = selecionado == -1 ? null : nomes[selecionado];
    });
  }

  Future<void> _abrirFiltroTipoHistorico() async {
    final selecionado = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Tipo',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              title: const Text('Todos'),
              onTap: () => Navigator.pop(context, -1),
            ),
            ListTile(
              title: const Text('Receitas'),
              onTap: () => Navigator.pop(context, TipoMovimentacao.receita.index),
            ),
            ListTile(
              title: const Text('Despesas'),
              onTap: () => Navigator.pop(context, TipoMovimentacao.despesa.index),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selecionado == null) return;
    setState(() {
      _filtroTipo = selecionado == -1
          ? null
          : TipoMovimentacao.values[selecionado];
    });
  }

  Widget _historico() {
    final lista = _movimentacoesFiltradas;
    final idsVisiveis = lista.map((m) => m.id).whereType<int>().toSet();
    _selecionadasHistorico.retainAll(idsVisiveis);
    final hoje = _inicioDoDia(DateTime.now());
    final ontem = DateTime(hoje.year, hoje.month, hoje.day - 1);

    String tituloDoDia(DateTime dia) {
      if (dia == hoje) return 'Hoje';
      if (dia == ontem) return 'Ontem';
      return _dataFormatada(dia);
    }

    return Column(
      children: [
                Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _pesquisaHistoricoController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Pesquisar descrição ou valor',
              hintText: 'Ex.: Uber, 150,00 ou R\$ 150,00',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _pesquisaHistorico.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar pesquisa',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _pesquisaHistoricoController.clear();

                        setState(() {
                          _pesquisaHistorico = '';
                        });
                      },
                    ),
            ),
            onChanged: (texto) {
              setState(() {
                _pesquisaHistorico = texto;
              });
            },
            onSubmitted: (_) {
              FocusScope.of(context).unfocus();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            16,
            8,
            16,
            4,
          ),
          child: _seletorPeriodo(),
        ),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(
            16,
            4,
            16,
            8,
          ),
          child: Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.swap_vert, size: 18),
                label: Text(
                  _filtroTipo == null
                      ? 'Tipo'
                      : _filtroTipo == TipoMovimentacao.receita
                          ? 'Receitas'
                          : 'Despesas',
                ),
                onPressed: _abrirFiltroTipoHistorico,
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.category_outlined, size: 18),
                label: Text(_filtroCategoria ?? 'Categoria'),
                onPressed: _abrirFiltroCategoriaHistorico,
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.account_balance_outlined, size: 18),
                label: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 190),
                  child: Text(_rotuloContaHistorico, maxLines: 1, overflow: TextOverflow.ellipsis)),
                onPressed: _escolherContaHistorico,
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: 'Filtrar contabilização',
                initialValue: _filtroAtiva == null ? 'todas' : _filtroAtiva! ? 'ativas' : 'desativadas',
                onSelected: (valor) => setState(() {
                  _filtroAtiva = valor == 'todas' ? null : valor == 'ativas';
                }),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'todas', child: Text('Todas')),
                  PopupMenuItem(value: 'ativas', child: Text('Ativas')),
                  PopupMenuItem(value: 'desativadas', child: Text('Desativadas')),
                ],
                child: Chip(avatar: const Icon(Icons.pause_circle_outline, size: 18),
                  label: Text(_filtroAtiva == null ? 'Todas' : _filtroAtiva! ? 'Ativas' : 'Desativadas')),
              ),
            ],
          ),
        ),

        if (_ocupadoHistorico) const LinearProgressIndicator(),
        if (_selecionadasHistorico.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(icon: const Icon(Icons.checklist), label: const Text('Selecionar movimentações'),
              onPressed: lista.isEmpty || _ocupadoHistorico ? null : () => _selecionarHistorico(lista.first.id)),
          ))
        else
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Wrap(
            spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('${_selecionadasHistorico.length} selecionadas'),
              TextButton(onPressed: _ocupadoHistorico ? null : () => setState(() {
                _selecionadasHistorico.addAll(idsVisiveis);
              }), child: const Text('Selecionar visíveis')),
              TextButton(onPressed: _ocupadoHistorico ? null : () => setState(() => _selecionadasHistorico.clear()), child: const Text('Cancelar')),
              PopupMenuButton<String>(
                enabled: !_ocupadoHistorico, tooltip: 'Ações das selecionadas',
                onSelected: (acao) {
                  if (acao == 'categoria') { _categorizarHistorico(); }
                  else { _aplicarAcaoHistorico(Set.of(_selecionadasHistorico), ativa: acao == 'ativar'); }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'desativar', child: Text('Desativar selecionadas')),
                  PopupMenuItem(value: 'ativar', child: Text('Reativar selecionadas')),
                  PopupMenuItem(value: 'categoria', child: Text('Alterar categoria')),
                ],
                child: const Chip(label: Text('Ações'), avatar: Icon(Icons.more_horiz)),
              ),
            ],
          )),

        Expanded(
          child: lista.isEmpty
              ? const EstadoVazio(
                  icone: Icons.search_off,
                  titulo: 'Nada por aqui',
                  subtitulo:
                      'Nenhuma movimentação corresponde à pesquisa e aos filtros selecionados.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    100,
                  ),
                  itemCount: lista.length,
                  itemBuilder: (_, index) {
                    final item = lista[index];
                    final dia = _inicioDoDia(item.data);
                    final iniciaDia = index == 0 ||
                        _inicioDoDia(lista[index - 1].data) != dia;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (iniciaDia)
                          Semantics(
                            header: true,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(4, index == 0 ? 4 : 14, 4, 10),
                              child: Text(
                                tituloDoDia(dia),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        CardMovimentacao(
                      movimentacao: item,
                      selecionada: _selecionadasHistorico.contains(item.id),
                      emSelecao: _selecionadasHistorico.isNotEmpty,
                      onSelecionar: () => _selecionarHistorico(item.id),
                      onAlternarContabilizacao: () => _alternarContabilizacao(item),
                      dinheiro: _dinheiro,
                      dataFormatada: _dataFormatada,
                      onEditar: () {
                        _abrirFormulario(
                          movimentacao: item,
                        );
                      },
                      onExcluir: () {
                        _excluir(item);
                      },
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ==========================================================
  // RELATÓRIOS
  // ==========================================================

  List<ResumoMes> _resumosMensais() {
    final Map<String, Map<String, double>> mapa = {};

    for (final item in _movimentacoesFinanceirasPeriodo) {
      final chave =
          '${item.data.year}-${item.data.month}';

      mapa.putIfAbsent(
        chave,
        () => {
          'receitas': 0,
          'despesas': 0,
        },
      );

      if (item.tipo == TipoMovimentacao.receita) {
        mapa[chave]!['receitas'] =
            mapa[chave]!['receitas']! +
            item.centavos;
      } else {
        mapa[chave]!['despesas'] =
            mapa[chave]!['despesas']! +
            item.centavos;
      }
    }

    final lista = mapa.entries.map((entry) {
      final partes = entry.key.split('-');

      return ResumoMes(
        ano: int.parse(partes[0]),
        mes: int.parse(partes[1]),
        receitas: entry.value['receitas']! / 100,
        despesas: entry.value['despesas']! / 100,
      );
    }).toList();

    lista.sort((a, b) {
      final dataA = DateTime(a.ano, a.mes);
      final dataB = DateTime(b.ano, b.mes);

      return dataA.compareTo(dataB);
    });

    return lista;
  }

  Widget _graficoMensal() => GraficoFluxoMensal(dados: _resumosMensais());

  Future<void> _escolherPeriodosComparacao() async {
    final hoje = DateTime.now();
    var periodoA = _comparacaoA;
    var periodoB = _comparacaoB;
    final escolha = await showDialog<(DateTimeRange, DateTimeRange)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, atualizar) {
          String rotulo(DateTimeRange? periodo) => periodo == null
              ? 'Escolher datas'
              : '${_dataFormatada(periodo.start)} – ${_dataFormatada(periodo.end)}';
          Future<void> escolher(bool primeiro) async {
            final intervalo = await showDateRangePicker(
              context: context,
              locale: const Locale('pt', 'BR'),
              helpText: primeiro ? 'Período A' : 'Período B (base da comparação)',
              firstDate: DateTime(2000),
              lastDate: DateTime(2100, 12, 31),
              initialDateRange: (primeiro ? periodoA : periodoB) ??
                  DateTimeRange(start: DateTime(hoje.year, hoje.month), end: hoje),
            );
            if (!context.mounted || intervalo == null) return;
            atualizar(() {
              if (primeiro) {
                periodoA = intervalo;
              } else {
                periodoB = intervalo;
              }
            });
          }
          return AlertDialog(
            title: const Text('Escolher períodos'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Período A'),
                  OutlinedButton(onPressed: () => escolher(true), child: Text(rotulo(periodoA))),
                  const SizedBox(height: 16),
                  const Text('Período B • base da comparação'),
                  OutlinedButton(onPressed: () => escolher(false), child: Text(rotulo(periodoB))),
                  const SizedBox(height: 12),
                  const Text('Compare meses, trimestres ou quaisquer intervalos.'),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
              FilledButton(
                onPressed: periodoA == null || periodoB == null ? null
                    : () => Navigator.pop(dialogContext, (periodoA!, periodoB!)),
                child: const Text('Comparar'),
              ),
            ],
          );
        },
      ),
    );
    if (!mounted || escolha == null) return;
    setState(() {
      _comparacaoA = escolha.$1;
      _comparacaoB = escolha.$2;
    });
  }

  Widget _comparacaoPeriodos() {
    final hoje = DateTime.now();
    DateTime inicio;
    DateTime fim;
    DateTime anterior;
    final livre = _comparacaoA != null && _comparacaoB != null;
    DateTime fimAnterior;
    Widget controles() => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(
          onPressed: _escolherPeriodosComparacao,
          child: const Text('Escolher períodos'),
        ),
        if (livre)
          TextButton(
            onPressed: () => setState(() {
              _comparacaoA = null;
              _comparacaoB = null;
            }),
            child: const Text('Período anterior'),
          ),
      ],
    );
    if (livre) {
      inicio = _inicioDoDia(_comparacaoA!.start);
      final ultimoA = _comparacaoA!.end;
      fim = DateTime(ultimoA.year, ultimoA.month, ultimoA.day + 1);
      anterior = _inicioDoDia(_comparacaoB!.start);
      final ultimoB = _comparacaoB!.end;
      fimAnterior = DateTime(ultimoB.year, ultimoB.month, ultimoB.day + 1);
    } else {
    switch (_periodoFiltro) {
      case PeriodoFiltro.todos:
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Comparação de períodos', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('Escolha dois intervalos ou selecione um mês, ano ou intervalo no filtro acima para comparar com o período anterior.'),
                const SizedBox(height: 12),
                controles(),
              ],
            ),
          ),
        );
      case PeriodoFiltro.esteMes:
        inicio = DateTime(hoje.year, hoje.month);
        fim = DateTime(hoje.year, hoje.month + 1);
        anterior = DateTime(hoje.year, hoje.month - 1);
        break;
      case PeriodoFiltro.mesPassado:
        inicio = DateTime(hoje.year, hoje.month - 1);
        fim = DateTime(hoje.year, hoje.month);
        anterior = DateTime(hoje.year, hoje.month - 2);
        break;
      case PeriodoFiltro.esteAno:
        inicio = DateTime(hoje.year);
        fim = DateTime(hoje.year + 1);
        anterior = DateTime(hoje.year - 1);
        break;
      case PeriodoFiltro.personalizado:
        if (_inicioPersonalizado == null || _fimPersonalizado == null) {
          return const SizedBox.shrink();
        }
        inicio = _inicioDoDia(_inicioPersonalizado!);
        final ultimo = _fimPersonalizado!;
        fim = DateTime(ultimo.year, ultimo.month, ultimo.day + 1);
        final dias = DateTime.utc(fim.year, fim.month, fim.day)
            .difference(DateTime.utc(inicio.year, inicio.month, inicio.day)).inDays;
        anterior = DateTime(inicio.year, inicio.month, inicio.day - dias);
        break;
    }

    fimAnterior = inicio;
    }

    final atuais = _movimentacoes.where((m) => m.contabilizavel).where((m) =>
        !m.data.isBefore(inicio) && m.data.isBefore(fim)).toList();
    final anteriores = _movimentacoes.where((m) => m.contabilizavel).where((m) =>
        !m.data.isBefore(anterior) && m.data.isBefore(fimAnterior)).toList();
    double total(List<Movimentacao> itens, TipoMovimentacao tipo) =>
        itens.where((m) => m.tipo == tipo).fold(0.0, (soma, m) => soma + m.valor);
    final receita = total(atuais, TipoMovimentacao.receita);
    final despesa = total(atuais, TipoMovimentacao.despesa);
    final receitaAntes = total(anteriores, TipoMovimentacao.receita);
    final despesaAntes = total(anteriores, TipoMovimentacao.despesa);
    String datas(DateTime de, DateTime ate) =>
        '${_dataFormatada(de)} – ${_dataFormatada(DateTime(ate.year, ate.month, ate.day - 1))}';

    String nomeIntervalo(DateTime de, DateTime ate) {
      const meses = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
        'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
      final ultimo = DateTime(ate.year, ate.month, ate.day - 1);
      if (de.day == 1 && ate.day == 1 && de.year == ultimo.year && de.month == ultimo.month) {
        return '${meses[de.month - 1]} ${de.year}';
      }
      return datas(de, ate);
    }
    int dias(DateTime de, DateTime ate) => DateTime.utc(ate.year, ate.month, ate.day)
        .difference(DateTime.utc(de.year, de.month, de.day)).inDays;
    final labelA = livre ? 'A' : 'Selecionado';
    final labelB = livre ? 'B' : 'Anterior';
    Widget linha(String titulo, double atual, double antes, {bool saldo = false}) {
      final diferenca = atual - antes;
      final igual = diferenca.abs() < 0.005;
      String variacao = igual
          ? 'Sem variação'
          : '${diferenca > 0 ? '+' : '−'}${_dinheiro(diferenca.abs())}';
      if (antes > 0.005) {
        final percentual = diferenca / antes * 100;
        variacao += ' (${percentual > 0 ? '+' : ''}${percentual.toStringAsFixed(1).replaceAll('.', ',')}%)';
      } else if (!igual) {
        variacao += saldo && antes < 0
            ? ' • saldo anterior negativo; percentual não exibido'
            : ' • sem base para percentual';
      }
      if (anteriores.isEmpty) variacao = 'Sem registros no período $labelB';
      if (atuais.isEmpty) variacao = 'Sem registros no período $labelA';
      final temBase = anteriores.isNotEmpty && atuais.isNotEmpty;
      final destaque = !temBase || igual ? const Color(0xFF626A70)
          : diferenca < 0 ? const Color(0xFFB63838) : const Color(0xFF17804E);
      final corGrafico = titulo == 'Despesas'
          ? const Color(0xFFD86B69) : const Color(0xFF49A879);
      const meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
      String legenda(DateTime de, DateTime ate) {
        final ultimo = DateTime(ate.year, ate.month, ate.day - 1);
        return de.year == ultimo.year && de.month == ultimo.month
            ? '${meses[de.month - 1]} ${de.year}'
            : '${meses[de.month - 1]} ${de.year} – ${meses[ultimo.month - 1]} ${ultimo.year}';
      }
      final porDia = <DateTime, double>{};
      for (final m in atuais) {
        if (!saldo && m.tipo != (titulo == 'Receitas' ? TipoMovimentacao.receita : TipoMovimentacao.despesa)) continue;
        final dia = DateTime(m.data.year, m.data.month, m.data.day);
        porDia[dia] = (porDia[dia] ?? 0) + (saldo && m.tipo == TipoMovimentacao.despesa ? -m.valor : m.valor);
      }
      final pontos = <double>[];
      for (var dia = inicio; dia.isBefore(fim); dia = DateTime(dia.year, dia.month, dia.day + 1)) {
        pontos.add(porDia[dia] ?? 0);
      }
      final textoVariacao = !temBase ? 'Sem dados para comparar'
          : igual ? 'Sem variação'
          : '${diferenca > 0 ? '↑ +' : '↓ −'}${_dinheiro(diferenca.abs())}'
            '${antes > 0.005 ? ' (${diferenca > 0 ? '+' : ''}${(diferenca / antes * 100).toStringAsFixed(1).replaceAll('.', ',')}%)' : ''}';
      final escalaCartao = MediaQuery.textScalerOf(context).scale(17) / 17;
      final alturaCartao = 340.0 + math.max(0.0, escalaCartao - 1.0) * 220;
      return AspectRatio(
        aspectRatio: 240 / alturaCartao,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 240, height: alturaCartao,
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.black, fontFamily: 'Roboto'),
                child: Column(children: [
                  const SizedBox(height: 20),
                  Text(saldo ? 'SALDO FINAL' : 'RESUMO DE ${titulo.toUpperCase()}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: FittedBox(child: Text(_dinheiro(atual),
                      style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w800))),
                  ),
                  const SizedBox(height: 5),
                  Text(legenda(inicio, fim), style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 8),
                  SizedBox(height: 46, width: 240, child: CustomPaint(
                    painter: _MiniGraficoComparacao(pontos, corGrafico, saldo))),
                  const Divider(height: 1, color: Color(0xFFE5E5E5)),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: FittedBox(child: Text('vs. ${_dinheiro(antes)}',
                      style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700))),
                  ),
                  const SizedBox(height: 5),
                  Text(legenda(anterior, fimAnterior), style: const TextStyle(fontSize: 15)),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                    child: Tooltip(
                      message: variacao,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                        decoration: BoxDecoration(color: destaque, borderRadius: BorderRadius.circular(22)),
                        child: FittedBox(child: Text(textoVariacao,
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600))),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
    }    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    const Text('Comparação de Períodos:',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: false, label: Text('Período anterior')),
                        ButtonSegment(value: true, label: Text('Personalizado')),
                      ],
                      selected: {livre},
                      onSelectionChanged: (selecao) {
                        if (selecao.first) {
                          _escolherPeriodosComparacao();
                        } else {
                          setState(() {
                            _comparacaoA = null;
                            _comparacaoB = null;
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Período A: ', style: TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: '${nomeIntervalo(inicio, fim)}  vs.  '),
                    const TextSpan(text: 'Período B: ', style: TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: nomeIntervalo(anterior, fimAnterior)),
                  ]),
                  textAlign: TextAlign.center,
                ),
                if (livre)
                  TextButton(onPressed: _escolherPeriodosComparacao, child: const Text('Alterar datas')),
              ]),
            ),
            if (dias(inicio, fim) != dias(anterior, fimAnterior))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: const Color(0xFF3C3020),
                child: Text(
                  '*Os intervalos têm durações diferentes: ${dias(inicio, fim)} vs. ${dias(anterior, fimAnterior)} dias.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFFFD18D)),
                ),
              ),
            if (hoje.isBefore(fim) || hoje.isBefore(fimAnterior))
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Um dos períodos ainda está em andamento.', textAlign: TextAlign.center),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: linha('Receitas', receita, receitaAntes)),
          const SizedBox(width: 6),
          Expanded(child: linha('Despesas', despesa, despesaAntes)),
          const SizedBox(width: 6),
          Expanded(child: linha('Saldo do período', receita - despesa, receitaAntes - despesaAntes, saldo: true)),
        ],
      ),
      ],
    );
  }

  int _rankingAnual = 0;

  Widget _visaoAnual() {
    const meses = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
    const abreviados = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    const verde = Color(0xFF26845B);
    const vermelho = Color(0xFFC45454);
    final cor = Theme.of(context).colorScheme;
    final anos = {DateTime.now().year, _anoAnalise,
      ..._movimentacoes.map((m) => m.data.year)}.toList()
      ..sort((a, b) => b.compareTo(a));
    final receitasCentavos = List<int>.filled(12, 0);
    final despesasCentavos = List<int>.filled(12, 0);
    final registros = List<int>.filled(12, 0);
    for (final m in _movimentacoes.where((m) => m.contabilizavel && m.data.year == _anoAnalise)) {
      final i = m.data.month - 1;
      registros[i]++;
      if (m.tipo == TipoMovimentacao.receita) { receitasCentavos[i] += m.centavos; }
      else { despesasCentavos[i] += m.centavos; }
    }
    final receitas = List<double>.generate(12, (i) => receitasCentavos[i] / 100);
    final despesas = List<double>.generate(12, (i) => despesasCentavos[i] / 100);
    final saldos = List<double>.generate(12, (i) => (receitasCentavos[i] - despesasCentavos[i]) / 100);
    final valores = [despesas, receitas, saldos][_rankingAnual];
    final ranking = List<int>.generate(12, (i) => i)
        .where((i) => registros[i] > 0).toList()
      ..sort((a, b) {
        final ordem = valores[b].compareTo(valores[a]);
        return ordem == 0 ? a.compareTo(b) : ordem;
      });
    final maximo = [...receitas, ...despesas].fold(0.0, math.max);
    double soma(List<double> itens) => itens.fold<int>(0, (a, b) => a + (b * 100).round()) / 100;
    Widget resumo(String titulo, double valor, Color destaque) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cor.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo, style: TextStyle(color: cor.onSurfaceVariant)),
        const SizedBox(height: 6),
        Text(_dinheiro(valor), style: TextStyle(fontSize: 20,
          fontWeight: FontWeight.w700, color: destaque)),
      ]),
    );
    Widget legenda(String texto, Color destaque) => Row(mainAxisSize: MainAxisSize.min,
      children: [Icon(Icons.square_rounded, size: 10, color: destaque),
        const SizedBox(width: 6), Text(texto)]);
    Widget barra(double valor, Color destaque) => LayoutBuilder(
      builder: (context, constraints) => Align(alignment: Alignment.centerLeft,
        child: Container(height: 7,
          width: maximo <= 0 ? 0 : constraints.maxWidth * (valor / maximo).clamp(0.0, 1.0),
          decoration: BoxDecoration(color: destaque, borderRadius: BorderRadius.circular(4)))),
    );
    void detalhes(int i) {
      showModalBottomSheet<void>(context: context, showDragHandle: true,
        builder: (context) => SafeArea(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${meses[i]} $_anoAnalise', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              if (registros[i] == 0) const Text('Sem registros neste mês.')
              else ...[
                resumo('Receitas', receitas[i], verde),
                resumo('Despesas', despesas[i], vermelho),
                resumo('Saldo', saldos[i], saldos[i] < 0 ? vermelho : cor.primary),
              ],
            ]))));
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: cor.surfaceContainerLow, borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Visão anual', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          key: ValueKey(_anoAnalise), initialValue: _anoAnalise,
          decoration: const InputDecoration(labelText: 'Ano'),
          items: anos.map((ano) => DropdownMenuItem(value: ano, child: Text('$ano'))).toList(),
          onChanged: (ano) { if (ano != null) setState(() => _anoAnalise = ano); },
        ),
        const SizedBox(height: 10),
        Text('Janeiro a dezembro • independente do filtro acima',
          style: TextStyle(fontSize: 12, color: cor.onSurfaceVariant)),
        const SizedBox(height: 16),
        resumo('Receitas do ano', soma(receitas), verde),
        const SizedBox(height: 8),
        resumo('Despesas do ano', soma(despesas), vermelho),
        const SizedBox(height: 8),
        resumo('Saldo do ano', soma(saldos), soma(saldos) < 0 ? vermelho : cor.primary),
        const SizedBox(height: 24),
        const Text('Receitas x Despesas', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(spacing: 16, runSpacing: 8, children: [legenda('Receitas', verde), legenda('Despesas', vermelho)]),
        const SizedBox(height: 8),
        Text('Mesma escala para os 12 meses. Toque para ver os valores.',
          style: TextStyle(fontSize: 12, color: cor.onSurfaceVariant)),
        const SizedBox(height: 12),
        for (var i = 0; i < 12; i++)
          Semantics(button: true,
            label: '${meses[i]}: ${registros[i] == 0 ? 'sem registros' : 'receitas ${_dinheiro(receitas[i])}, despesas ${_dinheiro(despesas[i])}'}',
            child: InkWell(onTap: () => detalhes(i), borderRadius: BorderRadius.circular(8),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  SizedBox(width: 42, child: Text(abreviados[i], style: const TextStyle(fontSize: 12))),
                  Expanded(child: registros[i] == 0
                    ? Text('— Sem registros', style: TextStyle(fontSize: 11, color: cor.onSurfaceVariant))
                    : Column(children: [barra(receitas[i], verde), const SizedBox(height: 4), barra(despesas[i], vermelho)])),
                ])))),
        const SizedBox(height: 24),
        const Text('Ranking dos meses', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < 3; i++) ChoiceChip(
            label: Text(['Despesas', 'Receitas', 'Saldo'][i]),
            selected: _rankingAnual == i, showCheckmark: false,
            onSelected: (_) => setState(() => _rankingAnual = i)),
        ]),
        const SizedBox(height: 10),
        Text('Do maior para o menor • somente meses com registros. Empates compartilham a posição.',
          style: TextStyle(fontSize: 12, color: cor.onSurfaceVariant)),
        const SizedBox(height: 12),
        if (ranking.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('Nenhuma movimentação neste ano. Selecione outro ano para analisar.')),
        for (var pos = 0; pos < ranking.length; pos++) ...[
          InkWell(onTap: () => detalhes(ranking[pos]),
            borderRadius: BorderRadius.circular(10),
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 36, child: Text('${ranking.indexWhere((i) => (valores[i] * 100).round() == (valores[ranking[pos]] * 100).round()) + 1}º',
                  style: TextStyle(fontWeight: FontWeight.w700, color: cor.primary))),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(meses[ranking[pos]], style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(_dinheiro(valores[ranking[pos]]), style: TextStyle(
                    color: _rankingAnual == 0 || valores[ranking[pos]] < 0 ? vermelho : verde,
                    fontWeight: FontWeight.w700)),
                ])),
                const Icon(Icons.chevron_right, size: 20),
              ]))),
          if (pos < ranking.length - 1) const Divider(height: 1),
        ],
        const SizedBox(height: 12),
        Text('Meses em andamento podem ter dados parciais. Os valores refletem os lançamentos cadastrados.',
          style: TextStyle(fontSize: 12, color: cor.onSurfaceVariant)),
      ]),
    );
  }


  Widget _graficoDespesas({bool compacto = false}) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _periodoDoGrafico(),
    GraficoDespesasAlternavel(
    periodo: _periodoExplicito,
    movimentos: _movimentacoesPeriodo,
    contas: _contasGrafico,
    coresCategorias: {for (final c in _categoriasBanco.where((c) => c.tipo == TipoMovimentacao.despesa)) c.nome: c.cor},
    modo: _agrupamentoDespesa,
    onModo: (modo) => setState(() { _agrupamentoDespesa = modo; }),
    compacto: compacto,
    onVerTudo: () => setState(() { _paginaAtual = 2; }),
  ),
  const SizedBox(height: 8),
  _acoesRevisao(),
  ]);

  Widget _relatorios() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        const Text(
          'Relatórios',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          _nomePeriodoAtual,
          style: const TextStyle(
            color: Colors.grey,
          ),
        ),

        const SizedBox(height: 14),

        _seletorPeriodo(),

        const SizedBox(height: 24),

        _avisoDesativadas(),
        _graficoMensal(),
        const SizedBox(height: 24),

        if (_movimentacoesPeriodo.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: CardResumo(
                  titulo: 'Receitas',
                  valor: _dinheiro(_receitas),
                  icone: Icons.trending_up,
                  cor: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CardResumo(
                  titulo: 'Despesas',
                  valor: _dinheiro(_despesas),
                  icone: Icons.trending_down,
                  cor: Colors.red,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          CardResumo(
            titulo: 'Saldo do período',
            valor: _dinheiro(_saldo),
            icone:
                Icons.account_balance_wallet_outlined,
            cor: const Color(0xFF6750A4),
          ),

          const SizedBox(height: 24),

          const Text('Despesas', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _graficoDespesas(),

          const SizedBox(height: 20),

        ],

        _comparacaoPeriodos(),
        const SizedBox(height: 20),
        _visaoAnual(),
        const SizedBox(height: 24),

        if (_movimentacoesPeriodo.isEmpty)
          const EstadoVazio(
            icone: Icons.bar_chart,
            titulo: 'Sem dados para analisar',
            subtitulo:
                'Cadastre movimentações ou selecione outro período.',
          ),


        const SizedBox(height: 100),
      ],
    );
  }
}

class TelaDetalhesCategoria extends StatelessWidget {
  const TelaDetalhesCategoria({
    super.key,
    required this.categoria,
    required this.movimentacoes,
    this.periodo = 'Todo o período',
    this.agrupamento = 'Por categoria',
  });

  final String categoria;
  final String periodo, agrupamento;
  final List<Movimentacao> movimentacoes;

  String _dataFormatada(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';
  }

  String _dinheiro(double valor) {
    final partes = valor.toStringAsFixed(2).split('.');
    final inteira = partes[0];
    final decimal = partes[1];

    final buffer = StringBuffer();

    for (int i = 0; i < inteira.length; i++) {
      final restante = inteira.length - i;
      buffer.write(inteira[i]);

      if (restante > 1 && restante % 3 == 1) {
        buffer.write('.');
      }
    }

    return 'R\$ ${buffer.toString()},$decimal';
  }

  @override
  Widget build(BuildContext context) {
    final total = movimentacoes.fold<double>(
      0,
      (soma, item) => soma + item.valor,
    );

    final ordenadas = [...movimentacoes]
      ..sort((a, b) => b.data.compareTo(a.data));

    return Scaffold(
      appBar: AppBar(
        title: Text(categoria),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('$agrupamento • $categoria'),
          Text(periodo),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total gasto',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _dinheiro(total),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${movimentacoes.length} '
                  '${movimentacoes.length == 1 ? 'movimentação' : 'movimentações'}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Movimentações',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 12),

          ...ordenadas.map(
            (item) => Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE8E6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.arrow_downward,
                    color: Colors.red,
                  ),
                ),
                title: Text(
                  item.descricao.isEmpty
                      ? item.categoria
                      : item.descricao,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  _dataFormatada(item.data),
                ),
                trailing: Text(
                  '- ${_dinheiro(item.valor)}',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// FORMULÁRIO
// ============================================================

class TelaFormulario extends StatefulWidget {
  const TelaFormulario({
    super.key,
    required this.categorias,
    this.movimentacao,
    this.tipoInicial,
  });

  final List<Categoria> categorias;
  final Movimentacao? movimentacao;
  final TipoMovimentacao? tipoInicial;

  @override
  State<TelaFormulario> createState() =>
      _TelaFormularioState();
}

class _TelaFormularioState
    extends State<TelaFormulario> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController
      _valorController;

  late final TextEditingController
      _descricaoController;

  late TipoMovimentacao _tipo;
  late String _categoria;
  late DateTime _data;

  bool get _editando =>
      widget.movimentacao != null;

  List<Categoria> get _categoriasDoTipo {
  return widget.categorias
      .where(
        (categoria) => categoria.tipo == _tipo,
      )
      .toList();
}

  @override
  void initState() {
    super.initState();

    final item = widget.movimentacao;

    _tipo =
        item?.tipo ?? widget.tipoInicial ??
        TipoMovimentacao.despesa;

    final categoriasDoTipo = widget.categorias
    .where(
      (categoria) => categoria.tipo == _tipo,
    )
    .toList();

_categoria =
    item?.categoria ??
    (categoriasDoTipo.isEmpty ? '' : widget.tipoInicial == null
        ? categoriasDoTipo.first.nome
        : categoriasDoTipo.firstWhere(
            (categoria) => categoria.nome.trim().toLowerCase() == 'outros',
            orElse: () => categoriasDoTipo.firstWhere(
              (categoria) => categoria.padrao && categoria.codigoIcone ==
                  (_tipo == TipoMovimentacao.receita
                      ? Icons.add_circle_outline.codePoint
                      : Icons.more_horiz.codePoint),
              orElse: () => categoriasDoTipo.first,
            ),
          ).nome);

    _data =
        item?.data ??
        DateUtils.dateOnly(DateTime.now());

    _valorController =
        TextEditingController(
      text: item == null
          ? ''
          : item.valor
              .toStringAsFixed(2)
              .replaceAll('.', ','),
    );

    _descricaoController =
        TextEditingController(
      text: item?.descricao ?? '',
    );
  }

  @override
  void dispose() {
    _valorController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final selecionada =
        await showDatePicker(
      context: context,
      locale: const Locale("pt", "BR"),
      initialDate: _data,
      firstDate: DateTime(math.min(2000, _data.year)),
      lastDate: DateTime(math.max(2100, _data.year), 12, 31),
    );

    if (mounted && selecionada != null) {
      setState(() {
        _data = selecionada;
      });
    }
  }

  void _salvar() {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    var textoValor =
        _valorController.text.trim();

    if (textoValor.contains(',')) {
      textoValor = textoValor
          .replaceAll('.', '')
          .replaceAll(',', '.');
    }

    final valor =
        double.tryParse(textoValor);

    if (valor == null || !valor.isFinite || !(valor * 100).isFinite || valor <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Informe um valor válido.',
          ),
        ),
      );

      return;
    }

    Navigator.pop(
      context,
      Movimentacao(
        id: widget.movimentacao?.id,
        ativa: widget.movimentacao?.ativa ?? true,
        contaId: widget.movimentacao?.contaId,
        importacaoId: widget.movimentacao?.importacaoId,
        transferenciaPar: widget.movimentacao?.transferenciaPar,
        tipo: _tipo,
        valor: valor,
        categoria: _categoria,
        descricao:
            _descricaoController.text.trim(),
        data: _data,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editando
              ? 'Editar movimentação'
              : 'Nova movimentação',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SegmentedButton<
                TipoMovimentacao>(
              segments: const [
                ButtonSegment(
                  value:
                      TipoMovimentacao.receita,
                  icon: Icon(
                    Icons.arrow_upward,
                  ),
                  label: Text('Receita'),
                ),
                ButtonSegment(
                  value:
                      TipoMovimentacao.despesa,
                  icon: Icon(
                    Icons.arrow_downward,
                  ),
                  label: Text('Despesa'),
                ),
              ],
              selected: {_tipo},
              onSelectionChanged: (selecionado) {
  setState(() {
    _tipo = selecionado.first;

    final categoriasDisponiveis =
        _categoriasDoTipo;

    final categoriaAindaValida =
        categoriasDisponiveis.any(
      (categoria) =>
          categoria.nome == _categoria,
    );

    if (!categoriaAindaValida &&
        categoriasDisponiveis.isNotEmpty) {
      _categoria =
          categoriasDisponiveis.first.nome;
    }
  });
},
            ),

            const SizedBox(height: 24),

            TextFormField(
              controller:
                  _valorController,
              keyboardType:
                  const TextInputType
                      .numberWithOptions(
                decimal: true,
              ),
              decoration:
                  const InputDecoration(
                labelText: 'Valor',
                prefixText: 'R\$ ',
                prefixIcon: Icon(
                  Icons.attach_money,
                ),
              ),
              validator: (valor) {
                if (valor == null ||
                    valor.trim().isEmpty) {
                  return 'Informe o valor.';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller:
                  _descricaoController,
              textCapitalization:
                  TextCapitalization.sentences,
              decoration:
                  InputDecoration(
                labelText: widget.tipoInicial != null ? 'Descrição (opcional)' : 'Descrição',
                hintText:
                    'Ex.: Supermercado',
                prefixIcon: Icon(
                  Icons.description_outlined,
                ),
              ),
              validator: (valor) {
                if (widget.tipoInicial != null) return null;
                if (valor == null ||
                    valor.trim().isEmpty) {
                  return 'Informe uma descrição.';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              key: ValueKey(_tipo),
              initialValue: _categoriasDoTipo.any((c) => c.nome == _categoria) ? _categoria : null,
              validator: (v) => v == null || v.isEmpty ? 'Selecione uma categoria.' : null,
              decoration:
                  const InputDecoration(
                labelText: 'Categoria',
                prefixIcon: Icon(
                  Icons.category_outlined,
                ),
              ),

              items: _categoriasDoTipo.map(
  (categoria) {
    return DropdownMenuItem<String>(
      value: categoria.nome,
      child: Text(categoria.nome),
    );
  },
).toList(),
              onChanged: (categoria) {
                if (categoria != null) {
                  setState(() {
                    _categoria = categoria;
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            InkWell(
              borderRadius:
                  BorderRadius.circular(16),
              onTap: _selecionarData,
              child: Container(
                padding:
                    const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius:
                      BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(
                      0xFFE9E4EE,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        '${_data.day.toString().padLeft(2, '0')}/'
                        '${_data.month.toString().padLeft(2, '0')}/'
                        '${_data.year}',
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            FilledButton.icon(
              onPressed: _salvar,
              icon: const Icon(Icons.check),
              label: Text(
                _editando
                    ? 'Salvar alterações'
                    : 'Adicionar movimentação',
              ),
              style:
                  FilledButton.styleFrom(
                minimumSize:
                    const Size.fromHeight(
                  54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CARD RESUMO
// ============================================================

class CardResumo extends StatelessWidget {
  const CardResumo({
    super.key,
    required this.titulo,
    required this.valor,
    required this.icone,
    required this.cor,
    this.onAdicionar,
    this.comparacao,
  });

  final String titulo;
  final String valor;
  final IconData icone;
  final Color cor;
  final VoidCallback? onAdicionar;
  final String? comparacao;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icone, color: cor),
              if (onAdicionar != null)
                IconButton(
                  tooltip: titulo == 'Receitas' ? 'Adicionar receita' : 'Adicionar despesa',
                  onPressed: onAdicionar,
                  icon: const Icon(Icons.add_circle_outline),
                  color: cor,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            titulo,
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (comparacao != null) ...[
            const SizedBox(height: 8),
            Text(comparacao!, style: TextStyle(fontSize: 11, color: cor)),
          ],        ],
      ),
    );
  }
}

// ============================================================
// CARD MOVIMENTAÇÃO
// ============================================================

class CardMovimentacao extends StatelessWidget {
  const CardMovimentacao({
    super.key,
    required this.movimentacao,
    required this.dinheiro,
    required this.dataFormatada,
    required this.onEditar,
    required this.onExcluir,
    this.onAlternarContabilizacao,
    this.onSelecionar,
    this.selecionada = false,
    this.emSelecao = false,
  });

  final Movimentacao movimentacao;

  final String Function(double)
      dinheiro;

  final String Function(DateTime)
      dataFormatada;

  final VoidCallback onEditar;
  final VoidCallback onExcluir;
  final VoidCallback? onAlternarContabilizacao;
  final VoidCallback? onSelecionar;
  final bool selecionada, emSelecao;

  void _mostrarDetalhes(BuildContext context) {
    showModalBottomSheet<void>(context: context, isScrollControlled: true,
      builder: (context) => SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24), child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Detalhes da movimentação', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('${movimentacao.tipo == TipoMovimentacao.receita ? '+' : '-'} ${dinheiro(movimentacao.valor)}', style: const TextStyle(fontSize: 24)),
            Text('${movimentacao.categoria} • ${dataFormatada(movimentacao.data)}'),
            Text(movimentacao.ativa ? 'Contabilização ativa' : 'Contabilização desativada'),
            if (movimentacao.transferencia) const Text('Transferência entre contas: fora de receitas e despesas.'),
            const SizedBox(height: 20),
            const Text('Descrição original', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SelectableText(movimentacao.descricao),
            const SizedBox(height: 16),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
          ],
        ),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final receita =
        movimentacao.tipo ==
        TipoMovimentacao.receita;

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListTile(
        selected: selecionada,
        onLongPress: onSelecionar,
        onTap: emSelecao ? onSelecionar : () => _mostrarDetalhes(context),
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: emSelecao ? Checkbox(value: selecionada, onChanged: (_) => onSelecionar?.call()) : CircleAvatar(
          backgroundColor: receita
              ? Colors.green.withValues(
                  alpha: 0.12,
                )
              : Colors.red.withValues(
                  alpha: 0.12,
                ),
          child: Icon(
            receita
                ? Icons.arrow_upward
                : Icons.arrow_downward,
            color: receita
                ? Colors.green
                : Colors.red,
          ),
        ),
        title: Text(
          resumirDescricao(movimentacao.descricao),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight:
                FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${!movimentacao.ativa ? 'Contabilização desativada • ' : ''}${movimentacao.transferencia ? 'Transferência entre contas • ' : ''}${movimentacao.categoria} • '
          '${dataFormatada(movimentacao.data)}',
        ),
        trailing:
            PopupMenuButton<String>(
          enabled: !emSelecao,
          tooltip: 'Opções da movimentação',
          onSelected: (acao) {
            if (acao == 'contabilizacao') {
              onAlternarContabilizacao?.call();
            } else if (acao == 'editar') {
              onEditar();
            } else if (acao ==
                'excluir') {
              onExcluir();
            }
          },
          itemBuilder: (_) => [
            if (onAlternarContabilizacao != null)
              PopupMenuItem(value: 'contabilizacao', child: Row(children: [
                Icon(movimentacao.ativa ? Icons.pause_circle_outline : Icons.play_circle_outline),
                const SizedBox(width: 10),
                Expanded(child: Text(movimentacao.ativa ? 'Desativar contabilização' : 'Reativar contabilização')),
              ])),
            PopupMenuItem(
              value: 'editar',
              child: Row(
                children: [
                  Icon(
                    Icons.edit_outlined,
                  ),
                  SizedBox(width: 10),
                  Text('Editar'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'excluir',
              child: Row(
                children: [
                  Icon(
                    Icons.delete_outline,
                  ),
                  SizedBox(width: 10),
                  Text('Excluir'),
                ],
              ),
            ),
          ],
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              Text(
                '${receita ? '+' : '-'} '
                '${dinheiro(movimentacao.valor)}',
                style: TextStyle(
                  color: receita
                      ? Colors.green
                      : Colors.red,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Icon(
                Icons.more_horiz,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ESTADO VAZIO
// ============================================================

class EstadoVazio extends StatelessWidget {
  const EstadoVazio({
    super.key,
    required this.icone,
    required this.titulo,
    required this.subtitulo,
  });

  final IconData icone;
  final String titulo;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 50,
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              icone,
              size: 60,
              color:
                  Colors.grey.shade400,
            ),
            const SizedBox(height: 14),
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 300,
              ),
              child: Text(
                subtitulo,
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ============================================================
// REVISÃO DO EXTRATO IMPORTADO
// ============================================================

class TelaRevisaoExtrato extends StatefulWidget {
  const TelaRevisaoExtrato({
    super.key,
    this.nomeArquivo,
    required this.itens,
    required this.categorias,
    this.resultado,
    this.conta,
  });

  final String? nomeArquivo;
  final List<ItemExtrato> itens;
  final List<Categoria> categorias;
  final ResultadoImportacao? resultado;
  final ContaOrigem? conta;

  @override
  State<TelaRevisaoExtrato> createState() =>
      _TelaRevisaoExtratoState();
}

class _TelaRevisaoExtratoState
    extends State<TelaRevisaoExtrato> {

    bool _editandoCategorias = false;
  final Set<ItemExtrato> _itensParaCategorizar = {};

  void _alternarEdicaoCategorias() {
    setState(() {
      _editandoCategorias = !_editandoCategorias;
      _itensParaCategorizar.clear();
    });
  }

  String _categoriaFiltro = "Todas";

  TipoMovimentacao? _tipoFiltro;

PeriodoFiltro _periodoFiltroRevisao =
    PeriodoFiltro.todos;

DateTime? _inicioFiltroRevisao;
DateTime? _fimFiltroRevisao;

  String _dataFormatada(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';
  }

  String _dinheiro(double valor) {
    final partes = valor.toStringAsFixed(2).split('.');

    final inteira = partes[0];
    final decimal = partes[1];

    final buffer = StringBuffer();

    for (int i = 0; i < inteira.length; i++) {
      final restante = inteira.length - i;

      buffer.write(inteira[i]);

      if (restante > 1 && restante % 3 == 1) {
        buffer.write('.');
      }
    }

    return 'R\$ ${buffer.toString()},$decimal';
  }

  int get _quantidadeSelecionada {
    return widget.itens
        .where((item) => item.selecionado)
        .length;
  }

  bool _estaNoPeriodoRevisao(DateTime data) {
  final hoje = DateTime.now();

  DateTime? inicio;
  DateTime? fim;

  switch (_periodoFiltroRevisao) {
    case PeriodoFiltro.esteMes:
      inicio = DateTime(
        hoje.year,
        hoje.month,
        1,
      );

      fim = DateTime(
        hoje.year,
        hoje.month + 1,
        0,
        23,
        59,
        59,
        999,
      );
      break;

    case PeriodoFiltro.mesPassado:
      inicio = DateTime(
        hoje.year,
        hoje.month - 1,
        1,
      );

      fim = DateTime(
        hoje.year,
        hoje.month,
        0,
        23,
        59,
        59,
        999,
      );
      break;

    case PeriodoFiltro.esteAno:
      inicio = DateTime(
        hoje.year,
        1,
        1,
      );

      fim = DateTime(
        hoje.year,
        12,
        31,
        23,
        59,
        59,
        999,
      );
      break;

    case PeriodoFiltro.todos:
      return true;

    case PeriodoFiltro.personalizado:
      if (_inicioFiltroRevisao == null ||
          _fimFiltroRevisao == null) {
        return true;
      }

      inicio = DateTime(
        _inicioFiltroRevisao!.year,
        _inicioFiltroRevisao!.month,
        _inicioFiltroRevisao!.day,
      );

      fim = DateTime(
        _fimFiltroRevisao!.year,
        _fimFiltroRevisao!.month,
        _fimFiltroRevisao!.day,
        23,
        59,
        59,
        999,
      );
      break;
  }

  return !data.isBefore(inicio) &&
      !data.isAfter(fim);
}

  List<ItemExtrato> get _itensVisiveis {
  return widget.itens.where((item) {
    final categoriaOk =
        _categoriaFiltro == 'Todas' ||
        item.categoria == _categoriaFiltro;

    final tipoOk =
        _tipoFiltro == null ||
        item.tipo == _tipoFiltro;

    final periodoOk =
        _estaNoPeriodoRevisao(item.data);

    return categoriaOk &&
        tipoOk &&
        periodoOk;
  }).toList();
}

  Future<void> _mostrarAvisoRevisao(
    String titulo,
    String mensagem,
  ) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final cores = Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          backgroundColor: cores.primaryContainer,
          icon: Icon(
            Icons.info_outline,
            color: cores.onPrimaryContainer,
          ),
          title: Text(
            titulo,
            style: TextStyle(
              color: cores.onPrimaryContainer,
            ),
          ),
          content: SingleChildScrollView(
            child: Text(
              mensagem,
              style: TextStyle(
                color: cores.onPrimaryContainer,
              ),
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: cores.onPrimaryContainer,
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Entendi'),
            ),
          ],
        );
      },
    );
  }

    Future<void> _criarRegraDoItem(ItemExtrato item) async {
    int? categoriaId;

    for (final categoria in widget.categorias) {
      if (categoria.tipo == item.tipo &&
          categoria.nome == item.categoria) {
        categoriaId = categoria.id;
        break;
      }
    }

    if (item.conflitoDeRegras) {
      await _mostrarAvisoRevisao(
        'Escolha a categoria primeiro',
        'Resolva o conflito de categorias deste item '
        'antes de criar uma nova regra.',
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaRegrasImportacao(
          regraInicial: {
            'texto': item.descricao,
            'tipo': item.tipo.name,
            'categoria_id': categoriaId,
          },
        ),
      ),
    );
  }

  Future<void> _categorizarSelecionados() async {
    final itens = _itensParaCategorizar.toList();

    if (itens.isEmpty) {
      await _mostrarAvisoRevisao(
        'Nenhuma movimentação selecionada',
        'Marque as movimentações que deseja categorizar.',
      );
      return;
    }

    final tipo = itens.first.tipo;

    if (itens.any((item) => item.tipo != tipo)) {
      await _mostrarAvisoRevisao(
        'Selecione apenas um tipo',
        'Para alterar a categoria em grupo, selecione '
        'somente entradas ou somente saídas.\n\n'
        'Use o filtro Tipo para facilitar a seleção.',
      );
      return;
    }

    final nomes = widget.categorias
        .where((categoria) => categoria.tipo == tipo)
        .map((categoria) => categoria.nome)
        .toSet()
        .toList()
      ..sort();

        if (nomes.isEmpty) {
      await _mostrarAvisoRevisao(
        'Nenhuma categoria disponível',
        'Crie uma categoria para esse tipo de movimentação '
        'antes de continuar.',
      );
      return;
    }

    final categoria = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(
                  'Categoria para ${itens.length} movimentações',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'A escolha será aplicada a todos os itens '
                  'selecionados para edição, inclusive os '
                  'ocultos pelos filtros.',
                ),
              ),
              ...nomes.map(
                (nome) => ListTile(
                  title: Text(nome),
                  onTap: () {
                    Navigator.pop(sheetContext, nome);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || categoria == null) return;

    setState(() {
      for (final item in itens) {
        item.categoria = categoria;
        item.conflitoDeRegras = false;
      }

      _itensParaCategorizar.clear();
      _editandoCategorias = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${itens.length} movimentações alteradas para $categoria.',
        ),
      ),
    );
  }

  void _selecionarTodos(bool valor) {
    setState(() {
      for (final item in _itensVisiveis) {
        if (_editandoCategorias) {
          if (valor) {
            _itensParaCategorizar.add(item);
          } else {
            _itensParaCategorizar.remove(item);
          }
        } else {
          item.selecionado = valor;
        }
      }
    });
  }

    Future<void> _confirmar() async {
    final selecionados = widget.itens
        .where((item) => item.selecionado)
        .toList();

    if (selecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selecione pelo menos uma movimentação.',
          ),
        ),
      );

      return;
    }

    final conflitos = selecionados
        .where((item) => item.conflitoDeRegras)
        .length;

    if (conflitos > 0) {
      await _mostrarAvisoRevisao(
        'Revise as categorias',
        '$conflitos movimentações selecionadas possuem '
        'regras indicando categorias diferentes.\n\n'
        'Escolha a categoria desses itens, individualmente '
        'ou em grupo, ou desmarque-os para não importar.\n\n'
        'Se algum item estiver oculto, ajuste os filtros '
        'para encontrá-lo.',
      );
      return;
    }

    final quantidadeSuspeita = selecionados
        .where((item) => item.possivelDuplicata)
        .length;

    if (quantidadeSuspeita > 0) {
      final importarMesmoAssim = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Possíveis duplicatas'),
            content: SingleChildScrollView(
              child: Text(
                quantidadeSuspeita == 1
                    ? 'Uma movimentação selecionada pode estar '
                        'duplicada.\n\n'
                        'Confira antes de continuar para evitar '
                        'contar o mesmo valor duas vezes. '
                        'Se for uma movimentação diferente, '
                        'você pode importá-la mesmo assim.'
                    : '$quantidadeSuspeita movimentações selecionadas '
                        'podem estar duplicadas.\n\n'
                        'Confira antes de continuar para evitar '
                        'contar os mesmos valores duas vezes. '
                        'Se forem movimentações diferentes, '
                        'você pode importá-las mesmo assim.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('Voltar e revisar'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Importar mesmo assim'),
              ),
            ],
          );
        },
      );

      if (!mounted || importarMesmoAssim != true) {
        return;
      }
    }

    if (!mounted) return;

    Navigator.pop(
      context,
      selecionados,
    );
  }

  String get _textoPeriodoFiltro {
  switch (_periodoFiltroRevisao) {
    case PeriodoFiltro.esteMes:
      return 'Este mês';
    case PeriodoFiltro.mesPassado:
      return 'Mês passado';
    case PeriodoFiltro.esteAno:
      return 'Este ano';
    case PeriodoFiltro.todos:
      return 'Período';
    case PeriodoFiltro.personalizado:
      if (_inicioFiltroRevisao == null ||
          _fimFiltroRevisao == null) {
        return 'Período';
      }

      return '${_dataFormatada(_inicioFiltroRevisao!)} - '
          '${_dataFormatada(_fimFiltroRevisao!)}';
  }
}

Future<void> _abrirFiltroCategoria() async {
  final nomes = widget.categorias
      .map((categoria) => categoria.nome)
      .toSet()
      .toList()
    ..sort();

  final selecionada = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: RadioGroup<String>(
          groupValue: _categoriaFiltro,
          onChanged: (valor) => Navigator.pop(context, valor),
          child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                'Categoria',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: Radio<String>(
                value: 'Todas',
              ),
              title: const Text('Todas'),
              onTap: () {
                Navigator.pop(context, 'Todas');
              },
            ),
            ...nomes.map(
              (nome) => ListTile(
                leading: Radio<String>(
                  value: nome,
                ),
                title: Text(nome),
                onTap: () {
                  Navigator.pop(context, nome);
                },
              ),
            ),
          ],
          ),
        ),
      );
    },
  );

  if (!mounted || selecionada == null) return;

  setState(() {
    _categoriaFiltro = selecionada;
  });
}

Future<void> _abrirFiltroTipo() async {
  final selecionado =
      await showModalBottomSheet<TipoMovimentacao?>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Tipo',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              title: const Text('Todos'),
              onTap: () {
                Navigator.pop(context, null);
              },
            ),
            ListTile(
              title: const Text('Entradas'),
              onTap: () {
                Navigator.pop(
                  context,
                  TipoMovimentacao.receita,
                );
              },
            ),
            ListTile(
              title: const Text('Saídas'),
              onTap: () {
                Navigator.pop(
                  context,
                  TipoMovimentacao.despesa,
                );
              },
            ),
          ],
        ),
      );
    },
  );

  if (!mounted) return;

  setState(() {
    _tipoFiltro = selecionado;
  });
}

Future<void> _abrirFiltroPeriodo() async {
  final selecionado =
      await showModalBottomSheet<PeriodoFiltro>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Período',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              title: const Text('Todo o período'),
              onTap: () {
                Navigator.pop(
                  context,
                  PeriodoFiltro.todos,
                );
              },
            ),
            ListTile(
              title: const Text('Este mês'),
              onTap: () {
                Navigator.pop(
                  context,
                  PeriodoFiltro.esteMes,
                );
              },
            ),
            ListTile(
              title: const Text('Mês passado'),
              onTap: () {
                Navigator.pop(
                  context,
                  PeriodoFiltro.mesPassado,
                );
              },
            ),
            ListTile(
              title: const Text('Este ano'),
              onTap: () {
                Navigator.pop(
                  context,
                  PeriodoFiltro.esteAno,
                );
              },
            ),
            ListTile(
              title: const Text('Personalizado'),
              onTap: () {
                Navigator.pop(
                  context,
                  PeriodoFiltro.personalizado,
                );
              },
            ),
          ],
        ),
      );
    },
  );

  if (!mounted || selecionado == null) return;

  if (selecionado == PeriodoFiltro.personalizado) {
    final intervalo = await showDateRangePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange:
          _inicioFiltroRevisao != null &&
                  _fimFiltroRevisao != null
              ? DateTimeRange(
                  start: _inicioFiltroRevisao!,
                  end: _fimFiltroRevisao!,
                )
              : null,
    );

    if (!mounted || intervalo == null) return;

    setState(() {
      _periodoFiltroRevisao =
          PeriodoFiltro.personalizado;
      _inicioFiltroRevisao = intervalo.start;
      _fimFiltroRevisao = intervalo.end;
    });

    return;
  }

  setState(() {
    _periodoFiltroRevisao = selecionado;
    _inicioFiltroRevisao = null;
    _fimFiltroRevisao = null;
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editandoCategorias
              ? 'Alterar categorias'
              : 'Revisar extrato',
        ),
        actions: [
          IconButton(
            tooltip: _editandoCategorias
                ? 'Cancelar edição em grupo'
                : 'Alterar categorias em grupo',
            icon: Icon(
              _editandoCategorias
                  ? Icons.close
                  : Icons.edit_note,
            ),
            onPressed: _alternarEdicaoCategorias,
          ),
        ],
        bottom: _editandoCategorias
            ? PreferredSize(
                preferredSize: const Size.fromHeight(64),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    'Marque os itens para alterar a categoria. '
                    'As marcações de importação serão mantidas.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            : null,
      ),

      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: Column(children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(
              16,
              8,
              16,
              8,
            ),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                                Row(
                  children: [
                    Icon(
                      Icons.fact_check_outlined,
                      color: Theme.of(context)
                          .colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.nomeArquivo == null ? 'Confira antes de importar' : 'Confira: ${widget.nomeArquivo}',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme.onPrimaryContainer,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                if (widget.resultado != null) ...[
                  Text('Formato detectado: ${widget.resultado!.banco.nome}'),
                  Text('Conta de origem: ${widget.conta?.rotulo ?? "Não informada"}'),
                  Text('Valores: ${widget.resultado!.decimal == "," ? "1.234,56" : "1,234.56"} • Datas: ${widget.resultado!.formatoData == "mda" ? "mês/dia/ano" : widget.resultado!.formatoData == "amd" ? "ano/mês/dia" : "dia/mês/ano"}'),
                  if (widget.resultado!.ocorrencias.isNotEmpty)
                    TextButton(onPressed: () => showDialog<void>(context: context, builder: (ctx) => AlertDialog(
                      title: const Text('Linhas não importadas'),
                      content: SizedBox(width: double.maxFinite, child: ListView.builder(shrinkWrap: true,
                        itemCount: widget.resultado!.ocorrencias.length,
                        itemBuilder: (_, i) { final o = widget.resultado!.ocorrencias[i];
                          return ListTile(title: Text('Linha ${o.linha}'), subtitle: Text(o.motivo)); })),
                      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar'))])),
                      child: Text('${widget.resultado!.ocorrencias.length} linhas descartadas — ver motivos')),
                  TextButton(onPressed: () => Navigator.pop(context, <ItemExtrato>[]), child: const Text('Ajustar colunas do arquivo')),
                ],
                Text(
                  '${widget.itens.length} movimentações encontradas',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme.onPrimaryContainer,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  '$_quantidadeSelecionada selecionadas para importação • ${widget.itens.where((i) => i.selecionado && !i.ativa).length} desativadas',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    _selecionarTodos(true);
                  },
                  icon: const Icon(
                    Icons.check_box_outlined,
                  ),
                  label: const Text(
                    'Selecionar todos',
                  ),
                ),


                TextButton(
                  onPressed: () {
                    _selecionarTodos(false);
                  },
                  child: const Text(
                    'Limpar seleção',
                  ),
                ),
              ],
            ),
          ),

          Padding(
  padding: const EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 8,
  ),
  child: Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      OutlinedButton.icon(
        icon: const Icon(
          Icons.category_outlined,
          size: 18,
        ),
        label: Text(
          _categoriaFiltro == 'Todas'
              ? 'Categoria'
              : _categoriaFiltro,
        ),
        onPressed: _abrirFiltroCategoria,
      ),
      OutlinedButton.icon(
        icon: const Icon(
          Icons.swap_vert,
          size: 18,
        ),
        label: Text(
          _tipoFiltro == null
              ? 'Tipo'
              : _tipoFiltro ==
                      TipoMovimentacao.receita
                  ? 'Entradas'
                  : 'Saídas',
        ),
        onPressed: _abrirFiltroTipo,
      ),
      OutlinedButton.icon(
        icon: const Icon(
          Icons.date_range_outlined,
          size: 18,
        ),
        label: Text(
          _textoPeriodoFiltro,
        ),
        onPressed: _abrirFiltroPeriodo,
      ),
    ],
  ),
),


          const Divider(),

          ])),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
            sliver: SliverList.builder(
              itemCount: _itensVisiveis.length,
              itemBuilder: (context, index) {
                final item = _itensVisiveis [index];

                final receita =
                    item.tipo ==
                    TipoMovimentacao.receita;

                return Card(
                  margin: const EdgeInsets.only(
                    bottom: 10,
                  ),
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      8,
                      8,
                      12,
                      12,
                    ),
                    child: Column(
                      children: [
                                                Align(
                          alignment: Alignment.centerRight,
                          child: PopupMenuButton<String>(
                            tooltip: 'Opções da movimentação',
                            icon: const Icon(Icons.more_vert),
                            onSelected: (opcao) async {
                              if (opcao == 'criar_regra') {
                                await _criarRegraDoItem(item);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem<String>(
                                value: 'criar_regra',
                                child: Text('Criar regra'),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Checkbox(
                              value: _editandoCategorias
                                  ? _itensParaCategorizar.contains(item)
                                  : item.selecionado,
                              onChanged: (valor) {
                                setState(() {
                                  if (_editandoCategorias) {
                                    if (valor == true) {
                                      _itensParaCategorizar.add(item);
                                    } else {
                                      _itensParaCategorizar.remove(item);
                                    }
                                  } else {
                                    item.selecionado = valor ?? false;
                                  }
                                });
                              },
                            ),

                            CircleAvatar(
                              backgroundColor: receita
                                  ? Colors.green.withValues(
                                      alpha: 0.12,
                                    )
                                  : Colors.red.withValues(
                                      alpha: 0.12,
                                    ),
                              child: Icon(
                                receita
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                color: receita
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.descricao,
                                    style: const TextStyle(
                                      fontWeight:
                                          FontWeight.w600,
                                    ),
                                  ),
                                  if (item.contabilizacaoSugerida != null) ...[
                                    const SizedBox(height: 8),
                                    Text('Sua preferência nesta conta: contabilização ${item.contabilizacaoSugerida! ? 'ativa' : 'desativada'}.'),
                                    const Text('Sugestão pela mesma descrição e tipo. Você decide se deseja aplicar.'),
                                    TextButton(
                                      onPressed: () => setState(() {
                                        item.ativa = item.contabilizacaoSugerida!;
                                        item.contabilizacaoSugerida = null;
                                      }),
                                      child: const Text('Aplicar sugestão'),
                                    ),
                                  ],
                                  if (item.possivelInvestimento || item.contabilizacaoSugerida != null || !item.ativa) ...[
                                    const SizedBox(height: 8),
                                    Text(item.possivelInvestimento ? 'Possível aplicação ou resgate. Deseja contabilizar nos totais?' : 'Incluir esta movimentação nos totais?'),
                                    SwitchListTile.adaptive(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('Contabilizar'),
                                      subtitle: Text(item.ativa ? 'Será incluída nos totais.' : 'Será importada desativada, mantendo o registro no histórico.'),
                                      value: item.ativa,
                                      onChanged: (valor) => setState(() => item.ativa = valor),
                                    ),
                                  ],
                                  if (item.conflitoDeRegras)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 6,
                                        bottom: 4,
                                      ),
                                      child: Text(
                                        'Regras indicam categorias diferentes. '
                                        'Escolha a categoria deste item '
                                        'antes de importar.',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme.error,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  if (item.possivelDuplicata)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 6,
                                        bottom: 4,
                                      ),
                                      child: Text(
                                        'Possível duplicata. '
                                        'Desmarque se já estiver registrada.',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme.error,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),

                                  const SizedBox(height: 4),

                                  Text(
                                    _dataFormatada(
                                      item.data,
                                    ),
                                    style: const TextStyle(
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Text(
                              '${receita ? '+' : '-'} '
                              '${_dinheiro(item.valor)}',
                              style: TextStyle(
                                color: receita
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        Row(
                          children: [
                            const SizedBox(width: 12),

                            const Icon(
                              Icons.category_outlined,
                              size: 20,
                              color: Colors.grey,
                            ),

                            const SizedBox(width: 10),

                            Expanded(
                              child: DropdownButton<String>(
                                value: widget.categorias
        .where(
          (categoria) =>
              categoria.tipo == item.tipo,
        )
        .any(
          (categoria) =>
              categoria.nome == item.categoria,
        )
    ? item.categoria
    : null,
                                isExpanded: true,
                                underline:
                                    const SizedBox.shrink(),
                                items: widget.categorias
    .where(
      (categoria) =>
          categoria.tipo == item.tipo,
    )
    .fold<Map<String, Categoria>>(
      {},
      (mapa, categoria) {
        mapa[categoria.nome] = categoria;
        return mapa;
      },
    )
    .values
    .map(
      (categoria) {
        return DropdownMenuItem<String>(
          value: categoria.nome,
          child: Text(
            categoria.nome,
          ),
        );
      },
    )
    .toList(),
                                onChanged: (categoria) {
                                  if (categoria == null) {
                                    return;
                                  }

                                  setState(() {
                                    item.categoria = categoria;
                                    item.conflitoDeRegras = false;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          16,
          8,
          16,
          16,
        ),
        child: FilledButton.icon(
          onPressed: _editandoCategorias
              ? (_itensParaCategorizar.isEmpty
                  ? null
                  : _categorizarSelecionados)
              : _confirmar,
          icon: Icon(
            _editandoCategorias
                ? Icons.category_outlined
                : Icons.file_download_done,
          ),
          label: Text(
            _editandoCategorias
                ? 'Categorizar ${_itensParaCategorizar.length} itens'
                : 'Importar $_quantidadeSelecionada movimentações',
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CONFIGURAÇÕES
// ============================================================

class TelaImportacoes extends StatefulWidget {
  const TelaImportacoes({super.key});

  @override
  State<TelaImportacoes> createState() =>
      _TelaImportacoesState();
}

class _TelaImportacoesState extends State<TelaImportacoes> {
  late Future<List<Map<String, dynamic>>> _consulta;
  bool _excluindo = false;

  @override
  void initState() {
    super.initState();
    _consulta = BancoDados.instancia.listarImportacoes();
  }

  void _recarregar() {
    setState(() {
      _consulta = BancoDados.instancia.listarImportacoes();
    });
  }

  String _formatarData(String valor) {
    final data = DateTime.parse(valor).toLocal();

    String dois(int numero) => numero.toString().padLeft(2, '0');

    return '${dois(data.day)}/${dois(data.month)}/${data.year}'
        ' às ${dois(data.hour)}:${dois(data.minute)}';
  }

  Future<void> _excluir(Map<String, dynamic> lote) async {
    if (_excluindo) return;

    setState(() {
      _excluindo = true;
    });

    try {
      final nome = lote['nome_arquivo'] as String;
      final quantidade = lote['quantidade_atual'] as int;

      final confirmar = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Excluir importação?'),
            content: Text(
              'Arquivo: $nome\n\n'
              'Serão excluídas as $quantidade movimentações '
              'que ainda pertencem a esta importação, '
              'inclusive as que você editou depois.\n\n'
              'As outras movimentações e suas categorias '
              'serão mantidas. O arquivo CSV não será apagado.\n\n'
              'Esta ação não pode ser desfeita.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Excluir importação'),
              ),
            ],
          );
        },
      );

      if (confirmar != true || !mounted) return;

      await BancoDados.instancia.excluirImportacao(
        lote['id'] as int,
      );

      if (!mounted) return;

      _recarregar();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Importação excluída.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível excluir a importação. '
            'Tente novamente.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _excluindo = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importações'),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Aqui aparecem as importações feitas após '
              'a atualização que passou a registrar os lotes. '
              'As importações anteriores não aparecem nesta lista.',
            ),
          ),
          if (_excluindo)
            const LinearProgressIndicator(),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _consulta,
              builder: (context, snapshot) {
                if (snapshot.connectionState !=
                    ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Não foi possível carregar as importações.',
                        ),
                        TextButton(
                          onPressed: _recarregar,
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  );
                }

                final lotes = snapshot.data ?? [];

                if (lotes.isEmpty) {
                  return const Center(
                    child: Text('Nenhuma importação registrada.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: lotes.length,
                  itemBuilder: (context, index) {
                    final lote = lotes[index];

                    return Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.description_outlined,
                        ),
                        title: Text(
                          lote['nome_arquivo'] as String,
                        ),
                        subtitle: Text(
                          '${_formatarData(lote['importado_em'] as String)}\n'
                          '${lote['conta_nome'] == null ? "Origem não identificada" : "${lote['banco_nome']} • ${lote['conta_nome']}"}\n'
                          '${lote['quantidade_atual']} movimentações atuais'
                          ' • ${lote['quantidade_original']} na importação',
                        ),
                        trailing: IconButton(
                          tooltip: 'Excluir importação',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _excluindo
                              ? null
                              : () => _excluir(lote),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TelaGerenciarDados extends StatefulWidget {
  const TelaGerenciarDados({super.key});

  @override
  State<TelaGerenciarDados> createState() =>
      _TelaGerenciarDadosState();
}

class _TelaGerenciarDadosState extends State<TelaGerenciarDados> {
  bool _restaurando = false;

  Future<void> _restaurar() async {
    if (_restaurando) return;

    setState(() {
      _restaurando = true;
    });

    try {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Restaurar perfil atual?'),
            content: const SingleChildScrollView(
              child: Text(
                'Todas as receitas, despesas, previsões da agenda e importações do perfil atual '
                'serão apagadas.\n\n'
                'As categorias personalizadas serão removidas. '
                'As categorias padrão voltarão aos nomes, '
                'ícones e cores originais.\n\n'
                'Os arquivos CSV do celular serão mantidos.\n\n'
                'Esta ação não pode ser desfeita.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      Theme.of(dialogContext).colorScheme.error,
                  foregroundColor:
                      Theme.of(dialogContext).colorScheme.onError,
                ),
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Apagar dados e restaurar'),
              ),
            ],
          );
        },
      );

      if (confirmar != true || !mounted) return;

      await BancoDados.instancia.restaurarAplicativo();
      try {
        await LembretesAgenda.atualizarAgendamentos();
      } catch (erro) {
        debugPrint('Dados restaurados; falha ao atualizar lembretes: $erro');
      }

      modoTema.value = ThemeMode.system;

      corTema.value = 'Roxo';
      tamanhoTexto.value = 'Padrão';

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Dados apagados e categorias padrão restauradas.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível restaurar o aplicativo. '
            'Tente novamente.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _restaurando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar dados'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              enabled: !_restaurando,
              leading: const Icon(Icons.description_outlined),
              title: const Text('Importações'),
              subtitle: const Text(
                'Veja e exclua extratos importados',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _restaurando
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TelaImportacoes(),
                        ),
                      );
                    },
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              enabled: !_restaurando,
              leading: Icon(
                Icons.restart_alt,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text('Restaurar perfil atual'),
              subtitle: const Text(
                'Apague os dados apenas do perfil em uso',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _restaurando ? null : _restaurar,
            ),
          ),
          if (_restaurando)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

class TelaAparencia extends StatefulWidget {
  const TelaAparencia({super.key});

  @override
  State<TelaAparencia> createState() => _TelaAparenciaState();
}

class _TelaAparenciaState extends State<TelaAparencia> {
  bool _salvando = false;

  Future<void> _selecionar(ThemeMode modo) async {
    if (_salvando || modoTema.value == modo) return;

    setState(() {
      _salvando = true;
    });

    try {
      await alterarModoTema(modo);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível salvar a aparência. '
            'Tente novamente.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _salvando = false;
        });
      }
    }
  }

    Future<void> _selecionarCor(String nome) async {
    if (_salvando || corTema.value == nome) return;

    setState(() {
      _salvando = true;
    });

    try {
      await alterarCorTema(nome);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível salvar a cor. Tente novamente.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _salvando = false;
        });
      }
    }
  }

  Future<void> _selecionarTamanho(String nome) async {
    if (_salvando || tamanhoTexto.value == nome) return;
    setState(() => _salvando = true);
    try {
      await alterarTamanhoTexto(nome);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar o tamanho do texto. Tente novamente.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }
  Widget _opcao({
    required ThemeMode modo,
    required ThemeMode atual,
    required String titulo,
    required String descricao,
    required IconData icone,
  }) {
    final selecionado = modo == atual;

    return Card(
      child: ListTile(
        enabled: !_salvando,
        leading: Icon(icone),
        title: Text(titulo),
        subtitle: Text(descricao),
        trailing: Icon(
          selecionado
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
          color: selecionado
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
          semanticLabel: selecionado
              ? 'Selecionado'
              : 'Não selecionado',
        ),
        onTap: _salvando ? null : () => _selecionar(modo),
      ),
    );
  }

  Widget _secaoAparencia(List<Widget> conteudo) {
    final cores = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cores.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cores.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: conteudo,
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aparência'),
      ),
      body: ValueListenableBuilder<ThemeMode>(
        valueListenable: modoTema,
        builder: (context, atual, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _secaoAparencia([
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Modo de aparência',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _opcao(
                modo: ThemeMode.system,
                atual: atual,
                titulo: 'Sistema',
                descricao: 'Acompanha a aparência do celular',
                icone: Icons.brightness_auto_outlined,
              ),
              _opcao(
                modo: ThemeMode.light,
                atual: atual,
                titulo: 'Claro',
                descricao: 'Mantém o aplicativo claro',
                icone: Icons.light_mode_outlined,
              ),
              _opcao(
                modo: ThemeMode.dark,
                atual: atual,
                titulo: 'Escuro',
                descricao: 'Mantém o aplicativo escuro',
                icone: Icons.dark_mode_outlined,
              ),
              ]),
              const SizedBox(height: 24),
              _secaoAparencia([
              const Text(
                'Cor do tema',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<String>(
                valueListenable: corTema,
                builder: (context, selecionada, child) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: coresTema.entries.map((opcao) {
                      return ChoiceChip(
                        avatar: CircleAvatar(
                          backgroundColor: opcao.value,
                          radius: 10,
                        ),
                        label: Text(opcao.key),
                        selected: selecionada == opcao.key,
                        onSelected: _salvando
                            ? null
                            : (_) => _selecionarCor(opcao.key),
                      );
                    }).toList(),
                  );
                },
              ),
              ]),
              const SizedBox(height: 24),
              _secaoAparencia([
              const Text(
                'Tamanho do texto',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Ajuste a leitura do aplicativo.'),
              const SizedBox(height: 12),
              ValueListenableBuilder<String>(
                valueListenable: tamanhoTexto,
                builder: (context, selecionado, child) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tamanhosTexto.keys.map((nome) => ChoiceChip(
                    label: Text(nome),
                    selected: selecionado == nome,
                    onSelected: _salvando ? null : (_) => _selecionarTamanho(nome),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 12),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Assim ficará o texto nas suas movimentações.'),
                ),
              ),
              ]),
              if (_salvando)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                ),
            ],
          );
        },
      ),
    );
  }
}

class TelaRegrasImportacao extends StatefulWidget {
  const TelaRegrasImportacao({
    super.key,
    this.regraInicial,
  });

  final Map<String, dynamic>? regraInicial;

  @override
  State<TelaRegrasImportacao> createState() =>
      _TelaRegrasImportacaoState();
}

class _TelaRegrasImportacaoState
    extends State<TelaRegrasImportacao> {
  late Future<List<Map<String, dynamic>>> _consulta;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    _consulta = BancoDados.instancia.listarRegrasImportacao();

    if (widget.regraInicial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        await _abrirFormularioRegra(
          regra: widget.regraInicial,
        );

        if (!mounted) return;

        if (ModalRoute.of(context)?.isCurrent == true) {
          Navigator.pop(context);
        }
      });
    }
  }

  void _recarregar() {
    setState(() {
      _consulta = BancoDados.instancia.listarRegrasImportacao();
    });
  }

    Future<void> _abrirFormularioRegra({
    Map<String, dynamic>? regra,
  }) async {
    if (_ocupado) return;

    setState(() {
      _ocupado = true;
    });

    try {
      final categorias = await BancoDados.instancia.listarCategorias();

      if (!mounted) return;

      String texto = regra?['texto'] as String? ?? '';
      TipoMovimentacao tipo = regra?['tipo'] == 'receita'
          ? TipoMovimentacao.receita
          : TipoMovimentacao.despesa;
      int? categoriaId = regra?['categoria_id'] as int?;

      if (!categorias.any(
        (categoria) =>
            categoria.id == categoriaId && categoria.tipo == tipo,
      )) {
        categoriaId = null;
      }

      bool salvando = false;
      String? mensagemErro;

      final salvo = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (formContext, atualizarFormulario) {
              final cores = Theme.of(formContext).colorScheme;
              final categoriasDoTipo = categorias
                  .where((categoria) => categoria.tipo == tipo)
                  .toList();

              return AlertDialog(
                backgroundColor: cores.surfaceContainerHigh,
                title: Text(
                  regra?['id'] == null ? 'Nova regra' : 'Editar regra',
                  style: TextStyle(color: cores.primary),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        initialValue: texto,
                        enabled: !salvando,
                        decoration: const InputDecoration(
                          labelText: 'Descrição contém',
                          hintText: 'Ex.: Academia Vida',
                        ),
                        onChanged: (valor) {
                          texto = valor;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<TipoMovimentacao>(
                        initialValue: tipo,
                        decoration: const InputDecoration(
                          labelText: 'Tipo',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: TipoMovimentacao.receita,
                            child: Text('Entrada'),
                          ),
                          DropdownMenuItem(
                            value: TipoMovimentacao.despesa,
                            child: Text('Saída'),
                          ),
                        ],
                        onChanged: salvando
                            ? null
                            : (valor) {
                                if (valor == null) return;

                                atualizarFormulario(() {
                                  tipo = valor;
                                  categoriaId = null;
                                  mensagemErro = null;
                                });
                              },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        key: ValueKey(tipo),
                        initialValue: categoriaId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Categoria',
                        ),
                        items: categoriasDoTipo.map((categoria) {
                          return DropdownMenuItem<int>(
                            value: categoria.id!,
                            child: Text(
                              categoria.nome,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: salvando
                            ? null
                            : (valor) {
                                atualizarFormulario(() {
                                  categoriaId = valor;
                                });
                              },
                      ),
                      if (categoriasDoTipo.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'Crie uma categoria desse tipo '
                            'em Configurações → Categorias.',
                          ),
                        ),
                      if (mensagemErro != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            mensagemErro!,
                            style: TextStyle(color: cores.error),
                          ),
                        ),
                      if (salvando)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: LinearProgressIndicator(),
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: salvando
                        ? null
                        : () => Navigator.pop(formContext, false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: salvando
                        ? null
                        : () async {
                            if (texto.trim().isEmpty ||
                                categoriaId == null) {
                              atualizarFormulario(() {
                                mensagemErro =
                                    'Preencha a descrição e escolha '
                                    'uma categoria.';
                              });
                              return;
                            }

                            atualizarFormulario(() {
                              salvando = true;
                              mensagemErro = null;
                            });

                            try {
                              await BancoDados.instancia
                                  .salvarRegraImportacao(
                                id: regra?['id'] as int?,
                                texto: texto,
                                tipo: tipo,
                                categoriaId: categoriaId!,
                              );

                              if (!formContext.mounted) return;

                              Navigator.pop(formContext, true);
                            } catch (_) {
                              if (!formContext.mounted) return;

                              atualizarFormulario(() {
                                salvando = false;
                                mensagemErro =
                                    'Não foi possível salvar. Verifique '
                                    'se já existe uma regra com esse '
                                    'texto e tipo e se a categoria '
                                    'continua disponível.';
                              });
                            }
                          },
                    child: const Text('Salvar regra'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (!mounted) return;

      if (salvo == true) {
        _recarregar();
      }
    } catch (_) {
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final cores = Theme.of(dialogContext).colorScheme;

          return AlertDialog(
            backgroundColor: cores.primaryContainer,
            title: Text(
              'Não foi possível abrir o formulário',
              style: TextStyle(color: cores.onPrimaryContainer),
            ),
            content: Text(
              'Tente novamente.',
              style: TextStyle(color: cores.onPrimaryContainer),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: cores.onPrimaryContainer,
                ),
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Entendi'),
              ),
            ],
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _ocupado = false;
        });
      }
    }
  }

  Future<void> _excluir(Map<String, dynamic> regra) async {
    if (_ocupado) return;

    setState(() {
      _ocupado = true;
    });

    try {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final cores = Theme.of(dialogContext).colorScheme;

          return AlertDialog(
            backgroundColor: cores.primaryContainer,
            title: Text(
              'Excluir regra?',
              style: TextStyle(color: cores.onPrimaryContainer),
            ),
            content: Text(
              'A regra para "${regra['texto']}" será removida.\n\n'
              'As movimentações já salvas e suas categorias '
              'não serão alteradas.',
              style: TextStyle(color: cores.onPrimaryContainer),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: cores.onPrimaryContainer,
                ),
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Excluir regra'),
              ),
            ],
          );
        },
      );

      if (confirmar != true || !mounted) return;

      await BancoDados.instancia.excluirRegraImportacao(
        regra['id'] as int,
      );

      if (!mounted) return;

      _recarregar();
    } catch (_) {
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final cores = Theme.of(dialogContext).colorScheme;

          return AlertDialog(
            backgroundColor: cores.primaryContainer,
            title: Text(
              'Não foi possível excluir',
              style: TextStyle(color: cores.onPrimaryContainer),
            ),
            content: Text(
              'Tente novamente.',
              style: TextStyle(color: cores.onPrimaryContainer),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: cores.onPrimaryContainer,
                ),
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Entendi'),
              ),
            ],
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _ocupado = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
            appBar: AppBar(
        title: const Text('Regras de importação'),
        actions: [
          IconButton(
            tooltip: 'Nova regra',
            icon: const Icon(Icons.add),
            onPressed: _ocupado
                ? null
                : () => _abrirFormularioRegra(),
          ),
        ],
      ),
                     body: Column(
        children: [
          if (_ocupado) const LinearProgressIndicator(),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _consulta,
              builder: (context, snapshot) {
                if (snapshot.connectionState !=
                    ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Não foi possível carregar as regras.'),
                        TextButton(
                          onPressed: _ocupado ? null : _recarregar,
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  );
                }

                final regras = snapshot.data ?? [];

                if (regras.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Nenhuma regra cadastrada.\n\n'
                        'As regras permitem escolher a categoria '
                        'pelo texto da descrição do extrato.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: regras.length,
                  itemBuilder: (context, index) {
                    final regra = regras[index];
                    final entrada = regra['tipo'] == 'receita';
                    final categoriaValida =
                        regra['categoria_nome'] != null &&
                        regra['categoria_tipo'] == regra['tipo'];

                    return Card(
                      child: ListTile(
                        leading: Icon(
                          entrada
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                        ),
                                                onTap: _ocupado
                            ? null
                            : () => _abrirFormularioRegra(regra: regra),
                        title: Text('Contém: ${regra['texto']}'),
                        subtitle: Text(
                          '${entrada ? 'Entrada' : 'Saída'}'
                          ' → ${regra['categoria_nome'] ?? 'Categoria removida'}'
                          '${categoriaValida ? '' : '\nRevise a categoria desta regra.'}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Excluir regra',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _ocupado
                              ? null
                              : () => _excluir(regra),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TelaConfiguracoes extends StatelessWidget {
  const TelaConfiguracoes({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Configurações',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _TituloConfiguracao(
            titulo: 'Personalização',
          ),

          _ItemConfiguracao(
            icone: Icons.palette_outlined,
            titulo: 'Aparência',
            subtitulo: 'Modo claro, escuro ou do sistema',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TelaAparencia(),
                ),
              );
            },
          ),

          _ItemConfiguracao(
            icone: Icons.category_outlined,
            titulo: 'Categorias',
            subtitulo: 'Crie e organize suas categorias',
            onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const TelaCategorias(),
    ),
  );
},
          ),

          const SizedBox(height: 24),

          const _TituloConfiguracao(
            titulo: 'Seus dados',
          ),

          _ItemConfiguracao(
            icone: Icons.account_balance_outlined,
            titulo: 'Contas/Bancos',
            subtitulo: 'Contas de origem dos extratos deste perfil',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
              TelaContas(banco: ContasBanco(BancoDados.instancia.database)))),
          ),
          _ItemConfiguracao(
            icone: Icons.description_outlined,
            titulo: 'Exportar e Relatórios',
            subtitulo: 'CSV, Excel e relatório financeiro em PDF',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
              TelaExportacao(database: BancoDados.instancia.database,
                perfil: CadastroPerfis.atual.value.nome, perfis: CadastroPerfis.listar,
                abrirPerfil: (perfil) => BancoDados.paraPerfil(perfil).database))),
          ),
          _ItemConfiguracao(
            icone: Icons.restore_from_trash_outlined,
            titulo: 'Lixeira',
            subtitulo: 'Recupere lançamentos excluídos nos últimos 30 dias',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
              TelaLixeira(banco: LixeiraBanco(BancoDados.instancia.database)))),
          ),
          _ItemConfiguracao(
            icone: Icons.fact_check_outlined,
            titulo: 'Preferências de contabilização',
            subtitulo: 'Revise sugestões salvas por conta e descrição',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
              TelaPreferenciasContabilizacao(banco: BancoDados.instancia))),
          ),
          _ItemConfiguracao(
            icone: Icons.rule_outlined,
            titulo: 'Regras de importação',
            subtitulo: 'Categorias automáticas pela descrição',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TelaRegrasImportacao(),
                ),
              );
            },
          ),

          _ItemConfiguracao(
            icone: Icons.storage_outlined,
            titulo: 'Gerenciar dados',
            subtitulo: 'Importações e restauração do aplicativo',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TelaGerenciarDados(),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          const _TituloConfiguracao(
            titulo: 'Sobre',
          ),

          _ItemConfiguracao(
            icone: Icons.info_outline,
            titulo: 'Sobre o Finanças Fácil',
            subtitulo: 'Informações sobre o aplicativo',
            onTap: () {
              showDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Finanças Fácil'),
                  content: const Text(
                    'Aplicativo para controle pessoal e profissional de receitas, '
                    'despesas, contas bancárias, importação de extratos CSV e '
                    'planejamento financeiro.\n\n'
                    'Seus dados financeiros permanecem armazenados localmente '
                    'no seu dispositivo.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Fechar'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TituloConfiguracao extends StatelessWidget {
  const _TituloConfiguracao({
    required this.titulo,
  });

  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8,
      ),
      child: Text(
        titulo,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ItemConfiguracao extends StatelessWidget {
  const _ItemConfiguracao({
    required this.icone,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  final IconData icone;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        leading: Icon(
          icone,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          titulo,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(subtitulo),
        trailing: const Icon(
          Icons.chevron_right,
        ),
        onTap: onTap,
      ),
    );
  }
}

class TelaCategorias extends StatefulWidget {
  const TelaCategorias({super.key});

  @override
  State<TelaCategorias> createState() => _TelaCategoriasState();
}

class _TelaCategoriasState extends State<TelaCategorias> {
  bool _carregando = true;
  List<Categoria> _categorias = [];

  @override
  void initState() {
    super.initState();
    _carregarCategorias();
  }

  Future<void> _carregarCategorias() async {
    final categorias =
        await BancoDados.instancia.listarCategorias();

    if (!mounted) return;

    setState(() {
      _categorias = categorias;
      _carregando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final despesas = _categorias
        .where(
          (categoria) =>
              categoria.tipo == TipoMovimentacao.despesa,
        )
        .toList();

    final receitas = _categorias
        .where(
          (categoria) =>
              categoria.tipo == TipoMovimentacao.receita,
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
  title: const Text(
    'Categorias',
    style: TextStyle(
      fontWeight: FontWeight.bold,
    ),
  ),
  actions: [
    IconButton(
      tooltip: 'Nova categoria',
      icon: const Icon(Icons.add),
      onPressed: () async {
        final criada = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => const TelaNovaCategoria(),
          ),
        );

        if (criada == true) {
          _carregarCategorias();
        }
      },
    ),
  ],
),
      body: _carregando
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SecaoCategorias(
                  titulo: 'Despesas',
                  categorias: despesas,
                  onCategoriaAlterada: _carregarCategorias,
                ),

                const SizedBox(height: 24),

                _SecaoCategorias(
                  titulo: 'Receitas',
                  categorias: receitas,
                  onCategoriaAlterada: _carregarCategorias,
                ),
              ],
            ),
    );
  }
}

class _SecaoCategorias extends StatelessWidget {
  const _SecaoCategorias({
    required this.titulo,
    required this.categorias,
    required this.onCategoriaAlterada,
  });

  final String titulo;
  final List<Categoria> categorias;
  final VoidCallback onCategoriaAlterada;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            12,
            0,
            12,
            8,
          ),
          child: Text(
            titulo,
            style: TextStyle(
              color: Theme
                  .of(context)
                  .colorScheme
                  .primary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        ...categorias.map(
              (categoria) =>
              Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                    categoria.cor.withValues(alpha: 0.15),
                    child: Icon(
                      categoria.icone,
                      color: categoria.cor,
                    ),
                  ),
                  title: Text(
                    categoria.nome,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.edit_outlined,
                  ),
                  onTap: () async {
                    final alterada = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            TelaNovaCategoria(
                              categoria: categoria,
                            ),
                      ),
                    );

                    if (alterada == true) {
                      onCategoriaAlterada();
                    }
                  },
                ),
              ),
        ),
      ],
    );
  }
}

class TelaNovaCategoria extends StatefulWidget {
  const TelaNovaCategoria({
    super.key,
    this.categoria,
  });

  final Categoria? categoria;

  @override
  State<TelaNovaCategoria> createState() =>
      _TelaNovaCategoriaState();
}

class _TelaNovaCategoriaState extends State<TelaNovaCategoria> {
  final _nomeController = TextEditingController();

  TipoMovimentacao _tipo = TipoMovimentacao.despesa;

  IconData _iconeSelecionado = Icons.category_outlined;
  Color _corSelecionada = const Color(0xFF6750A4);
  bool get _editando => widget.categoria != null;

@override
void initState() {
  super.initState();

  final categoria = widget.categoria;

  if (categoria != null) {
    _nomeController.text = categoria.nome;
    _tipo = categoria.tipo;
    _iconeSelecionado = categoria.icone;
    _corSelecionada = categoria.cor;
  }
}

  final List<IconData> _icones = const [
    Icons.restaurant_outlined,
    Icons.delivery_dining_outlined,
    Icons.directions_car_outlined,
    Icons.home_outlined,
    Icons.health_and_safety_outlined,
    Icons.school_outlined,
    Icons.sports_esports_outlined,
    Icons.shopping_bag_outlined,
    Icons.receipt_long_outlined,
    Icons.payments_outlined,
    Icons.work_outline,
    Icons.pets_outlined,
    Icons.flight_outlined,
    Icons.card_giftcard_outlined,
    Icons.savings_outlined,
    Icons.category_outlined,
  ];

  final List<Color> _cores = const [
    Color(0xFFE57373),
    Color(0xFFFF8A65),
    Color(0xFFFFB74D),
    Color(0xFF81C784),
    Color(0xFF4DB6AC),
    Color(0xFF64B5F6),
    Color(0xFF7986CB),
    Color(0xFF9575CD),
    Color(0xFFBA68C8),
    Color(0xFFF06292),
    Color(0xFF90A4AE),
    Color(0xFF6750A4),
  ];

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _confirmarExclusao() async {
  final categoria = widget.categoria;

  if (categoria == null || categoria.padrao) {
    return;
  }

  final quantidade = await BancoDados.instancia
      .contarMovimentacoesCategoria(categoria);

  if (!mounted) return;

  if (quantidade > 0) {
  final categorias = await BancoDados.instancia.listarCategorias();

  if (!mounted) return;

  final destinos = categorias
      .where(
        (item) =>
            item.tipo == categoria.tipo &&
            item.id != categoria.id,
      )
      .toList();

  Categoria? destinoSelecionado;

  final mover = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text(
              'Categoria em uso',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A categoria "${categoria.nome}" possui '
                  '$quantidade '
                  '${quantidade == 1 ? 'movimentação' : 'movimentações'}.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Para não perder seus dados, escolha outra categoria '
                  'para onde as movimentações serão transferidas.',
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<Categoria>(
                  initialValue: destinoSelecionado,
                  decoration: const InputDecoration(
                    labelText: 'Categoria de destino',
                    border: OutlineInputBorder(),
                  ),
                  items: destinos.map((item) {
                    return DropdownMenuItem<Categoria>(
                      value: item,
                      child: Text(item.nome),
                    );
                  }).toList(),
                  onChanged: (valor) {
                    setStateDialog(() {
                      destinoSelecionado = valor;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: destinoSelecionado == null
                    ? null
                    : () {
                        Navigator.pop(dialogContext, true);
                      },
                child: const Text('Mover e excluir'),
              ),
            ],
          );
        },
      );
    },
  );

  if (mover != true || destinoSelecionado == null) {
    return;
  }

  await BancoDados.instancia.excluirCategoria(
    categoria: categoria,
    destino: destinoSelecionado,
  );

  if (!mounted) return;

  Navigator.pop(context, true);
  return;
}

  final confirmar = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Excluir categoria?'),
        content: Text(
          'Deseja excluir a categoria "${categoria.nome}"? '
          'Esta ação não poderá ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      );
    },
  );

  if (confirmar != true) return;

  await BancoDados.instancia.excluirCategoria(
    categoria: categoria,
  );

  if (!mounted) return;

  Navigator.pop(context, true);
}

  Future<void> _salvar() async {
  final nome = _nomeController.text.trim();

  if (nome.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Digite um nome para a categoria.'),
      ),
    );
    return;
  }

  final categoriaAtualizada = Categoria(
    id: widget.categoria?.id,
    nome: nome,
    tipo: _tipo,
    codigoIcone: _iconeSelecionado.codePoint,
    codigoCor: _corSelecionada.toARGB32(),
    padrao: widget.categoria?.padrao ?? false,
  );

  try {
    if (_editando) {
      await BancoDados.instancia.atualizarCategoria(
        antiga: widget.categoria!,
        atualizada: categoriaAtualizada,
      );
    } else {
      await BancoDados.instancia.inserirCategoria(
        categoriaAtualizada,
      );
    }

    if (!mounted) return;

    Navigator.pop(context, true);
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          e is StateError
              ? e.message
              : _editando
                  ? 'Não foi possível salvar. Já pode existir uma categoria com esse nome e tipo.'
                  : 'Já existe uma categoria com esse nome e tipo.',
        ),
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  title: Text(
    _editando ? 'Editar categoria' : 'Nova categoria',
    style: const TextStyle(
      fontWeight: FontWeight.bold,
    ),
  ),
  actions: [
    if (_editando && widget.categoria?.padrao == false)
      IconButton(
        tooltip: 'Excluir categoria',
        icon: const Icon(
          Icons.delete_outline,
        ),
        onPressed: _confirmarExclusao,
      ),
  ],
),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nomeController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nome',
              hintText: 'Ex.: Pets',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Tipo',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 8),

          SegmentedButton<TipoMovimentacao>(
            segments: const [
              ButtonSegment(
                value: TipoMovimentacao.despesa,
                label: Text('Despesa'),
                icon: Icon(Icons.remove_circle_outline),
              ),
              ButtonSegment(
                value: TipoMovimentacao.receita,
                label: Text('Receita'),
                icon: Icon(Icons.add_circle_outline),
              ),
            ],
            selected: {_tipo},
            onSelectionChanged: widget.categoria?.padrao == true
                ? null
                : (selecionados) {
                    setState(() {
                      _tipo = selecionados.first;
                    });
                  },
          ),

          const SizedBox(height: 24),

          const Text(
            'Ícone',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _icones.map((icone) {
              final selecionado =
                  icone.codePoint == _iconeSelecionado.codePoint;

              return InkWell(
                borderRadius: BorderRadius.circular(50),
                onTap: () {
                  setState(() {
                    _iconeSelecionado = icone;
                  });
                },
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: selecionado
                      ? _corSelecionada.withValues(alpha: 0.22)
                      : Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                  child: Icon(
                    icone,
                    color: selecionado
                        ? _corSelecionada
                        : Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          const Text(
            'Cor',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _cores.map((cor) {
              final selecionada =
                  cor.toARGB32() == _corSelecionada.toARGB32();

              return InkWell(
                borderRadius: BorderRadius.circular(50),
                onTap: () {
                  setState(() {
                    _corSelecionada = cor;
                  });
                },
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: cor,
                  child: selecionada
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          FilledButton.icon(
            onPressed: _salvar,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Salvar categoria'),
          ),
        ],
      ),
    );
  }
}
class GraficoFluxoMensal extends StatefulWidget {
  const GraficoFluxoMensal({super.key, required this.dados});
  final List<ResumoMes> dados;

  @override
  State<GraficoFluxoMensal> createState() => _GraficoFluxoMensalState();
}

class _GraficoFluxoMensalState extends State<GraficoFluxoMensal> {
  String? _mesSelecionado;
  static const _meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
    'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
  String _chave(ResumoMes m) => '${m.ano}-${m.mes}';
  String _moeda(double v) {
    final partes = v.toStringAsFixed(2).split('.');
    final inteiro = partes[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return 'R\$ $inteiro,${partes[1]}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dados.isEmpty) return const SizedBox.shrink();
    final cores = Theme.of(context).colorScheme;
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final receitaCor = escuro ? const Color(0xFF76E5CD) : const Color(0xFF087F70);
    final despesaCor = escuro ? const Color(0xFFFF9283) : const Color(0xFFC64B3D);
    final porMes = {for (final m in widget.dados) _chave(m): m};
    final dados = <ResumoMes>[];
    final primeiro = widget.dados.first;
    final ultimo = widget.dados.last;
    var data = DateTime(primeiro.ano, primeiro.mes);
    final fim = DateTime(ultimo.ano, ultimo.mes);
    while (!data.isAfter(fim)) {
      dados.add(porMes['${data.year}-${data.month}'] ?? ResumoMes(
        ano: data.year, mes: data.month, receitas: 0, despesas: 0));
      data = DateTime(data.year, data.month + 1);
    }
    final encontrado = dados.indexWhere((m) => _chave(m) == _mesSelecionado);
    final indice = encontrado < 0 ? dados.length - 1 : encontrado;
    final atual = dados[indice];
    final maximo = dados.fold<double>(1,
      (v, m) => math.max(v, math.max(m.receitas, m.despesas))) * 1.15;
    String escala(double valor) => valor >= 1000
        ? '${(valor / 1000).toStringAsFixed(1).replaceAll('.', ',')} mil'
        : valor.toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cores.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Receitas × Despesas',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Evolução mensal • toque em um mês'),
          const SizedBox(height: 16),
          Wrap(spacing: 18, runSpacing: 8, children: [
            Text('● Receitas', style: TextStyle(color: receitaCor, fontWeight: FontWeight.w600)),
            Text('● Despesas', style: TextStyle(color: despesaCor, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 20),
          Text('Escala em R\$: 0 • ${escala(maximo / 2)} • ${escala(maximo)}',
            style: TextStyle(color: cores.onSurfaceVariant)),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, constraints) {
            final largura = math.max(constraints.maxWidth, dados.length * 64.0);
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: largura,
                child: Column(children: [
                  Semantics(
                    label: 'Gráfico mensal. Use os botões dos meses abaixo para consultar os valores.',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (evento) {
                        final escolhido = (evento.localPosition.dx / largura * dados.length)
                            .floor().clamp(0, dados.length - 1);
                        setState(() => _mesSelecionado = _chave(dados[escolhido]));
                      },
                      child: SizedBox(
                        height: 200,
                        width: largura,
                        child: CustomPaint(painter: _PintorFluxoMensal(
                          dados: dados, maximo: maximo, selecionado: indice,
                          receitaCor: receitaCor, despesaCor: despesaCor,
                          gradeCor: cores.outlineVariant,
                        )),
                      ),
                    ),
                  ),
                  Row(children: [
                    for (var i = 0; i < dados.length; i++)
                      Expanded(child: TextButton(
                        onPressed: () => setState(() => _mesSelecionado = _chave(dados[i])),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                          backgroundColor: i == indice ? cores.secondaryContainer : null,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('${_meses[dados[i].mes - 1]}\n${dados[i].ano}',
                          textAlign: TextAlign.center),
                      )),
                  ]),
                ]),
              ),
            );
          }),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cores.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_meses[atual.mes - 1]} ${atual.ano}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Receitas: ${_moeda(atual.receitas)}', style: TextStyle(color: receitaCor)),
              Text('Despesas: ${_moeda(atual.despesas)}', style: TextStyle(color: despesaCor)),
              const SizedBox(height: 8),
              Text(!porMes.containsKey(_chave(atual))
                ? 'Sem registros neste mês.'
                : atual.receitas > 0
                  ? '${(atual.despesas / atual.receitas * 100).toStringAsFixed(1).replaceAll('.', ',')}% das receitas comprometidas com despesas'
                  : 'Sem receitas para calcular a porcentagem.'),
            ]),
          ),
          if (dados.length > porMes.length) ...[
            const SizedBox(height: 8),
            const Text('Meses sem registros aparecem com valor zero.'),
          ],
        ],
      ),
    );
  }
}

class _PintorFluxoMensal extends CustomPainter {
  _PintorFluxoMensal({required this.dados, required this.maximo,
    required this.selecionado, required this.receitaCor,
    required this.despesaCor, required this.gradeCor});
  final List<ResumoMes> dados;
  final double maximo;
  final int selecionado;
  final Color receitaCor, despesaCor, gradeCor;

  @override
  void paint(Canvas canvas, Size size) {
    final base = size.height - 10;
    final altura = base - 10;
    double x(int i) => (i + 0.5) * size.width / dados.length;
    double y(double v) => base - v / maximo * altura;
    for (var i = 0; i <= 2; i++) {
      final linha = y(maximo * i / 2);
      canvas.drawLine(Offset(0, linha), Offset(size.width, linha),
        Paint()..color = gradeCor.withValues(alpha: 0.5)..strokeWidth = 1);
    }
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromLTRB(x(selecionado) - 9, 0, x(selecionado) + 9, base),
      const Radius.circular(8)), Paint()..color = gradeCor.withValues(alpha: 0.25));
    void serie(bool receita, Color cor) {
      double valor(int i) => receita ? dados[i].receitas : dados[i].despesas;
      final linha = Path()..moveTo(x(0), y(valor(0)));
      for (var i = 1; i < dados.length; i++) {
        // Segmentos retos preservam os valores sem criar picos artificiais.
        linha.lineTo(x(i), y(valor(i)));
      }
      final area = Path.from(linha)
        ..lineTo(x(dados.length - 1), base)..lineTo(x(0), base)..close();
      canvas.drawPath(area, Paint()..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [cor.withValues(alpha: 0.45), cor.withValues(alpha: 0.02)],
      ).createShader(Offset.zero & size));
      canvas.drawPath(linha, Paint()..color = cor..strokeWidth = 3
        ..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round);
      for (var i = 0; i < dados.length; i++) {
        canvas.drawCircle(Offset(x(i), y(valor(i))), i == selecionado ? 6 : 3,
          Paint()..color = cor);
      }
    }
    serie(false, despesaCor);
    serie(true, receitaCor);
  }

  @override
  bool shouldRepaint(covariant _PintorFluxoMensal oldDelegate) => true;
}
class _MiniGraficoComparacao extends CustomPainter {
  _MiniGraficoComparacao(this.valores, this.cor, this.barras);
  final List<double> valores;
  final Color cor;
  final bool barras;
  @override
  void paint(Canvas canvas, Size size) {
    if (valores.isEmpty) return;
    final minimo = valores.fold<double>(0, math.min);
    final maximo = valores.fold<double>(0, math.max);
    final amplitude = math.max(1.0, maximo - minimo);
    double y(double v) => size.height - 2 - (v - minimo) / amplitude * (size.height - 6);
    final base = y(0);
    if (barras) {
      final passo = size.width / valores.length;
      for (var i = 0; i < valores.length; i++) {
        canvas.drawRect(Rect.fromLTRB(i * passo + passo * 0.15,
          math.min(base, y(valores[i])), (i + 1) * passo - passo * 0.15,
          math.max(base, y(valores[i]))), Paint()..color = valores[i] < 0 ? const Color(0xFFD86B69) : cor);
      }
      return;
    }
    double x(int i) => valores.length == 1 ? size.width / 2 : i * size.width / (valores.length - 1);
    final linha = Path()..moveTo(x(0), y(valores[0]));
    for (var i = 1; i < valores.length; i++) { linha.lineTo(x(i), y(valores[i])); }
    final area = Path.from(linha)..lineTo(x(valores.length - 1), base)..lineTo(x(0), base)..close();
    canvas.drawPath(area, Paint()..shader = LinearGradient(begin: Alignment.topCenter,
      end: Alignment.bottomCenter, colors: [cor.withValues(alpha: 0.4), cor.withValues(alpha: 0.02)])
      .createShader(Offset.zero & size));
    canvas.drawPath(linha, Paint()..color = cor..style = PaintingStyle.stroke..strokeWidth = 2);
    if (valores.length == 1) canvas.drawCircle(Offset(x(0), y(valores[0])), 3, Paint()..color = cor);
  }
  @override
  bool shouldRepaint(covariant _MiniGraficoComparacao oldDelegate) => true;
}




class LembretesAgenda {
  static const _canal = MethodChannel('financas_facil/agenda');
  static bool get suportado => Platform.isAndroid;
  static Future<void> atualizarAgendamentos() async {
    if (suportado) await _canal.invokeMethod<void>('sincronizar');
  }
  static Future<bool> permitido({bool solicitar = false}) async {
    if (!suportado) return false;
    return await _canal.invokeMethod<bool>(solicitar ? 'permitir' : 'status') ??
        false;
  }

  static Future<void> sincronizar(
    int perfil,
    String nome,
    List<Previsto> itens,
  ) async {
    await atualizarAgendamentos();
  }
}



String dinheiroAgenda(int centavos) {
  final partes = (centavos.abs() / 100).toStringAsFixed(2).split('.');
  final inteiro = partes[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]}.',
  );
  return '${centavos < 0 ? '−' : ''}R\$ $inteiro,${partes[1]}';
}

class TelaAgenda extends StatefulWidget {
  const TelaAgenda({
    super.key,
    required this.banco,
    required this.perfil,
    required this.nomePerfil,
    required this.categorias,
    required this.onRealizado,
    this.movimentacoes = const [],
    this.categoriasVisuais = const [],
  });
  final AgendaBanco banco;
  final List<Categoria> categoriasVisuais;
  final List<Movimentacao> movimentacoes;
  final int perfil;
  final String nomePerfil;
  final Map<String, List<String>> categorias;
  final Future<void> Function() onRealizado;
  @override
  State<TelaAgenda> createState() => _TelaAgendaState();
}

class _TelaAgendaState extends State<TelaAgenda> with WidgetsBindingObserver {
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _dia = diaAgenda(DateTime.now());
  List<Previsto> _itens = [];
  bool _carregando = true, _ocupado = false, _permitido = false;
  String? _erro, _erroLembretes;
  String _filtro = 'todos';
  bool _todosVencimentos = false;

  @override
  void didUpdateWidget(covariant TelaAgenda oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movimentacoes != widget.movimentacoes ||
        oldWidget.categorias.toString() != widget.categorias.toString()) {
      _carregar();
    }
  }
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _carregar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_ocupado) _carregar();
  }

  void _aviso(String texto) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(texto)));
  } }

  Future<void> _carregar() async {
    try {
      final itens = await widget.banco.listar();
      if (!mounted) return;
      setState(() {
        _itens = itens;
        _erro = null;
        _carregando = false;
      });
      try {
        await LembretesAgenda.sincronizar(
          widget.perfil,
          widget.nomePerfil,
          itens,
        );
        final permitido = await LembretesAgenda.permitido();
        if (mounted) {
          setState(() {
            _permitido = permitido;
            _erroLembretes = null;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(
            () => _erroLembretes = 'Não foi possível atualizar os lembretes. Toque em atualizar para tentar novamente.',
          );
      } }
    } catch (_) {
      if (mounted) {
        setState(() {
          _erro = 'Não foi possível carregar a agenda.';
          _carregando = false;
        });
      }
    }
  }

  Future<void> _editar([Previsto? item]) async {
    if (_ocupado) return;
    final salvou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FormularioAgenda(
          banco: widget.banco,
          categorias: widget.categorias,
          existente: item,
          dataInicial:
              _dia ??
              (_mes.year == DateTime.now().year &&
                      _mes.month == DateTime.now().month
                  ? diaAgenda(DateTime.now())
                  : _mes),
        ),
      ),
    );
    if (salvou == true) {
      await _carregar();
      if (item?.status == 'realizado') await widget.onRealizado();
      _aviso('Previsão salva.');
    }
  }

  Future<void> _realizar(Previsto item) async {
    if (_ocupado) return;
    var data = diaAgenda(DateTime.now());
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, atualizar) => AlertDialog(
          title: Text(
            item.receita ? 'Confirmar recebimento' : 'Confirmar pagamento',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${item.titulo}\n${dinheiroAgenda(item.centavos)}'),
              const SizedBox(height: 12),
              const Text(
                'Será adicionada uma movimentação ao saldo realizado.',
              ),
              TextButton.icon(
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(dataAgendaBR(data)),
                onPressed: () async {
                  final escolha = await showDatePicker(
                    context: context,
                    initialDate: data,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (escolha != null && context.mounted) {
  atualizar(() => data = escolha);
}
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Voltar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
    if (confirmou != true || !mounted) return;
    setState(() => _ocupado = true);
    try {
      final criado = await widget.banco.realizar(item, data);
      await _carregar();
      await widget.onRealizado();
      _aviso(
        criado
            ? 'Movimentação registrada.'
            : 'Esta previsão já foi processada.',
      );
    } catch (_) {
      _aviso(
        'Não foi possível confirmar. Atualize a agenda antes de tentar novamente.',
      );
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _cancelar(Previsto item) async {
    if (_ocupado) return;
    final seguintes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar previsão?'),
        content: Text(
          'Cancelar “${item.titulo}”? Os valores já realizados serão preservados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Voltar'),
          ),
          if (item.frequencia != 'unica')
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Esta e próximas'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Só esta'),
          ),
        ],
      ),
    );
    if (seguintes == null || !mounted) return;
    setState(() => _ocupado = true);
    try {
      await widget.banco.cancelar(item, seguintes: seguintes);
      await _carregar();
    } catch (_) {
      _aviso('Não foi possível cancelar a previsão.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _moverMes(int passo) => setState(() {
    _mes = DateTime(_mes.year, _mes.month + passo);
    _dia = null;
  });

  Future<void> _selecionarMes() async {
    final data = await showDatePicker(context: context, initialDate: _mes,
      firstDate: DateTime(2000), lastDate: DateTime(2220, 12, 31),
      helpText: 'Escolha o mês e o ano', initialDatePickerMode: DatePickerMode.year);
    if (!mounted || data == null) return;
    setState(() { _mes = DateTime(data.year, data.month); _dia = diaAgenda(data); });
  }

  Future<void> _excluirCompromisso(Previsto item) async {
    if (_ocupado) return;
    final confirmou = await showDialog<bool>(context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir compromisso?'),
        content: Text('Excluir “${item.titulo}” do calendário? '
          'Uma movimentação já registrada no Histórico será mantida. '
          'As outras ocorrências da série serão mantidas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Voltar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ]));
    if (!mounted || confirmou != true) return;
    setState(() => _ocupado = true);
    try {
      await widget.banco.excluir(item);
      await _carregar();
    } catch (_) { _aviso('Não foi possível excluir o compromisso.'); }
    finally { if (mounted) setState(() => _ocupado = false); }
  }

  ColorScheme get _coresCalendario {
    final cores = Theme.of(context).colorScheme;
    if (Theme.of(context).brightness != Brightness.dark) return cores;
    return cores.copyWith(
      surface: const Color(0xFF090E15),
      surfaceContainerLow: const Color(0xFF131B24),
      surfaceContainerHighest: const Color(0xFF1B222D),
      primary: const Color(0xFFA78BFA),
      onPrimary: const Color(0xFF170D2D),
      onSurface: const Color(0xFFF1F1F6),
      onSurfaceVariant: const Color(0xFFA9ADBC),
      outlineVariant: const Color(0xFF252B38),
    );
  }

  Categoria? _categoriaVisual(Previsto item) {
    for (final categoria in widget.categoriasVisuais) {
      if (categoria.nome == item.categoria && categoria.tipo.name == item.tipo) return categoria;
    }
    return null;
  }

  Widget _menuCompromisso(Previsto item) => PopupMenuButton<String>(
    enabled: !_ocupado, tooltip: 'Opções do compromisso',
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 200),
    iconSize: 20,
    onSelected: (acao) {
      if (acao == 'editar') { _editar(item); }
      else if (acao == 'cancelar') { _cancelar(item); }
      else { _excluirCompromisso(item); }
    },
    itemBuilder: (_) => [
      if (item.status != 'cancelado')
        const PopupMenuItem(value: 'editar', child: Text('Editar esta ocorrência')),
      if (item.pendente)
        const PopupMenuItem(value: 'cancelar', child: Text('Cancelar previsão / série')),
      const PopupMenuItem(value: 'excluir', child: Text('Excluir compromisso')),
    ],
  );

  void _detalhesCompromisso(Previsto item) {
    showModalBottomSheet<void>(context: context, showDragHandle: true,
      backgroundColor: _coresCalendario.surfaceContainerLow,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(item.titulo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('${item.categoria} • ${item.receita ? 'Receita' : 'Despesa'}'),
            Text('Vencimento: ${dataAgendaBR(item.data)}'),
            const SizedBox(height: 12),
            Text(dinheiroAgenda(item.centavos), style: TextStyle(fontSize: 24,
              color: item.receita ? const Color(0xFF55D997) : const Color(0xFFFF7787), fontWeight: FontWeight.bold)),
            Text(item.rotuloStatus(DateTime.now())),
            if (item.frequencia != 'unica') Text('Repetição: ${item.rotuloFrequencia}'),
            if (item.conta.isNotEmpty) Text('Conta: ${item.conta}'),
            if (item.lembrete != null) Text('Lembrete: ${item.lembrete == 0 ? 'no dia' : '${item.lembrete} dia(s) antes'}, '
              '${item.hora.toString().padLeft(2, '0')}:${item.minuto.toString().padLeft(2, '0')}'),
            if (item.observacoes.isNotEmpty) ...[
              const SizedBox(height: 12), const Text('Observações', style: TextStyle(fontWeight: FontWeight.w600)),
              Text(item.observacoes),
            ],
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (item.pendente) FilledButton(onPressed: _ocupado ? null : () {
                Navigator.pop(sheetContext); _realizar(item);
              }, child: Text(item.receita ? 'Marcar recebido' : 'Marcar pago')),
              if (item.status != 'cancelado') OutlinedButton(onPressed: _ocupado ? null : () {
                Navigator.pop(sheetContext); _editar(item);
              }, child: const Text('Editar')),
              TextButton(onPressed: _ocupado ? null : () {
                Navigator.pop(sheetContext); _excluirCompromisso(item);
              }, child: const Text('Excluir')),
            ]),
          ]))),
    );
  }

  Future<void> _configurarLembretes() async {
    if (_ocupado) return;
    if (!LembretesAgenda.suportado) {
      _aviso('Lembretes disponíveis no Android.'); return;
    }
    if (_erroLembretes != null) _aviso(_erroLembretes!);
    try {
      final ok = await LembretesAgenda.permitido(solicitar: !_permitido);
      if (!ok) _aviso('Permita as notificações nas configurações do Android.');
      await _carregar();
    } catch (_) { _aviso('Não foi possível ativar os lembretes.'); }
  }

  Widget _cardCompromisso(Previsto item) => _CompromissoDiaCalendario(
    item: item, categoria: _categoriaVisual(item), cores: _coresCalendario,
    menu: _menuCompromisso(item),
    onDetalhes: () => _detalhesCompromisso(item),
    onRealizar: _ocupado ? null : () => _realizar(item),
  );

  @override
  Widget build(BuildContext context) {
    if (_carregando) return const Center(child: CircularProgressIndicator());
    if (_erro != null) {
      return Center(
        child: TextButton(
          onPressed: _carregar,
          child: Text('$_erro Tentar novamente'),
        ),
      );
    }

    final cor = _coresCalendario;
    final hoje = diaAgenda(DateTime.now());
    final noMes = _itens
        .where((i) => i.data.year == _mes.year && i.data.month == _mes.month)
        .toList();
    final visiveis = (_filtro == 'atrasado' ? _itens : noMes)
        .where(
          (i) =>
              (_filtro == 'todos' ||
                  (_filtro == 'atrasado'
                      ? i.pendente && i.data.isBefore(hoje)
                      : i.status == _filtro)) &&
              (_filtro == 'atrasado' || _dia == null || i.data == _dia),
        )
        .toList();
    final pendentes = noMes.where((i) => i.status != 'cancelado');
    final proximos = _itens.where((i) => i.pendente && !i.data.isBefore(hoje)).toList()..sort((a, b) => a.data.compareTo(b.data));
    final pagar = pendentes
        .where((i) => !i.receita)
        .fold(0, (s, i) => s + i.centavos);
    final receber = pendentes
        .where((i) => i.receita)
        .fold(0, (s, i) => s + i.centavos);
    final atrasados = _itens
        .where((i) => i.pendente && i.data.isBefore(hoje))
        .length;
    final deslocamento = _mes.weekday % 7;
    final dias = DateTime(_mes.year, _mes.month + 1, 0).day;
    final eventosPorDia = <DateTime, List<Previsto>>{};
    for (final item in noMes) {
      if (item.status != 'cancelado') {
        (eventosPorDia[item.data] ??= []).add(item);
      }
    }
    final reaisPorDia = <DateTime, List<Movimentacao>>{};
    for (final m in widget.movimentacoes) {
      if (m.data.year == _mes.year && m.data.month == _mes.month) {
        (reaisPorDia[diaAgenda(m.data)] ??= []).add(m);
      }
    }
    return Theme(
      data: Theme.of(context).copyWith(colorScheme: cor, visualDensity: VisualDensity.compact),
      child: ColoredBox(color: cor.surface, child: RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(children: [
              const Expanded(child: Text('Calendário',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800))),
              IconButton(
                tooltip: _erroLembretes != null ? 'Revisar lembretes' :
                  !_permitido ? 'Ativar lembretes' : 'Lembretes',
                onPressed: _configurarLembretes,
                icon: Icon(_erroLembretes != null ? Icons.notifications_active_outlined : Icons.notifications_outlined,
                  size: 21, color: _erroLembretes != null ? Colors.amber : cor.onSurfaceVariant)),
              IconButton(tooltip: 'Atualizar agenda', onPressed: _ocupado ? null : _carregar,
                icon: Icon(Icons.refresh, size: 20, color: cor.onSurfaceVariant)),
            ]),
            Text('Planeje seus compromissos financeiros',
              style: TextStyle(fontSize: 12, color: cor.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(children: [
              IconButton(tooltip: 'Mês anterior',
                onPressed: _mes.year <= 2000 && _mes.month == 1 ? null : () => _moverMes(-1),
                icon: const Icon(Icons.chevron_left, size: 22)),
              Expanded(child: TextButton(onPressed: _selecionarMes,
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 2)),
                child: Text(MaterialLocalizations.of(context).formatMonthYear(_mes),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cor.onSurface, fontWeight: FontWeight.w700, fontSize: 15)))),
              IconButton(tooltip: 'Próximo mês',
                onPressed: _mes.year >= 2220 && _mes.month == 12 ? null : () => _moverMes(1),
                icon: const Icon(Icons.chevron_right, size: 22)),
              const SizedBox(width: 4),
              OutlinedButton(onPressed: () => setState(() {
                _mes = DateTime(hoje.year, hoje.month); _dia = hoje; _filtro = 'todos';
              }), style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 32), padding: const EdgeInsets.symmetric(horizontal: 8),
                side: BorderSide(color: cor.primary.withValues(alpha: .6)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
                child: const Text('Hoje', style: TextStyle(fontSize: 12))),
            ]),
            const SizedBox(height: 2),
            Row(children: [for (final dia in ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'])
              Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 5),
                child: FittedBox(fit: BoxFit.scaleDown, child: Text(dia,
                  style: TextStyle(fontSize: 11, color: cor.onSurfaceVariant))))),
            ]),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: math.max(36, MediaQuery.textScalerOf(context).scale(14) * 1.4 + 12),
              mainAxisSpacing: 1,
              crossAxisSpacing: 1,
            ),
            itemCount: ((deslocamento + dias + 6) ~/ 7) * 7,
            itemBuilder: (context, index) {
              final numero = index - deslocamento + 1;
              if (numero < 1 || numero > dias) {
                final vizinho = DateTime(_mes.year, _mes.month, numero);
                return Center(child: Text('${vizinho.day}', maxLines: 1,
                  style: TextStyle(fontSize: 12, color: cor.onSurfaceVariant.withValues(alpha: .35))));
              }
              final data = DateTime(_mes.year, _mes.month, numero);
              final eventos = eventosPorDia[data] ?? const <Previsto>[];
              final reais = reaisPorDia[data] ?? const <Movimentacao>[];
              final selecionado = _dia == data;
              return Semantics(
                label: '${dataAgendaBR(data)}, ${eventos.length} previsões${reais.isEmpty ? '' : ', ${reais.length} movimentações'}',
                selected: selecionado,
                button: true,
                child: InkWell(
                  onTap: () => setState(() {
                    _dia = selecionado ? null : data;
                    if (_filtro == 'atrasado') _filtro = 'todos';
                  }),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selecionado
                          ? cor.primary
                          : cor.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: data == hoje
                          ? Border.all(color: cor.primary)
                          : Border.all(color: cor.outlineVariant.withValues(alpha: .35)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(fit: BoxFit.scaleDown, child: Text(
                          '$numero', maxLines: 1,
                          style: TextStyle(
                            fontSize: 14,
                            color: selecionado ? cor.onPrimary : cor.onSurface,
                            fontWeight: selecionado
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        )),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (eventos.any((i) => i.status == 'realizado') || reais.isNotEmpty)
                              const Padding(padding: EdgeInsets.only(right: 3),
                                child: Icon(Icons.circle, size: 5, color: Color(0xFFA78BFA))),
                            if (eventos.any((i) => i.pendente))
                              const Padding(padding: EdgeInsets.only(right: 3),
                                child: Icon(Icons.circle, size: 5, color: Colors.amber)),
                            if (eventos.any((i) => i.receita) || reais.any((m) => m.tipo == TipoMovimentacao.receita))
                              const Icon(
                                Icons.circle,
                                size: 5,
                                color: Colors.green,
                              ),
                            if (eventos.any((i) => !i.receita) || reais.any((m) => m.tipo == TipoMovimentacao.despesa))
                              const Padding(
                                padding: EdgeInsets.only(left: 3),
                                child: Icon(
                                  Icons.circle,
                                  size: 5,
                                  color: Colors.red,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

            const SizedBox(height: 6),
            SingleChildScrollView(scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final entrada in const <(String, Color)>[
                  ('Receita', Color(0xFF42D990)), ('Despesa', Color(0xFFFF667C)),
                  ('Pago/recebido', Color(0xFFA78BFA)), ('Em aberto', Colors.amber),
                ]) Padding(padding: const EdgeInsets.only(right: 10),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.circle, size: 7, color: entrada.$2), const SizedBox(width: 4),
                    Text(entrada.$1, style: TextStyle(fontSize: 10, color: cor.onSurfaceVariant)),
                  ])),
              ])),
            const SizedBox(height: 12),
            _ResumoCalendario(receber: receber, pagar: pagar, cores: cor),
            const SizedBox(height: 10),
            SingleChildScrollView(scrollDirection: Axis.horizontal,
              child: Row(children: [for (final opcao in {
                'todos': 'Todos', 'pendente': 'Pendentes', 'realizado': 'Realizados',
                'atrasado': 'Atrasados ($atrasados)',
              }.entries) Padding(padding: const EdgeInsets.only(right: 5),
                child: ChoiceChip(label: Text(opcao.value), selected: _filtro == opcao.key,
                  showCheckmark: false, selectedColor: cor.primary,
                  backgroundColor: cor.surface, side: BorderSide.none,
                  labelStyle: TextStyle(fontSize: 11,
                    color: _filtro == opcao.key ? cor.onPrimary : cor.onSurfaceVariant),
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => _filtro = opcao.key))),
              ])),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_filtro == 'atrasado' ? 'Compromissos atrasados' : _dia == null
                  ? 'Compromissos do mês' : _tituloDiaCalendario(_dia!),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Text('${visiveis.length} ${visiveis.length == 1 ? 'compromisso' : 'compromissos'}',
                  style: TextStyle(fontSize: 11, color: cor.onSurfaceVariant)),
              ])),
              if (_dia != null && _filtro != 'atrasado')
                IconButton(tooltip: 'Mostrar mês inteiro', onPressed: () => setState(() => _dia = null),
                  icon: Icon(Icons.calendar_view_month, size: 18, color: cor.onSurfaceVariant)),
              SizedBox(width: 42, height: 42, child: FloatingActionButton.small(
                heroTag: 'adicionar_compromisso', tooltip: 'Adicionar compromisso',
                backgroundColor: cor.primary, foregroundColor: cor.onPrimary,
                elevation: 0, shape: const CircleBorder(),
                onPressed: _ocupado ? null : () => _editar(), child: const Icon(Icons.add))),
            ]),
            const SizedBox(height: 8),
            if (visiveis.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Nenhum compromisso neste filtro.', style: TextStyle(fontSize: 12, color: cor.onSurfaceVariant))),
            for (final item in visiveis) _cardCompromisso(item),
            const SizedBox(height: 8),
            Row(children: [
              const Expanded(child: Text('Próximos vencimentos',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
              if (proximos.length > 4)
                TextButton(onPressed: () => setState(() => _todosVencimentos = !_todosVencimentos),
                  child: Text(_todosVencimentos ? 'Ver menos' : 'Ver todos', style: const TextStyle(fontSize: 12))),
            ]),
            if (proximos.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Nenhum compromisso a vencer.', style: TextStyle(fontSize: 12, color: cor.onSurfaceVariant))),
            if (proximos.isNotEmpty) Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: cor.surfaceContainerLow, borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                for (final item in (_todosVencimentos ? proximos : proximos.take(4)))
                  _VencimentoCalendario(item: item, categoria: _categoriaVisual(item), cores: cor,
                    onTap: () => _detalhesCompromisso(item)),
              ])),
          ],
        ),
      )),
    );
  }

}

class FormularioAgenda extends StatefulWidget {
  const FormularioAgenda({
    super.key,
    required this.banco,
    required this.categorias,
    required this.dataInicial,
    this.existente,
  });
  final AgendaBanco banco;
  final Map<String, List<String>> categorias;
  final DateTime dataInicial;
  final Previsto? existente;
  @override
  State<FormularioAgenda> createState() => _FormularioAgendaState();
}

class _FormularioAgendaState extends State<FormularioAgenda> {
  final _form = GlobalKey<FormState>();
  late String _titulo, _valor, _tipo, _categoria;
  late String _conta, _observacoes;
  late DateTime _data;
  String _frequencia = 'unica';
  int _quantidade = 12, _antecedencia = 0;
  bool _lembrete = false, _salvando = false;
  TimeOfDay _hora = const TimeOfDay(hour: 9, minute: 0);
  @override
  void initState() {
    super.initState();
    final item = widget.existente;
    _titulo = item?.titulo ?? '';
    _conta = item?.conta ?? '';
    _observacoes = item?.observacoes ?? '';
    _frequencia = item?.frequencia ?? 'unica';
    _valor = item == null
        ? ''
        : (item.centavos / 100).toStringAsFixed(2).replaceAll('.', ',');
    _tipo = item?.tipo ?? 'despesa';
    _categoria = item?.categoria ?? _categoriaInicial(_tipo);
    _data = item?.data ?? widget.dataInicial;
    _lembrete = item?.lembrete != null;
    _antecedencia = item?.lembrete ?? 0;
    _hora = TimeOfDay(hour: item?.hora ?? 9, minute: item?.minuto ?? 0);
  }

  int? _centavos(String texto) {
    final limpo = texto.trim();
    if (!RegExp(r'^\d{1,9}([,.]\d{1,2})?$').hasMatch(limpo)) return null;
    final valor = double.tryParse(limpo.replaceAll(',', '.'));
    return valor == null || valor <= 0 ? null : (valor * 100).round();
  }

  String _categoriaInicial(String tipo) {
    final nomes = widget.categorias[tipo] ?? const <String>[];
    return nomes.firstWhere((nome) => nome.toLowerCase() == 'outros',
      orElse: () => nomes.isEmpty ? 'Outros' : nomes.first);
  }

  Future<void> _salvar() async {
    if (_salvando || !_form.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      await widget.banco.salvar(
        existente: widget.existente,
        titulo: _titulo,
        conta: _conta,
        observacoes: _observacoes,
        tipo: _tipo,
        centavos: _centavos(_valor)!,
        categoria: _categoria,
        data: _data,
        frequencia: _frequencia,
        quantidade: _quantidade,
        lembrete: _lembrete ? _antecedencia : null,
        hora: _hora.hour,
        minuto: _hora.minute,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível salvar. Verifique os dados; esta série pode já ter uma ocorrência na data escolhida.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categorias = {
      ...?widget.categorias[_tipo],
      _categoria,
    }.toList()..sort();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existente == null ? 'Adicionar compromisso' : 'Editar compromisso',
        ),
      ),
      body: AbsorbPointer(
        absorbing: _salvando,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'despesa', label: Text('Despesa')),
                  ButtonSegment(value: 'receita', label: Text('Receita')),
                ],
                selected: {_tipo},
                onSelectionChanged: (v) => setState(() {
                  _tipo = v.first;
                  _categoria = _categoriaInicial(_tipo);
                }),
              ),
              const SizedBox(height: 20),
              TextFormField(
                initialValue: _titulo,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  hintText: 'Ex.: Aluguel, salário',
                ),
                onChanged: (v) => _titulo = v,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Informe uma descrição.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _valor,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Valor (R\$)',
                  hintText: 'Ex.: 1250,50 — sem separador de milhar',
                ),
                onChanged: (v) => _valor = v,
                validator: (v) => _centavos(v ?? '') == null
                    ? 'Informe um valor positivo com até 2 casas decimais.'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey('$_tipo/$_categoria'),
                initialValue: _categoria,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: categorias
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _categoria = v!),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Vencimento'),
                subtitle: Text(dataAgendaBR(_data)),
                trailing: const Icon(Icons.calendar_month),
                onTap: () async {
                  final data = await showDatePicker(
                    context: context,
                    initialDate: _data,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2220, 12, 31),
                  );
                  if (mounted && data != null) setState(() => _data = data);
                },
              ),
              TextFormField(
                initialValue: _conta,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Conta',
                  hintText: 'Informe a conta ou carteira',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined)),
                onChanged: (v) => _conta = v,
                validator: (v) => v == null || v.trim().isEmpty ? 'Informe a conta.' : null,
              ),
              const SizedBox(height: 12),
              if (widget.existente == null) ...[
                DropdownButtonFormField<String>(
                  initialValue: _frequencia,
                  decoration: const InputDecoration(labelText: 'Repetição'),
                  items: const [
                    DropdownMenuItem(
                      value: 'unica',
                      child: Text('Não repetir'),
                    ),
                    DropdownMenuItem(value: 'semanal', child: Text('Semanal')),
                    DropdownMenuItem(value: 'mensal', child: Text('Mensal')),
                    DropdownMenuItem(value: 'anual', child: Text('Anual')),
                  ],
                  onChanged: (v) => setState(() => _frequencia = v!),
                ),
                if (_frequencia != 'unica') ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: '$_quantidade',
                    decoration: const InputDecoration(
                      labelText:
                          'Quantidade de ocorrências (incluindo a primeira)',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _quantidade = int.tryParse(v) ?? 0,
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return n == null || n < 1 || n > 120
                          ? 'Use de 1 a 120 ocorrências.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cada ocorrência poderá ser confirmada ou editada separadamente. Dias 29, 30 e 31 são ajustados para o último dia dos meses mais curtos.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ] else
                Text('Repetição: ${widget.existente!.rotuloFrequencia}. '
                  'A edição afeta apenas esta ocorrência.'
                  '${widget.existente!.status == 'realizado' ? ' Os dados financeiros também serão atualizados no Histórico, mantendo a data do pagamento.' : ''}'),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Lembrar desta previsão'),
                value: _lembrete,
                subtitle: const Text('Notificação local no Android'),
                onChanged: LembretesAgenda.suportado
                    ? (v) => setState(() => _lembrete = v)
                    : null,
              ),
              if (_lembrete) ...[
                DropdownButtonFormField<int>(
                  initialValue: _antecedencia,
                  decoration: const InputDecoration(
                    labelText: 'Quando lembrar',
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('No vencimento')),
                    DropdownMenuItem(value: 1, child: Text('1 dia antes')),
                    DropdownMenuItem(value: 3, child: Text('3 dias antes')),
                    DropdownMenuItem(value: 7, child: Text('7 dias antes')),
                  ],
                  onChanged: (v) => setState(() => _antecedencia = v!),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Horário'),
                  subtitle: Text(_hora.format(context)),
                  trailing: const Icon(Icons.schedule),
                  onTap: () async {
                    final hora = await showTimePicker(
                      context: context,
                      initialTime: _hora,
                    );
                    if (mounted && hora != null) setState(() => _hora = hora);
                  },
                ),
                const Text(
                  'Ative as notificações na agenda. O Android pode atrasar lembretes para economizar bateria. Horários já passados não geram novos alertas.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
              const SizedBox(height: 24),
              TextFormField(
                initialValue: _observacoes,
                maxLength: 1000,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Observações (opcional)'),
                onChanged: (v) => _observacoes = v,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _salvando ? null : _salvar,
                child: Text(_salvando ? 'Salvando…' : 'Salvar compromisso'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

DateTime diaAgenda(DateTime data) => DateTime(data.year, data.month, data.day);
String dataAgenda(DateTime data) =>
    '${data.year.toString().padLeft(4, '0')}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}';
String dataAgendaBR(DateTime data) =>
    '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';

// Always anchor to the original day: Jan 31 -> Feb 28 -> Mar 31.
List<DateTime> datasRecorrentes(
  DateTime inicio,
  String frequencia,
  int quantidade,
) {
  if (!['unica', 'semanal', 'mensal', 'anual'].contains(frequencia) ||
      quantidade < 1 ||
      quantidade > 120) {
    throw ArgumentError('Recorrência inválida.');
  }
  return List.generate(frequencia == 'unica' ? 1 : quantidade, (i) {
    if (frequencia == 'unica') return diaAgenda(inicio);
    if (frequencia == 'semanal') {
      return DateTime(inicio.year, inicio.month, inicio.day + 7 * i);
    }
    final mes = DateTime(
      inicio.year + (frequencia == 'anual' ? i : 0),
      inicio.month + (frequencia == 'mensal' ? i : 0),
    );
    final ultimo = DateTime(mes.year, mes.month + 1, 0).day;
    return DateTime(
      mes.year,
      mes.month,
      inicio.day > ultimo ? ultimo : inicio.day,
    );
  });
}

class Previsto {
  const Previsto({
    required this.id,
    required this.serie,
    required this.titulo,
    required this.tipo,
    required this.centavos,
    required this.categoria,
    required this.data,
    required this.frequencia,
    required this.lembrete,
    required this.hora,
    required this.minuto,
    required this.status,
    this.conta = '',
    this.observacoes = '',
  });
  final int id, centavos, hora, minuto;
  final int? lembrete;
  final String serie, titulo, tipo, categoria, frequencia, status;
  final String conta, observacoes;
  final DateTime data;
  bool get pendente => status == 'pendente';
  bool get receita => tipo == 'receita';
  String get rotuloFrequencia => const {'unica': 'Não repetir', 'semanal': 'Semanal',
    'mensal': 'Mensal', 'anual': 'Anual'}[frequencia] ?? frequencia;
  String rotuloStatus(DateTime hoje) {
    if (status == 'cancelado') return 'Cancelado';
    if (!pendente) return receita ? 'Recebido' : 'Pago';
    final dia = diaAgenda(hoje);
    if (data.isBefore(dia)) return 'Vencido • pendente';
    return data.isAfter(dia) ? 'Previsto' : 'Pendente';
  }
  factory Previsto.mapa(Map<String, Object?> m) => Previsto(
    id: m['id'] as int,
    serie: m['serie'] as String,
    titulo: m['titulo'] as String,
    tipo: m['tipo'] as String,
    centavos: m['centavos'] as int,
    categoria: m['categoria'] as String,
    data: DateTime.parse(m['data'] as String),
    frequencia: m['frequencia'] as String,
    lembrete: m['lembrete'] as int?,
    hora: m['hora'] as int,
    minuto: m['minuto'] as int,
    status: m['status'] as String,
    conta: m['conta'] as String? ?? '',
    observacoes: m['observacoes'] as String? ?? '',
  );
}


class AgendaBanco {
  AgendaBanco(this.database);
  final Future<Database> database;
  // Migração aditiva: os registros e IDs anteriores permanecem intactos.
  static Future<void> migrarPlanejamento(DatabaseExecutor db) async {
    for (final tabela in ['agenda', 'movimentacoes']) {
      final colunas = await db.rawQuery('PRAGMA table_info($tabela)');
      for (final campo in ['conta', 'observacoes']) {
        if (!colunas.any((c) => c['name'] == campo)) {
          await db.execute("ALTER TABLE $tabela ADD COLUMN $campo TEXT NOT NULL DEFAULT ''");
        }
      }
    }
    // Uma exclusão pelo Histórico reabre a previsão, sem recriar pagamentos.
    await db.execute('''CREATE TRIGGER IF NOT EXISTS agenda_movimentacao_excluida
      AFTER DELETE ON movimentacoes BEGIN
        UPDATE agenda SET status = 'pendente', movimentacao_id = NULL
        WHERE movimentacao_id = OLD.id AND status = 'realizado';
      END''');
    await db.execute('''CREATE TRIGGER IF NOT EXISTS agenda_movimentacao_editada
      AFTER UPDATE ON movimentacoes BEGIN
        UPDATE agenda SET titulo = NEW.descricao, tipo = NEW.tipo,
          centavos = CAST(ROUND(NEW.valor * 100) AS INTEGER), categoria = NEW.categoria,
          conta = NEW.conta, observacoes = NEW.observacoes
        WHERE movimentacao_id = NEW.id AND status = 'realizado';
      END''');
    await db.execute('''CREATE TRIGGER IF NOT EXISTS agenda_categoria_editada
      AFTER UPDATE OF nome, tipo ON categorias BEGIN
        UPDATE agenda SET categoria = NEW.nome, tipo = NEW.tipo
        WHERE categoria = OLD.nome AND tipo = OLD.tipo;
      END''');
  }
  static Future<void> criar(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS agenda (
      id INTEGER PRIMARY KEY AUTOINCREMENT, serie TEXT NOT NULL,
      titulo TEXT NOT NULL, tipo TEXT NOT NULL CHECK(tipo IN ('receita','despesa')),
      centavos INTEGER NOT NULL CHECK(centavos > 0), categoria TEXT NOT NULL,
      data TEXT NOT NULL, frequencia TEXT NOT NULL,
      lembrete INTEGER, hora INTEGER NOT NULL, minuto INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'pendente' CHECK(status IN ('pendente','realizado','cancelado')),
      movimentacao_id INTEGER, UNIQUE(serie, data))''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS agenda_data ON agenda(data, status)',
    );
  }

  Future<List<Previsto>> listar() async => (await (await database).query(
    'agenda',
    orderBy: 'data, id',
  )).map(Previsto.mapa).toList();

  Future<void> salvar({
    Previsto? existente,
    required String titulo,
    required String tipo,
    required int centavos,
    required String categoria,
    required DateTime data,
    required String frequencia,
    required int quantidade,
    required int? lembrete,
    required int hora,
    required int minuto,
    String conta = '',
    String observacoes = '',
  }) async {
    if (titulo.trim().isEmpty ||
        centavos <= 0 ||
        hora < 0 ||
        hora > 23 ||
        minuto < 0 ||
        minuto > 59) {
      throw ArgumentError('Dados inválidos.');
    }
    final datas = datasRecorrentes(
      data,
      existente == null ? frequencia : 'unica',
      quantidade,
    );
    final db = await database;
    await db.transaction((txn) async {
      final valores = <String, Object?>{
        'titulo': titulo.trim(),
        'tipo': tipo,
        'centavos': centavos,
        'categoria': categoria,
        'lembrete': lembrete,
        'hora': hora,
        'minuto': minuto,
        'conta': conta.trim(),
        'observacoes': observacoes.trim(),
      };
      if (existente != null) {
        final linhas = await txn.query('agenda', where: "id = ? AND status != 'cancelado'",
          whereArgs: [existente.id]);
        if (linhas.isEmpty) throw StateError('Compromisso indisponível.');
        final atual = linhas.single;
        final alterados = await txn.update(
          'agenda',
          {...valores, 'data': dataAgenda(data)},
          where: "id = ? AND status != 'cancelado'",
          whereArgs: [existente.id],
        );
        if (alterados != 1) {
          throw StateError('Este lançamento não está mais pendente.');
        }
        if (atual['status'] == 'realizado') {
          final quantidade = await txn.update('movimentacoes', {
            'descricao': titulo.trim(), 'tipo': tipo, 'valor': centavos / 100,
            'categoria': categoria, 'conta': conta.trim(), 'observacoes': observacoes.trim(),
          }, where: 'id = ?', whereArgs: [atual['movimentacao_id']]);
          if (quantidade != 1) throw StateError('Movimentação vinculada não encontrada.');
        }
      } else {
        final serie = '${DateTime.now().microsecondsSinceEpoch}';
        for (final dia in datas) {
          await txn.insert('agenda', {
            ...valores,
            'serie': serie,
            'data': dataAgenda(dia),
            'frequencia': frequencia,
          });
        }
      }
    });
  }

  Future<bool> realizar(Previsto item, DateTime dataRealizada) async {
    final db = await database;
    return db.transaction((txn) async {
      final linhas = await txn.query(
        'agenda',
        where: "id = ? AND status = 'pendente'",
        whereArgs: [item.id],
      );
      if (linhas.isEmpty) return false;
      final atual = Previsto.mapa(linhas.single);
      int? contaId;
      final nomeConta = ContasBanco.normalizarNome(atual.conta);
      if (nomeConta.isNotEmpty) {
        final possuiContas = await txn.rawQuery(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'contas'",
        );
        if (possuiContas.isNotEmpty) {
          final contas = await txn.query(
            'contas',
            columns: ['id'],
            where: 'LOWER(nome) = ?',
            whereArgs: [nomeConta.toLowerCase()],
          );
          if (contas.length == 1) {
            contaId = contas.single['id'] as int?;
          }
        }
      }
      final id = await txn.insert('movimentacoes', {
        'tipo': atual.tipo,
        'valor': atual.centavos / 100,
        'categoria': atual.categoria,
        'descricao': atual.titulo,
        'conta': atual.conta,
        'conta_id': ?contaId,
        'observacoes': atual.observacoes,
        'data': diaAgenda(dataRealizada).toIso8601String(),
      });
      await txn.update(
        'agenda',
        {'status': 'realizado', 'movimentacao_id': id},
        where: 'id = ?',
        whereArgs: [item.id],
      );
      return true;
    });
  }

  Future<void> cancelar(Previsto item, {required bool seguintes}) async {
    await (await database).update(
      'agenda',
      {'status': 'cancelado'},
      where: seguintes
          ? "serie = ? AND data >= ? AND status = 'pendente'"
          : "id = ? AND status = 'pendente'",
      whereArgs: seguintes ? [item.serie, dataAgenda(item.data)] : [item.id],
    );
  }

  Future<void> excluir(Previsto item) async {
    await (await database).delete('agenda', where: 'id = ?', whereArgs: [item.id]);
  }
}








