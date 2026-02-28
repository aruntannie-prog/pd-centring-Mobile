import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'drive_api.dart';

// ─── Upload State ─────────────────────────────────────────────────────────────

enum UploadStatus { idle, uploading, success, failed }

class UploadState {
  final UploadStatus status;
  final String? url;
  final String? error;

  const UploadState.idle()
      : status = UploadStatus.idle,
        url = null,
        error = null;
  const UploadState.uploading()
      : status = UploadStatus.uploading,
        url = null,
        error = null;
  const UploadState.success(this.url)
      : status = UploadStatus.success,
        error = null;
  const UploadState.failed(this.error)
      : status = UploadStatus.failed,
        url = null;

  bool get isIdle => status == UploadStatus.idle;
  bool get isUploading => status == UploadStatus.uploading;
  bool get isSuccess => status == UploadStatus.success;
  bool get isFailed => status == UploadStatus.failed;
}

// ─── Upload Service ───────────────────────────────────────────────────────────

/// Manages image upload lifecycle with proper async state.
/// UI only calls [upload()] and listens to [stream] — no blocking logic ever
/// runs on the main thread.
class UploadService {
  final StreamController<UploadState> _controller =
      StreamController<UploadState>.broadcast();

  Stream<UploadState> get stream => _controller.stream;
  UploadState _state = const UploadState.idle();
  UploadState get current => _state;

  // Stores pending bytes so retry can reuse them without re-reading the file
  Uint8List? _pendingCropBytes;
  Uint8List? _pendingOriginalBytes;
  String? _pendingFileName;

  void _emit(UploadState state) {
    _state = state;
    if (!_controller.isClosed) _controller.add(state);
  }

  /// Begin upload of a profile photo pair (crop + original).
  /// Returns immediately — progress comes via [stream].
  void upload({
    required String fileName,
    required Uint8List cropBytes,
    required Uint8List originalBytes,
  }) {
    _pendingCropBytes = cropBytes;
    _pendingOriginalBytes = originalBytes;
    _pendingFileName = fileName;
    _doUpload();
  }

  /// Retry the last failed upload.
  void retry() {
    if (_pendingCropBytes != null) _doUpload();
  }

  void _doUpload() {
    _emit(const UploadState.uploading());
    // Fire and forget — runs completely off the event handler
    unawaited(_run(
      fileName: _pendingFileName!,
      crop: _pendingCropBytes!,
      original: _pendingOriginalBytes!,
    ));
  }

  Future<void> _run({
    required String fileName,
    required Uint8List crop,
    required Uint8List original,
  }) async {
    try {
      // Upload only the highest-value image (the crop) directly.
      // Removes legacy redundant dual-upload to save time and bandwidth.
      final url = await GoogleDriveApi.uploadFile(
        fileName: fileName,
        bytes: crop,
        maxRetries: 2,
      );

      if (url != null) {
        debugPrint('UploadService: ✅ Upload complete → $url');
        _emit(UploadState.success(url));
      } else {
        debugPrint('UploadService: ❌ Upload failed');
        _emit(const UploadState.failed('Upload failed after 2 attempts'));
      }
    } catch (e) {
      debugPrint('UploadService error: $e');
      _emit(UploadState.failed(e.toString()));
    }
  }

  void dispose() {
    _controller.close();
  }
}
