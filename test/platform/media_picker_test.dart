import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:worthhit/domain/product_media.dart';
import 'package:worthhit/platform/media_picker.dart';

class Source implements MediaFileSource {
  Source({
    this.name = 'photo.png',
    this.mimeType = 'image/png',
    this.byteLength = 8,
  });
  @override
  final String name;
  @override
  final String mimeType;
  @override
  final int byteLength;
  int reads = 0;
  Completer<Uint8List>? pending;
  @override
  Future<Uint8List> readBytes({
    required MediaPickCancellation cancellation,
  }) async {
    reads++;
    if (pending != null) return pending!.future;
    return Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
  }
}

void main() {
  const images = {'image/png'};
  test(
    'all selected metadata and aggregate budget validate before any read',
    () async {
      for (final invalid in [
        Source(mimeType: 'video/mp4'),
        Source(byteLength: 0),
        Source(byteLength: maxProductMediaFileBytes + 1),
        Source(name: ''),
      ]) {
        final first = Source();
        await expectLater(
          readMediaSources([first, invalid], allowedMimeTypes: images),
          throwsA(isA<MediaFailure>()),
        );
        expect(first.reads, 0);
        expect(invalid.reads, 0);
      }
      final source = Source();
      await expectLater(
        readMediaSources([source], allowedMimeTypes: images, existingCount: 4),
        throwsA(isA<MediaFailure>()),
      );
      await expectLater(
        readMediaSources(
          [source],
          allowedMimeTypes: images,
          existingBytes: maxProductMediaTotalBytes,
        ),
        throwsA(isA<MediaFailure>()),
      );
      expect(source.reads, 0);
    },
  );

  test(
    'missing MIME uses recognized extension but conflicting media fails',
    () async {
      final result = await readMediaSources([
        Source(mimeType: ''),
      ], allowedMimeTypes: images);
      expect(result.single.mimeType, 'image/png');
      final conflict = Source(mimeType: 'video/mp4');
      await expectLater(
        readMediaSources([conflict], allowedMimeTypes: images),
        throwsA(isA<MediaFailure>()),
      );
      expect(conflict.reads, 0);
    },
  );

  test(
    'sequential reads return immutable validated files with no partial success',
    () async {
      final first = Source()..pending = Completer<Uint8List>();
      final second = Source();
      final selection = readMediaSources([
        first,
        second,
      ], allowedMimeTypes: images);
      await Future<void>.delayed(Duration.zero);
      expect(first.reads, 1);
      expect(second.reads, 0);
      first.pending!.complete(
        Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
      );
      final files = await selection;
      expect(second.reads, 1);
      expect(files, hasLength(2));
      expect(() => files.clear(), throwsUnsupportedError);
      await expectLater(
        readMediaSources([Source(byteLength: 9)], allowedMimeTypes: images),
        throwsA(isA<MediaFailure>()),
      );
    },
  );

  test(
    'cancellation during stalled reads returns promptly and accepts no bytes',
    () async {
      final cancellation = MediaPickCancellation();
      final source = Source()..pending = Completer<Uint8List>();
      final operation = readMediaSources(
        [source],
        allowedMimeTypes: images,
        cancellation: cancellation,
      );
      final expectation = expectLater(
        operation,
        throwsA(
          isA<MediaFailure>().having((e) => e.cancelled, 'cancelled', true),
        ),
      );
      cancellation.cancel();
      await expectation;
      source.pending!.complete(Uint8List(8));
    },
  );

  test(
    'empty selection is cancellation without changing existing draft budget',
    () async {
      expect(
        await readMediaSources(
          [],
          allowedMimeTypes: images,
          existingCount: 2,
          existingBytes: 16,
        ),
        isEmpty,
      );
      for (final types in [
        <String>{},
        {'text/html'},
      ]) {
        await expectLater(
          readMediaSources([], allowedMimeTypes: types),
          throwsA(isA<MediaFailure>()),
        );
      }
    },
  );

  test('nonweb picker reports unsupported platform explicitly', () async {
    final picker = createMediaPicker();
    await expectLater(
      picker.pick(allowedMimeTypes: images),
      throwsA(isA<MediaFailure>()),
    );
    picker.cancel();
    picker.dispose();
  });
}
