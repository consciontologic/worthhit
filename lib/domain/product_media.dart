import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

const maxProductMediaFiles = 4;
const maxProductMediaFileBytes = 8 * 1024 * 1024;
const maxProductMediaTotalBytes = 12 * 1024 * 1024;
const productImageMimeTypes = {
  'image/png',
  'image/jpeg',
  'image/webp',
  'image/gif',
};
const productMediaMimeTypes = {...productImageMimeTypes, 'video/mp4'};

enum ProductMediaKind { image, video }

class MediaFailure implements Exception {
  const MediaFailure(this.safeMessage, {this.cancelled = false});
  final String safeMessage;
  final bool cancelled;

  @override
  String toString() => safeMessage;
}

/// Validated, immutable local media. It is intentionally not serializable to
/// draft storage: files remain in this tab and are uploaded only on appraisal.
final class ProductMedia {
  ProductMedia._({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.kind,
    required this.byteLength,
    required this.base64Data,
  });

  factory ProductMedia.fromBytes({
    String? id,
    required String name,
    required String mimeType,
    required Uint8List bytes,
  }) {
    final type = normalizeProductMediaMime(mimeType);
    final identity =
        id ??
        '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${Random.secure().nextInt(0x7fffffff).toRadixString(36)}';
    if (identity.isEmpty ||
        identity.length > 100 ||
        name.trim().isEmpty ||
        name.length > 240 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(identity + name)) {
      throw const MediaFailure(
        'The selected file has invalid identifying information.',
      );
    }
    if (bytes.isEmpty || bytes.length > maxProductMediaFileBytes) {
      throw const MediaFailure(
        'Each file must contain data and be at most 8 MiB.',
      );
    }
    if (!productMediaMimeTypes.contains(type)) {
      throw const MediaFailure(
        'Choose a PNG, JPEG, WebP, GIF image or an MP4 video.',
      );
    }
    if (!_signatureMatches(type, bytes)) {
      throw const MediaFailure(
        'The file content does not match its format. Choose a valid image or MP4 video.',
      );
    }
    return ProductMedia._(
      id: identity,
      name: name,
      mimeType: type,
      kind: type == 'video/mp4'
          ? ProductMediaKind.video
          : ProductMediaKind.image,
      byteLength: bytes.length,
      base64Data: base64Encode(bytes),
    );
  }

  final String id, name, mimeType, base64Data;
  final ProductMediaKind kind;
  final int byteLength;

  String get dataUrl => 'data:$mimeType;base64,$base64Data';

  Map<String, dynamic> toContentPart() => kind == ProductMediaKind.image
      ? {
          'type': 'image_url',
          'image_url': {'url': dataUrl},
        }
      : {
          'type': 'video_url',
          'video_url': {'url': dataUrl},
        };
}

String normalizeProductMediaMime(String value) =>
    switch (value.trim().toLowerCase()) {
      'image/jpg' => 'image/jpeg',
      final type => type,
    };

void validateProductMedia(List<ProductMedia> files) {
  if (files.length > maxProductMediaFiles) {
    throw const MediaFailure(
      'Add at most 4 files. Remove a file before adding another.',
    );
  }
  var total = 0;
  final identities = <String>{};
  for (final file in files) {
    if (!identities.add(file.id) ||
        file.byteLength < 1 ||
        file.byteLength > maxProductMediaFileBytes ||
        !productMediaMimeTypes.contains(file.mimeType)) {
      throw const MediaFailure(
        'The selected files are invalid. Remove them and select them again.',
      );
    }
    total += file.byteLength;
    if (total > maxProductMediaTotalBytes) {
      throw const MediaFailure(
        'Files may total at most 12 MiB. Remove a file and try again.',
      );
    }
  }
}

bool _signatureMatches(String mime, Uint8List bytes) {
  bool starts(List<int> signature, [int offset = 0]) {
    if (bytes.length < signature.length + offset) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i + offset] != signature[i]) return false;
    }
    return true;
  }

  bool text(String value, [int offset = 0]) =>
      starts(ascii.encode(value), offset);
  return switch (mime) {
    'image/png' => starts([137, 80, 78, 71, 13, 10, 26, 10]),
    'image/jpeg' => starts([255, 216, 255]),
    'image/gif' => text('GIF87a') || text('GIF89a'),
    'image/webp' => text('RIFF') && text('WEBP', 8),
    // Reject other ISO-BMFF payloads such as AVIF/HEIC and audio-only M4A.
    'video/mp4' =>
      bytes.length >= 16 &&
          text('ftyp', 4) &&
          ByteData.sublistView(bytes).getUint32(0) >= 16 &&
          ByteData.sublistView(bytes).getUint32(0) <= bytes.length &&
          const [
            'isom',
            'iso2',
            'iso3',
            'iso4',
            'iso5',
            'iso6',
            'mp41',
            'mp42',
            'avc1',
            'M4V ',
            'M4VH',
            'M4VP',
          ].any((brand) => text(brand, 8)),
    _ => false,
  };
}
