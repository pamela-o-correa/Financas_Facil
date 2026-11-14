part of 'main.dart';

// ============================================================
// DESIGN SYSTEM — MINIMALISTA PREMIUM (4 TEMAS)
// ============================================================

abstract final class Espacamento {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class RaioBorda {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double cartao = 20;
  static const double destaque = 24;
}

class PaletaTema {
  const PaletaTema({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.brilhoPadrao,
    required this.background,
    required this.surface,
    required this.surfaceContainer,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.primaryText,
    required this.secondaryText,
    required this.accent,
    required this.outline,
    required this.receita,
    required this.despesa,
    required this.paletaGrafico,
  });

  final String id;
  final String nome;
  final String descricao;
  final Brightness brilhoPadrao;
  final Color background;
  final Color surface;
  final Color surfaceContainer;
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color primaryText;
  final Color secondaryText;
  final Color accent;
  final Color outline;
  final Color receita;
  final Color despesa;
  final List<Color> paletaGrafico;
}

const Map<String, PaletaTema> paletasTema = {
  'Noir': PaletaTema(
    id: 'Noir',
    nome: 'Noir',
    descricao: 'Preto e branco sofisticado e discreto',
    brilhoPadrao: Brightness.dark,
    background: Color(0xFF101114),
    surface: Color(0xFF1C1D21),
    surfaceContainer: Color(0xFF282A2F),
    primary: Color(0xFFE4E4E4),
    onPrimary: Color(0xFF101114),
    secondary: Color(0xFFA8ABB2),
    primaryText: Color(0xFFF7F7F5),
    secondaryText: Color(0xFFA8ABB2),
    accent: Color(0xFFE4E4E4),
    outline: Color(0xFF34373E),
    receita: Color(0xFF52C799),
    despesa: Color(0xFFEB6F70),
    paletaGrafico: [
      Color(0xFFE4E4E4),
      Color(0xFF52C799),
      Color(0xFF8AB4F8),
      Color(0xFFF6AD55),
      Color(0xFFB794F4),
      Color(0xFFEB6F70),
      Color(0xFF90A4AE),
    ],
  ),
  'Espresso': PaletaTema(
    id: 'Espresso',
    nome: 'Espresso',
    descricao: 'Estética café, aconchegante e refinada',
    brilhoPadrao: Brightness.light,
    background: Color(0xFFFAF6F0),
    surface: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFE8D7C3),
    primary: Color(0xFF35271F),
    onPrimary: Color(0xFFFAF6F0),
    secondary: Color(0xFF795D49),
    primaryText: Color(0xFF35271F),
    secondaryText: Color(0xFF6E5849),
    accent: Color(0xFF795D49),
    outline: Color(0xFFDCC7B0),
    receita: Color(0xFF1F6E4A),
    despesa: Color(0xFFB23A32),
    paletaGrafico: [
      Color(0xFF35271F),
      Color(0xFF795D49),
      Color(0xFFA67C52),
      Color(0xFF2B6F56),
      Color(0xFFC47D5B),
      Color(0xFF8C6258),
      Color(0xFF9E8C7A),
    ],
  ),
  'Sage': PaletaTema(
    id: 'Sage',
    nome: 'Sage',
    descricao: 'Verde natural, moderno e elegante',
    brilhoPadrao: Brightness.light,
    background: Color(0xFFF4F7F2),
    surface: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFE1EBDF),
    primary: Color(0xFF183C30),
    onPrimary: Color(0xFFF4F7F2),
    secondary: Color(0xFF47735E),
    primaryText: Color(0xFF193B30),
    secondaryText: Color(0xFF4F6B5F),
    accent: Color(0xFF47735E),
    outline: Color(0xFFCBD9C8),
    receita: Color(0xFF186A4B),
    despesa: Color(0xFFB33F3D),
    paletaGrafico: [
      Color(0xFF183C30),
      Color(0xFF47735E),
      Color(0xFF6B9E82),
      Color(0xFF3C6E71),
      Color(0xFFB5835A),
      Color(0xFF84A98C),
      Color(0xFF7B8C83),
    ],
  ),
  'Amethyst': PaletaTema(
    id: 'Amethyst',
    nome: 'Amethyst',
    descricao: 'Roxo sofisticado, contemporâneo e delicado',
    brilhoPadrao: Brightness.light,
    background: Color(0xFFF7F4FA),
    surface: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFEBE4F3),
    primary: Color(0xFF392B53),
    onPrimary: Color(0xFFF7F4FA),
    secondary: Color(0xFF775C9E),
    primaryText: Color(0xFF35284A),
    secondaryText: Color(0xFF64567A),
    accent: Color(0xFF775C9E),
    outline: Color(0xFFDAD0E8),
    receita: Color(0xFF1A7353),
    despesa: Color(0xFFB53B48),
    paletaGrafico: [
      Color(0xFF392B53),
      Color(0xFF775C9E),
      Color(0xFF9B82C1),
      Color(0xFF3B7A6B),
      Color(0xFFC26D85),
      Color(0xFF647AA3),
      Color(0xFF8C829E),
    ],
  ),
};

