import 'package:flutter/material.dart';

abstract final class WorthitColors {
  static const paper = Color(0xFFFFF9ED);
  static const ink = Color(0xFF20211D);
  static const lime = Color(0xFFD4F267);
  static const coral = Color(0xFFFF8B70);
  static const muted = Color(0xFF5C5D52);
  static const line = Color(0xFFD5D0C2);
  static const soft = Color(0xFFF1EBDD);
}

ThemeData worthitTheme() {
  const outline = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(6)),
    borderSide: BorderSide(color: WorthitColors.ink, width: 1.5),
  );
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'WorthitSans',
    scaffoldBackgroundColor: WorthitColors.paper,
    colorScheme: const ColorScheme.light(
      primary: WorthitColors.ink,
      onPrimary: WorthitColors.paper,
      secondary: WorthitColors.lime,
      onSecondary: WorthitColors.ink,
      surface: WorthitColors.paper,
      onSurface: WorthitColors.ink,
      error: Color(0xFF9E2D19),
      onError: Colors.white,
      outline: WorthitColors.muted,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      headlineLarge: const TextStyle(
        fontSize: 38,
        height: 1.08,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.1,
        color: WorthitColors.ink,
      ),
      headlineMedium: const TextStyle(
        fontSize: 29,
        height: 1.12,
        fontWeight: FontWeight.w700,
        letterSpacing: -.6,
      ),
      titleLarge: const TextStyle(
        fontSize: 22,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -.3,
      ),
      titleMedium: const TextStyle(
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: const TextStyle(fontSize: 16, height: 1.5),
      bodyMedium: const TextStyle(fontSize: 14, height: 1.5),
      bodySmall: const TextStyle(
        fontSize: 12,
        height: 1.5,
        color: WorthitColors.muted,
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: WorthitColors.ink,
      selectionColor: WorthitColors.lime,
      selectionHandleColor: WorthitColors.ink,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: outline,
      enabledBorder: outline,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
        borderSide: BorderSide(color: WorthitColors.ink, width: 3),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      hintStyle: TextStyle(color: WorthitColors.muted, fontSize: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        backgroundColor: WorthitColors.lime,
        foregroundColor: WorthitColors.ink,
        side: const BorderSide(color: WorthitColors.ink, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(
          fontFamily: 'WorthitSans',
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: WorthitColors.ink,
        side: const BorderSide(color: WorthitColors.ink, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        textStyle: const TextStyle(
          fontFamily: 'WorthitSans',
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
    dividerTheme: const DividerThemeData(
      color: WorthitColors.line,
      thickness: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: WorthitColors.ink,
      linearTrackColor: WorthitColors.lime,
    ),
  );
}

class WorthitBrand extends StatelessWidget {
  const WorthitBrand({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: WorthitColors.lime,
          border: Border.all(color: WorthitColors.ink, width: 2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.sell_outlined, size: 23),
      ),
      if (!compact) ...[
        const SizedBox(width: 10),
        const Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'worthit',
              style: TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
                height: 1.1,
              ),
            ),
          ),
        ),
      ],
    ],
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
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: warning ? const Color(0xFFFFE3D8) : WorthitColors.soft,
      border: Border.all(color: WorthitColors.ink, width: 1.5),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message),
        if (action != null) ...[const SizedBox(height: 6), action!],
      ],
    ),
  );
}
