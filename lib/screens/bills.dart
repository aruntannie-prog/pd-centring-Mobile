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

class _BillsScreenState extends State<BillsScreen> {
  String _filter = 'all';
  String _search = '';
  final _chips = ['All', 'Pending', 'Returned', 'DC'];
  final _keys = ['all', 'pending', 'returned', 'dc'];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final bills = store.filtered(_filter, _search);
    final colors = context.appColors;

    return Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                      text: 'Bills &   ',
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
          ]),
        ),
        // Body
        Expanded(
          child: Stack(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(children: [
                SearchBar2(
                    hint: 'Name, bill no, site...',
                    count: '${bills.length}',
                    onChanged: (v) => setState(() => _search = v)),
                // Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                      children: List.generate(_chips.length, (i) {
                    final on = _keys[i] == _filter;
                    return GestureDetector(
                      onTap: () => setState(() => _filter = _keys[i]),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8, bottom: 16),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: on ? colors.brand : colors.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: on ? colors.brand : colors.border,
                              width: 0.5),
                          boxShadow: on
                               ? [
                                   BoxShadow(
                                       color: colors.brand.withOpacity(0.3),
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
                        child: Text(_chips[i],
                            style: jakarta(context,
                                size: 11,
                                weight: FontWeight.w700,
                                color: on ? colors.surface : colors.textSub)),
                      ),
                    );
                  })),
                ),
                // List
                Expanded(
                  child: !store.loaded
                      ? Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 3, color: colors.brand))
                      : bills.isEmpty
                          ? Center(
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                  Icon(Icons.search_off_rounded,
                                      size: 48,
                                      color: colors.textMuted.withOpacity(0.5)),
                                  const SizedBox(height: 16),
                                  Text('No bills found',
                                      style: jakarta(context,
                                          size: 16,
                                          weight: FontWeight.w700,
                                          color: colors.textSub)),
                                  const SizedBox(height: 4),
                                  Text('Try a different filter',
                                      style: jakarta(context,
                                          size: 12, color: colors.textMuted)),
                                ]))
                          : ListView.builder(
                          padding: EdgeInsets.only(
                              bottom:
                                  95 + MediaQuery.of(context).padding.bottom), // extra padding for bottom nav & FAB
                          itemCount: bills.length,
                          itemBuilder: (_, i) => BillCard(
                              bill: bills[i],
                              onTap: () => widget.onBillTap(bills[i])),
                        ),
                ),
              ]),
            ),
          ]),
        ),
      ]);
  }
}
