import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/bill.dart';
import '../models/store.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class BillDetailScreen extends StatelessWidget {
  final Bill bill;
  final VoidCallback onBack;
  final Function(Bill) onEdit;
  const BillDetailScreen(
      {super.key,
      required this.bill,
      required this.onBack,
      required this.onEdit});

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
                                '${liveBill.materials.length} item${liveBill.materials.length > 1 ? "s" : ""}')),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: _InfoBox('Returned',
                                '${liveBill.returnedCount} / ${liveBill.materials.length}')),
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
              // Materials
              SectionHeader('MATERIALS — TAP TO MARK RETURNED'),
              ...liveBill.materials.map((m) {
                final ret = m.isReturned;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: ret ? colors.tealBg : colors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: ret ? colors.tealBd : colors.border, width: 0.5),
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
                                      const SizedBox(height: 4),
                                      Text('${m.days} days for rent',
                                          style: jakarta(context,
                                              size: 12,
                                              color: colors.textMuted)),
                                      const SizedBox(height: 6),
                                      Text('Due: ${m.dueDateFormatted}',
                                          style: jakarta(context,
                                              size: 12,
                                              weight: FontWeight.w700,
                                              color: ret
                                                  ? colors.teal
                                                  : const Color(0xFFFF5555))),
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
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                context
                                    .read<AppStore>()
                                    .markMaterialReturned(liveBill.id, m.id);
                              },
                              child: Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isDark
                                        ? [
                                            const Color(0xFF097A6B),
                                            const Color(0xFF075A4E)
                                          ]
                                        : [
                                            const Color(0xFF0CAF98),
                                            const Color(0xFF097A6B)
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                        color: (isDark
                                                ? const Color(0xFF097A6B)
                                                : const Color(0xFF0CAF98))
                                            .withOpacity(.3),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                          Icons.check_circle_outline_rounded,
                                          color: Colors.white,
                                          size: 22),
                                      const SizedBox(width: 8),
                                      Text('MARK AS RETURNED',
                                          style: jakarta(context,
                                                  size: 13,
                                                  weight: FontWeight.w800,
                                                  color: Colors.white)
                                              .copyWith(letterSpacing: .5)),
                                    ]),
                              ),
                            ),
                        ]),
                  ),
                );
              }),
            ]),
          ),
        ),
      ]),
    );
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
