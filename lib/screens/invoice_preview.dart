import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/bill.dart';
import '../theme/app_theme.dart';

class InvoicePreviewSheet extends StatelessWidget {
  final Bill bill;
  final VoidCallback onConfirm;
  final bool isSaving;

  const InvoicePreviewSheet({
    super.key,
    required this.bill,
    required this.onConfirm,
    this.isSaving = false,
  });

  static String _fmtDate(DateTime d) {
    const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${mo[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBill = bill.type == BillType.bill;
    final accentColor = isBill ? colors.teal : colors.brand;

    // Totals
    final mRent = bill.materials.fold(0.0, (s, m) => s + m.amount);
    final cbRent = bill.columnBoxes.fold(0.0, (s, b) => s + b.totalAmount);
    final rbRent = bill.roundBoxes.fold(0.0, (s, b) => s + b.totalAmount);
    final ssTotalSqft = bill.sideSheets.fold(0.0, (s, e) => s + e.sqft);
    final ssRent = bill.sideSheets.fold(0.0, (s, e) => s + e.amount);
    
    final palagaiRent = bill.palagai.fold(0.0, (s, p) => s + p.amount);
    final muttuRent = bill.muttu.fold(0.0, (s, m) => s + m.amount);
    final roofRent = bill.roofItems.fold(0.0, (s, r) => s + r.amount);

    final rentTotal = mRent + cbRent + rbRent + ssRent + palagaiRent + muttuRent + roofRent;
    final grandTotal = rentTotal + bill.vehicleChargeUp + bill.vehicleChargeDown + bill.labourChargeUp + bill.labourChargeDown;
    final balanceDue = grandTotal - bill.advancePaid;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
                color: colors.border, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 8),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Invoice Preview',
                    style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: colors.textMain)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accentColor.withOpacity(0.3), width: 0.5),
                  ),
                  child: Text(isBill ? 'BILL' : 'DC',
                      style: jakarta(context,
                              size: 11, weight: FontWeight.w800, color: accentColor)
                          .copyWith(letterSpacing: 2)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5),
          // Scrollable content
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              children: [
                // Bill info card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [const Color(0xFF14224A), const Color(0xFF0A1628)]
                          : [const Color(0xFF14224A), const Color(0xFF1E2E44)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(bill.billNumber,
                        style: jakarta(context,
                                size: 10,
                                weight: FontWeight.w800,
                                color: Colors.white.withOpacity(0.4))
                            .copyWith(letterSpacing: 2.5)),
                    const SizedBox(height: 8),
                    Text(bill.customerName,
                        style: GoogleFonts.playfairDisplay(
                            fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('📍 ${bill.site}  ·  ${_fmtDate(bill.billDate)}',
                        style: jakarta(context,
                            size: 12, color: Colors.white.withOpacity(0.6))),
                    if (bill.dueDate != null) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: bill.isOverdue
                                ? const Color(0xFFFF4D5E).withOpacity(0.25)
                                : Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.schedule_rounded,
                                size: 12,
                                color: bill.isOverdue
                                    ? const Color(0xFFFF8A97)
                                    : Colors.white.withOpacity(0.7)),
                            const SizedBox(width: 5),
                            Text(
                              bill.isOverdue
                                  ? 'Overdue ${bill.overdueDays}d · Due ${bill.dueDateFormatted}'
                                  : 'Due: ${bill.dueDateFormatted}',
                              style: jakarta(context,
                                  size: 11,
                                  weight: FontWeight.w700,
                                  color: bill.isOverdue
                                      ? const Color(0xFFFF8A97)
                                      : Colors.white.withOpacity(0.8)),
                            ),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Start: ${_fmtDate(bill.billDate)}',
                            style: jakarta(context,
                                size: 11,
                                color: Colors.white.withOpacity(0.6)),
                          ),
                        ),
                      ]),
                    ],
                  ]),
                ),
                const SizedBox(height: 20),

                // Column Boxes
                if (bill.columnBoxes.isNotEmpty) ...[
                  _PreviewSection(
                    title: 'COLUMN BOXES',
                    color: colors.brand,
                    colors: colors,
                    context: context,
                    rows: bill.columnBoxes.expand((b) {
                      final rows = b.heightRows.map((r) =>
                          _PreviewRow('${b.sizeKey} · ${r.heightFt}ft × ${r.qty}pcs',
                              '₹${r.amount.toStringAsFixed(0)}'));
                      final shoeRows = b.shoe != null
                          ? [_PreviewRow('${b.sizeKey} · Shoe × ${b.shoe!.qty}pcs',
                              '₹${b.shoe!.amount.toStringAsFixed(0)}')]
                          : <_PreviewRow>[];
                      return [...rows, ...shoeRows];
                    }).toList(),
                    total: cbRent,
                  ),
                  const SizedBox(height: 12),
                ],

                // Round Boxes
                if (bill.roundBoxes.isNotEmpty) ...[
                  _PreviewSection(
                    title: 'ROUND BOXES',
                    color: colors.teal,
                    colors: colors,
                    context: context,
                    rows: bill.roundBoxes.expand((b) {
                      final rows = b.heightRows.map((r) =>
                          _PreviewRow('${b.sizeKey} · ${r.heightFt}ft × ${r.qty}pcs',
                              '₹${r.amount.toStringAsFixed(0)}'));
                      final shoeRows = b.shoe != null
                          ? [_PreviewRow('${b.sizeKey} · Shoe × ${b.shoe!.qty}pcs',
                              '₹${b.shoe!.amount.toStringAsFixed(0)}')]
                          : <_PreviewRow>[];
                      return [...rows, ...shoeRows];
                    }).toList(),
                    total: rbRent,
                  ),
                  const SizedBox(height: 12),
                ],

                // Side Sheets
                if (bill.sideSheets.isNotEmpty) ...[
                  _PreviewSection(
                    title: 'SIDE SHEETS · ${ssTotalSqft.toStringAsFixed(1)} sqft',
                    color: colors.amber,
                    colors: colors,
                    context: context,
                    rows: bill.sideSheets.map((e) => _PreviewRow(
                        '${e.sheetType} Sheet · Size ${e.size} × ${e.qty} = ${e.sqft.toStringAsFixed(1)} sqft @ ₹${e.rate.toStringAsFixed(0)}',
                        '₹${e.amount.toStringAsFixed(0)}')).toList(),
                    total: ssRent,
                  ),
                  const SizedBox(height: 12),
                ],

                // Palagai
                if (bill.palagai.isNotEmpty) ...[
                  _PreviewSection(
                    title: 'PALAGAI',
                    color: colors.indigo,
                    colors: colors,
                    context: context,
                    rows: bill.palagai.map((e) => _PreviewRow(
                        'Palagai ${e.length} · ${e.size} × ${e.qty}pcs @ ₹${e.rate.toStringAsFixed(0)}',
                        '₹${e.amount.toStringAsFixed(0)}')).toList(),
                    total: palagaiRent,
                  ),
                  const SizedBox(height: 12),
                ],

                // Muttu
                if (bill.muttu.isNotEmpty) ...[
                  _PreviewSection(
                    title: 'MUTTU',
                    color: colors.brand,
                    colors: colors,
                    context: context,
                    rows: bill.muttu.map((e) => _PreviewRow(
                        'Muttu ${e.length} · ${e.size} × ${e.qty}pcs @ ₹${e.rate.toStringAsFixed(0)}',
                        '₹${e.amount.toStringAsFixed(0)}')).toList(),
                    total: muttuRent,
                  ),
                  const SizedBox(height: 12),
                ],

                // Roof Material
                if (bill.roofItems.isNotEmpty) ...[
                  _PreviewSection(
                    title: 'ROOF MATERIAL',
                    color: colors.teal,
                    colors: colors,
                    context: context,
                    rows: bill.roofItems.map((e) => _PreviewRow(
                        '${e.itemName} × ${e.qty}pcs @ ₹${e.rate.toStringAsFixed(0)}',
                        '₹${e.amount.toStringAsFixed(0)}')).toList(),
                    total: roofRent,
                  ),
                  const SizedBox(height: 12),
                ],

                // Free-form materials
                if (bill.materials.isNotEmpty) ...[
                  _PreviewSection(
                    title: 'MATERIALS',
                    color: colors.indigo,
                    colors: colors,
                    context: context,
                    rows: bill.materials.map((m) => _PreviewRow(
                        '${m.name} · ${m.quantity.toStringAsFixed(0)} ${m.unit} × ${m.days}d @ ₹${m.rate.toStringAsFixed(0)}',
                        '₹${m.amount.toStringAsFixed(0)}')).toList(),
                    total: mRent,
                  ),
                  const SizedBox(height: 12),
                ],

                // Financial summary
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.border, width: 0.5),
                  ),
                  child: Column(children: [
                    _FinRow('Total Rent', '₹${rentTotal.toStringAsFixed(2)}', colors, context),
                    if (bill.vehicleChargeUp > 0) ...[
                      const SizedBox(height: 8),
                      _FinRow('Vehicle (UP)', '₹${bill.vehicleChargeUp.toStringAsFixed(2)}', colors, context),
                    ],
                    if (bill.vehicleChargeDown > 0) ...[
                      const SizedBox(height: 8),
                      _FinRow('Vehicle (DOWN)', '₹${bill.vehicleChargeDown.toStringAsFixed(2)}', colors, context),
                    ],
                    if (bill.labourChargeUp > 0) ...[
                      const SizedBox(height: 8),
                      _FinRow('Labour (UP)', '₹${bill.labourChargeUp.toStringAsFixed(2)}', colors, context),
                    ],
                    if (bill.labourChargeDown > 0) ...[
                      const SizedBox(height: 8),
                      _FinRow('Labour (DOWN)', '₹${bill.labourChargeDown.toStringAsFixed(2)}', colors, context),
                    ],
                    const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, thickness: 0.5)),
                    _FinRow('GRAND TOTAL', '₹${grandTotal.toStringAsFixed(2)}', colors, context, bold: true, large: true),
                    if (bill.advancePaid > 0) ...[
                      const SizedBox(height: 8),
                      _FinRow('Advance Paid', '- ₹${bill.advancePaid.toStringAsFixed(2)}', colors, context, color: colors.teal),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accentColor.withOpacity(0.3), width: 0.5),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('BALANCE DUE', style: jakarta(context, size: 12, weight: FontWeight.w800, color: accentColor)),
                        Text('₹${balanceDue.toStringAsFixed(2)}',
                            style: GoogleFonts.playfairDisplay(
                                fontSize: 18, fontWeight: FontWeight.w900, color: accentColor)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          // Action buttons
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(top: BorderSide(color: colors.border, width: 0.5)),
            ),
            child: Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border, width: 0.5),
                    ),
                    child: Center(
                        child: Text('← Back to Edit',
                            style: jakarta(context,
                                size: 14, weight: FontWeight.w700, color: colors.textSub))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: isSaving ? null : onConfirm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isBill
                            ? [const Color(0xFF0CAF98), const Color(0xFF097A6B)]
                            : [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: accentColor.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Center(
                        child: isSaving
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text('✓  Confirm & Save',
                                style: jakarta(context,
                                    size: 14, weight: FontWeight.w800, color: Colors.white))),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _PreviewRow {
  final String label;
  final String amount;
  const _PreviewRow(this.label, this.amount);
}

class _PreviewSection extends StatelessWidget {
  final String title;
  final Color color;
  final AppColors colors;
  final BuildContext context;
  final List<_PreviewRow> rows;
  final double total;

  const _PreviewSection({
    required this.title,
    required this.color,
    required this.colors,
    required this.context,
    required this.rows,
    required this.total,
  });

  @override
  Widget build(BuildContext ctx) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border, width: 0.5),
        boxShadow: [BoxShadow(color: colors.glow, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(title,
                style: jakarta(context, size: 9, weight: FontWeight.w800, color: color)
                    .copyWith(letterSpacing: 1.5)),
            Text('₹${total.toStringAsFixed(0)}',
                style: jakarta(context, size: 13, weight: FontWeight.w800, color: color)),
          ]),
        ),
        ...rows.asMap().entries.map((entry) {
          final isLast = entry.key == rows.length - 1;
          final row = entry.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: isLast ? null : Border(bottom: BorderSide(color: colors.border, width: 0.5)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(
                  child: Text(row.label,
                      style: jakarta(context, size: 12, color: colors.textSub))),
              Text(row.amount,
                  style: jakarta(context, size: 12, weight: FontWeight.w700, color: colors.textMain)),
            ]),
          );
        }),
      ]),
    );
  }
}

Widget _FinRow(String label, String value, AppColors colors, BuildContext ctx,
    {bool bold = false, bool large = false, Color? color}) {
  return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(label,
        style: jakarta(ctx,
            size: bold ? 14 : 13,
            weight: bold ? FontWeight.w800 : FontWeight.w600,
            color: color ?? colors.textSub)),
    Text(value,
        style: bold
            ? GoogleFonts.playfairDisplay(
                fontSize: large ? 20 : 16,
                fontWeight: FontWeight.w900,
                color: color ?? colors.textMain)
            : jakarta(ctx,
                size: 13,
                weight: FontWeight.w700,
                color: color ?? colors.textMain)),
  ]);
}
