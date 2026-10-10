import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/dates.dart';
import '../../core/quantity.dart';
import '../../domain/expiry.dart';
import '../../domain/whatsapp.dart';
import '../../models/rental.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/rental_tile.dart';
import 'customer_detail_screen.dart';
import 'delivery_form_screen.dart';
import 'record_return_sheet.dart';
import 'whatsapp_sheet.dart';

class DeliveryDetailScreen extends StatelessWidget {
  const DeliveryDetailScreen({super.key, required this.rentalId});

  final String rentalId;

  static Future<void> open(BuildContext context, String rentalId) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DeliveryDetailScreen(rentalId: rentalId),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final rental = app.rentalById(rentalId);

    // Opened from a notification for a delivery that was since deleted, or
    // data is still loading.
    if (rental == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Delivery')),
        body: app.loaded
            ? const EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Delivery not found',
                message: 'It may have been deleted.',
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }

    final info = app.expiry(rental);
    final customer = app.customerById(rental.customerId);
    final phone = customer?.phone ?? '';
    final waNumber = whatsAppNumber(phone);

    return Scaffold(
      appBar: AppBar(
        title: Text(rental.dcNumber),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => DeliveryFormScreen.open(context, existing: rental),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) {
              if (v == 'delete') _confirmDelete(context, rental);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Text('Delete delivery')),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: rental.isClosed
          ? null
          : Align(
              // Size to the button's height; only the width is capped.
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: PageWidth.maxWidth),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      onPressed: () => RecordReturnSheet.show(context, rental),
                      icon: const Icon(Icons.assignment_return_rounded),
                      label: const Text('Record return'),
                    ),
                  ),
                ),
              ),
            ),
      body: PageWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _Hero(rental: rental, info: info, today: app.today),

            if (!rental.isClosed) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: QuickAction(
                      icon: Icons.event_repeat_rounded,
                      label: 'Extend expiry',
                      color: SdColors.ember,
                      onTap: () => _changeExpiry(context, rental),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: QuickAction(
                      icon: Icons.chat_rounded,
                      label: 'WhatsApp',
                      color: SdColors.whatsApp,
                      onTap: waNumber == null
                          ? null
                          : () => WhatsAppSheet.show(context, rental, waNumber),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: QuickAction(
                      icon: Icons.call_rounded,
                      label: 'Call',
                      color: const Color(0xFF2F6FED),
                      onTap: phone.trim().isEmpty
                          ? null
                          : () => _call(context, phone),
                    ),
                  ),
                ],
              ),
              if (waNumber == null)
                const _Hint(
                  'Add a valid mobile number to this customer to use WhatsApp.',
                )
              else if (rental.lastMessagedAt != null)
                _Hint(
                  'Last WhatsApp reminder: ${formatDay(rental.lastMessagedAt!)}',
                  icon: Icons.done_all_rounded,
                ),
            ],

            // ── Customer ─────────────────────────────────────────────────
            const SectionHeader('Customer'),
            SoftCard(
              onTap: customer == null
                  ? null
                  : () => CustomerDetailScreen.open(context, customer.id),
              child: Row(
                children: [
                  InitialsAvatar(app.customerNameOf(rental), size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.customerNameOf(rental),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (phone.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            phone,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        if (rental.site.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Site: ${rental.site}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (customer != null)
                    Icon(Icons.chevron_right_rounded, color: context.sd.muted),
                ],
              ),
            ),

            // ── Material ─────────────────────────────────────────────────
            SectionHeader('Material', count: rental.items.length),
            SoftCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < rental.items.length; i++) ...[
                    if (i > 0) Divider(height: 1, indent: 16, endIndent: 16),
                    _ItemRow(rental: rental, item: rental.items[i]),
                  ],
                ],
              ),
            ),

            // ── Returns ──────────────────────────────────────────────────
            if (rental.returns.isNotEmpty) ...[
              SectionHeader('Returns', count: rental.returns.length),
              SoftCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    for (final ret
                        in (rental.returns.toList()
                          ..sort((a, b) => b.date.compareTo(a.date))))
                      ListTile(
                        leading: _IconBubble(
                          Icons.assignment_return_rounded,
                          SdColors.active,
                        ),
                        title: Text(
                          '${_itemName(rental, ret.itemId)} · ${formatQty(ret.qty)}',
                        ),
                        subtitle: Text(
                          [
                            formatDay(ret.date),
                            if (ret.note.isNotEmpty) ret.note,
                          ].join(' · '),
                        ),
                        trailing: IconButton(
                          tooltip: 'Undo this return',
                          icon: const Icon(Icons.undo_rounded),
                          onPressed: () => _confirmUndo(context, rental, ret),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            // ── Expiry changes ───────────────────────────────────────────
            if (rental.expiryHistory.isNotEmpty) ...[
              const SectionHeader('Expiry changes'),
              SoftCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    for (final ch in rental.expiryHistory.reversed)
                      ListTile(
                        leading: _IconBubble(
                          Icons.event_repeat_rounded,
                          SdColors.ember,
                        ),
                        title: Text(
                          '${formatDay(ch.from)} → ${formatDay(ch.to)}',
                        ),
                        subtitle: Text('Changed on ${formatDay(ch.changedAt)}'),
                      ),
                  ],
                ),
              ),
            ],

            if (rental.notes.isNotEmpty) ...[
              const SectionHeader('Notes'),
              SoftCard(child: Text(rental.notes)),
            ],
          ],
        ),
      ),
    );
  }

  static String _itemName(Rental r, String itemId) {
    for (final i in r.items) {
      if (i.id == itemId) return i.name;
    }
    return 'Removed item';
  }

  Future<void> _call(BuildContext context, String phone) async {
    final messenger = ScaffoldMessenger.of(context);
    var ok = false;
    try {
      ok = await launchUrl(Uri(scheme: 'tel', path: normalizeDigits(phone)));
    } catch (_) {}
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Calling is not available on this device'),
        ),
      );
    }
  }

  Future<void> _changeExpiry(BuildContext context, Rental rental) async {
    final app = context.read<AppState>();
    final picked = await showDatePicker(
      context: context,
      helpText: 'New expiry date',
      initialDate: rental.expiresOn.isBefore(rental.issuedOn)
          ? rental.issuedOn
          : rental.expiresOn,
      firstDate: rental.issuedOn,
      lastDate: addDays(app.today, 365 * 3),
    );
    if (picked == null) return;
    await app.changeExpiry(rental, picked);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Expiry set to ${formatDay(picked)}')),
      );
    }
  }

  Future<void> _confirmUndo(
    BuildContext context,
    Rental rental,
    ReturnEntry ret,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Undo this return?'),
        content: Text(
          '${_itemName(rental, ret.itemId)} · ${formatQty(ret.qty)} '
          'on ${formatDay(ret.date)} will be counted as still out.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Undo'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AppState>().undoReturn(rental, ret.id);
    }
  }

  Future<void> _confirmDelete(BuildContext context, Rental rental) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${rental.dcNumber}?'),
        content: const Text(
          'This removes the delivery, its returns and its reminders. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: SdColors.expired),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final app = context.read<AppState>();
      Navigator.of(context).pop();
      await app.deleteRental(rental.id);
    }
  }
}

