import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'delivery_detail_screen.dart' show normalizeDigits;
import '../../domain/whatsapp.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../core/quantity.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/rental_tile.dart';
import '../widgets/stored_image.dart';
import 'document_viewer.dart';
import 'customer_form_screen.dart';
import 'delivery_form_screen.dart';

class CustomerDetailScreen extends StatelessWidget {
  const CustomerDetailScreen({super.key, required this.customerId});

  final String customerId;

  static Future<void> open(BuildContext context, String customerId) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerDetailScreen(customerId: customerId),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final customer = app.customerById(customerId);
    if (customer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Customer')),
        body: const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Customer not found',
        ),
      );
    }

    final rentals = app.rentalsFor(customerId);
    final open = rentals.where((r) => !r.isClosed).toList();
    final closed = rentals.where((r) => r.isClosed).toList()
      ..sort((a, b) => b.expiresOn.compareTo(a.expiresOn));

    // Material currently with this customer, summed across open deliveries.
    final holding = <String, double>{};
    final units = <String, String>{};
    for (final r in open) {
      for (final i in r.outstandingItems) {
        final key = '${i.name}|${i.unit}';
        holding[key] = (holding[key] ?? 0) + r.outstandingQty(i);
        units[key] = i.unit;
      }
    }
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                CustomerFormScreen.open(context, existing: customer),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v != 'delete') return;
              if (rentals.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'This customer has deliveries on record and cannot be deleted.',
                    ),
                  ),
                );
                return;
              }
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Delete ${customer.name}?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: SdColors.expired,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                Navigator.of(context).pop();
                await app.deleteCustomer(customer.id);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Text('Delete customer')),
            ],
          ),
        ],
      ),
      body: PageWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            SoftCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: customer.photoUrl.isEmpty
                            ? null
                            : () => showImage(
                                context,
                                customer.photoUrl,
                                title: customer.name,
                              ),
                        child: InitialsAvatar(
                          customer.name,
                          size: 64,
                          photoUrl: customer.photoUrl,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.name,
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${open.length} open · ${closed.length} returned',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _InfoLine(Icons.call_rounded, customer.phone),
                  if (customer.altPhone.isNotEmpty)
                    _InfoLine(Icons.phone_forwarded_rounded, customer.altPhone),
                  if (customer.address.isNotEmpty)
                    _InfoLine(Icons.place_rounded, customer.address),
                  if (customer.referredBy.isNotEmpty)
                    _InfoLine(
                      Icons.handshake_outlined,
                      'Referred by ${customer.referredBy}',
                    ),
                  if (customer.notes.isNotEmpty)
                    _InfoLine(Icons.notes_rounded, customer.notes),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: QuickAction(
                    icon: Icons.add_box_rounded,
                    label: 'New DC',
                    color: SdColors.ember,
                    onTap: () => DeliveryFormScreen.open(
                      context,
                      customerId: customer.id,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: QuickAction(
                    icon: Icons.call_rounded,
                    label: 'Call',
                    color: const Color(0xFF2F6FED),
                    onTap: customer.phone.trim().isEmpty
                        ? null
                        : () => _open(
                            context,
                            Uri(
                              scheme: 'tel',
                              path: normalizeDigits(customer.phone),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: QuickAction(
                    icon: Icons.chat_rounded,
                    label: 'WhatsApp',
                    color: SdColors.whatsApp,
                    onTap: whatsAppNumber(customer.phone) == null
                        ? null
                        : () => _open(
                            context,
                            Uri.parse(
                              'https://wa.me/${whatsAppNumber(customer.phone)}',
                            ),
                          ),
                  ),
                ),
              ],
            ),
            SectionHeader(
              'ID & address proof',
              count: customer.documents.isEmpty
                  ? null
                  : customer.documents.length,
              trailing: TextButton(
                onPressed: () =>
                    CustomerFormScreen.open(context, existing: customer),
                child: Text(customer.documents.isEmpty ? 'Add' : 'Edit'),
              ),
            ),
            if (customer.documents.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'No documents yet.',
                  style: theme.textTheme.bodySmall,
                ),
              )
            else
              SizedBox(
                height: 118,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: customer.documents.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final d = customer.documents[i];
                    return SizedBox(
                      width: 104,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => openDocument(context, d),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                width: 104,
                                height: 78,
                                child: d.isPdf
                                    ? Container(
                                        color: SdColors.expired.withValues(
                                          alpha: 0.10,
                                        ),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.picture_as_pdf_rounded,
                                          color: SdColors.expired,
                                          size: 30,
                                        ),
                                      )
                                    : StoredImage(d.url),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              d.kind,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (holding.isNotEmpty) ...[
              const SectionHeader('Material with customer'),
              SoftCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Column(
                  children: [
                    for (final (i, e) in holding.entries.indexed) ...[
                      if (i > 0) const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.key.split('|').first,
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                            Text(
                              formatQty(e.value),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 30,
                              child: Text(
                                '${units[e.key]}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            SectionHeader('Open deliveries', count: open.length),
            if (open.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Text(
                  'Nothing out on rent.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            for (final r in open)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RentalTile(r, showCustomer: false),
              ),
            if (closed.isNotEmpty) ...[
              SectionHeader('Returned', count: closed.length),
              for (final r in closed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: RentalTile(r, showCustomer: false),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open this on this device')),
      );
    }
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: context.sd.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}
