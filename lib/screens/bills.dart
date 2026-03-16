import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/store.dart';
import '../models/bill.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class BillsScreen extends StatefulWidget {
  final Function(Bill) onBillTap;
  final VoidCallback onNewBill;
  const BillsScreen(
      {super.key, required this.onBillTap, required this.onNewBill});
  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  // DC tab state
  String _dcFilter = 'all';
  String _dcSearch = '';

  // Bills tab state
  String _billFilter = 'all';
  String _billSearch = '';

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

  List<Bill> _dcList(AppStore store) {
    var list = store.bills.where((b) => b.type == BillType.dc).toList();
    if (_dcFilter == 'unbilled') list = list.where((b) => !b.isBilled).toList();
    if (_dcFilter == 'billed') list = list.where((b) => b.isBilled).toList();
    if (_dcFilter == 'overdue') list = list.where((b) => b.isOverdue && !b.isBilled).toList();
    if (_dcSearch.isNotEmpty) {
      final q = _dcSearch.toLowerCase();
      list = list
          .where((b) =>
              b.customerName.toLowerCase().contains(q) ||
              b.billNumber.toLowerCase().contains(q) ||
              b.site.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  List<Bill> _billList(AppStore store) {
    var list = store.bills.where((b) => b.type == BillType.bill).toList();
    if (_billFilter == 'pending') {
      list = list
          .where((b) =>
              b.status == BillStatus.allPending ||
              b.status == BillStatus.partial)
          .toList();
    } else if (_billFilter == 'overdue') {
      list = list.where((b) => b.status == BillStatus.overdue).toList();
    } else if (_billFilter == 'partial') {
      list = list.where((b) => b.status == BillStatus.partial).toList();
    } else if (_billFilter == 'returned') {
      list = list.where((b) => b.status == BillStatus.allReturned).toList();
    }
    if (_billSearch.isNotEmpty) {
      final q = _billSearch.toLowerCase();
      list = list
          .where((b) =>
              b.customerName.toLowerCase().contains(q) ||
              b.billNumber.toLowerCase().contains(q) ||
              b.site.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final colors = context.appColors;
    final dcList = _dcList(store);
    final billList = _billList(store);
    final dcTotal = store.bills.where((b) => b.type == BillType.dc).length;
    final billTotal = store.bills.where((b) => b.type == BillType.bill).length;
    final isDcTab = _tab.index == 0;

    return Column(children: [
      // Header
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                border: Border.all(color: colors.border, width: 0.5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text('◉   REGISTER',
                  style: jakarta(context,
                          size: 9,
                          weight: FontWeight.w800,
                          color: colors.textSub)
                      .copyWith(letterSpacing: 2))),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text.rich(TextSpan(children: [
                TextSpan(
                    text: 'Bills &  ',
                    style: GoogleFonts.playfairDisplay(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: colors.textMain)),
                TextSpan(
                    text: 'DC',
                    style: GoogleFonts.playfairDisplay(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: colors.teal,
                        fontStyle: FontStyle.italic)),
              ])),
              GestureDetector(
                onTap: widget.onNewBill,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.brand,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: colors.brand.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Text('+ ADD',
                      style: jakarta(context,
                          size: 12,
                          weight: FontWeight.w800,
                          color: colors.surface)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${store.totalBills} total · ${store.pendingCount} pending',
              style: jakarta(context, size: 12, color: colors.textMuted)),
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
              labelStyle:
                  jakarta(context, size: 12, weight: FontWeight.w800),
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
                        Icon(Icons.local_shipping_outlined,
                            size: 14,
                            color: isDcTab ? colors.teal : colors.textMuted),
                        const SizedBox(width: 6),
                        Text('DC Bills'),
                        const SizedBox(width: 6),
                        _TabBadge(
                          count: dcTotal,
                          active: isDcTab,
                          activeColor: colors.teal,
                          colors: colors,
                        ),
                      ]),
                ),
                Tab(
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 14,
                            color:
                                !isDcTab ? colors.brand : colors.textMuted),
                        const SizedBox(width: 6),
                        Text('Final Bills'),
                        const SizedBox(width: 6),
                        _TabBadge(
                          count: billTotal,
                          active: !isDcTab,
                          activeColor: colors.brand,
                          colors: colors,
                        ),
                      ]),
                ),
              ],
            ),
          ),
        ]),
      ),
      // Tab views
      Expanded(
        child: TabBarView(
          controller: _tab,
          children: [
            _DcTabContent(
              dcList: dcList,
              filter: _dcFilter,
              store: store,
              onFilterChange: (f) => setState(() => _dcFilter = f),
              onSearchChange: (v) => setState(() => _dcSearch = v),
              onBillTap: widget.onBillTap,
            ),
            _BillTabContent(
              billList: billList,
              filter: _billFilter,
              store: store,
              onFilterChange: (f) => setState(() => _billFilter = f),
              onSearchChange: (v) => setState(() => _billSearch = v),
              onBillTap: widget.onBillTap,
            ),
          ],
        ),
      ),
    ]);
  }
}

// ── Tab Badge ──────────────────────────────────────────────────────────────────
class _TabBadge extends StatelessWidget {
  final int count;
  final bool active;
  final Color activeColor;
  final AppColors colors;
  const _TabBadge(
      {required this.count,
      required this.active,
      required this.activeColor,
      required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: active
            ? activeColor.withOpacity(0.15)
            : colors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$count',
          style: jakarta(context,
              size: 10,
              weight: FontWeight.w800,
              color: active ? activeColor : colors.textMuted)),
    );
  }
}

