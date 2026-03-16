import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/rate_card.dart';
import '../theme/app_theme.dart';

/// Public model to replace _MatEntry in new_bill.dart
class MatEntry {
  String name;
  int? days;
  double quantity;
  String unit;
  double rate;

  MatEntry({
    this.name = '',
    this.days,
    this.quantity = 0.0,
    this.unit = 'pcs',
    this.rate = 0.0,
  });

  double get amount => quantity * rate;
}

/// A single material row using a free-text name field.
/// When the user types a name and days, the app looks up the rate
/// from the rate card automatically (and allows manual override).
class RateCardPickerRow extends StatefulWidget {
  final MatEntry entry;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final int index;
  final bool isDark;

  const RateCardPickerRow({
    super.key,
    required this.entry,
    required this.onChanged,
    required this.onRemove,
    required this.index,
    required this.isDark,
  });

  @override
  State<RateCardPickerRow> createState() => _RateCardPickerRowState();
}

class _RateCardPickerRowState extends State<RateCardPickerRow> {
  late TextEditingController _nameCtrl;
  late TextEditingController _sizeCtrl;
  late TextEditingController _rateCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _daysCtrl;

  // Curated base names for autocomplete to avoid massive 300+ items hanging the dropdown
  static final List<String> _baseNames = [
    '12" Palagai', '9" Palagai', '6" Palagai',
    'Chanal', 'H-Bem', 'Props Jockey 2m', 'Props Jockey 2.5m', 'Props Jockey 3m', 
    'MS Props 10ft/12ft', 'MS Props 15ft',
    'Span 2.5m+2.5m', 'Span 2.0m+2.0m',
    '9" x 9" Box', '9" x 12" Box', '9" x 15" Box', '9" x 18" Box', '9" x 21" Box', '9" x 24" Box',
    '12" x 12" Box', '12" x 15" Box', '12" x 18" Box', '12" x 21" Box', '12" x 24" Box',
    '15" x 15" Box', '15" x 18" Box', '15" x 21" Box', '15" x 24" Box',
    '18" x 18" Box', '18" x 21" Box', '18" x 24" Box',
    '21" x 21" Box', '21" x 24" Box',
    '24" x 24" Box', 
    'L Box 9"x9"', 'L Box 9"x12"', 'L Box 12"x12"', 'Round Box 36"x36"',
    'Joint Piece', 'Corner Piece', 'MS Plate 2ft x 3ft', 'MS Plate 1.5ft x 3ft', 'MS Plate 1ft x 3ft',
    'Auger 12"', 'Auger 9"', 'Auger 6"'
  ];

