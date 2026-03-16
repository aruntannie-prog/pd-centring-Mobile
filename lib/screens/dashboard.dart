import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/store.dart';
import '../models/bill.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class DashboardScreen extends StatelessWidget {
  final Function(int) onNav;
  final Function(Bill) onBillTap;
  final VoidCallback onAddCustomer;
  final VoidCallback onNewBill;
  final VoidCallback onSwitchBranch;
  const DashboardScreen(
      {super.key,
      required this.onNav,
      required this.onBillTap,
      required this.onAddCustomer,
      required this.onNewBill,
      required this.onSwitchBranch});

  static String getTodayString() {
    final now = DateTime.now();
    const mo = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${now.day} ${mo[now.month - 1]} ${now.year} · PD Centring';
  }

  static String getHeroDate() {
    final now = DateTime.now();
    const days = [
      'SUNDAY',
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY'
    ];
    const mo = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
    ];
    return '${days[now.weekday % 7]} · ${now.day} ${mo[now.month - 1]} ${now.year}';
  }

  static String getTodayCompact() {
    final now = DateTime.now();
    const mo = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${now.day} ${mo[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final colors = context.appColors;

    final branch = store.selectedBranch;
    final isKov = branch == 'Kovilambakkam';
    final branchColor = isKov ? colors.brand : colors.teal;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant,
                    border: Border.all(color: colors.border, width: 0.5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text('⌂   HOME',
                      style: jakarta(context,
                              size: 9,
                              weight: FontWeight.w800,
                              color: colors.textSub)
                          .copyWith(letterSpacing: 2)),
                ),
                const Spacer(),
                // Branch chip — tap to switch
                GestureDetector(
                  onTap: onSwitchBranch,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: branchColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: branchColor.withOpacity(0.3), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isKov ? Icons.location_city_rounded : Icons.storefront_rounded,
                            size: 12, color: branchColor),
                        const SizedBox(width: 5),
                        Text(
                          isKov ? 'Kovilambakkam' : 'Rathinamangalam',
                          style: jakarta(context,
                                  size: 9,
                                  weight: FontWeight.w800,
                                  color: branchColor)
                              .copyWith(letterSpacing: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.swap_horiz_rounded, size: 12, color: branchColor),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text.rich(TextSpan(children: [
              TextSpan(
                  text: 'Dash',
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: colors.textMain,
                      fontStyle: FontStyle.italic)),
              TextSpan(
                  text: 'board',
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
          child: RefreshIndicator(
            onRefresh: () async {
              await context.read<AppStore>().sync();
            },
            color: colors.brand,
            backgroundColor: colors.surface,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: 90 + MediaQuery.of(context).padding.bottom), // extra bottom padding for floating bar
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _HeroCard(store: store, onNav: onNav),
                const SizedBox(height: 20),
                _TodayBanner(count: store.todayCount, onNav: onNav),
                const SectionHeader('Quick Actions'),
                _QuickActions(
                    onNav: onNav,
                    onAddCustomer: onAddCustomer,
                    onNewBill: onNewBill),
              ]),
            ),
          ),
        ),
      ]);
  }
}

