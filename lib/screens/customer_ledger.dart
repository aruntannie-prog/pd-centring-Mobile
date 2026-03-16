import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/bill.dart';
import '../models/customer.dart';
import '../models/ledger.dart';
import '../models/store.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class CustomerLedgerScreen extends StatefulWidget {
  final Customer customer;
  final VoidCallback onBack;
  final Function(Bill) onBillTap;

  const CustomerLedgerScreen({
    super.key,
    required this.customer,
    required this.onBack,
    required this.onBillTap,
  });

  @override
  State<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends State<CustomerLedgerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  static String _fmt(DateTime d) {
    const mo = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${mo[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Use all bills for this customer (store is already branch-filtered)
    final ledger = computeLedger(store.bills, widget.customer.id);
    final entries = ledger.entries;
    final txns = ledger.transactions;

    final totalGiven =
        entries.fold(0.0, (s, e) => s + e.given);
    final totalReturned =
        entries.fold(0.0, (s, e) => s + e.returned);
    final totalBalance = totalGiven - totalReturned;
    final hasPending = totalBalance > 0;

    return SafeArea(
      bottom: false,
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            GestureDetector(
              onTap: widget.onBack,
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
                Text('Back to ${widget.customer.name}',
                    style: jakarta(context,
                        size: 14,
                        weight: FontWeight.w700,
                        color: colors.textSub),
                    overflow: TextOverflow.ellipsis),
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
                child: Text('◉   LEDGER',
                    style: jakarta(context,
                            size: 9,
                            weight: FontWeight.w800,
                            color: colors.textSub)
                        .copyWith(letterSpacing: 2))),
            const SizedBox(height: 12),
            Text.rich(TextSpan(children: [
              TextSpan(
                  text: 'Material  ',
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: colors.textMain)),
              TextSpan(
                  text: 'Ledger',
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: colors.brand,
                      fontStyle: FontStyle.italic)),
            ])),
            const SizedBox(height: 2),
            Text(widget.customer.name,
                style: jakarta(context, size: 13, color: colors.textMuted)),
            const SizedBox(height: 16),

            // Summary stats bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF14224A), const Color(0xFF0A1628)]
                      : [const Color(0xFF14224A), const Color(0xFF1E2E44)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                Expanded(
                    child: _DarkStat(
                  label: 'GIVEN',
                  value: fmtQty(totalGiven),
                  color: Colors.white.withOpacity(0.9),
                )),
                _VertDivider(),
                Expanded(
                    child: _DarkStat(
                  label: 'RETURNED',
                  value: fmtQty(totalReturned),
                  color: const Color(0xFF20E5CD),
                )),
                _VertDivider(),
                Expanded(
                    child: _DarkStat(
                  label: 'PENDING',
                  value: fmtQty(totalBalance),
                  color: hasPending
                      ? const Color(0xFFFF8A97)
                      : const Color(0xFF20E5CD),
                )),
              ]),
            ),
            const SizedBox(height: 16),

            // Tab bar
            Container(
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border, width: 0.5),
              ),
              child: TabBar(
                controller: _tab,
                indicator: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: colors.glow,
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelStyle: jakarta(context, size: 12, weight: FontWeight.w800),
                unselectedLabelStyle:
                    jakarta(context, size: 12, weight: FontWeight.w600),
                labelColor: colors.textMain,
                unselectedLabelColor: colors.textMuted,
                padding: const EdgeInsets.all(4),
                tabs: [
                  Tab(
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.table_chart_outlined,
                              size: 14,
                              color: _tab.index == 0
                                  ? colors.brand
                                  : colors.textMuted),
                          const SizedBox(width: 6),
                          const Text('Summary'),
                        ]),
                  ),
                  Tab(
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_rounded,
                              size: 14,
                              color: _tab.index == 1
                                  ? colors.brand
                                  : colors.textMuted),
                          const SizedBox(width: 6),
                          const Text('History'),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _tab.index == 1
                                  ? colors.brand.withOpacity(0.15)
                                  : colors.surfaceVariant,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('${txns.length}',
                                style: jakarta(context,
                                    size: 10,
                                    weight: FontWeight.w800,
                                    color: _tab.index == 1
                                        ? colors.brand
                                        : colors.textMuted)),
                          ),
                        ]),
                  ),
                ],
              ),
            ),
          ]),
        ),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              // Summary tab
              entries.isEmpty
                  ? _empty(context, colors, 'No material data yet',
                      'Materials will appear here once bills are created')
                  : _SummaryTab(
                      entries: entries,
                      colors: colors,
                      context: context,
                    ),

              // History tab
              txns.isEmpty
                  ? _empty(context, colors, 'No transactions yet',
                      'Transaction history will appear here')
                  : _HistoryTab(
                      txns: txns,
                      colors: colors,
                      context: context,
                      store: store,
                      onBillTap: widget.onBillTap,
                      fmt: _fmt,
                    ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _empty(BuildContext ctx, AppColors c, String label, String sub) {
    return Center(
      child:
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.inventory_2_outlined,
            size: 52, color: c.textMuted.withOpacity(0.4)),
        const SizedBox(height: 16),
        Text(label,
            style: jakarta(ctx,
                size: 16, weight: FontWeight.w700, color: c.textSub)),
        const SizedBox(height: 4),
        Text(sub,
            style: jakarta(ctx, size: 12, color: c.textMuted),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

// ── Summary Tab ────────────────────────────────────────────────────────────────
class _SummaryTab extends StatelessWidget {
  final List<LedgerEntry> entries;
  final AppColors colors;
  final BuildContext context;

  const _SummaryTab(
      {required this.entries,
      required this.colors,
      required this.context});

  @override
  Widget build(BuildContext ctx) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 95 + MediaQuery.of(ctx).padding.bottom),
      children: [
        SectionHeader('MATERIAL SUMMARY'),
        // Table
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border, width: 0.5),
            boxShadow: [
              BoxShadow(
                  color: colors.glow,
                  blurRadius: 16,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(children: [
            // Header row
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(children: [
                Expanded(
                    flex: 3,
                    child: Text('MATERIAL',
                        style: jakarta(context,
                                size: 9,
                                weight: FontWeight.w800,
                                color: colors.textMuted)
                            .copyWith(letterSpacing: 1.5))),
                _HeaderCell('GIVEN', context, colors),
                _HeaderCell('RETURNED', context, colors),
                _HeaderCell('BALANCE', context, colors),
              ]),
            ),
            // Data rows
            ...entries.asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              final isLast = i == entries.length - 1;
              final hasPending = e.balance > 0;
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: hasPending
                      ? colors.amberBg.withOpacity(0.5)
                      : null,
                  border: isLast
                      ? null
                      : Border(
                          bottom: BorderSide(
                              color: colors.border, width: 0.5)),
                  borderRadius: isLast
                      ? const BorderRadius.vertical(
                          bottom: Radius.circular(20))
                      : null,
                ),
                child: Row(children: [
                  Expanded(
                    flex: 3,
                    child: Row(children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasPending
                              ? colors.amber
                              : colors.teal,
                        ),
                      ),
                      Expanded(
                        child: Text(e.materialName,
                            style: jakarta(context,
                                size: 12,
                                weight: FontWeight.w700,
                                color: colors.textMain),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ),
                  _DataCell(fmtQty(e.given), context, colors,
                      color: colors.textSub),
                  _DataCell(fmtQty(e.returned), context, colors,
                      color: colors.teal),
                  _DataCell(fmtQty(e.balance), context, colors,
                      color: hasPending ? colors.amber : colors.textMuted,
                      bold: hasPending),
                ]),
              );
            }),
          ]),
        ),
        if (entries.any((e) => e.balance > 0)) ...[
          const SizedBox(height: 20),
          SectionHeader('PENDING ITEMS'),
          ...entries
              .where((e) => e.balance > 0)
              .map((e) => _PendingChip(
                  entry: e, colors: colors, context: context)),
        ],
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final BuildContext context;
  final AppColors colors;
  const _HeaderCell(this.text, this.context, this.colors);

  @override
  Widget build(BuildContext ctx) {
    return SizedBox(
      width: 66,
      child: Text(text,
          textAlign: TextAlign.right,
          style: jakarta(context,
                  size: 9,
                  weight: FontWeight.w800,
                  color: colors.textMuted)
              .copyWith(letterSpacing: 1.2)),
    );
  }
}

