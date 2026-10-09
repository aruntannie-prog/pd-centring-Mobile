import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/expiry.dart';
import '../../models/customer.dart';
import '../../models/rental.dart';
import '../../state/app_state.dart';
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
        (qPhone.length >= 4 &&
            customer != null &&
            (phoneKey(customer.phone).contains(qPhone) ||
                phoneKey(customer.altPhone).contains(qPhone)));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deliveries'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search DC no., customer, site, phone, item',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(_search.clear),
                      ),
              ),
            ),
          ),
        ),
      ),
      body: PageWidth(
        child: ValueListenableBuilder<DeliveryFilter>(
          valueListenable: widget.filter,
          builder: (context, filter, _) {
            final q = _search.text.trim().toLowerCase();
            final list = app.rentals
                .where(
                  (r) =>
                      filter.matches(app.expiry(r).status) &&
                      _matchesQuery(app, r, q),
                )
                .toList();
            if (filter == DeliveryFilter.returned) {
              list.sort((a, b) => b.expiresOn.compareTo(a.expiresOn));
            }

            return Column(
              children: [
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    children: [
                      for (final f in DeliveryFilter.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(f.label),
                            selected: f == filter,
                            onSelected: (_) => widget.filter.value = f,
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
                          icon: Icons.inbox_outlined,
                          title: q.isEmpty
                              ? 'No deliveries here'
                              : 'No matches',
                          message: q.isEmpty
                              ? 'Tap “New delivery” to add one.'
                              : null,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => RentalTile(list[i]),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