const Map<String, String> _aliasTemasLegados = {
  'Roxo': 'Amethyst',
  'Verde': 'Sage',
  'Azul': 'Noir',
};

String normalizarNomeTema(String? nome) {
  if (nome == null) return 'Amethyst';
  if (paletasTema.containsKey(nome)) return nome;
  return _aliasTemasLegados[nome] ?? 'Amethyst';
}

PaletaTema paletaAtual([String? nome]) =>
    paletasTema[normalizarNomeTema(nome ?? corTema.value)]!;

@immutable
class CoresSemanticas extends ThemeExtension<CoresSemanticas> {
  const CoresSemanticas({
    required this.receita,
    required this.receitaFundo,
    required this.despesa,
    required this.despesaFundo,
    required this.alerta,
    required this.alertaFundo,
    required this.bordaSutil,
    required this.textoSecundario,
    required this.paletaGrafico,
  });

  final Color receita;
  final Color receitaFundo;
  final Color despesa;
  final Color despesaFundo;
  final Color alerta;
  final Color alertaFundo;
  final Color bordaSutil;
  final Color textoSecundario;
  final List<Color> paletaGrafico;

  static CoresSemanticas de(BuildContext context) {
    final ext = Theme.of(context).extension<CoresSemanticas>();
    if (ext != null) return ext;
    final escuro = Theme.of(context).brightness == Brightness.dark;
    return CoresSemanticas(
      receita: escuro ? const Color(0xFF52C799) : const Color(0xFF1A7353),
      receitaFundo: escuro
          ? const Color(0xFF52C799).withValues(alpha: 0.14)
          : const Color(0xFF1A7353).withValues(alpha: 0.10),
      despesa: escuro ? const Color(0xFFEB6F70) : const Color(0xFFB53B48),
      despesaFundo: escuro
          ? const Color(0xFFEB6F70).withValues(alpha: 0.14)
          : const Color(0xFFB53B48).withValues(alpha: 0.10),
      alerta: escuro ? const Color(0xFFF6AD55) : const Color(0xFFB4690E),
      alertaFundo: escuro
          ? const Color(0xFFF6AD55).withValues(alpha: 0.15)
          : const Color(0xFFB4690E).withValues(alpha: 0.12),
      bordaSutil: Theme.of(context).colorScheme.outlineVariant,
      textoSecundario: Theme.of(context).colorScheme.onSurfaceVariant,
      paletaGrafico: paletasTema['Amethyst']!.paletaGrafico,
    );
  }

  @override
  CoresSemanticas copyWith({
    Color? receita,
    Color? receitaFundo,
    Color? despesa,
    Color? despesaFundo,
    Color? alerta,
    Color? alertaFundo,
    Color? bordaSutil,
    Color? textoSecundario,
    List<Color>? paletaGrafico,
  }) {
    return CoresSemanticas(
      receita: receita ?? this.receita,
      receitaFundo: receitaFundo ?? this.receitaFundo,
      despesa: despesa ?? this.despesa,
      despesaFundo: despesaFundo ?? this.despesaFundo,
      alerta: alerta ?? this.alerta,
      alertaFundo: alertaFundo ?? this.alertaFundo,
      bordaSutil: bordaSutil ?? this.bordaSutil,
      textoSecundario: textoSecundario ?? this.textoSecundario,
      paletaGrafico: paletaGrafico ?? this.paletaGrafico,
    );
  }

  @override
  CoresSemanticas lerp(ThemeExtension<CoresSemanticas>? other, double t) {
    if (other is! CoresSemanticas) return this;
    return CoresSemanticas(
      receita: Color.lerp(receita, other.receita, t)!,
      receitaFundo: Color.lerp(receitaFundo, other.receitaFundo, t)!,
      despesa: Color.lerp(despesa, other.despesa, t)!,
      despesaFundo: Color.lerp(despesaFundo, other.despesaFundo, t)!,
      alerta: Color.lerp(alerta, other.alerta, t)!,
      alertaFundo: Color.lerp(alertaFundo, other.alertaFundo, t)!,
      bordaSutil: Color.lerp(bordaSutil, other.bordaSutil, t)!,
      textoSecundario: Color.lerp(textoSecundario, other.textoSecundario, t)!,
      paletaGrafico: t < 0.5 ? paletaGrafico : other.paletaGrafico,
    );
  }
}

