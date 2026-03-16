# Invoice Generation Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add rate-card-based invoice generation with PDF share and print to the PD Centring Flutter app.

**Architecture:** Extend `RentalMaterial` + `Bill` models with pricing fields; add `RateCardPicker` widget and `InvoiceService`; update `new_bill.dart` and `bill_detail.dart`.

**Tech Stack:** Flutter/Dart, `pdf ^3.10.8`, `printing ^5.12.0`, Firebase Firestore (existing)

**Spec:** `docs/superpowers/specs/2026-03-13-invoice-generation-design.md`

---

## Chunk 1: Dependencies + Data Model

### Task 1: Add PDF packages to pubspec.yaml

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add dependencies**

Open `pubspec.yaml` and add under `dependencies:`:
```yaml
  pdf: ^3.10.8
  printing: ^5.12.0
```

- [ ] **Step 2: Install packages**

```powershell
flutter pub get
```
Expected output: `Got dependencies!` with no errors.

- [ ] **Step 3: Verify no conflicts**

```powershell
flutter pub outdated
```
Expected: pdf and printing listed, no version conflicts.

- [ ] **Step 4: Commit**

```powershell
git add pubspec.yaml pubspec.lock
git commit -m "chore: add pdf and printing packages"
```

---

### Task 2: Extend RentalMaterial and Bill data models

**Files:**
- Modify: `lib/models/bill.dart`

- [ ] **Step 1: Add fields to `RentalMaterial`**

In `lib/models/bill.dart`, update `RentalMaterial` class:

```dart
class RentalMaterial {
  final String id;
  String name;
  int days;
  DateTime dueDate;
  MaterialStatus status;
  double quantity;   // NEW
  String unit;       // NEW — "ft" | "pcs" | "nos"
  double rate;       // NEW — rate per unit

  double get amount => quantity * rate;

  RentalMaterial({
    String? id,
    required this.name,
    required this.days,
    required this.dueDate,
    this.status = MaterialStatus.pending,
    this.quantity = 0.0,   // NEW
    this.unit = 'pcs',     // NEW
    this.rate = 0.0,       // NEW
  }) : id = id ?? _uuid.v4();
```

- [ ] **Step 2: Update `RentalMaterial.toJson()`**

```dart
Map<String, dynamic> toJson() => {
  'id': id,
  'name': name,
  'days': days,
  'dueDate': dueDate.toIso8601String(),
  'status': status.name,
  'quantity': quantity,   // NEW
  'unit': unit,           // NEW
  'rate': rate,           // NEW
};
```

- [ ] **Step 3: Update `RentalMaterial.fromJson()`**

```dart
factory RentalMaterial.fromJson(Map<String, dynamic> j) => RentalMaterial(
  id: j['id'],
  name: j['name'],
  days: j['days'],
  dueDate: DateTime.parse(j['dueDate']),
  status: MaterialStatus.values.firstWhere((e) => e.name == j['status'],
      orElse: () => MaterialStatus.pending),
  quantity: (j['quantity'] as num?)?.toDouble() ?? 0.0,  // NEW
  unit: j['unit'] as String? ?? 'pcs',                   // NEW
  rate: (j['rate'] as num?)?.toDouble() ?? 0.0,          // NEW
);
```

- [ ] **Step 4: Add fields to `Bill` class**

In the `Bill` class, add after `materials`:
```dart
double vehicleChargeUp;    // NEW
double vehicleChargeDown;  // NEW
double advancePaid;        // NEW

double get rentTotal  => materials.fold(0.0, (s, m) => s + m.amount);
double get grandTotal => rentTotal + vehicleChargeUp + vehicleChargeDown;
double get balanceDue => grandTotal - advancePaid;
```

Update `Bill` constructor:
```dart
Bill({
  // ... existing params ...
  this.vehicleChargeUp = 0.0,    // NEW
  this.vehicleChargeDown = 0.0,  // NEW
  this.advancePaid = 0.0,        // NEW
  required this.materials,
})
```

- [ ] **Step 5: Update `Bill.toJson()` and `Bill.fromJson()`**

In `toJson()` add:
```dart
'vehicleChargeUp': vehicleChargeUp,
'vehicleChargeDown': vehicleChargeDown,
'advancePaid': advancePaid,
```

In `fromJson()` add:
```dart
vehicleChargeUp: (j['vehicleChargeUp'] as num?)?.toDouble() ?? 0.0,
vehicleChargeDown: (j['vehicleChargeDown'] as num?)?.toDouble() ?? 0.0,
advancePaid: (j['advancePaid'] as num?)?.toDouble() ?? 0.0,
```

- [ ] **Step 6: Verify no analysis errors**