class _DataCell extends StatelessWidget {
  final String text;
  final BuildContext context;
  final AppColors colors;
  final Color color;
  final bool bold;
  const _DataCell(this.text, this.context, this.colors,
      {required this.color, this.bold = false});

  @override
  Widget build(BuildContext ctx) {
    return SizedBox(
      width: 66,
      child: Text(text,
          textAlign: TextAlign.right,
          style: jakarta(context,
              size: 13,
              weight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color)),
    );
  }
}

class _PendingChip extends StatelessWidget {
  final LedgerEntry entry;
  final AppColors colors;
  final BuildContext context;
  const _PendingChip(
      {required this.entry,
      required this.colors,
      required this.context});

  @override
  Widget build(BuildContext ctx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.amberBd, width: 0.5),
        boxShadow: [
          BoxShadow(
              color: colors.glow, blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.amberBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.inventory_2_outlined,
              size: 20, color: colors.amber),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(entry.materialName,
                style: jakarta(context,
                    size: 14,
                    weight: FontWeight.w800,
                    color: colors.textMain)),
            const SizedBox(height: 2),
            Text(
                '${fmtQty(entry.given)} given · ${fmtQty(entry.returned)} returned',
                style:
                    jakarta(context, size: 11, color: colors.textMuted)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(fmtQty(entry.balance),
              style: jakarta(context,
                  size: 22,
                  weight: FontWeight.w900,
                  color: colors.amber)),
          Text('pending',
              style:
                  jakarta(context, size: 10, color: colors.textMuted)),
        ]),
      ]),
    );
  }
}

