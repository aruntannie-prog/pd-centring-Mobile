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

    // Use a unique view type for each URL so Flutter correctly mounts a new element
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

      // Prevent browser default drag behavior on images
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