```powershell
flutter analyze lib/models/bill.dart
```
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```powershell
git add lib/models/bill.dart
git commit -m "feat: extend RentalMaterial and Bill with pricing fields"
```

---

## Chunk 2: Rate Card Data + Picker Widget

### Task 3: Create rate card lookup table

**Files:**
- Create: `lib/data/rate_card.dart`

- [ ] **Step 1: Create the file with category enums and rate maps**

Create `lib/data/rate_card.dart`:

```dart
// Rate card data from PD NEW RATE CARD PDF

enum MaterialCategory {
  palagai,
  sheets,
  columnBoxes,
  props,
  channelsBeams,
  other,
}

class RateCardItem {
  final String name;
  final MaterialCategory category;
  final String defaultUnit; // "ft" | "pcs" | "nos"
  final Map<int, double> rateByDays; // tier days → rate
  final double? flatRate; // for items with no day tiers

  const RateCardItem({
    required this.name,
    required this.category,
    required this.defaultUnit,
    this.rateByDays = const {},
    this.flatRate,
  });
}

// Day tiers for snapping
const List<int> _tiers = [3, 5, 10, 20, 30];

int snapToTier(int days) {
  for (final t in _tiers) {
    if (days <= t) return t;
  }
  return 30;
}

double lookupRate(String materialName, int days) {
  final item = rateCardItems.firstWhere(
    (i) => i.name == materialName,
    orElse: () => RateCardItem(
      name: '', category: MaterialCategory.other, defaultUnit: 'pcs'),
  );
  if (item.flatRate != null) return item.flatRate!;
  if (item.rateByDays.isEmpty) return 0.0;
  final tier = snapToTier(days);
  return item.rateByDays[tier] ?? item.rateByDays[_tiers.last] ?? 0.0;
}

String defaultUnit(String materialName) {
  final item = rateCardItems.firstWhere(
    (i) => i.name == materialName,
    orElse: () => RateCardItem(
      name: '', category: MaterialCategory.other, defaultUnit: 'pcs'),
  );
  return item.defaultUnit;
}

const List<RateCardItem> rateCardItems = [
  // ── PALAGAI (PLANKS) ──────────────────────────────────
  RateCardItem(
    name: '12" Palagai',
    category: MaterialCategory.palagai,
    defaultUnit: 'ft',
    rateByDays: {3: 6, 5: 7, 10: 8, 20: 10, 30: 12},
  ),
  RateCardItem(
    name: '9" Palagai',
    category: MaterialCategory.palagai,
    defaultUnit: 'ft',
    rateByDays: {3: 5, 5: 6, 10: 7, 20: 8, 30: 10},
  ),
  RateCardItem(
    name: '6" Palagai',
    category: MaterialCategory.palagai,
    defaultUnit: 'ft',
    rateByDays: {3: 4, 5: 5, 10: 6, 20: 7, 30: 8},
  ),
  RateCardItem(
    name: 'Runner',
    category: MaterialCategory.palagai,
    defaultUnit: 'ft',
    rateByDays: {3: 4, 5: 5, 10: 6, 20: 7, 30: 8},
  ),

  // ── SHEETS ────────────────────────────────────────────
  RateCardItem(
    name: 'Centring Sheet 3x2',
    category: MaterialCategory.sheets,
    defaultUnit: 'pcs',
    rateByDays: {3: 20, 5: 20, 10: 20, 20: 25, 30: 30},
  ),
  RateCardItem(
    name: 'Sheet 2ft Adjustable (up to 15")',
    category: MaterialCategory.sheets,
    defaultUnit: 'pcs',
    flatRate: 30,
  ),
  RateCardItem(
    name: 'Sheet 2ft Adjustable (up to 39")',
    category: MaterialCategory.sheets,
    defaultUnit: 'pcs',
    flatRate: 70,
  ),

  // ── COLUMN BOXES ──────────────────────────────────────
  RateCardItem(
    name: 'Round Box 9"x9"',
    category: MaterialCategory.columnBoxes,
    defaultUnit: 'pcs',
    flatRate: 200,
  ),
  RateCardItem(
    name: 'Round Box 12"x12"',
    category: MaterialCategory.columnBoxes,
    defaultUnit: 'pcs',
    flatRate: 300,
  ),
  RateCardItem(
    name: 'Round Box 18"x18"',
    category: MaterialCategory.columnBoxes,
    defaultUnit: 'pcs',
    flatRate: 500,
  ),
  RateCardItem(
    name: 'Round Box 24"x24"',
    category: MaterialCategory.columnBoxes,
    defaultUnit: 'pcs',
    flatRate: 650,
  ),
  RateCardItem(
    name: 'Round Box 36"x36"',
    category: MaterialCategory.columnBoxes,
    defaultUnit: 'pcs',
    flatRate: 1000,
  ),

  // ── PROPS ─────────────────────────────────────────────
  RateCardItem(
    name: 'MS Props 10ft/12ft',
    category: MaterialCategory.props,
    defaultUnit: 'nos',
    flatRate: 40,
  ),
  RateCardItem(
    name: 'MS Props 15ft',
    category: MaterialCategory.props,
    defaultUnit: 'nos',
    flatRate: 60,
  ),
  RateCardItem(
    name: 'Props Jockey 2m',
    category: MaterialCategory.props,
    defaultUnit: 'nos',
    rateByDays: {3: 55, 5: 55, 10: 55, 20: 55, 30: 60},
  ),
  RateCardItem(
    name: 'Props Jockey 2.5m',
    category: MaterialCategory.props,
    defaultUnit: 'nos',
    rateByDays: {3: 85, 5: 85, 10: 85, 20: 85, 30: 90},
  ),
  RateCardItem(
    name: 'Props Jockey 3m',
    category: MaterialCategory.props,
    defaultUnit: 'nos',
    rateByDays: {3: 95, 5: 95, 10: 95, 20: 95, 30: 100},
  ),
  RateCardItem(
    name: 'Span 2.5m+2.5m',
    category: MaterialCategory.props,
    defaultUnit: 'nos',
    flatRate: 60,
  ),
  RateCardItem(
    name: 'Span 2.0m+2.0m',
    category: MaterialCategory.props,
    defaultUnit: 'nos',
    flatRate: 50,
  ),

  // ── CHANNELS & BEAMS ──────────────────────────────────
  RateCardItem(
    name: 'Chanal 10ft',
    category: MaterialCategory.channelsBeams,
    defaultUnit: 'nos',
    flatRate: 30,
  ),
  RateCardItem(
    name: 'Chanal 8ft',
    category: MaterialCategory.channelsBeams,
    defaultUnit: 'nos',
    flatRate: 25,
  ),
  RateCardItem(
    name: 'Chanal 6ft',
    category: MaterialCategory.channelsBeams,
    defaultUnit: 'nos',
    flatRate: 20,
  ),
  RateCardItem(
    name: 'Chanal 4ft',
    category: MaterialCategory.channelsBeams,
    defaultUnit: 'nos',
    flatRate: 15,
  ),
  RateCardItem(
    name: 'H-Bem 10ft',
    category: MaterialCategory.channelsBeams,
    defaultUnit: 'nos',
    flatRate: 50,
  ),
  RateCardItem(
    name: 'H-Bem 8ft',
    category: MaterialCategory.channelsBeams,
    defaultUnit: 'nos',
    flatRate: 40,
  ),
  RateCardItem(
    name: 'H-Bem 6ft',
    category: MaterialCategory.channelsBeams,
    defaultUnit: 'nos',
    flatRate: 30,
  ),
  RateCardItem(
    name: 'H-Bem 4ft',
    category: MaterialCategory.channelsBeams,
    defaultUnit: 'nos',
    flatRate: 20,
  ),

  // ── OTHER ─────────────────────────────────────────────
  RateCardItem(
    name: 'MS Plate 2ft x 3ft',
    category: MaterialCategory.other,
    defaultUnit: 'pcs',
    flatRate: 45,
  ),
  RateCardItem(
    name: 'MS Plate 1.5ft x 3ft',
    category: MaterialCategory.other,
    defaultUnit: 'pcs',
    flatRate: 40,
  ),
  RateCardItem(
    name: 'MS Plate 1ft x 3ft',
    category: MaterialCategory.other,
    defaultUnit: 'pcs',
    flatRate: 35,
  ),
  RateCardItem(
    name: 'Auger 12"',
    category: MaterialCategory.other,
    defaultUnit: 'nos',
    flatRate: 300,
  ),
  RateCardItem(
    name: 'Auger 9"',
    category: MaterialCategory.other,
    defaultUnit: 'nos',
    flatRate: 200,
  ),
  RateCardItem(
    name: 'Auger 6"',
    category: MaterialCategory.other,
    defaultUnit: 'nos',
    flatRate: 150,
  ),
];

/// Items grouped by category for the dropdown
Map<MaterialCategory, List<RateCardItem>> get rateCardByCategory {
  final map = <MaterialCategory, List<RateCardItem>>{};
  for (final item in rateCardItems) {
    map.putIfAbsent(item.category, () => []).add(item);
  }
  return map;
}

String categoryLabel(MaterialCategory cat) {
  switch (cat) {
    case MaterialCategory.palagai: return 'Palagai (Planks)';
    case MaterialCategory.sheets: return 'Centring Sheets';
    case MaterialCategory.columnBoxes: return 'Column Boxes';
    case MaterialCategory.props: return 'Props & Support';
    case MaterialCategory.channelsBeams: return 'Channels & Beams';
    case MaterialCategory.other: return 'Other';
  }
}
```