// ── History Tab ────────────────────────────────────────────────────────────────
class _HistoryTab extends StatelessWidget {
  final List<LedgerTransaction> txns;
  final AppColors colors;
  final BuildContext context;
  final AppStore store;
  final Function(Bill) onBillTap;
  final String Function(DateTime) fmt;

  const _HistoryTab({
    required this.txns,
    required this.colors,
    required this.context,
    required this.store,
    required this.onBillTap,
    required this.fmt,
  });

  @override
  Widget build(BuildContext ctx) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 95 + MediaQuery.of(ctx).padding.bottom),
      children: [
        SectionHeader('TRANSACTION HISTORY · ${txns.length} entries'),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border, width: 0.5),
            boxShadow: [
              BoxShadow(
                  color: colors.glow,
                  blurRadius: 16,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: txns.asMap().entries.map((entry) {
              final i = entry.key;
              final txn = entry.value;
              final isLast = i == txns.length - 1;
              final isReturn = txn.isReturn;
              final qtyColor = isReturn ? colors.red : colors.teal;
              final qtyText =
                  '${isReturn ? '-' : '+'}${fmtQty(txn.qty)}';

              final sourceBill = store.bills
                  .where((b) => b.id == txn.billId)
                  .firstOrNull;

              return GestureDetector(
                onTap: sourceBill != null
                    ? () => onBillTap(sourceBill)
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: isLast
                        ? null
                        : Border(
                            bottom: BorderSide(
                                color: colors.border, width: 0.5)),
                  ),
                  child: Row(children: [
                    // Date column
                    SizedBox(
                      width: 42,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(fmt(txn.date).split(' ')[0],
                            style: jakarta(context,
                                size: 16,
                                weight: FontWeight.w800,
                                color: colors.textMain)),
                        Text(fmt(txn.date).split(' ')[1],
                            style: jakarta(context,
                                size: 10,
                                weight: FontWeight.w700,
                                color: colors.textMuted)
                                .copyWith(letterSpacing: 0.5)),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    // Type indicator
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isReturn
                            ? colors.redBg
                            : colors.tealBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isReturn
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        size: 14,
                        color: isReturn ? colors.red : colors.teal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Material + source
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(txn.materialName,
                            style: jakarta(context,
                                size: 13,
                                weight: FontWeight.w700,
                                color: colors.textMain),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Row(children: [
                          Text(
                              isReturn ? 'Return · ' : '',
                              style: jakarta(context,
                                  size: 10,
                                  color: isReturn
                                      ? colors.red
                                      : colors.textMuted)),
                          Text(txn.billNumber,
                              style: jakarta(context,
                                      size: 10,
                                      weight: FontWeight.w700,
                                      color: sourceBill != null
                                          ? colors.brand
                                          : colors.textMuted)
                                  .copyWith(letterSpacing: 0.5)),
                          if (sourceBill != null) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.open_in_new_rounded,
                                size: 10, color: colors.brand),
                          ],
                        ]),
                      ]),
                    ),
                    // Qty
                    Text(qtyText,
                        style: jakarta(context,
                            size: 16,
                            weight: FontWeight.w900,
                            color: qtyColor)),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────
class _DarkStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _DarkStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: GoogleFonts.playfairDisplay(
              fontSize: 28, fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 2),
      Text(label,
          style: jakarta(context,
                  size: 8,
                  weight: FontWeight.w800,
                  color: Colors.white.withOpacity(0.5))
              .copyWith(letterSpacing: 1.5)),
    ]);
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 0.5, height: 40, color: Colors.white.withOpacity(0.15));
  }
}
