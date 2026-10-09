import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/quantity.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/rental_tile.dart';
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
          icon: Icons.search_off,
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
        title: Text(customer.name),
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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'customer-new-delivery',
        onPressed: () =>
            DeliveryFormScreen.open(context, customerId: customer.id),
        icon: const Icon(Icons.add),
        label: const Text('New delivery'),
      ),
      body: PageWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoLine(Icons.phone, customer.phone),
                    if (customer.altPhone.isNotEmpty)
                      _InfoLine(Icons.phone_forwarded, customer.altPhone),
                    if (customer.address.isNotEmpty)
                      _InfoLine(Icons.place_outlined, customer.address),
                    if (customer.notes.isNotEmpty)
                      _InfoLine(Icons.notes, customer.notes),
                  ],
                ),
              ),
            ),
            if (holding.isNotEmpty) ...[
              const SectionHeader('Material with customer'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in holding.entries)
                        Chip(
                          label: Text(
                            '${e.key.split('|').first} · '
                            '${formatQty(e.value)} ${units[e.key]}',
                          ),
                          labelStyle: theme.textTheme.labelLarge,
                        ),
                    ],
                  ),
                ),
              ),
            ],
            SectionHeader('Open deliveries', count: open.length),
            if (open.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Nothing out on rent.'),
              ),
            for (final r in open)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RentalTile(r, showCustomer: false),
              ),
            if (closed.isNotEmpty) ...[
              SectionHeader('Returned', count: closed.length),
              for (final r in closed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RentalTile(r, showCustomer: false),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
