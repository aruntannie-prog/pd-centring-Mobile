import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/dates.dart';
import '../../core/quantity.dart';
import '../../models/rental.dart';
import '../../state/app_state.dart';
import '../widgets/form_section.dart';
import '../theme.dart';

/// Bottom sheet to record material coming back. Supports partial returns
/// (e.g. 15 of 40 props) across several items in one go.
class RecordReturnSheet extends StatefulWidget {
  const RecordReturnSheet({super.key, required this.rental});

  final Rental rental;

  static Future<void> show(BuildContext context, Rental rental) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => RecordReturnSheet(rental: rental),
      );

  @override
  State<RecordReturnSheet> createState() => _RecordReturnSheetState();
}

class _RecordReturnSheetState extends State<RecordReturnSheet> {
  final _formKey = GlobalKey<FormState>();
  late final List<RentalItem> _items = widget.rental.outstandingItems;
  late final Map<String, TextEditingController> _qty = {
    for (final i in _items) i.id: TextEditingController(),
  };
  final _note = TextEditingController();
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final today = context.read<AppState>().today;
    _date = today.isBefore(widget.rental.issuedOn)
        ? widget.rental.issuedOn
        : today;
  }

  @override
  void dispose() {
    for (final c in _qty.values) {
      c.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final app = context.read<AppState>();
    final last = app.today.isBefore(widget.rental.issuedOn)
        ? widget.rental.issuedOn
        : app.today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: widget.rental.issuedOn,
      lastDate: last,
      helpText: 'Return date',
    );
    if (picked != null) setState(() => _date = dayOf(picked));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    const uuid = Uuid();
    final note = _note.text.trim();
    final entries = <ReturnEntry>[
      for (final item in _items)
        if (parsePositiveQty(_qty[item.id]!.text) case final q?)
          ReturnEntry(
            id: uuid.v4(),
            itemId: item.id,
            qty: q,
            date: _date,
            note: note,
          ),
    ];
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a quantity for at least one item')),
      );
      return;
    }
    setState(() => _saving = true);
    final app = context.read<AppState>();
    // Re-read the latest version so a change made meanwhile isn't overwritten.
    final latest = app.rentalById(widget.rental.id) ?? widget.rental;
    await app.addReturns(latest, entries);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: SdColors.active.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.assignment_return_rounded,
                    color: SdColors.active,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Record return', style: theme.textTheme.titleLarge),
                      Text(
                        widget.rental.dcNumber,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Leave a quantity empty if that item did not come back.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            for (final item in _items) _qtyRow(item),
            const SizedBox(height: 4),
            DateField(
              label: 'Return date',
              date: formatDay(_date),
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save return'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qtyRow(RentalItem item) {
    final left = widget.rental.outstandingQty(item);
    final ctrl = _qty[item.id]!;
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        border: Border.all(color: context.sd.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    '${formatQty(left)} ${item.unit} out',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Qty',
                suffixText: item.unit,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final q = parsePositiveQty(v);
                if (q == null) return 'Invalid';
                if (q > left + qtyEpsilon) return 'Max ${formatQty(left)}';
                return null;
              },
            ),
          ),
          const SizedBox(width: 2),
          TextButton(
            onPressed: () => setState(() => ctrl.text = formatQty(left)),
            child: const Text('All'),
          ),
        ],
      ),
    );
  }
}