- [ ] **Step 2: Verify no analysis errors**

```powershell
flutter analyze lib/data/rate_card.dart
```
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```powershell
git add lib/data/rate_card.dart
git commit -m "feat: add rate card lookup table from PD NEW RATE CARD PDF"
```

---

### Task 4: Create RateCardPickerRow widget

**Files:**
- Create: `lib/widgets/rate_card_picker.dart`

- [ ] **Step 1: Create the widget file**

Create `lib/widgets/rate_card_picker.dart` with this complete implementation:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/rate_card.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class _MatEntry {
  String name;
  int? days;
  double quantity;
  String unit;
  double rate;

  _MatEntry({
    this.name = '',
    this.days,
    this.quantity = 0.0,
    this.unit = 'pcs',
    this.rate = 0.0,
  });

  double get amount => quantity * rate;
}
```

> **Note:** Export `_MatEntry` from this file as `MatEntry` (public) so `new_bill.dart` can use it:
> `class MatEntry { ... }` (no underscore prefix)

- [ ] **Step 2: Add dropdown + row widget**

In the same file, add `RateCardPickerRow`:

```dart
class RateCardPickerRow extends StatefulWidget {
  final MatEntry entry;
  final int rentalDays;  // from bill date → due date
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final int index;

  const RateCardPickerRow({
    super.key,
    required this.entry,
    required this.rentalDays,
    required this.onChanged,
    required this.onRemove,
    required this.index,
  });

