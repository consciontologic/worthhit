import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../domain/product_media.dart';
import 'media_picker.dart';

MediaPicker createPicker() => BrowserMediaPicker();

class BrowserMediaPicker implements MediaPicker {
  MediaPickCancellation? _active;
  bool _disposed = false;

  @override
  Future<List<ProductMedia>> pick({
    required Set<String> allowedMimeTypes,
    int existingCount = 0,
    int existingBytes = 0,
  }) async {
    if (_disposed) {
      throw const MediaFailure('File selection cancelled.', cancelled: true);
    }
    if (_active != null) {
      throw const MediaFailure(
        'Finish or cancel the current file selection first.',
      );
    }
    validateMediaPickBudget(
      allowedMimeTypes: allowedMimeTypes,
      existingCount: existingCount,
      existingBytes: existingBytes,
    );
    if (existingCount == maxProductMediaFiles ||
        existingBytes == maxProductMediaTotalBytes) {
      throw const MediaFailure(
        'The file limit is reached. Remove a file before adding another.',
      );
    }
    final token = _active = MediaPickCancellation();
    try {
      // Keep the browser's user gesture: open the native dialog before awaiting.
      final files = await _chooseFiles(allowedMimeTypes, token);
      return await readMediaSources(
        files.map(_BrowserFileSource.new).toList(),
        allowedMimeTypes: allowedMimeTypes,
        existingCount: existingCount,
        existingBytes: existingBytes,
        cancellation: token,
      );
    } finally {
      token.cancel();
      if (identical(_active, token)) _active = null;
    }
  }

  Future<List<web.File>> _chooseFiles(
    Set<String> types,
    MediaPickCancellation token,
  ) {
    final completion = Completer<List<web.File>>();
    final input = web.HTMLInputElement()
      ..type = 'file'
      ..multiple = true
      ..accept = types.join(',')
      ..tabIndex = -1;
    input.style.display = 'none';
    input.setAttribute('aria-hidden', 'true');
    final changed = ((web.Event _) {
      if (completion.isCompleted) return;
      final files = input.files;
      completion.complete(
        files == null
            ? const []
            : [for (var i = 0; i < files.length; i++) files.item(i)!],
      );
    }).toJS;
    final cancelled = ((web.Event _) {
      if (!completion.isCompleted) completion.complete(const []);
    }).toJS;
    input.addEventListener('change', changed);
    input.addEventListener('cancel', cancelled);
    web.document.body?.append(input);
    token.whenCancelled.then((_) {
      if (!completion.isCompleted) {
        completion.completeError(
          const MediaFailure('File selection cancelled.', cancelled: true),
        );
      }
    });
    final result = completion.future.whenComplete(() {
      input.removeEventListener('change', changed);
      input.removeEventListener('cancel', cancelled);
      input.remove();
    });
    try {
      input.click();
    } catch (_) {
      if (!completion.isCompleted) {
        completion.completeError(
          const MediaFailure(
            'The browser could not open its file dialog. Try the add button again.',
          ),
        );
      }
    }
    return result;
  }

  @override
  void cancel() => _active?.cancel();
  @override
  void dispose() {
    _disposed = true;
    cancel();
  }
}

class _BrowserFileSource implements MediaFileSource {
  _BrowserFileSource(this.file);
  final web.File file;
  @override
  String get name => file.name;
  @override
  String get mimeType => file.type;
  @override
  int get byteLength => file.size;

  @override
  Future<Uint8List> readBytes({required MediaPickCancellation cancellation}) {
    cancellation.check();
    final reader = web.FileReader();
    final completion = Completer<Uint8List>();
    final loaded = ((web.Event _) {
      if (completion.isCompleted) return;
      try {
        completion.complete(
          (reader.result as JSArrayBuffer).toDart.asUint8List(),
        );
      } catch (_) {
        completion.completeError(
          const MediaFailure(
            'The selected file returned unreadable data. Select it again.',
          ),
        );
      }
    }).toJS;
    final failed = ((web.Event _) {
      if (!completion.isCompleted) {
        completion.completeError(
          const MediaFailure(
            'A selected file could not be read. Select it again.',
          ),
        );
      }
    }).toJS;
    final aborted = ((web.Event _) {
      if (!completion.isCompleted) {
        completion.completeError(
          const MediaFailure('File selection cancelled.', cancelled: true),
        );
      }
    }).toJS;
    reader.addEventListener('load', loaded);
    reader.addEventListener('error', failed);
    reader.addEventListener('abort', aborted);
    cancellation.whenCancelled.then((_) {
      if (!completion.isCompleted) {
        reader.abort();
        if (!completion.isCompleted) {
          completion.completeError(
            const MediaFailure('File selection cancelled.', cancelled: true),
          );
        }
      }
    });
    final result = completion.future
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            reader.abort();
            throw const MediaFailure(
              'Reading the selected file timed out. Select a smaller local file.',
            );
          },
        )
        .whenComplete(() {
          reader.removeEventListener('load', loaded);
          reader.removeEventListener('error', failed);
          reader.removeEventListener('abort', aborted);
        });
    try {
      reader.readAsArrayBuffer(file);
    } catch (_) {
      if (!completion.isCompleted) {
        completion.completeError(
          const MediaFailure(
            'The browser could not read a selected file. Select it again.',
          ),
        );
      }
    }
    return result;
  }
}
