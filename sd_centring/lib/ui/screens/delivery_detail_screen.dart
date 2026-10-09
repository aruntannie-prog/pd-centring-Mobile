import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/quantity.dart';
import '../../models/rental.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/rental_tile.dart';
import 'customer_detail_screen.dart';
import 'delivery_form_screen.dart';
import 'record_return_sheet.dart';

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
                icon: Icons.search_off,
                title: 'Delivery not found',
                message: 'It may have been deleted.',
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }

    final info = app.expiry(rental);
    final theme = Theme.of(context);
    final customer = app.customerById(rental.customerId);

    return Scaffold(
      appBar: AppBar(
        title: Text(rental.dcNumber),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => DeliveryFormScreen.open(context, existing: rental),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'delete') _confirmDelete(context, rental);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Text('Delete delivery')),
            ],
          ),
        ],
      ),
      bottomNavigationBar: rental.isClosed
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () => RecordReturnSheet.show(context, rental),
                  icon: const Icon(Icons.assignment_return_outlined),
                  label: const Text('Record return'),
                ),
              ),
            ),
      body: PageWidth(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Expiry header ──────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExpiryPill(info, large: true),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _DateBlock('Issued', rental.issuedOn)),
                        Expanded(
                          child: _DateBlock(
                            'Expiry',
                            rental.expiresOn,
                            color: statusColor(info.status),
                          ),
                        ),
                      ],
                    ),
                    if (rental.isClosed && rental.closedOn != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'All material returned on ${formatDay(rental.closedOn!)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    if (!rental.isClosed) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _changeExpiry(context, rental),
                        icon: const Icon(Icons.event_repeat),
                        label: const Text('Extend / change expiry'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Customer ───────────────────────────────────────────────────
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(app.customerNameOf(rental)),
                subtitle: Text(
                  [
                    if (customer != null && customer.phone.isNotEmpty)
                      customer.phone,
                    if (rental.site.isNotEmpty) 'Site: ${rental.site}',
                  ].join('\n'),
                ),
                isThreeLine:
                    customer != null &&
                    customer.phone.isNotEmpty &&
                    rental.site.isNotEmpty,
                trailing: customer == null
                    ? null
                    : const Icon(Icons.chevron_right),
                onTap: customer == null
                    ? null
                    : () => CustomerDetailScreen.open(context, customer.id),
              ),
            ),

            // ── Items ──────────────────────────────────────────────────────
            const SectionHeader('Material'),
            Card(
              child: Column(
                children: [
                  for (final item in rental.items)
                    _ItemRow(rental: rental, item: item),
                ],
              ),
            ),

            // ── Returns ────────────────────────────────────────────────────
            if (rental.returns.isNotEmpty) ...[
              const SectionHeader('Returns'),
              Card(
                child: Column(
                  children: [
                    for (final ret
                        in (rental.returns.toList()
                          ..sort((a, b) => b.date.compareTo(a.date))))
                      ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.assignment_return,
                          color: SdColors.active,
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
                          icon: const Icon(Icons.undo),
                          onPressed: () => _confirmUndo(context, rental, ret),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            // ── Expiry changes ─────────────────────────────────────────────
            if (rental.expiryHistory.isNotEmpty) ...[
              const SectionHeader('Expiry changes'),
              Card(
                child: Column(
                  children: [
                    for (final ch in rental.expiryHistory.reversed)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.event_repeat),
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(rental.notes),
                ),
              ),
            ],
            const SizedBox(height: 24),
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

class _DateBlock extends StatelessWidget {
  const _DateBlock(this.label, this.date, {this.color});

  final String label;
  final DateTime date;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.1),
        ),
        Text(
          formatDay(date),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                done ? 'All back' : '${formatQty(left)} ${item.unit} out',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: done ? SdColors.active : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            semanticsLabel: '${item.name} returned',
            semanticsValue: '${(progress * 100).round()}%',
            value: progress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
            color: SdColors.active,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(height: 4),
          Text(
            'Returned ${formatQty(returned)} of ${formatQty(item.qty)} ${item.unit}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
