# Invoice Generation — Design Spec

**Date:** 2026-03-13  
**Feature:** Invoice generation from the PD Rate Card, with PDF share and print

---

## Background

The PD Centring app tracks rental bills but has no pricing or invoice generation. The business uses a physical rate card (PD NEW RATE CARD, 5 pages) and generates handwritten invoices. The Vijayalashmi Constructions.1948SD PDF is the reference sample invoice.

**Goal:** Allow users to create a bill with itemized pricing from the rate card, and generate a PDF invoice that can be shared via WhatsApp/email or printed.

---

## Decisions Made

| Question | Decision |
|----------|----------|
| Invoice header | Match reference PDF exactly — bill details block only (Bill No, Date, Return Date, Customer, Site, Vehicle) |
| Rate entry | Full rate card picker dropdown — user selects material, rate auto-fills |
| Rate tier snapping | Snap to nearest tier (e.g. 25 days → 30-day rate), user can override |
| Vehicle charges | UP trip + DOWN trip + Advance Paid → Balance Due auto-computed |
| Invoice delivery | Both: Share PDF (WhatsApp/email) AND Print button |
| Approach | C — `RateCardPicker` widget extracted to own file; `InvoiceService` for PDF |

---

## Architecture

### New Files

| File | Responsibility |
|------|---------------|
| `lib/data/rate_card.dart` | Const rate lookup table; `lookupRate(name, days)` helper |
| `lib/widgets/rate_card_picker.dart` | Single material row widget: dropdown + qty + unit + rate (editable) + amount |
| `lib/services/invoice_service.dart` | PDF generation using `pdf` package; share via `printing` package |

### Modified Files

| File | Changes |
|------|---------|
| `lib/models/bill.dart` | Add `quantity`, `unit`, `rate` to `RentalMaterial`; add `vehicleChargeUp`, `vehicleChargeDown`, `advancePaid` to `Bill`; add computed getters |
| `lib/screens/new_bill.dart` | Replace material entry section with `RateCardPicker` widget; add financial summary section |
| `lib/screens/bill_detail.dart` | Add 🖨 Print and 📤 Share buttons; show financial totals |
| `pubspec.yaml` | Add `pdf: ^3.10.8` and `printing: ^5.12.0` |

---

## Data Model

### `RentalMaterial` — new fields

```dart
double quantity;  // e.g. 24.0
String unit;      // "ft" | "pcs" | "nos"
double rate;      // per unit, from rate card (user-editable)

double get amount => quantity * rate;
```

Defaults: `quantity = 0.0`, `unit = "pcs"`, `rate = 0.0`  
Backward compatible — missing fields default to 0.0 in `fromJson`.

### `Bill` — new fields

```dart
double vehicleChargeUp;    // UP trip charge
double vehicleChargeDown;  // DOWN/return trip charge  
double advancePaid;        // advance received

double get rentTotal  => materials.fold(0.0, (s, m) => s + m.amount);
double get grandTotal => rentTotal + vehicleChargeUp + vehicleChargeDown;
double get balanceDue => grandTotal - advancePaid;
```

Defaults: all `0.0`. Missing from Firestore → defaults to 0.

---

## Rate Card Data (`lib/data/rate_card.dart`)

Full const lookup table for all materials from the PD NEW RATE CARD PDF.

### Material Categories

**Palagai (Planks):**
- 12" Palagai: 3D=₹6, 5D=₹7, 10D=₹8, 20D=₹10, 30D=₹12 (per ft)
- 9" Palagai: 3D=₹5, 5D=₹6, 10D=₹7, 20D=₹8, 30D=₹10 (per ft)
- 6" Palagai: per ft (standard rate)
- Runner: per ft

**Sheets:**
- Centring Sheet 3×2: 3D=₹20, 5D=₹20, 10D=₹20, 20D=₹25, 30D=₹30 (per pcs)
- Column/Beam Sheets: per piece by width×length dimension

**Column Boxes:**
- Round Box: 9"×9" to 36"×36" (per pcs by size)
- Adjustable Sheet 2ft

**Props & Support:**
- MS Props: 10ft/12ft=₹40, 15ft=₹60 (per nos)
- Props Jockey 2m: 20D=₹55, 30D=₹60
- Props Jockey 2.5m: 20D=₹85, 30D=₹90
- Props Jockey 3m: 20D=₹95, 30D=₹100
- Span 2.5m+2.5m=₹60, 2.0m+2.0m=₹50

**Channels & Beams:**
- Chanal: 10ft=₹30, 8ft=₹25, 6ft=₹20, 4ft=₹15
- H-Bem: 10ft=₹50, 8ft=₹40, 6ft=₹30, 4ft=₹20

**Other:**
- MS Plate: 2ft×3ft=₹45, 1.5ft×3ft=₹40, 1ft×3ft=₹35
- Auger 12"=₹300/day, 9"=₹200/day, 6"=₹150/day

### `lookupRate()` function