  @override
  State<RateCardPickerRow> createState() => _RateCardPickerRowState();
}

class _RateCardPickerRowState extends State<RateCardPickerRow> {
  late TextEditingController _rateCtrl;
  late TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _rateCtrl = TextEditingController(
        text: widget.entry.rate > 0 ? widget.entry.rate.toStringAsFixed(2) : '');
    _qtyCtrl = TextEditingController(
        text: widget.entry.quantity > 0 ? widget.entry.quantity.toString() : '');
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _onMaterialSelected(String name) {
    final rate = lookupRate(name, widget.rentalDays);
    final unit = defaultUnit(name);
    setState(() {
      widget.entry.name = name;
      widget.entry.rate = rate;
      widget.entry.unit = unit;
      _rateCtrl.text = rate > 0 ? rate.toStringAsFixed(2) : '';
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = 'Material ${String.fromCharCode(65 + widget.index)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border, width: 0.5),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: colors.glow, blurRadius: 16, offset: const Offset(0, 4))
        ],
      ),
      child: Stack(children: [
        // accent bar
        Positioned(
          left: 0, top: 0, bottom: 0,
          child: Container(
            width: 4,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
              color: colors.teal,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Row header
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(label,
                style: jakarta(context, size: 10, weight: FontWeight.w800, color: colors.textMain)
                    .copyWith(letterSpacing: 2)),
              GestureDetector(
                onTap: widget.onRemove,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFFFF4D5E).withOpacity(.15)
                        : const Color(0xFFFFF0F1),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFFFF4D5E).withOpacity(.3)
                          : const Color(0xFFFFD1D6),
                      width: 0.5),
                    borderRadius: BorderRadius.circular(12)),
                  child: Text('✕ Remove',
                    style: jakarta(context, size: 10, weight: FontWeight.w700,
                        color: const Color(0xFFFF5555))),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // Material dropdown
            _buildLabel('Material'),
            _MaterialDropdown(
              selectedName: widget.entry.name,
              onSelected: _onMaterialSelected,
              colors: colors,
            ),
            const SizedBox(height: 12),

            // Qty + Unit + Rate + Amount
            Row(children: [
              // Qty
              Expanded(
                flex: 3,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildLabel('Quantity'),
                  TextFormField(
                    controller: _qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                    style: jakarta(context, size: 13, color: colors.textMain),
                    decoration: _inputDeco(colors),
                    onChanged: (v) {
                      widget.entry.quantity = double.tryParse(v) ?? 0.0;
                      widget.onChanged();
                    },
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              // Unit
              Expanded(
                flex: 2,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildLabel('Unit'),
                  DropdownButtonFormField<String>(
                    value: widget.entry.unit,
                    decoration: _inputDeco(colors),
                    style: jakarta(context, size: 13, color: colors.textMain),
                    items: ['ft', 'pcs', 'nos'].map((u) =>
                        DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => widget.entry.unit = v);
                        widget.onChanged();
                      }
                    },
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              // Rate
              Expanded(
                flex: 3,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildLabel('Rate (₹)'),
                  TextFormField(
                    controller: _rateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                    style: jakarta(context, size: 13, color: colors.textMain),
                    decoration: _inputDeco(colors),
                    onChanged: (v) {
                      widget.entry.rate = double.tryParse(v) ?? 0.0;
                      widget.onChanged();
                    },
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 8),

            // Amount display
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '= ₹${widget.entry.amount.toStringAsFixed(2)}',
                style: jakarta(context, size: 14, weight: FontWeight.w800,
                    color: colors.teal),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text,
        style: jakarta(context, size: 10, weight: FontWeight.w700,
            color: context.appColors.textMuted).copyWith(letterSpacing: 1)),
  );

  InputDecoration _inputDeco(AppColors colors) => InputDecoration(
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
}

class _MaterialDropdown extends StatelessWidget {
  final String selectedName;
  final ValueChanged<String> onSelected;
  final AppColors colors;

  const _MaterialDropdown({
    required this.selectedName,
    required this.onSelected,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = rateCardByCategory;
    final categories = MaterialCategory.values;

    // Build flat list with section headers
    final items = <DropdownMenuItem<String>>[];
    for (final cat in categories) {
      final catItems = grouped[cat] ?? [];
      if (catItems.isEmpty) continue;
      // Section header (disabled)
      items.add(DropdownMenuItem<String>(
        enabled: false,
        value: '__$cat',
        child: Text(categoryLabel(cat),
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: colors.textMuted,
                letterSpacing: 1.5)),
      ));
      // Items
      for (final item in catItems) {
        items.add(DropdownMenuItem<String>(
          value: item.name,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(item.name,
                style: TextStyle(fontSize: 13, color: colors.textMain)),
          ),
        ));
      }
    }

    return DropdownButtonFormField<String>(
      value: selectedName.isEmpty ? null : selectedName,
      hint: Text('Select material...', style: TextStyle(color: colors.textMuted, fontSize: 13)),
      isExpanded: true,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
      ),
      items: items,
      onChanged: (v) { if (v != null && !v.startsWith('__')) onSelected(v); },
    );
  }
}
```

- [ ] **Step 3: Verify no analysis errors**

```powershell
flutter analyze lib/widgets/rate_card_picker.dart
```
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```powershell
git add lib/widgets/rate_card_picker.dart lib/data/rate_card.dart
git commit -m "feat: add RateCardPickerRow widget with material dropdown"
```

---

## Chunk 3: New Bill Screen + Invoice Service

### Task 5: Update new_bill.dart

**Files:**
- Modify: `lib/screens/new_bill.dart`

- [ ] **Step 1: Update `_MatEntry` to use public `MatEntry` from rate_card_picker.dart**

At the top of `new_bill.dart`, replace the local `_MatEntry` class definition with an import:

```dart
import '../widgets/rate_card_picker.dart';
```

Remove the old `class _MatEntry { ... }` definition (lines 13–17).

- [ ] **Step 2: Update `_mats` type and usage**

Change all `_MatEntry` references to `MatEntry`. In `_save()`, update the material mapping to include new fields:

```dart
materials: _mats
    .map((m) => RentalMaterial(
          name: m.name,
          days: m.days!,
          dueDate: _baseDate.add(Duration(days: m.days!)),
          quantity: m.quantity,   // NEW
          unit: m.unit,           // NEW
          rate: m.rate,           // NEW
        ))
    .toList(),
```

Also add the new Bill fields in `_save()`:
```dart
final newBill = Bill(
  // existing fields ...
  vehicleChargeUp: double.tryParse(_vehicleUpCtrl.text) ?? 0.0,    // NEW
  vehicleChargeDown: double.tryParse(_vehicleDownCtrl.text) ?? 0.0, // NEW
  advancePaid: double.tryParse(_advanceCtrl.text) ?? 0.0,           // NEW
  materials: ...,
);
```

- [ ] **Step 3: Add 3 new TextEditingControllers**

In `_NewBillScreenState`, add:
```dart
final _vehicleUpCtrl = TextEditingController();
final _vehicleDownCtrl = TextEditingController();
final _advanceCtrl = TextEditingController();
```

In `initState()`, if editing an existing bill, populate them:
```dart
_vehicleUpCtrl.text = b.vehicleChargeUp > 0 ? b.vehicleChargeUp.toString() : '';
_vehicleDownCtrl.text = b.vehicleChargeDown > 0 ? b.vehicleChargeDown.toString() : '';
_advanceCtrl.text = b.advancePaid > 0 ? b.advancePaid.toString() : '';
```

In `dispose()`, add:
```dart
_vehicleUpCtrl.dispose();
_vehicleDownCtrl.dispose();
_advanceCtrl.dispose();
```

- [ ] **Step 4: Replace material entry UI with `RateCardPickerRow`**

In the `build` method, replace the existing `..._mats.asMap().entries.map((e) { ... })` block with:

```dart
..._mats.asMap().entries.map((e) {
  final i = e.key;
  final m = e.value;
  return RateCardPickerRow(
    key: ValueKey(i),
    entry: m,
    rentalDays: _mats.isNotEmpty && m.days != null ? m.days! : 30,
    onChanged: () => setState(() {}),
    onRemove: () => setState(() => _mats.removeAt(i)),
    index: i,
  );
}).toList(),
```

- [ ] **Step 5: Add Financial Summary section below materials list**

After the materials list in the `build` method, add:

```dart
const SizedBox(height: 24),
SectionHeader('FINANCIAL SUMMARY', action: null, onAction: null),
const SizedBox(height: 12),
// Vehicle charges
Row(children: [
  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _Label('Vehicle UP (₹)'),
    _Field(hint: '0', colors: colors, controller: _vehicleUpCtrl,
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() {})),
  ])),
  const SizedBox(width: 12),
  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _Label('Vehicle DOWN (₹)'),
    _Field(hint: '0', colors: colors, controller: _vehicleDownCtrl,
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() {})),
  ])),
]),
const SizedBox(height: 12),
_Field(hint: 'Advance Paid (₹)', colors: colors, controller: _advanceCtrl,
    keyboardType: TextInputType.number,
    onChanged: (_) => setState(() {})),
