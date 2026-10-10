import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/customer.dart';
import '../widgets/stored_image.dart';

/// Opens a customer document: images full-screen with pinch-zoom, PDFs in
/// the phone's PDF viewer or a new browser tab.
Future<void> openDocument(BuildContext context, CustomerDoc doc) async {
  if (doc.isImage || doc.url.startsWith('memory://') && !doc.isPdf) {
    await showImage(context, doc.url, title: doc.kind);
    return;
  }
  final messenger = ScaffoldMessenger.of(context);
  var ok = false;
  if (!doc.url.startsWith('memory://')) {
    try {
      ok = await launchUrl(
        Uri.parse(doc.url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }
  if (!ok) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          doc.url.startsWith('memory://')
              ? 'PDFs open once the app is connected to the database.'
              : 'Could not open this PDF on this device.',
        ),
      ),
    );
  }
}

Future<void> showImage(
  BuildContext context,
  String url, {
  required String title,
}) => Navigator.of(context).push(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(color: Colors.white)),
      ),
      body: InteractiveViewer(
        maxScale: 5,
        child: Center(child: StoredImage(url, fit: BoxFit.contain)),
      ),
    ),
  ),
);
