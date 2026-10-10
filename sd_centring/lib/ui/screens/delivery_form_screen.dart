import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../config/brand.dart';
import '../../core/dates.dart';
import '../../core/quantity.dart';
import '../../domain/dc_number.dart';
import '../../models/customer.dart';
import '../../models/rental.dart';
import '../../state/app_state.dart';
import '../widgets/rental_tile.dart';
import '../theme.dart';
import '../widgets/form_section.dart';
import 'customer_form_screen.dart';
import 'customer_picker.dart';

const _uuid = Uuid();

/// Create or edit a delivery challan. No prices — just who, where, what,
/// how much, and until when.
class DeliveryFormScreen extends StatefulWidget {
  const DeliveryFormScreen({super.key, this.existing, this.customerId});

  final Rental? existing;

  /// Pre-selects a customer for a new delivery.
  final String? customerId;

  static Future<void> open(
    BuildContext context, {
    Rental? existing,
    String? customerId,
  }) => Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          DeliveryFormScreen(existing: existing, customerId: customerId),
    ),
  );

  @override
  State<DeliveryFormScreen> createState() => _DeliveryFormScreenState();
}

class _ItemDraft {
  _ItemDraft({
    required this.id,
    String name = '',
    String qty = '',
    this.unit = 'pcs',
  }) : name = TextEditingController(text: name),
       qty = TextEditingController(text: qty);

  final String id;
  final TextEditingController name;
  final TextEditingController qty;
  String unit;

  void dispose() {
    name.dispose();
    qty.dispose();
  }
}

class _DeliveryFormScreenState extends State<DeliveryFormScreen> {
  static const _quickDays = [7, 15, 30, 45, 60];

