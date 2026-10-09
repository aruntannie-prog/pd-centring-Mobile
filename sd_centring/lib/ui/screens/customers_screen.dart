import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/expiry.dart';
import '../../models/customer.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/rental_tile.dart';
import 'customer_detail_screen.dart';
import 'customer_form_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final q = _search.text.trim().toLowerCase();
    final qPhone = phoneKey(q);
    final list = app.customers
        .where(
          (c) =>
              q.isEmpty ||
              c.name.toLowerCase().contains(q) ||
              c.address.toLowerCase().contains(q) ||
              (qPhone.length >= 3 && phoneKey(c.phone).contains(qPhone)),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'new-customer',
        tooltip: 'New customer',
        onPressed: () => CustomerFormScreen.open(context),
        child: const Icon(Icons.person_add_alt),
      ),
      body: PageWidth(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search name, phone, address',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: !app.loaded
                  ? const Center(child: CircularProgressIndicator())
                  : list.isEmpty
                  ? EmptyState(
                      icon: Icons.people_outline,
                      title: q.isEmpty ? 'No customers yet' : 'No matches',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 96),
                      itemCount: list.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 72),
                      itemBuilder: (_, i) => _CustomerRow(list[i]),
                    ),
            ),
          ],
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
    final rentals = app.rentalsFor(customer.id);
    final open = rentals.where((r) => !r.isClosed).length;
    final expired = rentals
        .where((r) => app.expiry(r).status == ExpiryStatus.expired)
        .length;
    final initial = customer.name.isEmpty
        ? '?'
        : customer.name.characters.first.toUpperCase();

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: SdColors.graphite,
        foregroundColor: Colors.white,
        child: Text(initial),
      ),
      title: Text(customer.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(customer.phone),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (expired > 0)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Badge(
                backgroundColor: SdColors.expired,
                label: Text('$expired expired'),
              ),
            ),
          if (open > 0)
            Text('$open open', style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
      onTap: () => CustomerDetailScreen.open(context, customer.id),
    );
  }
}