  @override
  void initState() {
    super.initState();
    // Try to extract base name and size if already populated (e.g. from DB)
    String initName = widget.entry.name;
    String initSize = '';
    
    // Quick heuristic to split "Name 10ft" or "Name 8.0x" back into base and size
    if (initName.endsWith('ft')) {
      final parts = initName.split(' ');
      if (parts.length > 1) {
        initSize = parts.last.replaceAll('ft', '');
        initName = parts.sublist(0, parts.length - 1).join(' ');
      }
    } else if (initName.endsWith('x')) {
      final parts = initName.split(' ');
      if (parts.length > 1) {
        initSize = parts.last.replaceAll('x', '');
        initName = parts.sublist(0, parts.length - 1).join(' ');
      }
    }

    _nameCtrl = TextEditingController(text: initName);
    _sizeCtrl = TextEditingController(text: initSize);
    _rateCtrl = TextEditingController(
        text: widget.entry.rate > 0
            ? widget.entry.rate.toStringAsFixed(2)
            : '');
    _qtyCtrl = TextEditingController(
        text: widget.entry.quantity > 0
            ? widget.entry.quantity.toString()
            : '');
    _daysCtrl = TextEditingController(
        text: widget.entry.days != null ? '${widget.entry.days}' : '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sizeCtrl.dispose();
    _rateCtrl.dispose();
    _qtyCtrl.dispose();
    _daysCtrl.dispose();
    super.dispose();
  }

  void _refreshRate() {
    final baseName = _nameCtrl.text.trim();
    final sizeStr = _sizeCtrl.text.trim();
    final days = widget.entry.days ?? 30;
    
    if (baseName.isEmpty) return;

    double fetchedRate = 0.0;
    String finalRecordName = baseName;

    if (sizeStr.isNotEmpty) {
      // Look for compound name strings in the exact Rate Card catalog
      if (lookupRate('$baseName - ${sizeStr}ft', days) > 0) {
        finalRecordName = '$baseName - ${sizeStr}ft';
        fetchedRate = lookupRate(finalRecordName, days);
      } else if (lookupRate('$baseName ${sizeStr}ft', days) > 0) {
        finalRecordName = '$baseName ${sizeStr}ft';
        fetchedRate = lookupRate(finalRecordName, days);
      } else if (lookupRate('$baseName $sizeStr', days) > 0) {
        finalRecordName = '$baseName $sizeStr';
        fetchedRate = lookupRate(finalRecordName, days);
      } else {
        // Did not match an exact catalog compound item.
        // If the base category exists (e.g. '12" Palagai'), multiply per-foot base rate by the typed size.
        final baseRate = lookupRate(baseName, days);
        if (baseRate > 0) {
          final sizeMlt = double.tryParse(sizeStr) ?? 1.0;
          fetchedRate = baseRate * sizeMlt;
          // Store Palagai names in their legacy format '12" Palagai 8.0x'
          finalRecordName = '$baseName ${sizeStr}x';
        } else {
          // If no lookup, just append space.
          finalRecordName = '$baseName $sizeStr';
        }
      }
    } else {
      // No size provided, use base name.
      fetchedRate = lookupRate(baseName, days);
    }

    widget.entry.name = finalRecordName;

    if (fetchedRate > 0) {
      setState(() {
        widget.entry.rate = fetchedRate;
        _rateCtrl.text = fetchedRate.toStringAsFixed(2);
      });
    }
    
    widget.onChanged();
  }

  InputDecoration _inputDeco(AppColors colors, {String? hint}) =>
      InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.border, width: 0.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.border, width: 0.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.brand, width: 1.5)),
        filled: true,
        fillColor: colors.surface,
      );

  Widget _label(BuildContext context, AppColors colors, String text) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: jakarta(context,
                    size: 9,
                    weight: FontWeight.w700,
                    color: colors.textMuted)
                .copyWith(letterSpacing: 1.2)),
      );

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final label = 'Material ${String.fromCharCode(65 + widget.index)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border, width: 0.5),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: colors.glow,
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Stack(children: [
        // Accent bar
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Container(
            width: 4,
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(20)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [colors.teal, const Color(0xFF075A4E)],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label,
                      style: jakarta(context,
                              size: 10,
                              weight: FontWeight.w800,
                              color: colors.textMain)
                          .copyWith(letterSpacing: 2)),
                  GestureDetector(
                    onTap: widget.onRemove,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? const Color(0xFFFF4D5E).withOpacity(.15)
                            : const Color(0xFFFFF0F1),
                        border: Border.all(
                          color: widget.isDark
                              ? const Color(0xFFFF4D5E).withOpacity(.3)
                              : const Color(0xFFFFD1D6),
                          width: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('✕ Remove',
                          style: jakarta(context,
                              size: 10,
                              weight: FontWeight.w700,
                              color: const Color(0xFFFF5555))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Material name (Autocomplete) + Days
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Material name with compact base list autocomplete
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(context, colors, 'Brand / Category'),
                        Autocomplete<String>(
                          initialValue: TextEditingValue(text: _nameCtrl.text),
                          optionsBuilder: (textEditingValue) {
                            final q = textEditingValue.text.toLowerCase();
                            if (q.isEmpty) return _baseNames;
                            return _baseNames
                                .where((n) => n.toLowerCase().contains(q))
                                .take(12);
                          },
                          onSelected: (selection) {
                            _nameCtrl.text = selection;
                            widget.entry.unit = defaultUnitFor(selection);
                            _refreshRate();
                          },
                          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                            controller.text = _nameCtrl.text;
                            controller.selection = TextSelection.collapsed(offset: controller.text.length);
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              style: jakarta(context, size: 13, color: colors.textMain),
                              decoration: _inputDeco(colors, hint: 'e.g. 12" Palagai'),
                              onChanged: (v) {
                                _nameCtrl.text = v;
                                widget.entry.unit = defaultUnitFor(v);
                                _refreshRate();
                              },
                            );
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4,
                                borderRadius: BorderRadius.circular(12),
                                color: colors.surface,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 220, maxWidth: 200),
                                  child: ListView.builder(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder: (context, index) {
                                      final opt = options.elementAt(index);
                                      return InkWell(
                                        onTap: () => onSelected(opt),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          child: Text(opt, style: jakarta(context, size: 13, color: colors.textMain)),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Size manual entry field
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(context, colors, 'Size'),
                        TextFormField(
                          controller: _sizeCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: jakarta(context, size: 13, color: colors.textMain),
                          decoration: _inputDeco(colors, hint: '10'),
                          onChanged: (v) {
                            _refreshRate();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Days
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(context, colors, 'Days'),
                        TextFormField(
                          controller: _daysCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: jakarta(context, size: 13, color: colors.textMain),
                          decoration: _inputDeco(colors, hint: '30'),
                          onChanged: (v) {
                            final days = int.tryParse(v);
                            widget.entry.days = days;
                            _refreshRate();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Qty + Unit + Rate
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quantity
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(context, colors, 'Quantity'),
                        TextFormField(
                          controller: _qtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[\d.]'))
                          ],
                          style: jakarta(context,
                              size: 13, color: colors.textMain),
                          decoration: _inputDeco(colors, hint: '0'),
                          onChanged: (v) {
                            widget.entry.quantity =
                                double.tryParse(v) ?? 0.0;
                            setState(() {});
                            widget.onChanged();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Unit dropdown
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(context, colors, 'Unit'),
                        DropdownButtonFormField<String>(
                          value: widget.entry.unit,
                          decoration: _inputDeco(colors),
                          style: jakarta(context,
                              size: 13, color: colors.textMain),
                          dropdownColor: colors.surface,
                          items: ['ft', 'pcs', 'nos']
                              .map((u) => DropdownMenuItem(
                                  value: u, child: Text(u)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => widget.entry.unit = v);
                              widget.onChanged();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Rate (editable)
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(context, colors, 'Rate (₹)'),
                        TextFormField(
                          controller: _rateCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[\d.]'))
                          ],
                          style: jakarta(context,
                              size: 13, color: colors.textMain),
                          decoration: _inputDeco(colors, hint: '0.00'),
                          onChanged: (v) {
                            widget.entry.rate =
                                double.tryParse(v) ?? 0.0;
                            setState(() {});
                            widget.onChanged();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Amount display
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.teal.withOpacity(0.1),
                    border: Border.all(
                        color: colors.teal.withOpacity(0.3),
                        width: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '= ₹${widget.entry.amount.toStringAsFixed(2)}',
                    style: GoogleFonts.playfairDisplay(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.teal),
                  ),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
