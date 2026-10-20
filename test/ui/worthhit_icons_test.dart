import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worthhit/ui/worthhit_icons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'every exported icon resolves to an outlined glyph in the bundled font',
    () async {
      final manifest = jsonDecode(
        File('assets/icons/manifest.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final data = await rootBundle.load('assets/icons/WorthhitIcons.ttf');
      final tables = <String, int>{};
      for (var index = 0; index < data.getUint16(4); index++) {
        final start = 12 + index * 16;
        final name = String.fromCharCodes(
          data.buffer.asUint8List(data.offsetInBytes + start, 4),
        );
        tables[name] = data.getUint32(start + 8);
      }
      final cmap = tables['cmap']!;
      int? format4;
      for (var index = 0; index < data.getUint16(cmap + 2); index++) {
        final record = cmap + 4 + index * 8;
        final offset = cmap + data.getUint32(record + 4);
        if (data.getUint16(offset) == 4) format4 = offset;
      }
      expect(format4, isNotNull, reason: 'BMP private-use icons need a cmap.');

      final glyphNames = <String>{};
      final glyphIds = <int>{};
      final shortLocations = data.getInt16(tables['head']! + 50) == 0;
      final loca = tables['loca']!;
      int location(int index) => shortLocations
          ? data.getUint16(loca + index * 2) * 2
          : data.getUint32(loca + index * 4);

      for (final item in manifest['glyphs'] as List<dynamic>) {
        final icon = item as Map<String, dynamic>;
        final name = icon['name'] as String;
        final codepoint = icon['codepoint'] as int;
        expect(glyphNames.add(name), isTrue, reason: 'Duplicate $name export.');
        final glyphId = _glyphId(data, format4!, codepoint);
        expect(glyphId, greaterThan(0), reason: '$name must not be .notdef.');
        expect(
          glyphIds.add(glyphId),
          isTrue,
          reason: '$name must have its own shape.',
        );
        final start = location(glyphId);
        expect(
          location(glyphId + 1),
          greaterThan(start),
          reason: '$name is empty.',
        );
        expect(
          data.getInt16(tables['glyf']! + start),
          greaterThan(0),
          reason: '$name needs actual contours.',
        );
        final metrics = data.getUint16(tables['hhea']! + 34);
        final bearingOffset = glyphId < metrics
            ? glyphId * 4 + 2
            : metrics * 4 + (glyphId - metrics) * 2;
        expect(
          data.getInt16(tables['hmtx']! + bearingOffset),
          data.getInt16(tables['glyf']! + start + 2),
          reason: '$name must stay centered in its 24-unit design box.',
        );
        final source = File('assets/icons/$name.svg').readAsStringSync();
        expect(source, contains('fill="currentColor"'));
        expect(source, isNot(contains('<rect')));
      }
      expect(glyphNames, hasLength(35));
      expect(
        data.getUint16(tables['maxp']! + 4),
        glyphNames.length + 1,
        reason: 'The font contains only exported icons and .notdef.',
      );
    },
  );

  test('navigation mirrors in RTL while pictograms keep their meaning', () {
    expect(WorthhitIcons.arrow_forward.matchTextDirection, isTrue);
    for (final icon in [
      WorthhitIcons.sell_outlined,
      WorthhitIcons.receipt_long_outlined,
      WorthhitIcons.play_arrow_outlined,
      WorthhitIcons.language,
      WorthhitIcons.update,
      WorthhitIcons.open_in_new,
      WorthhitIcons.content_copy,
    ]) {
      expect(icon.matchTextDirection, isFalse);
      expect(icon.fontFamily, WorthhitIcons.fontFamily);
    }
  });

  testWidgets('custom icons keep localized labels and inherit theme color', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    const ink = Color(0xffcaef63);
    await tester.pumpWidget(
      const MaterialApp(
        home: IconTheme(
          data: IconThemeData(color: ink, size: 20),
          child: Icon(WorthhitIcons.update, semanticLabel: 'Güncelleme hazır'),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Güncelleme hazır'), findsOneWidget);
    final text = tester.widget<RichText>(
      find.descendant(of: find.byType(Icon), matching: find.byType(RichText)),
    );
    expect(text.text.style!.color, ink);
    expect(text.text.style!.fontSize, 20);
    expect(text.text.style!.fontFamily, WorthhitIcons.fontFamily);
    handle.dispose();
  });
}

int _glyphId(ByteData data, int table, int codepoint) {
  final segments = data.getUint16(table + 6) ~/ 2;
  final endCodes = table + 14;
  final startCodes = endCodes + segments * 2 + 2;
  final deltas = startCodes + segments * 2;
  final offsets = deltas + segments * 2;
  for (var index = 0; index < segments; index++) {
    if (codepoint > data.getUint16(endCodes + index * 2)) continue;
    if (codepoint < data.getUint16(startCodes + index * 2)) return 0;
    final delta = data.getInt16(deltas + index * 2);
    final offset = data.getUint16(offsets + index * 2);
    if (offset == 0) return (codepoint + delta) & 0xffff;
    final address =
        offsets +
        index * 2 +
        offset +
        (codepoint - data.getUint16(startCodes + index * 2)) * 2;
    final glyph = data.getUint16(address);
    return glyph == 0 ? 0 : (glyph + delta) & 0xffff;
  }
  return 0;
}