ThemeData construirTemaPremium({
  required String nomeTema,
  required Brightness brilhoSolicitado,
}) {
  final paleta = paletaAtual(nomeTema);
  final usarEscuro = paleta.id == 'Noir' || brilhoSolicitado == Brightness.dark;

  final Color background;
  final Color surface;
  final Color surfaceContainer;
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color primaryText;
  final Color secondaryText;
  final Color outline;
  final Color receita;
  final Color despesa;

  if (!usarEscuro) {
    background = paleta.background;
    surface = paleta.surface;
    surfaceContainer = paleta.surfaceContainer;
    primary = paleta.primary;
    onPrimary = paleta.onPrimary;
    secondary = paleta.secondary;
    primaryText = paleta.primaryText;
    secondaryText = paleta.secondaryText;
    outline = paleta.outline;
    receita = paleta.receita;
    despesa = paleta.despesa;
  } else if (paleta.id == 'Noir') {
    background = paleta.background;
    surface = paleta.surface;
    surfaceContainer = paleta.surfaceContainer;
    primary = paleta.primary;
    onPrimary = paleta.onPrimary;
    secondary = paleta.secondary;
    primaryText = paleta.primaryText;
    secondaryText = paleta.secondaryText;
    outline = paleta.outline;
    receita = paleta.receita;
    despesa = paleta.despesa;
  } else {
    // Versão noturna harmônica para Espresso, Sage e Amethyst quando o modo escuro é forçado.
    background = Color.lerp(const Color(0xFF0E1013), paleta.primary, 0.16)!;
    surface = Color.lerp(const Color(0xFF17191E), paleta.primary, 0.22)!;
    surfaceContainer = Color.lerp(
      const Color(0xFF23262D),
      paleta.secondary,
      0.24,
    )!;
    primary = Color.lerp(
      const Color(0xFFF3F4F6),
      paleta.surfaceContainer,
      0.55,
    )!;
    onPrimary = Color.lerp(const Color(0xFF111215), paleta.primary, 0.45)!;
    secondary = Color.lerp(const Color(0xFFB8BDC6), paleta.secondary, 0.45)!;
    primaryText = const Color(0xFFF5F5F3);
    secondaryText = const Color(0xFFA9AEB7);
    outline = Color.lerp(const Color(0xFF2E323B), paleta.secondary, 0.25)!;
    receita = const Color(0xFF52C799);
    despesa = const Color(0xFFEB6F70);
  }

  final semente = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: usarEscuro ? Brightness.dark : Brightness.light,
  );

  final colorScheme = semente.copyWith(
    brightness: usarEscuro ? Brightness.dark : Brightness.light,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: surfaceContainer,
    onPrimaryContainer: primaryText,
    secondary: secondary,
    onSecondary: usarEscuro ? const Color(0xFF101114) : Colors.white,
    secondaryContainer: surfaceContainer,
    onSecondaryContainer: primaryText,
    surface: background,
    onSurface: primaryText,
    onSurfaceVariant: secondaryText,
    surfaceContainerLowest: background,
    surfaceContainerLow: surface,
    surfaceContainer: surfaceContainer.withValues(
      alpha: usarEscuro ? 0.65 : 0.45,
    ),
    surfaceContainerHigh: surfaceContainer.withValues(
      alpha: usarEscuro ? 0.85 : 0.72,
    ),
    surfaceContainerHighest: surfaceContainer,
    outline: outline,
    outlineVariant: outline.withValues(alpha: usarEscuro ? 0.65 : 0.55),
    error: despesa,
  );

  final baseText =
      (usarEscuro
              ? Typography.material2021().white
              : Typography.material2021().black)
          .apply(bodyColor: primaryText, displayColor: primaryText);

  final textTheme = baseText.copyWith(
    headlineLarge: baseText.headlineLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
      color: primaryText,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
    headlineMedium: baseText.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      color: primaryText,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
    titleLarge: baseText.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: primaryText,
    ),
    titleMedium: baseText.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
      color: primaryText,
    ),
    bodyLarge: baseText.bodyLarge?.copyWith(color: primaryText, height: 1.35),
    bodyMedium: baseText.bodyMedium?.copyWith(color: primaryText, height: 1.35),
    bodySmall: baseText.bodySmall?.copyWith(color: secondaryText, height: 1.3),
    labelLarge: baseText.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: colorScheme.brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: background,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: primaryText,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: primaryText,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RaioBorda.cartao),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      margin: const EdgeInsets.only(bottom: Espacamento.sm),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      elevation: 0,
      height: 68,
      surfaceTintColor: Colors.transparent,
      indicatorColor: surfaceContainer,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: primary, size: 24);
        }
        return IconThemeData(color: secondaryText, size: 22);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: primaryText,
          );
        }
        return TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: secondaryText,
        );
      }),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: onPrimary,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RaioBorda.lg),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: Espacamento.lg,
          vertical: Espacamento.sm + 2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RaioBorda.md),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryText,
        side: BorderSide(color: colorScheme.outline),
        padding: const EdgeInsets.symmetric(
          horizontal: Espacamento.md,
          vertical: Espacamento.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RaioBorda.md),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      selectedColor: surfaceContainer,
      side: BorderSide(color: colorScheme.outlineVariant),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RaioBorda.sm),
      ),
      labelStyle: TextStyle(
        color: primaryText,
        fontWeight: FontWeight.w500,
        fontSize: 13,
      ),
      secondaryLabelStyle: TextStyle(
        color: primaryText,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RaioBorda.destaque),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(RaioBorda.destaque),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: usarEscuro ? surfaceContainer : primary,
      contentTextStyle: TextStyle(
        color: usarEscuro ? primaryText : onPrimary,
        fontWeight: FontWeight.w500,
      ),
      actionTextColor: usarEscuro ? primary : surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RaioBorda.md),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Espacamento.md,
        vertical: Espacamento.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RaioBorda.md),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RaioBorda.md),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RaioBorda.md),
        borderSide: BorderSide(color: primary, width: 1.8),
      ),
    ),
    extensions: [
      CoresSemanticas(
        receita: receita,
        receitaFundo: receita.withValues(alpha: usarEscuro ? 0.16 : 0.11),
        despesa: despesa,
        despesaFundo: despesa.withValues(alpha: usarEscuro ? 0.16 : 0.11),
        alerta: usarEscuro ? const Color(0xFFF6AD55) : const Color(0xFFB4690E),
        alertaFundo:
            (usarEscuro ? const Color(0xFFF6AD55) : const Color(0xFFB4690E))
                .withValues(alpha: usarEscuro ? 0.16 : 0.12),
        bordaSutil: colorScheme.outlineVariant,
        textoSecundario: secondaryText,
        paletaGrafico: paleta.paletaGrafico,
      ),
    ],
  );
}

