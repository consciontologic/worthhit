import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worthhit/ui/worthhit_theme.dart';

void main() {
  double contrast(Color a, Color b) {
    final values = [a.computeLuminance(), b.computeLuminance()]..sort();
    return (values.last + .05) / (values.first + .05);
  }

  for (final brightness in Brightness.values) {
    test(
      '$brightness surfaces and accent retain readable text and controls',
      () {
        final palette = brightness == Brightness.dark
            ? WorthhitPalette.dark
            : WorthhitPalette.light;
        for (final surface in [palette.paper, palette.soft, palette.surface]) {
          expect(contrast(palette.ink, surface), greaterThanOrEqualTo(4.5));
          expect(contrast(palette.muted, surface), greaterThanOrEqualTo(4.5));
        }
        expect(
          contrast(palette.onLime, palette.lime),
          greaterThanOrEqualTo(4.5),
        );
        final theme = worthhitTheme(brightness: brightness);
        final border =
            theme.inputDecorationTheme.enabledBorder! as OutlineInputBorder;
        expect(
          contrast(border.borderSide.color, palette.surface),
          greaterThanOrEqualTo(3),
        );
      },
    );
  }
}