  final _formKey = GlobalKey<FormState>();
  final _dc = TextEditingController();
  final _site = TextEditingController();
  final _notes = TextEditingController();
  final _items = <_ItemDraft>[];
  Customer? _customer;
  late DateTime _issuedOn;
  late DateTime _expiresOn;
  bool _dirty = false;
  bool _saving = false;
  String? _customerError;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    final e = widget.existing;
    if (e != null) {
      _dc.text = e.dcNumber;
      _site.text = e.site;
      _notes.text = e.notes;
      _customer = app.customerById(e.customerId);
      _issuedOn = e.issuedOn;
      _expiresOn = e.expiresOn;
      for (final i in e.items) {
        _items.add(
          _ItemDraft(
            id: i.id,
            name: i.name,
            qty: formatQty(i.qty),
            unit: i.unit,
          ),
        );
      }
    } else {
      _dc.text = nextDcNumber(
        app.rentals,
        prefix: Brand.dcPrefix,
        start: Brand.dcStartNumber,
      );
      if (widget.customerId != null) {
        _customer = app.customerById(widget.customerId!);
      }
      _issuedOn = app.today;
      _expiresOn = addDays(_issuedOn, 30);
      _items.add(_ItemDraft(id: _uuid.v4()));
    }
    for (final c in [_dc, _site, _notes]) {
      c.addListener(_markDirty);
    }
  }

  /// Rebuilds once so the back-button guard (PopScope) knows about changes.
  void _markDirty() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _dc.dispose();
    _site.dispose();
    _notes.dispose();
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  Future<void> _chooseCustomer() async {
    final picked = await CustomerPicker.show(context);
    if (picked == null || !mounted) return;
    setState(() {
      _customer = picked;
      _customerError = null;
      _dirty = true;
    });
  }

  Future<void> _newCustomer() async {
    final created = await CustomerFormScreen.open(context);
    if (created == null || !mounted) return;
    setState(() {
      _customer = created;
      _customerError = null;
      _dirty = true;
    });
  }

  Future<void> _pickIssued() async {
    final app = context.read<AppState>();
    final picked = await showDatePicker(
      context: context,
      helpText: 'Delivery date',
      initialDate: _issuedOn,
      firstDate: DateTime(2020),
      lastDate: addDays(app.today, 30),
    );
    if (picked == null) return;
    setState(() {
      // Keep the same rental length when the issue date moves.
      final length = daysBetween(_issuedOn, _expiresOn);
      _issuedOn = dayOf(picked);
      _expiresOn = addDays(_issuedOn, length < 0 ? 0 : length);
      _dirty = true;
    });
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      helpText: 'Expiry date',
      initialDate: _expiresOn.isBefore(_issuedOn) ? _issuedOn : _expiresOn,
      firstDate: _issuedOn,
      lastDate: addDays(_issuedOn, 365 * 3),
    );
    if (picked == null) return;
    setState(() {
      _expiresOn = dayOf(picked);
      _dirty = true;
    });
  }

  String? _validateItems() {
    if (_items.isEmpty) return 'Add at least one item';
    final existing = widget.existing;
    for (final d in _items) {
      if (d.name.text.trim().isEmpty) return 'Every item needs a name';
      final q = parsePositiveQty(d.qty.text);
      if (q == null) return 'Every item needs a quantity above 0';
      if (existing != null) {
        final returned = existing.returnedQty(d.id);
        if (q + qtyEpsilon < returned) {
          return '${d.name.text.trim()}: ${formatQty(returned)} already returned — '
              'quantity cannot be lower';
        }
      }
    }
    if (existing != null) {
      final keptIds = _items.map((d) => d.id).toSet();
      for (final i in existing.items) {
        if (!keptIds.contains(i.id) && existing.returnedQty(i.id) > 0) {
          return '${i.name} has returns recorded — undo them before removing it';
        }
      }
    }
    return null;
  }

  Future<void> _save() async {
    final app = context.read<AppState>();
    setState(
      () => _customerError = _customer == null ? 'Choose a customer' : null,
    );
    final formOk = _formKey.currentState!.validate();
    final itemsError = _validateItems();
    if (!formOk || _customer == null || itemsError != null) {
      if (itemsError != null) {
        _toast(itemsError);
      }
      return;
    }
    if (_expiresOn.isBefore(_issuedOn)) {
      _toast('Expiry date cannot be before the delivery date');
      return;
    }

    setState(() => _saving = true);
    final items = [
      for (final d in _items)
        RentalItem(
          id: d.id,
          name: d.name.text.trim(),
          qty: parsePositiveQty(d.qty.text)!,
          unit: d.unit,
        ),
    ];
    final now = DateTime.now();
    final e = widget.existing;
    final latest = e == null ? null : app.rentalById(e.id) ?? e;
    final Rental rental;
    if (latest == null) {
      rental = Rental(
        id: _uuid.v4(),
        dcNumber: _dc.text.trim(),
        customerId: _customer!.id,
        customerName: _customer!.name,
        site: _site.text.trim(),
        issuedOn: _issuedOn,
        expiresOn: _expiresOn,
        items: items,
        notes: _notes.text.trim(),
        createdAt: now,
        updatedAt: now,
      );
    } else {
      rental = latest.copyWith(
        dcNumber: _dc.text.trim(),
        customerId: _customer!.id,
        customerName: _customer!.name,
        site: _site.text.trim(),
        issuedOn: _issuedOn,
        expiresOn: _expiresOn,
        items: items,
        notes: _notes.text.trim(),
        expiryHistory: _expiresOn == latest.expiresOn
            ? latest.expiryHistory
            : [
                ...latest.expiryHistory,
                ExpiryChange(
                  from: latest.expiresOn,
                  to: _expiresOn,
                  changedAt: now,
                ),
              ],
      );
    }
    final messenger = ScaffoldMessenger.of(context);
    await app.saveRental(rental);
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${rental.dcNumber} saved · expires ${formatDay(rental.expiresOn)}',
          ),
        ),
      );
  }

  /// Replaces any message still showing instead of queueing behind it.
  void _toast(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

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
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);
    final length = daysBetween(_issuedOn, _expiresOn);

    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          _dirty = false;
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: const CloseButton(),
          title: Text(
            _editing ? 'Edit ${widget.existing!.dcNumber}' : 'New delivery',
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
          label: _saving ? 'Saving…' : 'Save delivery',
          onPressed: _saving ? null : _save,
        ),
        body: PageWidth(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // ── Customer ─────────────────────────────────────────────
                FormSection(
                  icon: Icons.person_rounded,
                  title: 'Customer',
                  trailing: TextButton.icon(
                    onPressed: _newCustomer,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text('New customer'),
                  ),
                  children: [
                    InkWell(
                      onTap: _chooseCustomer,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.sd.field,
                          borderRadius: BorderRadius.circular(16),
                          border: _customerError == null
                              ? null
                              : Border.all(color: SdColors.expired, width: 1.2),
                        ),
                        child: Row(
                          children: [
                            _customer == null
                                ? Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: context.sd.card,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.person_search_rounded,
                                      color: context.sd.muted,
                                    ),
                                  )
                                : InitialsAvatar(_customer!.name),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _customer?.name ?? 'Choose customer',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: _customer == null
                                          ? context.sd.muted
                                          : null,
                                    ),
                                  ),
                                  if (_customer != null)
                                    Text(
                                      _customer!.phone,
                                      style: theme.textTheme.bodySmall,
                                    )
                                  else if (_customerError != null)
                                    Text(
                                      _customerError!,
                                      style: const TextStyle(
                                        color: SdColors.expired,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.expand_more_rounded,
                              color: context.sd.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _dc,
                            decoration: const InputDecoration(
                              labelText: 'DC number',
                              prefixIcon: Icon(Icons.tag_rounded),
                            ),
                            textCapitalization: TextCapitalization.characters,
                            validator: (v) {
                              final s = v?.trim() ?? '';
                              if (s.isEmpty) return 'Required';
                              if (isDcNumberTaken(
                                app.rentals,
                                s,
                                exceptId: widget.existing?.id,
                              )) {
                                return 'Already used';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _site,
                            decoration: const InputDecoration(
                              labelText: 'Site (optional)',
                              prefixIcon: Icon(Icons.place_rounded),
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // ── Dates ────────────────────────────────────────────────
                FormSection(
                  icon: Icons.event_rounded,
                  title: 'Rental period',
                  trailing: Text(
                    '$length day${length == 1 ? '' : 's'}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: SdColors.ember,
                    ),
                  ),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DateField(
                            label: 'Delivered on',
                            date: formatDay(_issuedOn),
                            onTap: _pickIssued,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DateField(
                            label: 'Expires on',
                            date: formatDay(_expiresOn),
                            onTap: _pickExpiry,
                            emphasise: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final d in _quickDays)
                          ChoiceChip(
                            label: Text('$d days'),
                            selected: length == d,
                            onSelected: (_) => setState(() {
                              _expiresOn = addDays(_issuedOn, d);
                              _dirty = true;
                            }),
                          ),
                      ],
                    ),
                  ],
                ),

                // ── Items ────────────────────────────────────────────────
                FormSection(
                  icon: Icons.inventory_2_rounded,
                  title: 'Material',
                  trailing: Text(
                    '${_items.length} item${_items.length == 1 ? '' : 's'}',
                    style: theme.textTheme.bodySmall,
                  ),
                  children: [
                    for (var i = 0; i < _items.length; i++) _itemRow(i),
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _items.add(_ItemDraft(id: _uuid.v4()));
                        _dirty = true;
                      }),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add item'),
                    ),
                  ],
                ),

                FormSection(
                  icon: Icons.notes_rounded,
                  title: 'Notes',
                  children: [
                    TextFormField(
                      controller: _notes,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                      ),
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

  Widget _itemRow(int index) {
    final d = _items[index];
    final name = TextFormField(
      controller: d.name,
      onChanged: (_) => _markDirty(),
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: 'Item',
        suffixIcon: PopupMenuButton<String>(
          tooltip: 'Pick material',
          icon: const Icon(Icons.arrow_drop_down),
          onSelected: (v) => setState(() {
            d.name.text = v;
            _dirty = true;
          }),
          itemBuilder: (_) => [
            for (final m in defaultMaterials)
              PopupMenuItem(value: m, child: Text(m)),
          ],
        ),
      ),
    );
    final qty = TextFormField(
      controller: d.qty,
      onChanged: (_) => _markDirty(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(labelText: 'Qty'),
    );
    final unit = DropdownButton<String>(
      value: defaultUnits.contains(d.unit) ? d.unit : null,
      hint: Text(d.unit),
      underline: const SizedBox.shrink(),
      items: [
        for (final u in defaultUnits)
          DropdownMenuItem(value: u, child: Text(u)),
      ],
      onChanged: (u) => setState(() {
        if (u != null) d.unit = u;
        _dirty = true;
      }),
    );
    final remove = IconButton(
      tooltip: 'Remove item',
      icon: const Icon(Icons.remove_circle_outline),
      onPressed: _items.length == 1
          ? null
          : () => setState(() {
              _items.removeAt(index).dispose();
              _dirty = true;
            }),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: context.sd.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: LayoutBuilder(
          builder: (context, c) {
            // Phones: item name gets its own line so it is never cut off.
            if (c.maxWidth < 480) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: name),
                      remove,
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: qty),
                      const SizedBox(width: 12),
                      unit,
                      const SizedBox(width: 48),
                    ],
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: name),
                const SizedBox(width: 8),
                Expanded(flex: 3, child: qty),
                const SizedBox(width: 8),
                unit,
                remove,
              ],
            );
          },
        ),
      ),
    );
  }
}