// ── DC Tab Content ─────────────────────────────────────────────────────────────
class _DcTabContent extends StatelessWidget {
  final List<Bill> dcList;
  final String filter;
  final AppStore store;
  final ValueChanged<String> onFilterChange;
  final ValueChanged<String> onSearchChange;
  final Function(Bill) onBillTap;

  const _DcTabContent({
    required this.dcList,
    required this.filter,
    required this.store,
    required this.onFilterChange,
    required this.onSearchChange,
    required this.onBillTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final chips = ['All', 'Unbilled', 'Billed', 'Overdue'];
    final keys = ['all', 'unbilled', 'billed', 'overdue'];
    final chipColors = [colors.textSub, colors.indigo, colors.teal, colors.red];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(children: [
        SearchBar2(
          hint: 'Customer, DC no, site...',
          count: '${dcList.length}',
          onChanged: onSearchChange,
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
              children: List.generate(chips.length, (i) {
            final on = keys[i] == filter;
            final chipColor = on ? chipColors[i] : colors.textSub;
            return GestureDetector(
              onTap: () => onFilterChange(keys[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8, bottom: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: on ? chipColor.withOpacity(0.12) : colors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: on ? chipColor : colors.border, width: 0.5),
                  boxShadow: on
                      ? [
                          BoxShadow(
                              color: chipColor.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ]
                      : [
                          BoxShadow(
                              color: colors.glow,
                              blurRadius: 4,
                              offset: const Offset(0, 2))
                        ],
                ),
                child: Text(chips[i],
                    style: jakarta(context,
                        size: 11,
                        weight: FontWeight.w700,
                        color: on ? chipColor : colors.textSub)),
              ),
            );
          })),
        ),
        Expanded(
          child: !store.loaded
              ? Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 3, color: colors.teal))
              : dcList.isEmpty
                  ? _EmptyState(
                      label: 'No DC records found',
                      sub: 'Try a different filter',
                      colors: colors,
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(
                          bottom: 95 + MediaQuery.of(context).padding.bottom),
                      itemCount: dcList.length,
                      itemBuilder: (_, i) => BillCard(
                            bill: dcList[i],
                            onTap: () => onBillTap(dcList[i]),
                          ),
                    ),
        ),
      ]),
    );
  }
}

// ── Final Bills Tab Content ────────────────────────────────────────────────────
class _BillTabContent extends StatelessWidget {
  final List<Bill> billList;
  final String filter;
  final AppStore store;
  final ValueChanged<String> onFilterChange;
  final ValueChanged<String> onSearchChange;
  final Function(Bill) onBillTap;

  const _BillTabContent({
    required this.billList,
    required this.filter,
    required this.store,
    required this.onFilterChange,
    required this.onSearchChange,
    required this.onBillTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final chips = ['All', 'Pending', 'Overdue', 'Partial', 'Returned'];
    final keys = ['all', 'pending', 'overdue', 'partial', 'returned'];

    final chipColors = [colors.textSub, colors.brand, colors.red, colors.amber, colors.teal];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(children: [
        SearchBar2(
          hint: 'Customer, bill no, site...',
          count: '${billList.length}',
          onChanged: onSearchChange,
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
              children: List.generate(chips.length, (i) {
            final on = keys[i] == filter;
            final chipColor = on ? chipColors[i] : colors.textSub;
            return GestureDetector(
              onTap: () => onFilterChange(keys[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8, bottom: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: on ? chipColor.withOpacity(0.12) : colors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: on ? chipColor : colors.border, width: 0.5),
                  boxShadow: on
                      ? [
                          BoxShadow(
                              color: chipColor.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ]
                      : [
                          BoxShadow(
                              color: colors.glow,
                              blurRadius: 4,
                              offset: const Offset(0, 2))
                        ],
                ),
                child: Text(chips[i],
                    style: jakarta(context,
                        size: 11,
                        weight: FontWeight.w700,
                        color: on ? chipColor : colors.textSub)),
              ),
            );
          })),
        ),
        Expanded(
          child: !store.loaded
              ? Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 3, color: colors.brand))
              : billList.isEmpty
                  ? _EmptyState(
                      label: 'No bills found',
                      sub: 'Try a different filter',
                      colors: colors,
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(
                          bottom: 95 + MediaQuery.of(context).padding.bottom),
                      itemCount: billList.length,
                      itemBuilder: (_, i) => BillCard(
                            bill: billList[i],
                            onTap: () => onBillTap(billList[i]),
                          ),
                    ),
        ),
      ]),
    );
  }
}

// ── Empty State ────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String label;
  final String sub;
  final AppColors colors;
  const _EmptyState(
      {required this.label, required this.sub, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.search_off_rounded,
            size: 48, color: colors.textMuted.withOpacity(0.5)),
        const SizedBox(height: 16),
        Text(label,
            style: jakarta(context,
                size: 16, weight: FontWeight.w700, color: colors.textSub)),
        const SizedBox(height: 4),
        Text(sub,
            style: jakarta(context, size: 12, color: colors.textMuted)),
      ]),
    );
  }
}
