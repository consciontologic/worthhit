import 'dart:async';
import 'dart:typed_data';

import '../domain/product_media.dart';
import 'media_picker_stub.dart'
    if (dart.library.js_interop) 'media_picker_web.dart'
    as implementation;

abstract interface class MediaPicker {
  Future<List<ProductMedia>> pick({
    required Set<String> allowedMimeTypes,
    int existingCount = 0,
    int existingBytes = 0,
  });
  void cancel();
  void dispose();
}

MediaPicker createMediaPicker() => implementation.createPicker();

class MediaPickCancellation {
  final _completion = Completer<void>();
  bool get cancelled => _completion.isCompleted;
  Future<void> get whenCancelled => _completion.future;
  void cancel() {
    if (!cancelled) _completion.complete();
  }

  void check() {
    if (cancelled) {
      throw const MediaFailure('File selection cancelled.', cancelled: true);
    }
  }

  Future<T> race<T>(Future<T> future) => Future.any([
    future,
    whenCancelled.then<T>(
      (_) => throw const MediaFailure(
        'File selection cancelled.',
        cancelled: true,
      ),
    ),
  ]);
}

abstract interface class MediaFileSource {
  String get name;
  String get mimeType;
  int get byteLength;
  Future<Uint8List> readBytes({required MediaPickCancellation cancellation});
}

void validateMediaPickBudget({
  required Set<String> allowedMimeTypes,
  required int existingCount,
  required int existingBytes,
}) {
  if (allowedMimeTypes.isEmpty ||
      !productMediaMimeTypes.containsAll(allowedMimeTypes)) {
    throw const MediaFailure(
      'Choose a model that supports the selected media type.',
    );
  }
  if (existingCount < 0 ||
      existingCount > maxProductMediaFiles ||
      existingBytes < 0 ||
      existingBytes > maxProductMediaTotalBytes) {
    throw const MediaFailure(
      'The existing files exceed the attachment limits. Remove a file and try again.',
    );
  }
}

String _mimeType(MediaFileSource file) {
  final reported = normalizeProductMediaMime(file.mimeType);
  if (reported.isNotEmpty && reported != 'application/octet-stream') {
    return reported;
  }
  return switch (file.name.split('.').last.toLowerCase()) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'mp4' => 'video/mp4',
    _ => '',
  };
}

/// Validate every file's metadata before allocating bytes, then read sequentially.
/// An unsuccessful selection never returns a partial list of additions.
Future<List<ProductMedia>> readMediaSources(
  List<MediaFileSource> sources, {
  required Set<String> allowedMimeTypes,
  int existingCount = 0,
  int existingBytes = 0,
  MediaPickCancellation? cancellation,
}) async {
  final token = cancellation ?? MediaPickCancellation();
  token.check();
  validateMediaPickBudget(
    allowedMimeTypes: allowedMimeTypes,
    existingCount: existingCount,
    existingBytes: existingBytes,
  );
  if (sources.length + existingCount > maxProductMediaFiles) {
    throw const MediaFailure(
      'Add at most 4 files. Remove a file before adding another.',
    );
  }
  var total = existingBytes;
  final types = <String>[];
  for (final source in sources) {
    if (source.name.trim().isEmpty ||
        source.name.length > 240 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(source.name)) {
      throw const MediaFailure(
        'The selected file has invalid identifying information.',
      );
    }
    final type = _mimeType(source);
    if (!allowedMimeTypes.contains(type)) {
      throw const MediaFailure(
        'A selected file type is unsupported by this model. Choose one of the offered file types.',
      );
    }
    if (source.byteLength <= 0 ||
        source.byteLength > maxProductMediaFileBytes) {
      throw const MediaFailure(
        'Each file must contain data and be at most 8 MiB.',
      );
    }
    total += source.byteLength;
    if (total > maxProductMediaTotalBytes) {
      throw const MediaFailure(
        'Files may total at most 12 MiB. Remove a file and try again.',
      );
    }
    types.add(type);
  }
  final result = <ProductMedia>[];
  for (var i = 0; i < sources.length; i++) {
    token.check();
    final source = sources[i];
    final bytes = await token.race(source.readBytes(cancellation: token));
    token.check();
    if (bytes.length != source.byteLength) {
      throw const MediaFailure(
        'A selected file changed or could not be read completely. Select it again.',
      );
    }
    result.add(
      ProductMedia.fromBytes(
        name: source.name,
        mimeType: types[i],
        bytes: bytes,
      ),
    );
  }
  validateProductMedia(result);
  return List.unmodifiable(result);
}
