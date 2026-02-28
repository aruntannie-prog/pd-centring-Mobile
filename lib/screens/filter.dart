import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/bill.dart';
import '../models/store.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class FilterScreen extends StatefulWidget {
  final Function(Bill) onBillTap;
  const FilterScreen({super.key, required this.onBillTap});
  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  String? _activeFilter;
  String _search = '';
  bool _showResults = false;
  final FocusNode _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  List<Bill> _getResults(AppStore store) {
    if (_search.isNotEmpty) {
      return store.filtered(null, _search);
    }
    if (_activeFilter == null) return [];
    return store.filtered(_activeFilter, '');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final results = _getResults(store);
    final counts = {
      'pending': store.filtered('pending', '').length,
      'partial': store.filtered('partial', '').length,
      'returned': store.filtered('returned', '').length,
      'dc': store.filtered('dc', '').length,
      'overdue': store.filtered('overdue', '').length,
      'week': store.filtered('week', '').length,
    };
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(children: [
      // Header
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text.rich(TextSpan(children: [
            TextSpan(
                text: 'Filter ',
                style: GoogleFonts.playfairDisplay(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: colors.textMain)),
            TextSpan(
                text: 'Bills',
                style: GoogleFonts.playfairDisplay(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: colors.brand,
                    fontStyle: FontStyle.italic)),
          ])),
          const SizedBox(height: 4),
          Text(
              _activeFilter == null && _search.isEmpty
                  ? 'Tap any option to filter'
                  : '${results.length} bills found',
              style: jakarta(context, size: 13, color: colors.textMuted)),
        ]),
      ),
      // Body
      Expanded(
        child: _showResults
            ? Column(children: [
                // Results Header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() {
                          _showResults = false;
                          _search = '';
                          _activeFilter = null;
                        }),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                              color: colors.surfaceVariant,
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: colors.border, width: 0.5)),
                          child: Row(children: [
                            Icon(Icons.arrow_back_ios_new_rounded,
                                size: 14, color: colors.textMain),
                            const SizedBox(width: 6),
                            Text('Filters',
                                style: jakarta(context,
                                    size: 12,
                                    weight: FontWeight.w700,
                                    color: colors.textMain)),
                          ]),
                        ),
                      ),
                      const Spacer(),
                      Text(
                          '${results.length} BILL${results.length == 1 ? "" : "S"} FOUND',
                          style: jakarta(context,
                                  size: 10,
                                  weight: FontWeight.w800,
                                  color: colors.textMuted)
                              .copyWith(letterSpacing: 2)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                        20, 8, 20, 100 + MediaQuery.of(context).padding.bottom),
                    itemCount: results.length,
                    itemBuilder: (_, i) => BillCard(
                        bill: results[i],
                        onTap: () => widget.onBillTap(results[i])),
                  ),
                ),
              ])
            : SingleChildScrollView(
                padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: 100 + MediaQuery.of(context).padding.bottom),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search
                      SearchBar2(
                        focusNode: _searchFocus,
                        hint: 'Bill no, name, phone...',
                        count: '${results.length}',
                        onChanged: (v) {
                          setState(() {
                            _search = v;
                            _activeFilter = null;
                          });
                        },
                        onSubmitted: (v) {
                          if (v.isNotEmpty) setState(() => _showResults = true);
                        },
                      ),
                      const SizedBox(height: 8),
                      // Status group
                      _FilterGroup(
                        title: 'By Material Status',
                        items: [
                          _FilterItem(
                              '🔴',
                              'Pending',
                              'Pending Bills & DCs',
                              'rd',
                              counts['pending'] ?? 0,
                              'pending',
                              colors,
                              isDark),
                          _FilterItem(
                              '📝',
                              'Delivery Challan (DC)',
                              'Only DCs',
                              'in',
                              counts['dc'] ?? 0,
                              'dc',
                              colors,
                              isDark),
                          _FilterItem(
                              '🟠',
                              'Partial Return',
                              'Some materials returned',
                              'am',
                              counts['partial'] ?? 0,
                              'partial',
                              colors,
                              isDark),
                          _FilterItem(
                              '✅',
                              'All Returned',
                              'Bill fully closed',
                              'tl',
                              counts['returned'] ?? 0,
                              'returned',
                              colors,
                              isDark),
                        ],
                        activeFilter: _activeFilter,
                        onTap: (f) => setState(() {
                          _activeFilter = f;
                          _search = '';
                          _showResults = true;
                        }),
                        colors: colors,
                      ),
                      const SizedBox(height: 16),
                      // Due date group
                      _FilterGroup(
                        title: 'By Due Date',
                        items: [
                          _FilterItem(
                              '⚠️',
                              'Overdue',
                              'Past due, not returned',
                              'rd',
                              counts['overdue'] ?? 0,
                              'overdue',
                              colors,
                              isDark),
                          _FilterItem('📅', 'Due This Week', '', 'gl',
                              counts['week'] ?? 0, 'week', colors, isDark),
                        ],
                        activeFilter: _activeFilter,
                        onTap: (f) => setState(() {
                          _activeFilter = f;
                          _search = '';
                          _showResults = true;
                        }),
                        colors: colors,
                      ),
                      const SizedBox(height: 16),
                      // Search group
                      _FilterGroup(
                        title: 'By Customer / Bill',
                        items: [
                          _FilterItem('📞', 'By Phone Number', '', 'gl', 0,
                              'phone', colors, isDark),
                          _FilterItem('🔢', 'By Bill Number', '', 'gl', 0,
                              'billno', colors, isDark),
                          _FilterItem('📍', 'By Site Location', '', 'gl', 0,
                              'site', colors, isDark),
                        ],
                        activeFilter: _activeFilter,
                        onTap: (f) {
                          _searchFocus.requestFocus();
                        },
                        colors: colors,
                      ),
                    ]),
              ),
      ),
    ]);
  }
}