const SizedBox(height: 16),
// Totals display
_FinancialSummaryCard(
  rentTotal: _mats.fold(0.0, (s, m) => s + m.amount),
  vehicleUp: double.tryParse(_vehicleUpCtrl.text) ?? 0.0,
  vehicleDown: double.tryParse(_vehicleDownCtrl.text) ?? 0.0,
  advancePaid: double.tryParse(_advanceCtrl.text) ?? 0.0,
  colors: colors,
),
```

- [ ] **Step 6: Add `_FinancialSummaryCard` widget at bottom of file**

```dart
class _FinancialSummaryCard extends StatelessWidget {
  final double rentTotal, vehicleUp, vehicleDown, advancePaid;
  final AppColors colors;
  const _FinancialSummaryCard({
    required this.rentTotal, required this.vehicleUp,
    required this.vehicleDown, required this.advancePaid,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final grand = rentTotal + vehicleUp + vehicleDown;
    final balance = grand - advancePaid;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        border: Border.all(color: colors.border, width: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        _Row('Rent Total (வாடகை)', rentTotal, colors, context),
        _Row('Vehicle UP', vehicleUp, colors, context),
        _Row('Vehicle DOWN', vehicleDown, colors, context),
        const Divider(height: 16),
        _Row('Grand Total', grand, colors, context, bold: true),
        _Row('Advance Paid', advancePaid, colors, context),
        _Row('Balance Due', balance, colors, context,
            bold: true, highlight: true),
      ]),
    );
  }

  Widget _Row(String label, double amount, AppColors colors,
      BuildContext context, {bool bold = false, bool highlight = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: jakarta(context,
            size: 12, weight: bold ? FontWeight.w800 : FontWeight.w500,
            color: colors.textSub)),
        Text('₹${amount.toStringAsFixed(2)}',
            style: jakarta(context, size: 13,
                weight: bold ? FontWeight.w900 : FontWeight.w600,
                color: highlight
                    ? const Color(0xFFFF6B35)
                    : bold ? colors.textMain : colors.textSub)),
      ]),
    );
}
```

- [ ] **Step 7: Verify no analysis errors**

```powershell
flutter analyze lib/screens/new_bill.dart
```
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```powershell
git add lib/screens/new_bill.dart
git commit -m "feat: integrate RateCardPicker and financial summary in new bill screen"
```

---

### Task 6: Create InvoiceService

**Files:**
- Create: `lib/services/invoice_service.dart`

- [ ] **Step 1: Create invoice_service.dart**

```dart
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/bill.dart';
import '../models/customer.dart';