class _HeroCard extends StatelessWidget {
  final AppStore store;
  final Function(int) onNav;
  const _HeroCard({required this.store, required this.onNav});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
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
      child: Stack(children: [
        // Orbs for premium abstract background
        Positioned(
            right: -30,
            bottom: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: Colors.white.withOpacity(.04)),
            )),
        Positioned(
            left: 40,
            top: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: Colors.white.withOpacity(.02)),
            )),
        // PD Logo top right
        Positioned(
          right: 0,
          top: 0,
          child: Image.asset('assets/logo.png',
              width: 64, colorBlendMode: BlendMode.lighten),
        ),

        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(DashboardScreen.getHeroDate(),
              style: jakarta(context,
                      size: 10,
                      weight: FontWeight.w800,
                      color: Colors.white.withOpacity(.4))
                  .copyWith(letterSpacing: 2.5)),
          const SizedBox(height: 12),
          Text.rich(TextSpan(children: [
            TextSpan(
                text: 'PD ',
                style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
            TextSpan(
                text: 'Centring',
                style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF20E5CD),
                    fontStyle: FontStyle.italic)),
          ])),
          const SizedBox(height: 4),
          Text('Shuttering Rental Management',
              style: jakarta(context,
                  size: 11, color: Colors.white.withOpacity(.6))),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
                child: GestureDetector(
                  onTap: () => onNav(1),
                  child: _StatBox(
                      value: '${store.totalBills}', label: 'Total Bills'),
                )),
            const SizedBox(width: 12),
            Expanded(
                child: GestureDetector(
                  onTap: () => onNav(1),
                  child: _StatBox(
                      value: '${store.pendingCount}',
                      label: 'Pending Bills',
                      isRed: true),
                )),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _StatBox(
                    value: '${store.pendingMaterialsCount}',
                    label: 'Pending Items',
                    isAmber: true)),
            const SizedBox(width: 12),
            Expanded(
                child: _StatBox(
                    value: '${store.customersWithPendingCount}',
                    label: 'Customers',
                    isAmber: true)),
          ]),
        ]),
      ]),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value, label;
  final bool isRed;
  final bool isAmber;
  const _StatBox(
      {required this.value,
      required this.label,
      this.isRed = false,
      this.isAmber = false});
  @override
  Widget build(BuildContext context) {
    final Color valColor = isRed
        ? const Color(0xFFFF8A97)
        : isAmber
            ? const Color(0xFFFFCC70)
            : Colors.white;
    final Color bgColor = isRed
        ? const Color(0xFFFF4D5E).withOpacity(.15)
        : isAmber
            ? const Color(0xFFFFB800).withOpacity(.12)
            : Colors.white.withOpacity(.08);
    final Color borderColor = isRed
        ? const Color(0xFFFF4D5E).withOpacity(.3)
        : isAmber
            ? const Color(0xFFFFB800).withOpacity(.3)
            : Colors.white.withOpacity(.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: GoogleFonts.playfairDisplay(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: valColor)),
        const SizedBox(height: 4),
        Text(label.toUpperCase(),
            style: jakarta(context,
                    size: 9,
                    weight: FontWeight.w800,
                    color: Colors.white.withOpacity(.6))
                .copyWith(letterSpacing: 1.5)),
      ]),
    );
  }
}

class _TodayBanner extends StatelessWidget {
  final int count;
  final Function(int) onNav;
  const _TodayBanner({required this.count, required this.onNav});
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GestureDetector(
      onTap: () => onNav(1), // Nav to Bills where today's bills can be seen
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.tealBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.tealBd, width: 0.5),
        boxShadow: [
          BoxShadow(
              color: colors.glow, blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colors.surface.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: const Text('📋', style: TextStyle(fontSize: 22)),
        ),
        const SizedBox(width: 16),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Bills Added Today',
              style: jakarta(context,
                  size: 14, weight: FontWeight.w800, color: colors.teal)),
          const SizedBox(height: 2),
          Text('${DashboardScreen.getTodayCompact()} · Auto tracked',
              style: jakarta(context, size: 11, color: colors.textMuted)),
        ])),
        Text('$count',
            style: GoogleFonts.playfairDisplay(
                fontSize: 36, fontWeight: FontWeight.w900, color: colors.teal)),
      ]),
    ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final Function(int) onNav;
  final VoidCallback onAddCustomer;
  final VoidCallback onNewBill;
  const _QuickActions(
      {required this.onNav,
      required this.onAddCustomer,
      required this.onNewBill});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(children: [
      Expanded(
          child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onNewBill,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF097A6B), const Color(0xFF075A4E)]
                  : [const Color(0xFF0CAF98), const Color(0xFF097A6B)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.3)
                      : const Color(0xFF0CAF98).withOpacity(.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8)),
            ],
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.add_circle_outline_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(height: 12),
            Text('New Bill / DC',
                style: jakarta(context,
                    size: 13, weight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 4),
            Text('Create new entry',
                style: jakarta(context,
                    size: 10, color: Colors.white.withOpacity(.7))),
          ]),
        ),
      )),
      const SizedBox(width: 16),
      Expanded(
          child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onAddCustomer,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.border, width: 0.5),
            boxShadow: [
              BoxShadow(
                  color: colors.glow,
                  blurRadius: 16,
                  offset: const Offset(0, 6)),
            ],
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: colors.surfaceVariant, shape: BoxShape.circle),
              child: Icon(Icons.person_add_alt_1_rounded,
                  color: colors.brand, size: 28),
            ),
            const SizedBox(height: 12),
            Text('New Customer',
                style: jakarta(context,
                    size: 13, weight: FontWeight.w800, color: colors.textMain)),
            const SizedBox(height: 4),
            Text('Add client profile',
                style: jakarta(context, size: 10, color: colors.textMuted)),
          ]),
        ),
      )),
    ]);
  }
}
