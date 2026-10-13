import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/expiry.dart';
import '../../models/customer.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/rental_tile.dart';
import 'customer_detail_screen.dart';
import 'customer_form_screen.dart';

/// Opens the new customer form, then confirms with a link to the customer.
Future<void> addCustomer(BuildContext context) async {
  final c = await CustomerFormScreen.open(context);
  if (c == null || !context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('${c.name} added'),
        action: SnackBarAction(
          label: 'VIEW',
          onPressed: () => CustomerDetailScreen.open(context, c.id),
        ),
      ),
    );
}

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

enum _Sort { name, newest }

class _CustomersScreenState extends State<CustomersScreen> {
  final _search = TextEditingController();
  var _sort = _Sort.name;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final q = _search.text.trim();
    final list = app.customers.where((c) => c.matches(q)).toList();
    // app.customers is already A–Z.
    if (_sort == _Sort.newest) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    final noId = app.customers.where((c) => c.documents.isEmpty).length;

    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: PageWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text('Customers', style: theme.textTheme.headlineMedium),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Text(
                  [
                    '${app.customers.length} customer'
                        '${app.customers.length == 1 ? '' : 's'}',
                    if (noId > 0) '$noId without ID proof',
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 13.5),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search name, phone, address',
                    prefixIcon: const Icon(Icons.search_rounded),
                    fillColor: context.sd.card,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final (sort, label) in const [
                      (_Sort.name, 'A–Z'),
                      (_Sort.newest, 'Newest first'),
                    ])
                      ChoiceChip(
                        label: Text(label),
                        selected: _sort == sort,
                        onSelected: (_) => setState(() => _sort = sort),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: !app.loaded
                    ? const Center(child: CircularProgressIndicator())
                    : list.isEmpty
                    ? EmptyState(
                        icon: Icons.people_rounded,
                        title: q.isEmpty ? 'No customers yet' : 'No matches',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _CustomerRow(list[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow(this.customer);

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);
    final rentals = app.rentalsFor(customer.id);
    final open = rentals.where((r) => !r.isClosed).length;
    final expired = rentals
        .where((r) => app.expiry(r).status == ExpiryStatus.expired)
        .length;

    Widget tag(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );

    return SoftCard(
      padding: const EdgeInsets.all(14),
      onTap: () => CustomerDetailScreen.open(context, customer.id),
      child: Row(
        children: [
          InitialsAvatar(customer.name, size: 48, photoUrl: customer.photoUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(customer.phone, style: theme.textTheme.bodySmall),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 10,
                  runSpacing: 2,
                  children: [
                    if (app.isPending(customer.id))
                      const _Mark(
                        Icons.cloud_upload_outlined,
                        'Not in cloud yet',
                        SdColors.soon,
                      )
                    else if (!app.isDemo)
                      const _Mark(
                        Icons.cloud_done_outlined,
                        'In cloud',
                        SdColors.active,
                      ),
                    if (customer.documents.isEmpty)
                      const _Mark(
                        Icons.badge_outlined,
                        'No ID proof',
                        SdColors.soon,
                      )
                    else
                      _Mark(
                        Icons.badge_outlined,
                        '${customer.documents.length} ID / proof',
                        context.sd.muted,
                      ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (expired > 0) tag('$expired expired', SdColors.expired),
              if (expired > 0 && open > 0) const SizedBox(height: 4),
              if (open > 0) tag('$open open', SdColors.active),
              if (open == 0 && expired == 0) tag('No rentals', SdColors.closed),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small icon + label status line on a customer row.
class _Mark extends StatelessWidget {
  const _Mark(this.icon, this.label, this.color);

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    ],
  );
}
