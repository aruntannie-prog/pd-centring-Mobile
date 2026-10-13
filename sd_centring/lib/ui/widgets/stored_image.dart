import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../theme.dart';

/// Shows an uploaded photo from storage (or from memory in demo mode).
///
/// On the web, images from Firebase Storage are drawn with an HTML <img>
/// element, so they show without extra CORS setup on the storage bucket.
class StoredImage extends StatelessWidget {
  const StoredImage(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.error,
    this.decodeSize,
  });

  final String url;
  final BoxFit fit;
  final Widget? error;

  /// Shown at about this many logical pixels: the image is decoded at that
  /// size instead of full resolution, which keeps long lists light.
  final double? decodeSize;

  @override
  Widget build(BuildContext context) {
    final fallback =
        error ??
        Container(
          color: context.sd.field,
          alignment: Alignment.center,
          child: Icon(Icons.broken_image_rounded, color: context.sd.muted),
        );
    final bytes = context.read<AppState>().files.memoryBytes(url);
    final cache = decodeSize == null
        ? null
        : (decodeSize! * MediaQuery.devicePixelRatioOf(context)).round();
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: fit,
        cacheWidth: cache,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return Image.network(
      url,
      fit: fit,
      cacheWidth: cache,
      gaplessPlayback: true,
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      errorBuilder: (_, _, _) => fallback,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : Container(
              color: context.sd.field,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
    );
  }
}