// ============================================================
// COMPONENTES REUTILIZÁVEIS DO DESIGN SYSTEM
// ============================================================

class CartaoMinimalista extends StatelessWidget {
  const CartaoMinimalista({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Espacamento.lg),
    this.corFundo,
    this.corBorda,
    this.raio = RaioBorda.cartao,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? corFundo;
  final Color? corBorda;
  final double raio;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final corpo = Padding(padding: padding, child: child);
    return Material(
      color: corFundo ?? esquema.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(raio),
        side: BorderSide(color: corBorda ?? esquema.outlineVariant, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? corpo
          : InkWell(
              borderRadius: BorderRadius.circular(raio),
              onTap: onTap,
              child: corpo,
            ),
    );
  }
}

class SeletorTemaVisual extends StatelessWidget {
  const SeletorTemaVisual({
    super.key,
    required this.temaSelecionado,
    required this.onSelecionar,
    this.habilitado = true,
  });

  final String temaSelecionado;
  final ValueChanged<String> onSelecionar;
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    final atual = normalizarNomeTema(temaSelecionado);
    final esquema = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final paleta in paletasTema.values)
          Padding(
            padding: const EdgeInsets.only(bottom: Espacamento.sm),
            child: Semantics(
              button: true,
              selected: atual == paleta.id,
              label: 'Tema ${paleta.nome}. ${paleta.descricao}',
              child: InkWell(
                borderRadius: BorderRadius.circular(RaioBorda.lg),
                onTap: habilitado ? () => onSelecionar(paleta.id) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(Espacamento.md),
                  decoration: BoxDecoration(
                    color: esquema.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(RaioBorda.lg),
                    border: Border.all(
                      color: atual == paleta.id
                          ? esquema.primary
                          : esquema.outlineVariant,
                      width: atual == paleta.id ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      _AmostraPaletaTema(paleta: paleta),
                      const SizedBox(width: Espacamento.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              paleta.nome,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              paleta.descricao,
                              style: TextStyle(
                                fontSize: 12,
                                color: esquema.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        atual == paleta.id
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: atual == paleta.id
                            ? esquema.primary
                            : esquema.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AmostraPaletaTema extends StatelessWidget {
  const _AmostraPaletaTema({required this.paleta});
  final PaletaTema paleta;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 44,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: paleta.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: paleta.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: paleta.primary,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(6),
                ),
              ),
            ),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: paleta.surfaceContainer,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