class InvoiceService {
  static Future<Uint8List> buildPdf(Bill bill, Customer? customer) async {
    final pdf = pw.Document();

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => _buildPage(ctx, bill, customer),
    ));

    return pdf.save();
  }

  static pw.Widget _buildPage(
      pw.Context ctx, Bill bill, Customer? customer) {
    final headerStyle = pw.TextStyle(
        fontSize: 10, fontWeight: pw.FontWeight.bold);
    final labelStyle = pw.TextStyle(fontSize: 9, color: PdfColors.grey700);
    final valueStyle = pw.TextStyle(fontSize: 10);

    // Header block
    final headerBlock = pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
          pw.Text('Bill No: ${bill.billNumber}', style: headerStyle),
          pw.Text('Date: ${bill.billDateFormatted}', style: headerStyle),
        ]),
        pw.SizedBox(height: 4),
        pw.Text(
          'Return Date: ${bill.materials.isNotEmpty ? bill.materials.first.dueDateFormatted : "-"}',
          style: labelStyle),
        pw.SizedBox(height: 4),
        pw.Text('Customer: ${bill.customerName}', style: valueStyle),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Site: ${bill.site}', style: valueStyle),
          pw.Text('Vehicle: PD', style: valueStyle),
        ]),
      ]),
    );

    // Table header
    final tableHeader = pw.Container(
      color: const PdfColor.fromInt(0xFF1A237E),
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: pw.Row(children: [
        _cell('S.No', 1, isHeader: true),
        _cell('Description', 5, isHeader: true),
        _cell('Qty', 2, isHeader: true),
        _cell('Unit', 2, isHeader: true),
        _cell('Rate (₹)', 2, isHeader: true),
        _cell('Amount (₹)', 2, isHeader: true),
      ]),
    );

    // Table rows
    final rows = <pw.Widget>[];
    for (var i = 0; i < bill.materials.length; i++) {
      final m = bill.materials[i];
      final bg = i.isEven ? PdfColors.grey100 : PdfColors.white;
      rows.add(pw.Container(
        color: bg,
        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        child: pw.Row(children: [
          _cell('${i + 1}', 1),
          _cell(m.name, 5),
          _cell(m.quantity.toStringAsFixed(2), 2),
          _cell(m.unit, 2),
          _cell(m.rate.toStringAsFixed(2), 2),
          _cell(m.amount.toStringAsFixed(2), 2),
        ]),
      ));
    }

    // Totals
    final totals = pw.Container(
      alignment: pw.Alignment.centerRight,
      padding: const pw.EdgeInsets.only(top: 12),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        _totalRow('Rent Total (வாடகை)', bill.rentTotal),
        _totalRow('Vehicle Charge UP (UP வண்டிதொகை)', bill.vehicleChargeUp),
        _totalRow('Vehicle Charge DOWN (DOWN வண்டிதொகை)', bill.vehicleChargeDown),
        pw.Divider(),
        _totalRow('Grand Total', bill.grandTotal, bold: true),
        _totalRow('Advance Paid', bill.advancePaid),
        _totalRow('Balance Due', bill.balanceDue,
            bold: true, color: PdfColors.orange),
      ]),
    );

    // Signature
    final footer = pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
      pw.Column(children: [
        pw.SizedBox(height: 32),
        pw.Container(width: 120, height: 0.5, color: PdfColors.black),
        pw.Text('Signature', style: pw.TextStyle(fontSize: 9)),
      ]),
    ]);

    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      headerBlock,
      pw.SizedBox(height: 12),
      tableHeader,
      ...rows,
      totals,
      pw.SizedBox(height: 24),
      footer,
    ]);
  }

  static pw.Widget _cell(String text, int flex, {bool isHeader = false}) =>
    pw.Expanded(
      flex: flex,
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 9,
              fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isHeader ? PdfColors.white : PdfColors.black)),
    );

  static pw.Widget _totalRow(String label, double amount,
      {bool bold = false, PdfColor? color}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
        pw.Text('$label:  ',
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text('₹${amount.toStringAsFixed(2)}',
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: color)),
      ]),
    );

  /// Share PDF via system share sheet (WhatsApp, email, etc.)
  static Future<void> sharePdf(Bill bill, Customer? customer) async {
    final bytes = await buildPdf(bill, customer);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Invoice_${bill.billNumber.replaceAll(' ', '_')}.pdf',
    );
  }

  /// Open system print dialog
  static Future<void> printPdf(Bill bill, Customer? customer) async {
    await Printing.layoutPdf(
      onLayout: (_) => buildPdf(bill, customer),
      name: 'Invoice_${bill.billNumber}',
    );
  }
}
```

- [ ] **Step 2: Verify no analysis errors**

```powershell
flutter analyze lib/services/invoice_service.dart
```
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```powershell
git add lib/services/invoice_service.dart
git commit -m "feat: add InvoiceService with PDF generation, share, and print"
```

---

### Task 7: Update bill_detail.dart — add Share + Print buttons + totals

**Files:**
- Modify: `lib/screens/bill_detail.dart`

- [ ] **Step 1: Import InvoiceService**

Add at top of `bill_detail.dart`:
```dart
import '../services/invoice_service.dart';
```

- [ ] **Step 2: Add _generateInvoice helper method**

In the state class, add:
```dart
Future<void> _shareInvoice(Bill bill, Customer? customer) async {
  try {
    await InvoiceService.sharePdf(bill, customer);
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate invoice: $e'),
            backgroundColor: const Color(0xFFFF5555)));
    }
  }
}

