import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/customer.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/rental_tile.dart';
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
    final q = _search.text.trim();
    final list = app.customers.where((c) => c.matches(q)).toList();

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text('Choose customer', style: theme.textTheme.titleLarge),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _search,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Search name or phone',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 2,
          ),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: SdColors.ember.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.person_add_alt_1_rounded,
              color: SdColors.ember,
            ),
          ),
          title: const Text(
            'Add new customer',
            style: TextStyle(color: SdColors.ember),
          ),
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
              ? const EmptyState(
                  icon: Icons.person_search_rounded,
                  title: 'No customers found',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final c = list[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 2,
                      ),
                      leading: InitialsAvatar(c.name, photoUrl: c.photoUrl),
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
