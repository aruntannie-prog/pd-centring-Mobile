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
    final dark = theme.brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFF25D366),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WhatsApp reminder',
                      style: theme.textTheme.titleLarge,
                    ),
                    Text(
                      'To ${app.customerNameOf(widget.rental)} · +${widget.number}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Looks like the chat it will appear in; the bubble is editable.
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 40, 14),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF0B141A) : const Color(0xFFEFE7DE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                decoration: BoxDecoration(
                  color: dark
                      ? const Color(0xFF005C4B)
                      : const Color(0xFFD9FDD3),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: TextField(
                  controller: _text,
                  maxLines: 16,
                  minLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: dark ? Colors.white : const Color(0xFF111B21),
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Message (you can edit it)',
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.edit_rounded,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tap the message to edit. WhatsApp opens with it typed in — press Send there.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: const Color(0xFF128C7E),
              foregroundColor: Colors.white,
            ),
            onPressed: _opening ? null : _open,
            icon: const Icon(Icons.send_rounded),
            label: Text(_opening ? 'Opening…' : 'Open WhatsApp'),
          ),
        ],
      ),
    );
  }
}