Future<void> _printInvoice(Bill bill, Customer? customer) async {
  try {
    await InvoiceService.printPdf(bill, customer);
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to print invoice: $e'),
            backgroundColor: const Color(0xFFFF5555)));
    }
  }
}
```

- [ ] **Step 3: Add Share + Print buttons to the action bar**

Locate the existing action buttons area (edit button) and add alongside:

```dart
// Share button
GestureDetector(
  onTap: () => _shareInvoice(bill, customer),
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: colors.teal.withOpacity(0.12),
      border: Border.all(color: colors.teal.withOpacity(0.3), width: 0.5),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.share_rounded, size: 14, color: colors.teal),
      const SizedBox(width: 6),
      Text('Share', style: jakarta(context, size: 12,
          weight: FontWeight.w700, color: colors.teal)),
    ]),
  ),
),
const SizedBox(width: 8),
// Print button
GestureDetector(
  onTap: () => _printInvoice(bill, customer),
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: colors.brand.withOpacity(0.12),
      border: Border.all(color: colors.brand.withOpacity(0.3), width: 0.5),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.print_rounded, size: 14, color: colors.brand),
      const SizedBox(width: 6),
      Text('Print', style: jakarta(context, size: 12,
          weight: FontWeight.w700, color: colors.brand)),
    ]),
  ),
),
```

- [ ] **Step 4: Add financial summary card below materials list**

After the materials list section, add:

```dart
if (bill.grandTotal > 0) ...[
  const SizedBox(height: 16),
  Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: colors.surfaceVariant,
      border: Border.all(color: colors.border, width: 0.5),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(children: [
      _summaryRow('Rent Total (வாடகை)', bill.rentTotal, colors, context),
      if (bill.vehicleChargeUp > 0)
        _summaryRow('Vehicle UP (UP வண்டிதொகை)', bill.vehicleChargeUp, colors, context),
      if (bill.vehicleChargeDown > 0)
        _summaryRow('Vehicle DOWN', bill.vehicleChargeDown, colors, context),
      const Divider(height: 16),
      _summaryRow('Grand Total', bill.grandTotal, colors, context, bold: true),
      if (bill.advancePaid > 0)
        _summaryRow('Advance Paid', bill.advancePaid, colors, context),
      _summaryRow('Balance Due', bill.balanceDue, colors, context,
          bold: true, highlight: true),
    ]),
  ),
],
```

Add the helper method at bottom of file:
```dart
Widget _summaryRow(String label, double amount, AppColors colors,
    BuildContext context, {bool bold = false, bool highlight = false}) =>
  Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: jakarta(context,
          size: 12, weight: bold ? FontWeight.w800 : FontWeight.w500,
          color: colors.textSub)),
      Text('₹${amount.toStringAsFixed(2)}',
          style: jakarta(context, size: 13,
              weight: bold ? FontWeight.w900 : FontWeight.w600,
              color: highlight ? const Color(0xFFFF6B35)
                  : bold ? colors.textMain : colors.textSub)),
    ]),
  );
```

- [ ] **Step 5: Verify no analysis errors**

```powershell
flutter analyze lib/screens/bill_detail.dart
```
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```powershell
git add lib/screens/bill_detail.dart
git commit -m "feat: add Share/Print invoice buttons and financial summary to bill detail"
```

---

## Chunk 4: Full Verification + Final Commit

### Task 8: Full verification

- [ ] **Step 1: Run full analyze**

```powershell
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 2: Build debug APK**

```powershell
flutter build apk --debug
```
Expected: `Build APK(s) done` with no errors.

- [ ] **Step 3: Manual smoke test on device/emulator**

1. Open app → New Bill
2. Add material → select "12\" Palagai" from dropdown → set days to 30 → verify rate auto-fills ₹12.00
3. Enter Qty: 24 ft → verify Amount shows ₹288.00
4. Add Vehicle UP: ₹750 → verify Grand Total = Rent Total + 750
5. Save bill → open it in Bill Detail → verify financial summary shows correct totals
6. Tap **Share** → verify PDF opens in share sheet with correct layout
7. Verify old bills (no pricing) still open without error

- [ ] **Step 4: Final commit + push**

```powershell
git add -A
git commit -m "feat: complete invoice generation with rate card, PDF share and print"
git push mobile master
```
