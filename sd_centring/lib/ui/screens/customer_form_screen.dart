import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/customer.dart';
import '../../state/app_state.dart';
import '../widgets/form_section.dart';
import '../widgets/rental_tile.dart';

/// Add or edit a customer. Pops with the saved [Customer].
class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key, this.existing, this.initialName = ''});

  final Customer? existing;
  final String initialName;

  static Future<Customer?> open(
    BuildContext context, {
    Customer? existing,
    String initialName = '',
  }) => Navigator.of(context).push<Customer>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          CustomerFormScreen(existing: existing, initialName: initialName),
    ),
  );

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.existing?.name ?? widget.initialName,
  );
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late final _altPhone = TextEditingController(
    text: widget.existing?.altPhone ?? '',
  );
  late final _address = TextEditingController(
    text: widget.existing?.address ?? '',
  );
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _phone, _altPhone, _address, _notes]) {
      c.addListener(_markDirty);
    }
  }

  void _markDirty() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  Future<bool> _confirmDiscard() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('What you entered on this screen will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _altPhone, _address, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validatePhone(String? v, {required bool required}) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return required ? 'Required' : null;
    final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 10 || digits.length > 13) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final app = context.read<AppState>();
    final phone = normalizePhone(_phone.text);

    final key = phoneKey(phone);
    final dup = app.customers.where(
      (c) => c.id != widget.existing?.id && phoneKey(c.phone) == key,
    );
    if (dup.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Phone number already used'),
          content: Text(
            '${dup.first.name} already has this number. Save anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save anyway'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    setState(() => _saving = true);
    final e = widget.existing;
    final customer = e == null
        ? Customer(
            id: const Uuid().v4(),
            name: _name.text.trim(),
            phone: phone,
            altPhone: normalizePhone(_altPhone.text),
            address: _address.text.trim(),
            notes: _notes.text.trim(),
            createdAt: DateTime.now(),
          )
        : e.copyWith(
            name: _name.text.trim(),
            phone: phone,
            altPhone: normalizePhone(_altPhone.text),
            address: _address.text.trim(),
            notes: _notes.text.trim(),
          );
    await app.saveCustomer(customer);
    if (mounted) Navigator.of(context).pop(customer);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: const CloseButton(),
          title: Text(
            widget.existing == null ? 'New customer' : 'Edit customer',
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
              child: const Text(
                'SAVE',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        bottomNavigationBar: SaveBar(
          label: _saving ? 'Saving…' : 'Save customer',
          onPressed: _saving ? null : _save,
        ),
        body: PageWidth(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                FormSection(
                  icon: Icons.person_rounded,
                  title: 'Contact',
                  children: [
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Name *',
                        prefixIcon: Icon(Icons.badge_rounded),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          (v?.trim().isEmpty ?? true) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone *',
                        prefixIcon: Icon(Icons.call_rounded),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) => _validatePhone(v, required: true),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _altPhone,
                      decoration: const InputDecoration(
                        labelText: 'Alternate phone',
                        prefixIcon: Icon(Icons.phone_forwarded_rounded),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) => _validatePhone(v, required: false),
                    ),
                  ],
                ),
                FormSection(
                  icon: Icons.place_rounded,
                  title: 'Address & notes',
                  children: [
                    TextFormField(
                      controller: _address,
                      decoration: const InputDecoration(labelText: 'Address'),
                      maxLines: 3,
                      minLines: 1,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notes,
                      decoration: const InputDecoration(labelText: 'Notes'),
                      maxLines: 3,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