/// Keeps '+' and digits only, for tel: links.
String normalizeDigits(String phone) {
  final t = phone.trim();
  final digits = t.replaceAll(RegExp(r'[^0-9]'), '');
  return t.startsWith('+') ? '+$digits' : digits;
}

/// Status-coloured header: big countdown, sub-line and the timeline bar.
class _Hero extends StatelessWidget {
  const _Hero({required this.rental, required this.info, required this.today});

  final Rental rental;
  final ExpiryInfo info;
  final DateTime today;

  static Color _deep(ExpiryStatus s) => switch (s) {
    ExpiryStatus.expired => const Color(0xFFB4232A),
    ExpiryStatus.dueToday => const Color(0xFFC2410C),
    ExpiryStatus.dueSoon => const Color(0xFF9A5B00),
    ExpiryStatus.active => const Color(0xFF13734A),
    ExpiryStatus.closed => const Color(0xFF4B5160),
  };

  @override
  Widget build(BuildContext context) {
    final base = statusColor(info.status);
    final deep = _deep(info.status);
    final sub = switch (info.status) {
      ExpiryStatus.closed when rental.closedOn != null =>
        'All material returned on ${formatDay(rental.closedOn!)}',
      ExpiryStatus.closed => 'All material returned',
      ExpiryStatus.expired => 'Expired on ${formatDay(rental.expiresOn)}',
      ExpiryStatus.dueToday => 'Material is due back today',
      _ => 'Expires on ${formatDay(rental.expiresOn)}',
    };
    final returnedQty = rental.items.fold(
      0.0,
      (s, i) => s + rental.returnedQty(i.id),
    );
    final totalQty = rental.items.fold(0.0, (s, i) => s + i.qty);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base, deep],
        ),
        boxShadow: [
          BoxShadow(
            color: deep.withValues(alpha: 0.30),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon(info.status), color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  statusName(info.status).toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${formatQty(totalQty - returnedQty)} of ${formatQty(totalQty)} out',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            info.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              height: 1.05,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          ExpiryTimeline(rental: rental, today: today, onDark: true),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text, {this.icon = Icons.info_outline_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
    child: Row(
      children: [
        Icon(icon, size: 15, color: context.sd.muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    ),
  );
}

class _IconBubble extends StatelessWidget {
  const _IconBubble(this.icon, this.color);

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, color: color, size: 20),
  );
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.rental, required this.item});

  final Rental rental;
  final RentalItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final returned = rental.returnedQty(item.id);
    final left = rental.outstandingQty(item);
    final progress = item.qty <= 0
        ? 1.0
        : (returned / item.qty).clamp(0.0, 1.0);
    final done = qtyIsZero(left);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.name, style: theme.textTheme.titleSmall),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: (done ? SdColors.active : SdColors.ember).withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  done ? 'All back' : '${formatQty(left)} ${item.unit} out',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: done ? SdColors.active : SdColors.emberDeep,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            semanticsLabel: '${item.name} returned',
            semanticsValue: '${(progress * 100).round()}%',
            value: progress,
            minHeight: 7,
            borderRadius: BorderRadius.circular(4),
            color: SdColors.active,
          ),
          const SizedBox(height: 6),
          Text(
            'Returned ${formatQty(returned)} of ${formatQty(item.qty)} ${item.unit}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
