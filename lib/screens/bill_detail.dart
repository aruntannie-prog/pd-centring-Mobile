import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/bill.dart';
import '../models/store.dart';
import '../services/invoice_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class BillDetailScreen extends StatefulWidget {
  final Bill bill;
  final VoidCallback onBack;
  final Function(Bill) onEdit;
  const BillDetailScreen(
      {super.key,
      required this.bill,
      required this.onBack,
      required this.onEdit});

  @override
  State<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends State<BillDetailScreen> {
  Bill get bill => widget.bill;
  VoidCallback get onBack => widget.onBack;
  Function(Bill) get onEdit => widget.onEdit;

  @override
  void initState() {
    super.initState();
    // Pre-load PDF assets in background so they're ready when user taps Print/Share.
    InvoiceService.preloadAssets();
  }

  String matEmoji(String name) => switch (name) {
        'Box' => '📦',
        'Shoe' => '👟',
        'Roof Material' => '🏠',
        'Side Sheet' => '📄',
        'Palagai' => '🪵',
        'Muttu' => '⚙️',
        'Props' => '🔧',
        _ => '📦',
      };

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    // Get live bill from store
    final liveBill =
        store.bills.firstWhere((b) => b.id == bill.id, orElse: () => bill);
    final allRet = liveBill.status == BillStatus.allReturned;
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;


    return SafeArea(
      bottom: false,
      child: Column(children: [
        // Header with back
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: onBack,
              behavior: HitTestBehavior.opaque,
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant,
                    border: Border.all(color: colors.border, width: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: colors.textMain),
                ),
                const SizedBox(width: 12),
                Text('Back to Register',
                    style: jakarta(context,
                        size: 14,
                        weight: FontWeight.w700,
                        color: colors.textSub)),
                const Spacer(),
                // Edit toggle
                GestureDetector(
                  onTap: () => onEdit(liveBill),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.surfaceVariant,
                      border: Border.all(color: colors.border, width: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.edit_outlined,
                        size: 18, color: colors.brand),
                  ),
                ),
                const SizedBox(width: 12),
                // Delete toggle
                GestureDetector(
                  onTap: () => _confirmDelete(context, colors),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFFFF4D5E).withOpacity(.15)
                          : const Color(0xFFFFF0F1),
                      border: Border.all(
                          color: isDark
                              ? const Color(0xFFFF4D5E).withOpacity(.3)
                              : const Color(0xFFFFD1D6),
                          width: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        size: 18, color: Color(0xFFFF5555)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  border: Border.all(color: colors.border, width: 0.5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text('◉   DETAIL',
                    style: jakarta(context,
                            size: 9,
                            weight: FontWeight.w800,
                            color: colors.textSub)
                        .copyWith(letterSpacing: 2))),
            const SizedBox(height: 12),
            Text.rich(TextSpan(children: [
              TextSpan(
                  text: liveBill.type == BillType.dc ? 'DC  ' : 'Bill  ',
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: colors.textMain)),
              TextSpan(
                  text: liveBill.billNumber.split(' ').last,
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: colors.brand,
                      fontStyle: FontStyle.italic)),
            ])),
          ]),
        ),
        // Body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(
                left: 20, right: 20, top: 20, bottom: 100),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Hero card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF14224A), const Color(0xFF0A1628)]
                        : [const Color(0xFF14224A), const Color(0xFF1E2E44)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                        color: isDark
                            ? Colors.black.withOpacity(0.5)
                            : const Color(0xFF14224A).withOpacity(.3),
                        blurRadius: 24,
                        offset: const Offset(0, 12)),
                  ],
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(liveBill.billNumber,
                                        style: jakarta(context,
                                                size: 10,
                                                weight: FontWeight.w800,
                                                color: Colors.white
                                                    .withOpacity(.4))
                                            .copyWith(letterSpacing: 2.5)),
                                    const SizedBox(height: 8),
                                    Text(liveBill.customerName,
                                        style: GoogleFonts.playfairDisplay(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.location_on_rounded,
                                            size: 14,
                                            color:
                                                Colors.white.withOpacity(0.5)),
                                        const SizedBox(width: 4),
                                        Expanded(
                                            child: Text(liveBill.site,
                                                style: jakarta(context,
                                                    size: 12,
                                                    color: Colors.white
                                                        .withOpacity(.6)),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis)),
                                      ],
                                    ),
                                  ]),
                            ),
                            const SizedBox(width: 8),
                            StatusPill(liveBill.status),
                          ]),
                      const SizedBox(height: 24),
                      Row(children: [
                        Expanded(
                            child: _InfoBox(
                                'Bill Date', liveBill.billDateFormatted)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _InfoBox('Materials',
                                '${liveBill.materials.length + liveBill.columnBoxes.length + liveBill.roundBoxes.length} item(s)')),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: _InfoBox('Returned',
                                '${liveBill.returnedCount} / ${liveBill.materials.length + liveBill.columnBoxes.length + liveBill.roundBoxes.length}')),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _InfoBox(
                                'Type',
                                liveBill.type == BillType.dc
                                    ? 'DC Bill'
                                    : 'Regular')),
                      ]),
                    ]),
              ),

              if (liveBill.linkedDcIds.isNotEmpty) ...[
                const SizedBox(height: 24),
                SectionHeader(
                    'CONSOLIDATED FROM · ${liveBill.linkedDcIds.length} DC${liveBill.linkedDcIds.length > 1 ? 's' : ''}'),
                Container(
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.border, width: 0.5),
                  ),
                  child: Column(
                    children: liveBill.linkedDcIds
                        .asMap()
                        .entries
                        .map((entry) {
                      final isLast =
                          entry.key == liveBill.linkedDcIds.length - 1;
                      final id = entry.value;
                      final dc = store.bills.firstWhere(
                          (b) => b.id == id,
                          orElse: () => Bill(
                              billNumber: id,
                              type: BillType.dc,
                              customerName: '',
                              customerId: '',
                              site: '',
                              billDate: DateTime.now(),
                              materials: []));
                      final matCount = dc.materials.length +
                          dc.columnBoxes.length +
                          dc.roundBoxes.length;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          border: isLast
                              ? null
                              : Border(
                                  bottom: BorderSide(
                                      color: colors.border, width: 0.5)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: colors.indigoBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: colors.indigoBd, width: 0.5),
                            ),
                            child: Icon(Icons.local_shipping_outlined,
                                size: 16, color: colors.indigo),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(dc.billNumber,
                                      style: jakarta(context,
                                              size: 12,
                                              weight: FontWeight.w800,
                                              color: colors.indigo)
                                          .copyWith(letterSpacing: 1.5)),
                                  const SizedBox(height: 2),
                                  Text(
                                      '${dc.billDateFormatted}${dc.site.isNotEmpty ? ' · ${dc.site}' : ''}',
                                      style: jakarta(context,
                                          size: 11, color: colors.textMuted)),
                                ]),
                          ),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (dc.grandTotal > 0)
                                  Text(
                                      '₹${dc.grandTotal.toStringAsFixed(0)}',
                                      style: jakarta(context,
                                          size: 13,
                                          weight: FontWeight.w800,
                                          color: colors.textMain)),
                                Text('$matCount item${matCount != 1 ? 's' : ''}',
                                    style: jakarta(context,
                                        size: 10,
                                        color: colors.textMuted)),
                              ]),
                        ]),
                      );
                    }).toList(),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              // Action Buttons
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _processWithLoading(
                        context,
                        'Generating PDF...',
                        () => InvoiceService.shareInvoice(liveBill),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border, width: 0.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.share_rounded, size: 18, color: colors.brand),
                          const SizedBox(width: 8),
                          Text('SHARE PDF',
                              style: jakarta(context,
                                      size: 12,
                                      weight: FontWeight.w800,
                                      color: colors.brand)
                                  .copyWith(letterSpacing: .5)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _processWithLoading(
                        context,
                        'Preparing Print...',
                        () => InvoiceService.printInvoice(liveBill),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                         gradient: LinearGradient(
                           colors: isDark
                               ? [const Color(0xFF2563EB), const Color(0xFF1D4ED8)]
                               : [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
                         ),
                         borderRadius: BorderRadius.circular(16),
                         boxShadow: [
                           BoxShadow(
                               color: const Color(0xFF2563EB).withOpacity(.3),
                               blurRadius: 12,
                               offset: const Offset(0, 4)),
                         ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.print_rounded, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          Text('PRINT',
                              style: jakarta(context,
                                      size: 12,
                                      weight: FontWeight.w800,
                                      color: Colors.white)
                                  .copyWith(letterSpacing: .5)),
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              // Closed banner
              if (allRet) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.tealBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colors.tealBd, width: 0.5),
                    boxShadow: [
                      BoxShadow(
                          color: colors.glow,
                          blurRadius: 16,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: colors.surface.withOpacity(0.6),
                          shape: BoxShape.circle),
                      child: const Text('🎉', style: TextStyle(fontSize: 28)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('All Materials Returned!',
                                style: jakarta(context,
                                    size: 15,
                                    weight: FontWeight.w800,
                                    color: colors.teal)),
                            const SizedBox(height: 2),
                            Text('This bill is now fully closed',
                                style: jakarta(context,
                                    size: 12,
                                    weight: FontWeight.w600,
                                    color: colors.textMuted)),
                          ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),
              ],
              // Column Boxes
              if (liveBill.columnBoxes.isNotEmpty) ...[
                SectionHeader('COLUMN BOXES & SHOES'),
                ...liveBill.columnBoxes.map((b) {
                  final ret = b.isReturned;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: ret ? colors.tealBg : colors.redBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ret ? colors.tealBd : colors.redBd, width: 0.5),
                      boxShadow: [BoxShadow(color: colors.glow, blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('📦  ${b.sizeKey}', style: jakarta(context, size: 16, weight: FontWeight.w800, color: colors.textMain)),
                                if (!ret && b.days > 0) ...[
                                  const SizedBox(height: 4),
                                  Text('Due: ${_formatDate(bill.billDate.add(Duration(days: b.days)))}',
                                      style: jakarta(context, size: 12, weight: FontWeight.w700, color: const Color(0xFFFF5555))),
                                ],
                                if (ret && b.returnDate != null) ...[
                                  const SizedBox(height: 4),
                                  Text('Returned: ${_formatDate(b.returnDate!)}', style: jakarta(context, size: 12, weight: FontWeight.w700, color: colors.teal)),
                                ],
                              ]),
                              ret
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: colors.tealBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: colors.tealBd, width: 0.5)),
                                      child: Text('RETURNED', style: jakarta(context, size: 10, weight: FontWeight.w800, color: colors.teal).copyWith(letterSpacing: 0.5)),
                                    )
                                  : const SizedBox.shrink(),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...b.heightRows.map((r) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${r.heightFt}ft (${r.qty} pcs)', style: jakarta(context, size: 13, color: colors.textSub)),
                                Text('₹${r.amount.toStringAsFixed(2)}', style: jakarta(context, size: 13, weight: FontWeight.w700, color: colors.textMain)),
                              ],
                            ),
                          )),
                          if (b.shoe != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Shoe (${b.shoe!.qty} pcs)', style: jakarta(context, size: 13, color: colors.textSub)),
                                  Text('₹${b.shoe!.amount.toStringAsFixed(2)}', style: jakarta(context, size: 13, weight: FontWeight.w700, color: colors.textMain)),
                                ],
                              ),
                            ),
                          const Divider(height: 16, thickness: 0.5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Amount', style: jakarta(context, size: 12, weight: FontWeight.w700, color: colors.textMuted)),
                              Text('₹${b.totalAmount.toStringAsFixed(2)}', style: jakarta(context, size: 14, weight: FontWeight.w800, color: colors.brand)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (ret)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(color: colors.tealBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.tealBd, width: 0.5)),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.check_circle_rounded, size: 20, color: colors.teal),
                                const SizedBox(width: 8),
                                Text('RETURNED', style: jakarta(context, size: 13, weight: FontWeight.w800, color: colors.teal).copyWith(letterSpacing: .5)),
                              ]),
                            )
                          else
                            GestureDetector(
                              onTap: () => _markBoxReturned(context, liveBill.id, b.sizeKey, false),
                              child: _returnButton(isDark),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],

              // Round Boxes
              if (liveBill.roundBoxes.isNotEmpty) ...[
                const SizedBox(height: 8),
                SectionHeader('ROUND BOXES & SHOES'),
                ...liveBill.roundBoxes.map((b) {
                  final ret = b.isReturned;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: ret ? colors.tealBg : colors.redBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ret ? colors.tealBd : colors.redBd, width: 0.5),
                      boxShadow: [BoxShadow(color: colors.glow, blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('🔵  ${b.sizeKey}', style: jakarta(context, size: 16, weight: FontWeight.w800, color: colors.textMain)),
                                if (!ret && b.days > 0) ...[
                                  const SizedBox(height: 4),
                                  Text('Due: ${_formatDate(bill.billDate.add(Duration(days: b.days)))}',
                                      style: jakarta(context, size: 12, weight: FontWeight.w700, color: const Color(0xFFFF5555))),
                                ],
                                if (ret && b.returnDate != null) ...[
                                  const SizedBox(height: 4),
                                  Text('Returned: ${_formatDate(b.returnDate!)}', style: jakarta(context, size: 12, weight: FontWeight.w700, color: colors.teal)),
                                ],
                              ]),
                              ret
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: colors.tealBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: colors.tealBd, width: 0.5)),
                                      child: Text('RETURNED', style: jakarta(context, size: 10, weight: FontWeight.w800, color: colors.teal).copyWith(letterSpacing: 0.5)),
                                    )
                                  : const SizedBox.shrink(),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...b.heightRows.map((r) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${r.heightFt}ft (${r.qty} pcs)', style: jakarta(context, size: 13, color: colors.textSub)),
                                Text('₹${r.amount.toStringAsFixed(2)}', style: jakarta(context, size: 13, weight: FontWeight.w700, color: colors.textMain)),
                              ],
                            ),
                          )),
                          if (b.shoe != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Shoe (${b.shoe!.qty} pcs)', style: jakarta(context, size: 13, color: colors.textSub)),
                                  Text('₹${b.shoe!.amount.toStringAsFixed(2)}', style: jakarta(context, size: 13, weight: FontWeight.w700, color: colors.textMain)),
                                ],
                              ),
                            ),
                          const Divider(height: 16, thickness: 0.5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Amount', style: jakarta(context, size: 12, weight: FontWeight.w700, color: colors.textMuted)),
                              Text('₹${b.totalAmount.toStringAsFixed(2)}', style: jakarta(context, size: 14, weight: FontWeight.w800, color: colors.brand)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (ret)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(color: colors.tealBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.tealBd, width: 0.5)),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.check_circle_rounded, size: 20, color: colors.teal),
                                const SizedBox(width: 8),
                                Text('RETURNED', style: jakarta(context, size: 13, weight: FontWeight.w800, color: colors.teal).copyWith(letterSpacing: .5)),
                              ]),
                            )
                          else
                            GestureDetector(
                              onTap: () => _markBoxReturned(context, liveBill.id, b.sizeKey, true),
                              child: _returnButton(isDark),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],

              // Side Sheets
              if (liveBill.sideSheets.isNotEmpty) ...[
                const SizedBox(height: 8),
                SectionHeader('SIDE SHEETS'),
                ...liveBill.sideSheets.asMap().entries.map((entry) {
                  final i = entry.key;
                  final e = entry.value;
                  final ret = e.isReturned;
                  final amount = e.amount;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: ret ? colors.tealBg : colors.redBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ret ? colors.tealBd : colors.redBd, width: 0.5),
                      boxShadow: [BoxShadow(color: colors.glow, blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('📄  ${e.sheetType} Sheet — Size: ${e.size}', style: jakarta(context, size: 16, weight: FontWeight.w800, color: colors.textMain)),
                                  if (!ret && e.days > 0) ...[
                                    const SizedBox(height: 4),
                                    Text('Due: ${_formatDate(bill.billDate.add(Duration(days: e.days)))}',
                                        style: jakarta(context, size: 12, weight: FontWeight.w700, color: const Color(0xFFFF5555))),
                                  ],
                                  if (ret && e.returnDate != null) ...[
                                    const SizedBox(height: 4),
                                    Text('Returned: ${_formatDate(e.returnDate!)}', style: jakarta(context, size: 12, weight: FontWeight.w700, color: colors.teal)),
                                  ],
                                ]),
                              ),
                              ret
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: colors.tealBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: colors.tealBd, width: 0.5)),
                                      child: Text('RETURNED', style: jakarta(context, size: 10, weight: FontWeight.w800, color: colors.teal).copyWith(letterSpacing: 0.5)),
                                    )
                                  : const SizedBox.shrink(),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${e.qty} pcs @ ₹${e.rate.toStringAsFixed(2)}/sqft (${e.sqft.toStringAsFixed(1)} sqft)', style: jakarta(context, size: 13, color: colors.textSub)),
                              Text('₹${amount.toStringAsFixed(2)}', style: jakarta(context, size: 14, weight: FontWeight.w800, color: colors.brand)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (ret)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(color: colors.tealBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.tealBd, width: 0.5)),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.check_circle_rounded, size: 20, color: colors.teal),
                                const SizedBox(width: 8),
                                Text('RETURNED', style: jakarta(context, size: 13, weight: FontWeight.w800, color: colors.teal).copyWith(letterSpacing: .5)),
                              ]),
                            )
                          else
                            GestureDetector(
                              onTap: () => _markSideSheetReturned(context, liveBill.id, i),
                              child: _returnButton(isDark),
                            ),
                        ]
                      )
                    )
                  );
                }),
              ],

              // Palagai
              if (liveBill.palagai.isNotEmpty) ...[
                const SizedBox(height: 8),
                SectionHeader('PALAGAI'),
                ...liveBill.palagai.asMap().entries.map((entry) {
                  final i = entry.key;
                  final p = entry.value;
                  final ret = p.isReturned;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: ret ? colors.tealBg : colors.redBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ret ? colors.tealBd : colors.redBd, width: 0.5),
                      boxShadow: [BoxShadow(color: colors.glow, blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('🪵  ${p.length == "Runner" ? "Runner" : "Length: ${p.length}"} — Size: ${p.size}', style: jakarta(context, size: 16, weight: FontWeight.w800, color: colors.textMain)),
                                  if (!ret && p.days > 0) ...[
                                    const SizedBox(height: 4),
                                    Text('Due: ${_formatDate(bill.billDate.add(Duration(days: p.days)))}',
                                        style: jakarta(context, size: 12, weight: FontWeight.w700, color: const Color(0xFFFF5555))),
                                  ],
                                  if (ret && p.returnDate != null) ...[
                                    const SizedBox(height: 4),
                                    Text('Returned: ${_formatDate(p.returnDate!)}', style: jakarta(context, size: 12, weight: FontWeight.w700, color: colors.teal)),
                                  ],
                                ]),
                              ),
                              ret
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: colors.tealBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: colors.tealBd, width: 0.5)),
                                    child: Text('RETURNED', style: jakarta(context, size: 10, weight: FontWeight.w800, color: colors.teal).copyWith(letterSpacing: 0.5)),
                                  )
                                : const SizedBox.shrink(),
                            ]
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${p.qty} pcs @ ₹${p.rate.toStringAsFixed(2)}', style: jakarta(context, size: 13, color: colors.textSub)),
                              Text('₹${p.amount.toStringAsFixed(2)}', style: jakarta(context, size: 14, weight: FontWeight.w800, color: colors.brand)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (ret)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(color: colors.tealBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.tealBd, width: 0.5)),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.check_circle_rounded, size: 20, color: colors.teal),
                                const SizedBox(width: 8),
                                Text('RETURNED', style: jakarta(context, size: 13, weight: FontWeight.w800, color: colors.teal).copyWith(letterSpacing: .5)),
                              ]),
                            )
                          else
                            GestureDetector(
                              onTap: () => _markPalagaiReturned(context, liveBill.id, i),
                              child: _returnButton(isDark),
                            ),
                        ]
                      )
                    )
                  );
                }),
              ],

              // Muttu
              if (liveBill.muttu.isNotEmpty) ...[
                const SizedBox(height: 8),
                SectionHeader('MUTTU'),
                ...liveBill.muttu.asMap().entries.map((entry) {
                  final i = entry.key;
                  final m = entry.value;
                  final ret = m.isReturned;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: ret ? colors.tealBg : colors.redBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ret ? colors.tealBd : colors.redBd, width: 0.5),
                      boxShadow: [BoxShadow(color: colors.glow, blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('⚙️  Length: ${m.length} — Size: ${m.size}', style: jakarta(context, size: 16, weight: FontWeight.w800, color: colors.textMain)),
                                  if (!ret && m.days > 0) ...[
                                    const SizedBox(height: 4),
                                    Text('Due: ${_formatDate(bill.billDate.add(Duration(days: m.days)))}',
                                        style: jakarta(context, size: 12, weight: FontWeight.w700, color: const Color(0xFFFF5555))),
                                  ],
                                  if (ret && m.returnDate != null) ...[
                                    const SizedBox(height: 4),
                                    Text('Returned: ${_formatDate(m.returnDate!)}', style: jakarta(context, size: 12, weight: FontWeight.w700, color: colors.teal)),
                                  ],
                                ]),
                              ),
                              ret
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: colors.tealBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: colors.tealBd, width: 0.5)),
                                    child: Text('RETURNED', style: jakarta(context, size: 10, weight: FontWeight.w800, color: colors.teal).copyWith(letterSpacing: 0.5)),
                                  )
                                : const SizedBox.shrink(),
                            ]
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${m.qty} pcs @ ₹${m.rate.toStringAsFixed(2)}', style: jakarta(context, size: 13, color: colors.textSub)),
                              Text('₹${m.amount.toStringAsFixed(2)}', style: jakarta(context, size: 14, weight: FontWeight.w800, color: colors.brand)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (ret)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(color: colors.tealBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.tealBd, width: 0.5)),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.check_circle_rounded, size: 20, color: colors.teal),
                                const SizedBox(width: 8),
                                Text('RETURNED', style: jakarta(context, size: 13, weight: FontWeight.w800, color: colors.teal).copyWith(letterSpacing: .5)),
                              ]),
                            )
                          else
                            GestureDetector(
                              onTap: () => _markMuttuReturned(context, liveBill.id, i),
                              child: _returnButton(isDark),
                            ),
                        ]
                      )
                    )
                  );
                }),
              ],

              // Roof Material
              if (liveBill.roofItems.isNotEmpty) ...[
                const SizedBox(height: 8),
                SectionHeader('ROOF MATERIALS'),
                ...liveBill.roofItems.asMap().entries.map((entry) {
                  final i = entry.key;
                  final r = entry.value;
                  final ret = r.isReturned;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: ret ? colors.tealBg : colors.redBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ret ? colors.tealBd : colors.redBd, width: 0.5),
                      boxShadow: [BoxShadow(color: colors.glow, blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('🏠  ${r.itemName}', style: jakarta(context, size: 16, weight: FontWeight.w800, color: colors.textMain)),
                                  if (!ret && r.days > 0) ...[
                                    const SizedBox(height: 4),
                                    Text('Due: ${_formatDate(bill.billDate.add(Duration(days: r.days)))}',
                                        style: jakarta(context, size: 12, weight: FontWeight.w700, color: const Color(0xFFFF5555))),
                                  ],
                                  if (ret && r.returnDate != null) ...[
                                    const SizedBox(height: 4),
                                    Text('Returned: ${_formatDate(r.returnDate!)}', style: jakarta(context, size: 12, weight: FontWeight.w700, color: colors.teal)),
                                  ],
                                ]),
                              ),
                              ret
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: colors.tealBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: colors.tealBd, width: 0.5)),
                                    child: Text('RETURNED', style: jakarta(context, size: 10, weight: FontWeight.w800, color: colors.teal).copyWith(letterSpacing: 0.5)),
                                  )
                                : const SizedBox.shrink(),
                            ]
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${r.qty} pcs @ ₹${r.rate.toStringAsFixed(2)}', style: jakarta(context, size: 13, color: colors.textSub)),
                              Text('₹${r.amount.toStringAsFixed(2)}', style: jakarta(context, size: 14, weight: FontWeight.w800, color: colors.brand)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (ret)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(color: colors.tealBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.tealBd, width: 0.5)),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.check_circle_rounded, size: 20, color: colors.teal),
                                const SizedBox(width: 8),
                                Text('RETURNED', style: jakarta(context, size: 13, weight: FontWeight.w800, color: colors.teal).copyWith(letterSpacing: .5)),
                              ]),
                            )
                          else
                            GestureDetector(
                              onTap: () => _markRoofMaterialReturned(context, liveBill.id, i),
                              child: _returnButton(isDark),
                            ),
                        ]
                      )
                    )
                  );
                }),
              ],

              const SizedBox(height: 24),

              if (liveBill.materials.isNotEmpty)
                SectionHeader('MATERIALS — TAP TO MARK RETURNED'),
              ...liveBill.materials.map((m) {
                final ret = m.isReturned;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: ret ? colors.tealBg : colors.redBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: ret ? colors.tealBd : colors.redBd, width: 0.5),
                    boxShadow: [
                      BoxShadow(
                          color: colors.glow,
                          blurRadius: 12,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('${matEmoji(m.name)}  ${m.name}',
                                          style: jakarta(context,
                                              size: 16,
                                              weight: FontWeight.w800,
                                              color: colors.textMain)),
                                      if (!ret) ...[
                                        const SizedBox(height: 6),
                                        Text('Due: ${m.dueDateFormatted}',
                                            style: jakarta(context,
                                                size: 12,
                                                weight: FontWeight.w700,
                                                color: const Color(0xFFFF5555))),
                                      ],
                                      if (ret && m.returnDate != null) ...[
                                        const SizedBox(height: 4),
                                        Text('Returned: ${_formatDate(m.returnDate!)}',
                                            style: jakarta(context,
                                                size: 12,
                                                weight: FontWeight.w700,
                                                color: colors.teal)),
                                      ],
                                    ]),
                                MaterialPill(m.status),
                              ]),
                          const SizedBox(height: 16),
                          // Action button
                          if (ret)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: colors.tealBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: colors.tealBd, width: 0.5),
                              ),
                              child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_rounded,
                                        size: 20, color: colors.teal),
                                    const SizedBox(width: 8),
                                    Text('RETURNED',
                                        style: jakarta(context,
                                                size: 13,
                                                weight: FontWeight.w800,
                                                color: colors.teal)
                                            .copyWith(letterSpacing: .5)),
                                  ]),
                            )
                          else
                            GestureDetector(
                              onTap: () => _markMaterialReturned(context, liveBill.id, m.id),
                              child: _returnButton(isDark),
                            ),
                        ]),
                  ),
                );
              }),
              const SizedBox(height: 32),
              SectionHeader('FINANCIAL SUMMARY'),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.border, width: 0.5),
                ),
                child: Column(
                  children: [
                    // Total Rent
                    _FinRow(
                      label: 'Total Rent',
                      value: '₹${liveBill.rentTotal.toStringAsFixed(0)}',
                      colors: colors,
                      context: context,
                    ),
                    if (liveBill.vehicleChargeUp > 0) ...[
                      const SizedBox(height: 12),
                      _FinRow(label: 'Transport (UP)', value: '₹${liveBill.vehicleChargeUp.toStringAsFixed(0)}', colors: colors, context: context),
                    ],
                    if (liveBill.vehicleChargeDown > 0) ...[
                      const SizedBox(height: 12),
                      _FinRow(label: 'Transport (DOWN)', value: '₹${liveBill.vehicleChargeDown.toStringAsFixed(0)}', colors: colors, context: context),
                    ],
                    if (liveBill.labourChargeUp > 0) ...[
                      const SizedBox(height: 12),
                      _FinRow(label: 'Labour (UP)', value: '₹${liveBill.labourChargeUp.toStringAsFixed(0)}', colors: colors, context: context),
                    ],
                    if (liveBill.labourChargeDown > 0) ...[
                      const SizedBox(height: 12),
                      _FinRow(label: 'Labour (DOWN)', value: '₹${liveBill.labourChargeDown.toStringAsFixed(0)}', colors: colors, context: context),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Divider(height: 1, thickness: 0.5, color: colors.border),
                    ),
                    // Total Amount + GST + Balance
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Amount',
                            style: jakarta(context, size: 14, weight: FontWeight.w800, color: colors.textMain)),
                        Text('₹${liveBill.grandTotal.toStringAsFixed(0)}',
                            style: GoogleFonts.playfairDisplay(fontSize: 17, fontWeight: FontWeight.w900,
                                color: liveBill.type == BillType.bill ? colors.teal : colors.brand)),
                      ],
                    ),
                    if (liveBill.gstEnabled) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: Text('GST Billing (18%)',
                              style: jakarta(context, size: 13, weight: FontWeight.w600, color: colors.textSub))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _FinRow(label: 'SGST (9%)', value: '₹${liveBill.sgst.toStringAsFixed(0)}', colors: colors, context: context, isMuted: true),
                      const SizedBox(height: 4),
                      _FinRow(label: 'CGST (9%)', value: '₹${liveBill.cgst.toStringAsFixed(0)}', colors: colors, context: context, isMuted: true),
                      const SizedBox(height: 8),
                      _FinRow(label: 'Total incl. GST', value: '₹${liveBill.totalWithGst.toStringAsFixed(0)}', colors: colors, context: context),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Divider(height: 1, thickness: 0.5, color: colors.border),
                    ),
                    if (liveBill.advancePaid > 0) ...[
                      _FinRow(label: 'Received Amount', value: '₹${liveBill.advancePaid.toStringAsFixed(0)}', colors: colors, context: context),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Divider(height: 1, thickness: 0.5, color: colors.border),
                      ),
                    ],
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: liveBill.type == BillType.bill ? colors.tealBg : colors.indigoBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('BALANCE AMOUNT',
                              style: jakarta(context, size: 12, weight: FontWeight.w800,
                                  color: liveBill.type == BillType.bill ? colors.teal : colors.indigo)),
                          Text('₹${liveBill.balanceDue.toStringAsFixed(0)}',
                              style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.w900,
                                  color: liveBill.type == BillType.bill ? colors.teal : colors.indigo)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  String _formatDate(DateTime d) {
    const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${mo[d.month - 1]} ${d.year}';
  }

  Widget _returnButton(bool isDark) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: isDark
            ? [const Color(0xFFCC3333), const Color(0xFFAA2222)]
            : [const Color(0xFFFF5555), const Color(0xFFCC3333)],
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
            color: const Color(0xFFFF5555).withOpacity(.3),
            blurRadius: 16,
            offset: const Offset(0, 4)),
      ],
    ),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 22),
      const SizedBox(width: 8),
      Text('MARK AS RETURNED',
          style: jakarta(context, size: 13, weight: FontWeight.w800, color: Colors.white)
              .copyWith(letterSpacing: .5)),
    ]),
  );

  Future<void> _markMaterialReturned(BuildContext ctx, String billId, String materialId) async {
    final picked = await showDatePicker(
      context: ctx,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select Return Date',
    );
    if (picked == null || !ctx.mounted) return;
    HapticFeedback.mediumImpact();
    await ctx.read<AppStore>().markMaterialReturned(billId, materialId, picked);
  }

  Future<void> _markBoxReturned(BuildContext ctx, String billId, String sizeKey, bool isRound) async {
    final picked = await showDatePicker(
      context: ctx,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select Return Date',
    );
    if (picked == null || !ctx.mounted) return;
    HapticFeedback.mediumImpact();
    if (isRound) {
      await ctx.read<AppStore>().markRoundBoxReturned(billId, sizeKey, picked);
    } else {
      await ctx.read<AppStore>().markColumnBoxReturned(billId, sizeKey, picked);
    }
  }

  Future<void> _markPalagaiReturned(BuildContext ctx, String billId, int index) async {
    final picked = await showDatePicker(
      context: ctx,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select Return Date',
    );
    if (picked == null || !ctx.mounted) return;
    HapticFeedback.mediumImpact();
    await ctx.read<AppStore>().markPalagaiReturned(billId, index, picked);
  }

  Future<void> _markMuttuReturned(BuildContext ctx, String billId, int index) async {
    final picked = await showDatePicker(
      context: ctx,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select Return Date',
    );
    if (picked == null || !ctx.mounted) return;
    HapticFeedback.mediumImpact();
    await ctx.read<AppStore>().markMuttuReturned(billId, index, picked);
  }

  Future<void> _markRoofMaterialReturned(BuildContext ctx, String billId, int index) async {
    final picked = await showDatePicker(
      context: ctx,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select Return Date',
    );
    if (picked == null || !ctx.mounted) return;
    HapticFeedback.mediumImpact();
    await ctx.read<AppStore>().markRoofMaterialReturned(billId, index, picked);
  }

  Future<void> _markSideSheetReturned(BuildContext ctx, String billId, int index) async {
    final picked = await showDatePicker(
      context: ctx,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select Return Date',
    );
    if (picked == null || !ctx.mounted) return;
    HapticFeedback.mediumImpact();
    await ctx.read<AppStore>().markSideSheetReturned(billId, index, picked);
  }

  Future<void> _processWithLoading(
      BuildContext context, String message, Future<void> Function() action) async {
    // On Flutter Web, everything runs on a single JS thread.
    // We use a ValueNotifier so the overlay widget rebuilds independently
    // and we await multiple endOfFrame calls to let the browser actually
    // commit the paint before the heavy PDF generation blocks the thread.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: ctx.appColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  strokeWidth: 3,
                  color: ctx.appColors.brand,
                ),
                const SizedBox(height: 20),
                Text(message,
                    textAlign: TextAlign.center,
                    style: jakarta(ctx, size: 14, weight: FontWeight.w600, color: ctx.appColors.textMain)),
                const SizedBox(height: 6),
                Text('This may take a few seconds...',
                    textAlign: TextAlign.center,
                    style: jakarta(ctx, size: 12, color: ctx.appColors.textMuted)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Wait for 3 consecutive frames to ensure the dialog is fully visible
      // on web's single-threaded rendering pipeline before blocking it.
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
      await action();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (context.mounted) {
        Navigator.of(context).pop(); // Dismiss loading dialog
      }
    }
  }

  void _confirmDelete(BuildContext context, AppColors colors) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: colors.border, width: 0.5)),
        title: Text('Delete this Bill?',
            style: jakarta(context,
                size: 18, weight: FontWeight.w800, color: colors.textMain)),
        content: Text(
            'This action is permanent and will remove the record from the cloud.',
            style: jakarta(context, size: 13, color: colors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL',
                style: jakarta(context,
                        size: 12,
                        weight: FontWeight.w800,
                        color: colors.textSub)
                    .copyWith(letterSpacing: 1)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AppStore>().deleteBill(bill.id);
              onBack();
            },
            child: Text('DELETE',
                style: jakarta(context,
                        size: 12,
                        weight: FontWeight.w800,
                        color: const Color(0xFFFF5555))
                    .copyWith(letterSpacing: 1)),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String label, value;
  const _InfoBox(this.label, this.value);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(.08), width: 0.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(),
              style: jakarta(context,
                      size: 8,
                      weight: FontWeight.w800,
                      color: Colors.white.withOpacity(.4))
                  .copyWith(letterSpacing: 1.5)),
          const SizedBox(height: 6),
          Text(value,
              style: jakarta(context,
                  size: 12, weight: FontWeight.w800, color: Colors.white),
              overflow: TextOverflow.ellipsis),
        ]),
      );
}

class _FinRow extends StatelessWidget {
  final String label;
  final String value;
  final AppColors colors;
  final BuildContext context;
  final bool isMuted;
  const _FinRow({required this.label, required this.value, required this.colors, required this.context, this.isMuted = false});
  @override
  Widget build(BuildContext ctx) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: jakarta(context, size: 13, weight: FontWeight.w600, color: isMuted ? colors.textMuted : colors.textSub)),
        Text(value, style: jakarta(context, size: 13, weight: FontWeight.w700, color: isMuted ? colors.textMuted : colors.textMain)),
      ],
    );
  }
}
