import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/whatsapp.dart';
import '../../models/rental.dart';
import '../../state/app_state.dart';

/// Opens a link outside the app. Replaceable in tests.
typedef LinkOpener = Future<bool> Function(Uri uri);

Future<bool> _openExternally(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Preview of the WhatsApp reminder. Staff can edit the text, then WhatsApp
/// opens with it typed in; they press Send there. Nothing is sent
/// automatically.
class WhatsAppSheet extends StatefulWidget {
  const WhatsAppSheet({super.key, required this.rental, required this.number});

  final Rental rental;
  final String number;

  @visibleForTesting
  static LinkOpener opener = _openExternally;

  static Future<void> show(
    BuildContext context,
    Rental rental,
    String number,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => WhatsAppSheet(rental: rental, number: number),
  );

  @override
  State<WhatsAppSheet> createState() => _WhatsAppSheetState();
}

class _WhatsAppSheetState extends State<WhatsAppSheet> {
  late final TextEditingController _text;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _text = TextEditingController(
      text: expiryMessage(
        widget.rental,
        customerName: app.customerNameOf(widget.rental),
        info: app.expiry(widget.rental),
      ),
    );
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final message = _text.text.trim();
    if (message.isEmpty) return;
    setState(() => _opening = true);
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await WhatsAppSheet.opener(whatsAppLink(widget.number, message));
    } catch (e) {
      debugPrint('WhatsApp launch failed: $e');
    }
    if (!mounted) return;
    if (!opened) {
      setState(() => _opening = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('WhatsApp could not be opened on this device'),
        ),
      );
      return;
    }
    final latest = app.rentalById(widget.rental.id) ?? widget.rental;
    await app.markMessaged(latest);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.watch<AppState>();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          Row(
            children: [
              const Icon(Icons.chat, color: Color(0xFF25D366)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'WhatsApp reminder',
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'To ${app.customerNameOf(widget.rental)} · +${widget.number}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _text,
            maxLines: 14,
            minLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Message (you can edit it)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'WhatsApp will open with this message. Press Send in WhatsApp to deliver it.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: const Color(0xFF128C7E),
              foregroundColor: Colors.white,
            ),
            onPressed: _opening ? null : _open,
            icon: const Icon(Icons.send),
            label: Text(_opening ? 'Opening…' : 'Open WhatsApp'),
          ),
        ],
      ),
    );
  }
}
