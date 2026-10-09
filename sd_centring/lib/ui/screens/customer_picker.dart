import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/customer.dart';
import '../../state/app_state.dart';
import 'customer_form_screen.dart';

/// Searchable list of customers in a bottom sheet. Returns the chosen one.
class CustomerPicker extends StatefulWidget {
  const CustomerPicker({super.key});

  static Future<Customer?> show(BuildContext context) =>
      showModalBottomSheet<Customer>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => const FractionallySizedBox(
          heightFactor: 0.85,
          child: CustomerPicker(),
        ),
      );

  @override
  State<CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends State<CustomerPicker> {
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
              (qPhone.length >= 3 && phoneKey(c.phone).contains(qPhone)),
        )
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _search,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Search name or phone',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_add_alt)),
          title: const Text('Add new customer'),
          onTap: () async {
            final created = await CustomerFormScreen.open(
              context,
              initialName: _search.text.trim(),
            );
            if (created != null && context.mounted) {
              Navigator.pop(context, created);
            }
          },
        ),
        const Divider(height: 1),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('No customers found'))
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final c = list[i];
                    return ListTile(
                      title: Text(c.name),
                      subtitle: Text(c.phone),
                      onTap: () => Navigator.pop(context, c),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