```dart
double lookupRate(String materialName, int days) {
  // Find material in table
  // Snap days to nearest tier: [3, 5, 10, 20, 30]
  // Return rate, or 0.0 if not found
}
```

Tier snapping: 1-3→3, 4-5→5, 6-10→10, 11-20→20, 21+→30

---

## Rate Card Picker Widget (`lib/widgets/rate_card_picker.dart`)

### `RateCardPickerRow` widget

**Inputs:** `_MatEntry` mutable object, `int rentalDays`, `VoidCallback onChanged`, `VoidCallback onRemove`

**UI Layout per row:**
```
Material A                                    [✕ Remove]
[Dropdown: 12" Palagai ▼]         [30] days
Qty: [24.0]  Unit: [ft ▼]   Rate: ₹[12.00]  = ₹288.00
```

- Material dropdown groups items under section headers: Palagai, Sheets, Column Boxes, Props, Channels & Beams, Other
- On material select: call `lookupRate(name, days)` → populate rate field
- Rate field is a `TextFormField` — editable by user
- Amount (`qty × rate`) shown as read-only computed label
- Unit dropdown: ft / pcs / nos

### `_MatEntry` model extension

```dart
class _MatEntry {
  String name;
  int? days;
  double quantity;  // NEW
  String unit;      // NEW
  double rate;      // NEW
  double get amount => quantity * rate;
}
```

---

## New Bill Screen Changes (`lib/screens/new_bill.dart`)

1. Replace the existing freeform material autocomplete rows with `RateCardPickerRow` widgets
2. Pass `_baseDate` duration to rows so rate tier auto-updates when date changes
3. Add **Financial Summary** section below materials:
   - Rent Total (auto, read-only)
   - Vehicle Charge UP (TextField, optional)
   - Vehicle Charge DOWN (TextField, optional)
   - Grand Total (auto, read-only)
   - Advance Paid (TextField, optional)  
   - Balance Due (auto, orange/red highlight)
4. On save: map `_MatEntry` → `RentalMaterial` with all new fields; map financial fields → `Bill`

---

## Invoice Service (`lib/services/invoice_service.dart`)

### Interface

```dart
class InvoiceService {
  /// Generate PDF bytes from a Bill + Customer
  static Future<Uint8List> buildPdf(Bill bill, Customer? customer) async { ... }

  /// Share PDF via device share sheet (WhatsApp, email, etc.)
  static Future<void> sharePdf(Bill bill, Customer? customer) async { ... }

  /// Open system print dialog
  static Future<void> printPdf(Bill bill, Customer? customer) async { ... }
}
```

### PDF Layout (matches reference invoice)

**Header block:**
```
Bill No: 1948               Date: 01-04-2022
Return Date: 30-04-2022
Customer: Vijayalashmi Constructions (Murali)
Site: Thoribakkam                Vehicle: PD
```

**Items table:**
`S.No | Description | Qty | Unit | Rate (₹) | Amount (₹)`  
Alternating light grey / white rows. Navy blue header row.

**Totals block (right-aligned):**
```
Rent Total (வாடகை):              ₹3,201.00
Vehicle Charge UP (UP வண்டிதொகை): ₹750.00
Vehicle Charge DOWN:              ₹0.00
Grand Total:                      ₹3,951.00
Advance Paid:                     ₹0.00
Balance Due:                      ₹3,951.00  ← red/orange
```

**Footer:** Signature line on right.

### Dependencies

```yaml
# pubspec.yaml
pdf: ^3.10.8
printing: ^5.12.0
```

---

## Bill Detail Screen Changes (`lib/screens/bill_detail.dart`)

1. Add action buttons in header row:
   - **📤 Share** → `InvoiceService.sharePdf(bill, customer)`
   - **🖨 Print** → `InvoiceService.printPdf(bill, customer)`
2. Show financial summary card below materials list:
   - Rent Total, Vehicle UP, Vehicle DOWN, Grand Total, Advance Paid, Balance Due

---

## Error Handling

- If `buildPdf` fails → show `SnackBar` with error message
- If no materials have quantities/rates → show warning before generating (prevent ₹0 invoices)
- If `printing` package unavailable on platform → hide Print button, show only Share

---

## Out of Scope

- GST calculation (not in reference invoice, excluded per YAGNI)
- Column/Beam sheet dimension picker UI (too complex for v1; user enters as free-form with manual rate)
- Invoice numbering separate from bill numbering
- Storing generated PDF in Firestore

---

## Verification Plan

1. Add a new bill with "12\" Palagai", 30 days → verify rate auto-fills ₹12
2. Set quantity 24 ft → verify amount shows ₹288
3. Add Vehicle UP ₹750 → verify Grand Total = Rent Total + 750
4. Tap Share → verify PDF opens in share sheet
5. Verify existing bills with no pricing data still open without errors
6. Run `flutter analyze` → 0 errors
7. Run `flutter build apk --debug` → successful build
