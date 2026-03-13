import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Conditional imports for Web vs Native
import 'cors_image_stub.dart' if (dart.library.html) 'cors_image_web.dart'
    as impl;

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
    String renderUrl = imageUrl;

    // Base64 data URLs can be decoded and rendered natively on all platforms
    if (renderUrl.startsWith('data:image')) {
      try {
        final base64Str = renderUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(bytes, fit: fit, width: width, height: height,
            errorBuilder: (_, __, ___) =>
                errorWidget ?? const Center(child: Icon(Icons.broken_image)));
      } catch (_) {
        return errorWidget ?? const Center(child: Icon(Icons.broken_image));
      }
    }

    // Google Drive blocks Canvas <img src=""> tags via CORB and Content-Type: text/html HTML wrappers.
    // We aggressively wrap all Drive URLs through `images.weserv.nl` which strips the HTML wrapper,
    // bypasses the CORB/SameSite cookie partitioned protections, and returns raw `image/jpeg`
    // with permissive `Access-Control-Allow-Origin: *` headers for Web.
    if (renderUrl.contains('drive.google.com')) {
      final encodedOriginal = Uri.encodeComponent(renderUrl);
      renderUrl = 'https://images.weserv.nl/?url=$encodedOriginal';
    }

    if (kIsWeb) {
      return impl.CORSResilientImage(
        imageUrl: renderUrl,
        fit: fit,
        width: width,
        height: height,
        placeholder: placeholder,
        errorWidget: errorWidget,
      );
    }

    // Default for native Android/iOS
    return CachedNetworkImage(
      imageUrl: renderUrl,
      fit: fit,
      width: width,
      height: height,
      placeholder: placeholder != null ? (context, url) => placeholder! : null,
      errorWidget:
          errorWidget != null ? (context, url, error) => errorWidget! : null,
    );
  }
}
