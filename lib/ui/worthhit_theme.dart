import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

/// Semantic surfaces keep controls and status copy readable in both appearances.
class WorthhitPalette {
  const WorthhitPalette({
    required this.paper,
    required this.ink,
    required this.muted,
    required this.line,
    required this.soft,
    required this.surface,
    required this.warning,
  });
  final Color paper, ink, muted, line, soft, surface, warning;
  Color get lime => const Color(0xFFCAEF63);
  Color get onLime => const Color(0xFF20241D);
  static const light = WorthhitPalette(
    paper: Color(0xFFECEDE5),
    ink: Color(0xFF252A25),
    muted: Color(0xFF555D53),
    line: Color(0xFFB6BCAE),
    soft: Color(0xFFE2E5D9),
    surface: Color(0xFFF6F7EF),
    warning: Color(0xFFF3DFCD),
  );
  static const dark = WorthhitPalette(
    paper: Color(0xFF161A18),
    ink: Color(0xFFE9EDE1),
    muted: Color(0xFFADB7A7),
    line: Color(0xFF4D574B),
    soft: Color(0xFF252D26),
    surface: Color(0xFF1D241F),
    warning: Color(0xFF493327),
  );
  static WorthhitPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

ThemeData worthhitTheme({Brightness brightness = Brightness.light}) {
  final c = brightness == Brightness.dark
      ? WorthhitPalette.dark
      : WorthhitPalette.light;
  final outline = OutlineInputBorder(
    borderRadius: BorderRadius.circular(2),
    borderSide: BorderSide(color: c.muted, width: 1.5),
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'WorthhitSans',
    fontFamilyFallback: const ['WorthhitArabic', 'WorthhitChinese'],
    scaffoldBackgroundColor: c.paper,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: c.ink,
      onPrimary: c.paper,
      secondary: c.lime,
      onSecondary: c.onLime,
      error: brightness == Brightness.dark
          ? const Color(0xFFFFB595)
          : const Color(0xFF942D13),
      onError: c.paper,
      surface: c.surface,
      onSurface: c.ink,
      outline: c.line,
      surfaceContainerHighest: c.soft,
      onSurfaceVariant: c.muted,
    ),
  );
  return base.copyWith(
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.paper,
      shape: RoundedRectangleBorder(side: BorderSide(color: c.ink, width: 2)),
    ),
    textTheme: base.textTheme.copyWith(
      headlineLarge: TextStyle(
        fontFamily: 'WorthhitDisplay',
        fontFamilyFallback: const ['WorthhitArabic', 'WorthhitChinese'],
        fontSize: 40,
        height: 1.04,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        color: c.ink,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'WorthhitDisplay',
        fontFamilyFallback: const ['WorthhitArabic', 'WorthhitChinese'],
        fontSize: 30,
        height: 1.12,
        fontWeight: FontWeight.w700,
        letterSpacing: -.7,
        color: c.ink,
      ),
      titleLarge: TextStyle(
        fontFamily: 'WorthhitDisplay',
        fontFamilyFallback: const ['WorthhitArabic', 'WorthhitChinese'],
        fontSize: 22,
        height: 1.22,
        fontWeight: FontWeight.w700,
        letterSpacing: -.35,
        color: c.ink,
      ),
      titleMedium: TextStyle(
        fontFamily: 'WorthhitSans',
        fontFamilyFallback: const ['WorthhitArabic', 'WorthhitChinese'],
        fontSize: 15,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: c.ink,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'WorthhitSans',
        fontFamilyFallback: const ['WorthhitArabic', 'WorthhitChinese'],
        fontSize: 16,
        height: 1.5,
        color: c.ink,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'WorthhitSans',
        fontFamilyFallback: const ['WorthhitArabic', 'WorthhitChinese'],
        fontSize: 14,
        height: 1.5,
        color: c.ink,
      ),
      bodySmall: TextStyle(
        fontFamily: 'WorthhitSans',
        fontFamilyFallback: const ['WorthhitArabic', 'WorthhitChinese'],
        fontSize: 12,
        height: 1.5,
        color: c.muted,
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.ink,
      selectionColor: c.lime.withValues(alpha: .35),
      selectionHandleColor: c.ink,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      border: outline,
      enabledBorder: outline,
      focusedBorder: outline.copyWith(
        borderSide: BorderSide(color: c.ink, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      hintStyle: TextStyle(color: c.muted, fontSize: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        backgroundColor: c.lime,
        foregroundColor: c.onLime,
        side: BorderSide(color: c.onLime, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        textStyle: const TextStyle(
          fontFamily: 'WorthhitSans',
          fontFamilyFallback: ['WorthhitArabic', 'WorthhitChinese'],
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: c.ink,
        side: BorderSide(color: c.muted, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        textStyle: const TextStyle(
          fontFamily: 'WorthhitSans',
          fontFamilyFallback: ['WorthhitArabic', 'WorthhitChinese'],
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    dividerTheme: DividerThemeData(color: c.line, thickness: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.ink,
      linearTrackColor: c.soft,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? c.onLime : c.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? c.lime : c.soft,
      ),
    ),
    tooltipTheme: TooltipThemeData(
      // Tooltip replaces its inherited style; preserve the local font chain.
      textStyle: base.textTheme.bodyMedium!.copyWith(color: c.paper),
      decoration: BoxDecoration(color: c.ink),
    ),
  );
}

/// Translates interface copy only. Evidence excerpts and user text stay literal.
class AppText extends StatelessWidget {
  const AppText(
    this.source, {
    super.key,
    this.style,
    this.textAlign,
    this.overflow,
    this.params = const {},
  });
  final String source;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final Map<String, Object> params;
  @override
  Widget build(BuildContext context) => Text(
    AppStrings.of(context).text(source, params),
    style: style,
    textAlign: textAlign,
    overflow: overflow,
  );
}

class WorthhitBrand extends StatelessWidget {
  const WorthhitBrand({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Worthhit',
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          Theme.of(context).brightness == Brightness.dark
              ? 'assets/brand/mark-dark.png'
              : 'assets/brand/mark-light.png',
          width: compact ? 36 : 28,
          height: compact ? 36 : 28,
          excludeFromSemantics: true,
        ),
        if (!compact) const SizedBox(width: 8),
        if (!compact)
          const Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'worthhit',
                style: TextStyle(
                  fontFamily: 'WorthhitDisplay',
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.9,
                  height: 1.1,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class StatusNotice extends StatelessWidget {
  const StatusNotice({
    super.key,
    required this.message,
    this.warning = false,
    this.action,
  });
  final String message;
  final bool warning;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final c = WorthhitPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warning ? c.warning : c.soft,
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.of(context).safeMessage(message)),
          if (action != null) ...[const SizedBox(height: 6), action!],
        ],
      ),
    );
  }
}
