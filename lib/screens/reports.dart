import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/bill.dart';
import '../models/store.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final returned =
        store.bills.where((b) => b.status == BillStatus.allReturned).length;
    final pending = store.bills
        .where((b) =>
            b.status == BillStatus.allPending || b.status == BillStatus.partial)
        .length;
    final dc = store.bills.where((b) => b.type == BillType.dc).length;

    // Aggregations
    final materialMap = <String, int>{};
    final locationMap = <String, int>{};
    for (final b in store.bills) {
      locationMap[b.site] = (locationMap[b.site] ?? 0) + 1;
      for (final m in b.materials) {
        materialMap[m.name] = (materialMap[m.name] ?? 0) + 1;
      }
    }

    final topMaterials = materialMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topLocations = locationMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxMatCount = topMaterials.isEmpty ? 1 : topMaterials.first.value;
    final maxLocCount = topLocations.isEmpty ? 1 : topLocations.first.value;
    final activeZones = topLocations.length;

    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
        bottom: false,
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('▣   ANALYTICS',
                  style: jakarta(context,
                          size: 9,
                          weight: FontWeight.w800,
                          color: colors.textSub)
                      .copyWith(letterSpacing: 2)),
              const SizedBox(height: 12),
              Text('Reports',
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: colors.brand,
                      fontStyle: FontStyle.italic)),
              const SizedBox(height: 4),
              Text('All-time · PD Centring',
                  style: jakarta(context, size: 13, color: colors.textMuted)),
            ]),
          ),
          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: 100 + MediaQuery.of(context).padding.bottom),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  const Color(0xFF1E3A8A),
                                  const Color(0xFF162B66)
                                ]
                              : [
                                  const Color(0xFF2563EB),
                                  const Color(0xFF1D4ED8)
                                ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                              color: (isDark
                                      ? const Color(0xFF1E3A8A)
                                      : const Color(0xFF2563EB))
                                  .withOpacity(.3),
                              blurRadius: 24,
                              offset: const Offset(0, 8))
                        ],
                      ),
                      child: Stack(children: [
                        Positioned(
                            right: -30,
                            top: -30,
                            child: Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(.05)))),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('TOTAL BILLS ISSUED',
                                  style: jakarta(context,
                                          size: 10,
                                          weight: FontWeight.w800,
                                          color: Colors.white.withOpacity(.5))
                                      .copyWith(letterSpacing: 2)),
                              const SizedBox(height: 12),
                              Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${store.totalBills}',
                                        style: GoogleFonts.playfairDisplay(
                                            fontSize: 48,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: -1)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(.1),
                                          border: Border.all(
                                              color:
                                                  Colors.white.withOpacity(.2)),
                                          borderRadius:
                                              BorderRadius.circular(16)),
                                      child: Column(children: [
                                        Text('${store.totalCustomers}',
                                            style: GoogleFonts.playfairDisplay(
                                                fontSize: 24,
                                                fontWeight: FontWeight.w800,
                                                color:
                                                    const Color(0xFFFFDCA8))),
                                        const SizedBox(height: 4),
                                        Text('CLIENTS',
                                            style: jakarta(context,
                                                    size: 9,
                                                    weight: FontWeight.w800,
                                                    color: Colors.white
                                                        .withOpacity(.6))
                                                .copyWith(letterSpacing: 1.5)),
                                      ]),
                                    ),
                                  ]),
                              const SizedBox(height: 12),
                              Text('Live Database Sync Active · All time data',
                                  style: jakarta(context,
                                      size: 11,
                                      color: Colors.white.withOpacity(.5))),
                            ]),
                      ]),
                    ),
                    const SizedBox(height: 24),

                    // KPI grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      childAspectRatio: 1.15,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      children: [
                        _KpiCard('✅', '$returned', 'All Returned', colors.teal,
                            colors),
                        _KpiCard('⏳', '$pending', 'Still Pending',
                            const Color(0xFFFF5555), colors),
                        _KpiCard('🚛', '$dc', 'DC Bills',
                            const Color(0xFF6B4EE6), colors),
                        _KpiCard(
                            '📍',
                            '$activeZones',
                            'Active Zones',
                            isDark
                                ? const Color(0xFFFFC043)
                                : const Color(0xFFB18000),
                            colors),
                      ],
                    ),
                    const SizedBox(height: 32),

                    if (topMaterials.isNotEmpty) ...[
                      const SectionHeader('Top Materials'),
                      ...topMaterials.take(5).map((e) => _Bar(
                          e.key,
                          e.value,
                          maxMatCount,
                          [const Color(0xFF6B4EE6), const Color(0xFF9070FF)],
                          colors)),
                      const SizedBox(height: 16),
                    ],

                    if (topLocations.isNotEmpty) ...[
                      const SectionHeader('Top Locations'),
                      ...topLocations.take(5).map((e) => _Bar(
                          '📍 ${e.key}',
                          e.value,
                          maxLocCount,
                          [colors.brand, colors.teal],
                          colors)),
                      const SizedBox(height: 20),
                    ],
                  ]),
            ),
          ),
        ]));
  }
}

class _KpiCard extends StatelessWidget {
  final String icon, value, label;
  final Color accentColor;
  final AppColors colors;
  const _KpiCard(
      this.icon, this.value, this.label, this.accentColor, this.colors);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border, width: 0.5),
          boxShadow: [
            BoxShadow(
                color: colors.glow, blurRadius: 16, offset: const Offset(0, 4))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor,
                    boxShadow: [
                      BoxShadow(
                          color: accentColor.withOpacity(0.5), blurRadius: 4)
                    ]))
          ]),
          const Spacer(),
          Text(value,
              style: GoogleFonts.playfairDisplay(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: colors.textMain,
                  letterSpacing: -1)),
          const SizedBox(height: 4),
          Text(label.toUpperCase(),
              style: jakarta(context,
                      size: 9, weight: FontWeight.w800, color: colors.textMuted)
                  .copyWith(letterSpacing: 1)),
        ]),
      );
}

class _Bar extends StatelessWidget {
  final String label;
  final int value, max;
  final List<Color> barColors;
  final AppColors colors;
  const _Bar(this.label, this.value, this.max, this.barColors, this.colors);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label,
                style: jakarta(context,
                    size: 12, weight: FontWeight.w700, color: colors.textMain)),
            Text('$value',
                style: jakarta(context,
                    size: 12, weight: FontWeight.w800, color: colors.brand)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(children: [
              Container(height: 8, color: colors.surfaceVariant),
              FractionallySizedBox(
                widthFactor: value / max,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(colors: barColors),
                      boxShadow: [
                        BoxShadow(
                            color: barColors[0].withOpacity(0.5), blurRadius: 4)
                      ]),
                ),
              ),
            ]),
          ),
        ]),
      );
}