class _FilterItem {
  final String emoji, name, sub, colorKey;
  final int count;
  final String filterKey;
  final AppColors colors;
  final bool isDark;
  const _FilterItem(this.emoji, this.name, this.sub, this.colorKey, this.count,
      this.filterKey, this.colors, this.isDark);

  Color getBg() {
    return switch (colorKey) {
      'rd' => isDark
          ? const Color(0xFFFF5555).withOpacity(0.15)
          : const Color(0xFFFFF0F1),
      'tl' => colors.tealBg,
      'in' => isDark
          ? const Color(0xFF14224A).withOpacity(0.5)
          : const Color(0xFFF0F4FF),
      'am' => isDark
          ? const Color(0xFFD49900).withOpacity(0.15)
          : const Color(0xFFFFF9EE),
      _ => colors.surfaceVariant,
    };
  }
}

class _FilterGroup extends StatelessWidget {
  final String title;
  final List<_FilterItem> items;
  final String? activeFilter;
  final Function(String) onTap;
  final AppColors colors;
  const _FilterGroup(
      {required this.title,
      required this.items,
      required this.activeFilter,
      required this.onTap,
      required this.colors});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.border, width: 0.5),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: colors.glow,
                  blurRadius: 16,
                  offset: const Offset(0, 4))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.toUpperCase(),
              style: jakarta(context,
                      size: 10,
                      weight: FontWeight.w800,
                      color: colors.textMuted)
                  .copyWith(letterSpacing: 2)),
          const SizedBox(height: 16),
          ...items.asMap().entries.map((e) {
            final item = e.value;
            final active = activeFilter == item.filterKey;
            return GestureDetector(
              onTap: () => onTap(item.filterKey),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                    vertical: 12, horizontal: active ? 16 : 8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: active
                      ? colors.brand.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: item.getBg(),
                          borderRadius: BorderRadius.circular(14)),
                      child: Center(
                          child: Text(item.emoji,
                              style: const TextStyle(fontSize: 20)))),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(item.name,
                            style: jakarta(context,
                                size: 14,
                                weight: FontWeight.w800,
                                color:
                                    active ? colors.brand : colors.textMain)),
                        if (item.sub.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(item.sub,
                              style: jakarta(context,
                                  size: 11, color: colors.textMuted)),
                        ]
                      ])),
                  if (item.count > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12)),
                      child: Text('${item.count}',
                          style: jakarta(context,
                              size: 11,
                              weight: FontWeight.w800,
                              color: colors.textSub)),
                    ),
                  const SizedBox(width: 12),
                  Icon(Icons.chevron_right_rounded,
                      color: colors.textMuted, size: 24),
                ]),
              ),
            );
          }),
        ]),
      );
}
