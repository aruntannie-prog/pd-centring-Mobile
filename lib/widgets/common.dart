import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/bill.dart';

// ── Status Pill ──
class StatusPill extends StatelessWidget {
  final BillStatus status;
  const StatusPill(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final cfg = _cfg(status, colors);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cfg.$1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cfg.$2, width: 0.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _Dot(cfg.$2, blink: status == BillStatus.allPending),
        const SizedBox(width: 5),
        Text(cfg.$3,
            style: jakarta(context,
                    size: 8.5, weight: FontWeight.w800, color: cfg.$2)
                .copyWith(letterSpacing: .8)),
      ]),
    );
  }

  (Color, Color, String) _cfg(BillStatus s, AppColors c) => switch (s) {
        BillStatus.allPending => (c.redBg, c.red, 'All Pending'),
        BillStatus.partial => (c.amberBg, c.amber, 'Partial Return'),
        BillStatus.allReturned => (c.tealBg, c.teal, 'All Returned'),
        BillStatus.dc => (c.indigoBg, c.indigo, 'DC Bill'),
      };
}

class MaterialPill extends StatelessWidget {
  final MaterialStatus status;
  const MaterialPill(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final ret = status == MaterialStatus.returned;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: ret ? colors.tealBg : colors.redBg,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: ret ? colors.tealBd : colors.redBd, width: 0.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: ret ? colors.teal : colors.red)),
        const SizedBox(width: 5),
        Text(ret ? 'Returned ✓' : 'Pending',
            style: jakarta(context,
                    size: 8.5,
                    weight: FontWeight.w800,
                    color: ret ? colors.teal : colors.red)
                .copyWith(letterSpacing: .6)),
      ]),
    );
  }
}

class _Dot extends StatefulWidget {
  final Color color;
  final bool blink;
  const _Dot(this.color, {this.blink = false});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color));
    if (!widget.blink) return dot;
    return FadeTransition(
        opacity: Tween(begin: .2, end: 1.0).animate(_ac), child: dot);
  }
}

// ── Bill Card ──
class BillCard extends StatelessWidget {
  final Bill bill;
  final VoidCallback onTap;
  const BillCard({super.key, required this.bill, required this.onTap});

  Color _borderColor(AppColors c) => switch (bill.status) {
        BillStatus.allPending => c.red,
        BillStatus.partial => c.amber,
        BillStatus.allReturned => c.teal,
        BillStatus.dc => c.indigo,
      };

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
    final colors = context.appColors;
    final bColor = _borderColor(colors);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border, width: 0.5),
          boxShadow: [
            BoxShadow(
                color: colors.glow, blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left accent bar
              Container(
                width: 5,
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(20)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [bColor, bColor.withOpacity(.1)],
                  ),
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 16, 14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(bill.billNumber,
                                  style: jakarta(context,
                                          size: 10,
                                          weight: FontWeight.w800,
                                          color: bill.type == BillType.dc
                                              ? colors.indigo
                                              : colors.teal)
                                      .copyWith(letterSpacing: 2.5)),
                              StatusPill(bill.status),
                            ]),
                        const SizedBox(height: 8),
                        Text(bill.customerName,
                            style: jakarta(context,
                                size: 16,
                                weight: FontWeight.w800,
                                color: colors.textMain)),
                        const SizedBox(height: 4),
                        Text('📍 ${bill.site} · ${bill.billDateFormatted}',
                            style: jakarta(context,
                                size: 11, color: colors.textMuted)),
                        const SizedBox(height: 12),
                        ...bill.materials.map((m) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: m.isReturned
                                      ? colors.tealBg
                                      : colors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(10),
                                  border: m.isReturned
                                      ? Border.all(
                                          color: colors.tealBd, width: 0.5)
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(children: [
                                      Text('${matEmoji(m.name)} ${m.name}',
                                          style: jakarta(context,
                                              size: 12,
                                              weight: FontWeight.w700,
                                              color: colors.textSub)),
                                      const SizedBox(width: 8),
                                      Text('${m.days}d',
                                          style: jakarta(context,
                                              size: 11,
                                              color: colors.textMuted)),
                                    ]),
                                    Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          MaterialPill(m.status),
                                          const SizedBox(height: 4),
                                          Text(
                                              m.isReturned
                                                  ? 'Done'
                                                  : 'Due: ${m.dueDateFormatted}',
                                              style: jakarta(context,
                                                  size: 10,
                                                  weight: FontWeight.w700,
                                                  color: m.isReturned
                                                      ? colors.teal
                                                      : colors.red)),
                                        ]),
                                  ],
                                ),
                              ),
                            )),
                      ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Search Bar ──
class SearchBar2 extends StatelessWidget {
  final String hint;
  final String count;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  const SearchBar2(
      {super.key,
      required this.hint,
      required this.count,
      required this.onChanged,
      this.onSubmitted,
      this.focusNode});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
              color: colors.glow, blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(children: [
        Padding(
            padding: const EdgeInsets.only(left: 16),
            child:
                Icon(Icons.search_rounded, size: 20, color: colors.textMuted)),
        Expanded(
            child: TextField(
          focusNode: focusNode,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: jakarta(context, size: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: jakarta(context, color: colors.textMuted),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        )),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(count,
                style: jakarta(context,
                    size: 11, weight: FontWeight.w800, color: colors.textSub)),
          ),
        ),
      ]),
    );
  }
}

// ── Section Header ──
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title.toUpperCase(),
            style: jakarta(context,
                    size: 10, weight: FontWeight.w800, color: colors.textMuted)
                .copyWith(letterSpacing: 2)),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!,
                style: jakarta(context,
                    size: 12, weight: FontWeight.w700, color: colors.teal)),
          ),
      ]),
    );
  }
}

// ── Chip Row ──
class FilterChips extends StatefulWidget {
  final List<String> labels;
  final int initial;
  final ValueChanged<int> onChanged;
  const FilterChips(
      {super.key,
      required this.labels,
      this.initial = 0,
      required this.onChanged});
  @override
  State<FilterChips> createState() => _FilterChipsState();
}

class _FilterChipsState extends State<FilterChips> {
  late int _sel;
  @override
  void initState() {
    super.initState();
    _sel = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
            children: List.generate(widget.labels.length, (i) {
          final on = i == _sel;
          return GestureDetector(
            onTap: () {
              setState(() => _sel = i);
              widget.onChanged(i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: on ? colors.brand : colors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: on ? colors.brand : colors.border, width: 0.5),
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
              child: Text(widget.labels[i],
                  style: jakarta(context,
                      size: 11,
                      weight: FontWeight.w700,
                      color: on ? colors.surface : colors.textSub)),
            ),
          );
        })),
      ),
    );
  }
}
