import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:worthhit/domain/product_media.dart';

ProductMedia image({int length = 8, String? id}) {
  final bytes = Uint8List(length);
  bytes.setRange(0, 8, [137, 80, 78, 71, 13, 10, 26, 10]);
  return ProductMedia.fromBytes(
    id: id,
    name: 'product.png',
    mimeType: 'image/png',
    bytes: bytes,
  );
}

ProductMedia video() => ProductMedia.fromBytes(
  name: 'product.mp4',
  mimeType: 'video/mp4',
  bytes: Uint8List.fromList([
    0,
    0,
    0,
    20,
    ...ascii.encode('ftypisom'),
    0,
    0,
    0,
    0,
    ...ascii.encode('isom'),
  ]),
);

void main() {
  test('validated image and video use documented data URL content parts', () {
    final photo = image();
    final clip = video();
    expect(photo.kind, ProductMediaKind.image);
    expect(clip.kind, ProductMediaKind.video);
    expect(photo.toContentPart(), {
      'type': 'image_url',
      'image_url': {'url': photo.dataUrl},
    });
    expect(clip.toContentPart(), {
      'type': 'video_url',
      'video_url': {'url': clip.dataUrl},
    });
    expect(photo.dataUrl, startsWith('data:image/png;base64,'));
    expect(clip.dataUrl, startsWith('data:video/mp4;base64,'));
    expect(photo.id, isNot(clip.id));
  });

  test(
    'supported image formats normalize aliases and retain immutable data',
    () {
      for (final entry in {
        'image/jpg': [255, 216, 255],
        'image/gif': ascii.encode('GIF89a'),
        'image/webp': ascii.encode('RIFFxxxxWEBP'),
      }.entries) {
        final bytes = Uint8List.fromList(entry.value);
        final media = ProductMedia.fromBytes(
          name: 'image',
          mimeType: entry.key,
          bytes: bytes,
        );
        final url = media.dataUrl;
        bytes[0] = 0;
        expect(media.dataUrl, url);
        expect(
          media.mimeType,
          entry.key == 'image/jpg' ? 'image/jpeg' : entry.key,
        );
      }
    },
  );

  test('empty mismatched executable or disguised video bytes are rejected', () {
    for (final entry in {
      'image/png': <int>[],
      'image/jpeg': ascii.encode('<script>SECRET</script>'),
      'text/html': ascii.encode('<html>SECRET</html>'),
      'video/mp4': ascii.encode('xxxxftypavifxxxx'),
    }.entries) {
      expect(
        () => ProductMedia.fromBytes(
          name: 'SECRET',
          mimeType: entry.key,
          bytes: Uint8List.fromList(entry.value),
        ),
        throwsA(
          isA<MediaFailure>().having(
            (e) => e.safeMessage,
            'safe',
            isNot(contains('SECRET')),
          ),
        ),
      );
    }
  });

  test('names ids and file limits validate before acceptance', () {
    expect(
      () => image(length: maxProductMediaFileBytes + 1),
      throwsA(isA<MediaFailure>()),
    );
    expect(() => image(id: ''), throwsA(isA<MediaFailure>()));
    expect(() => image(id: 'bad\nname'), throwsA(isA<MediaFailure>()));
    expect(
      () => ProductMedia.fromBytes(
        name: '',
        mimeType: 'image/png',
        bytes: Uint8List(8),
      ),
      throwsA(isA<MediaFailure>()),
    );
  });

  test('combined count size and duplicate identities fail closed', () {
    final first = image(length: 8 * 1024 * 1024);
    final second = image(length: 4 * 1024 * 1024);
    validateProductMedia([first, second]);
    expect(
      () => validateProductMedia([first, second, image()]),
      throwsA(isA<MediaFailure>()),
    );
    expect(
      () => validateProductMedia(List.generate(5, (_) => image())),
      throwsA(isA<MediaFailure>()),
    );
    expect(
      () => validateProductMedia([first, first]),
      throwsA(isA<MediaFailure>()),
    );
  });
}
