import '../domain/product_media.dart';
import 'media_picker.dart';

MediaPicker createPicker() => UnsupportedMediaPicker();

class UnsupportedMediaPicker implements MediaPicker {
  @override
  Future<List<ProductMedia>> pick({
    required Set<String> allowedMimeTypes,
    int existingCount = 0,
    int existingBytes = 0,
  }) async {
    throw const MediaFailure('File selection is available in the browser app.');
  }

  @override
  void cancel() {}
  @override
  void dispose() {}
}
