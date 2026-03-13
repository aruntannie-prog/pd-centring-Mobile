import 'package:flutter/material.dart';
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

class CORSResilientImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CORSResilientImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) return errorWidget ?? const SizedBox.shrink();

    // Firebase Storage URLs and other standard HTTPS URLs work perfectly
    // with Flutter's built-in Image.network() on web — no HtmlElementView needed.
    // Only Google Drive URLs require the HtmlElementView workaround due to CORB.
    if (!imageUrl.contains('drive.google.com') &&
        !imageUrl.contains('docs.google.com') &&
        !imageUrl.contains('images.weserv.nl')) {
      return Image.network(
        imageUrl,
        fit: fit,
        width: width,
        height: height,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return placeholder ??
              Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                ),
              );
        },
        errorBuilder: (context, error, stackTrace) {
          return errorWidget ?? const Center(child: Icon(Icons.broken_image));
        },
      );
    }

    // Google Drive URLs: use HtmlElementView with weserv.nl proxy to bypass CORB.
    final String viewType =
        'img-${imageUrl.hashCode}-${DateTime.now().millisecondsSinceEpoch}';

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final img = html.ImageElement()
        ..src = imageUrl
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none'
        ..style.objectFit = _fitToString(fit);

      img.onDragStart.listen((e) => e.preventDefault());
      return img;
    });

    return SizedBox(
      width: width,
      height: height,
      child: HtmlElementView(viewType: viewType),
    );
  }

  String _fitToString(BoxFit fit) {
    switch (fit) {
      case BoxFit.cover:
        return 'cover';
      case BoxFit.contain:
        return 'contain';
      case BoxFit.fill:
        return 'fill';
      case BoxFit.fitWidth:
        return 'fit-width';
      case BoxFit.fitHeight:
        return 'fit-height';
      case BoxFit.scaleDown:
        return 'scale-down';
      default:
        return 'cover';
    }
  }
}
