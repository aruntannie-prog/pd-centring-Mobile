import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/expiry.dart';
import '../../models/customer.dart';
import '../../models/rental.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/rental_tile.dart';

enum DeliveryFilter {
  open('Out on rent'),
  expiring('Expiring'),
  expired('Expired'),
  returned('Returned'),
  all('All');

  const DeliveryFilter(this.label);
  final String label;

  bool matches(ExpiryStatus s) => switch (this) {
    DeliveryFilter.open => s != ExpiryStatus.closed,
    DeliveryFilter.expiring =>
      s == ExpiryStatus.dueToday || s == ExpiryStatus.dueSoon,
    DeliveryFilter.expired => s == ExpiryStatus.expired,
    DeliveryFilter.returned => s == ExpiryStatus.closed,
    DeliveryFilter.all => true,
  };
}

class DeliveriesScreen extends StatefulWidget {
  const DeliveriesScreen({super.key, required this.filter});

  final ValueNotifier<DeliveryFilter> filter;

  @override
  State<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends State<DeliveriesScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matchesQuery(AppState app, Rental r, String q) {
    if (q.isEmpty) return true;
    final customer = app.customerById(r.customerId);
    final qPhone = phoneKey(q);
    return r.dcNumber.toLowerCase().contains(q) ||
        app.customerNameOf(r).toLowerCase().contains(q) ||
        r.site.toLowerCase().contains(q) ||
        r.items.any((i) => i.name.toLowerCase().contains(q)) ||
        // Phone match only for phone-like queries, so "SD-1001" does not
        // also list customers whose number contains 1001.
        (qPhone.length >= 4 &&
            RegExp(r'^[0-9+\-\s()]+$').hasMatch(q) &&
            customer != null &&
            (phoneKey(customer.phone).contains(qPhone) ||
                phoneKey(customer.altPhone).contains(qPhone)));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: PageWidth(
          child: ValueListenableBuilder<DeliveryFilter>(
            valueListenable: widget.filter,
            builder: (context, filter, _) {
              final q = _search.text.trim().toLowerCase();
              final matching = app.rentals
                  .where((r) => _matchesQuery(app, r, q))
                  .toList();
              int countFor(DeliveryFilter f) =>
                  matching.where((r) => f.matches(app.expiry(r).status)).length;
              final list = matching
                  .where((r) => filter.matches(app.expiry(r).status))
                  .toList();
              if (filter == DeliveryFilter.returned) {
                list.sort((a, b) => b.expiresOn.compareTo(a.expiresOn));
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                    child: Text(
                      'Deliveries',
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    child: Text(
                      '${countFor(DeliveryFilter.open)} out on rent · '
                      '${countFor(DeliveryFilter.expired)} expired',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search DC no., customer, site, phone, item',
                        prefixIcon: const Icon(Icons.search_rounded),
                        fillColor: context.sd.card,
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => setState(_search.clear),
                              ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 60,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      children: [
                        for (final f in DeliveryFilter.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              selected: f == filter,
                              onSelected: (_) => widget.filter.value = f,
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(f.label),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${countFor(f)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: f == filter
                                          ? Colors.white70
                                          : context.sd.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: !app.loaded
                        ? const Center(child: CircularProgressIndicator())
                        : list.isEmpty
                        ? EmptyState(
                            icon: Icons.inbox_rounded,
                            title: q.isEmpty
                                ? 'No deliveries here'
                                : 'No matches',
                            message: q.isEmpty
                                ? 'Tap “New delivery” to add one.'
                                : null,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
                            itemCount: list.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) => RentalTile(list[i]),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
