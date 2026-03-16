import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/store.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart'; // ignore: unused_import

class BranchSelectScreen extends StatefulWidget {
  final void Function(String branch) onSelected;
  final bool isSwitching; // true = came from inside the app to switch
  const BranchSelectScreen({
    super.key,
    required this.onSelected,
    this.isSwitching = false,
  });
  @override
  State<BranchSelectScreen> createState() => _BranchSelectScreenState();
}

class _BranchSelectScreenState extends State<BranchSelectScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade, _slide;
  String? _tapped;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut)
        .drive(Tween(begin: 0.0, end: 1.0));
    _slide = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic)
        .drive(Tween(begin: 32.0, end: 0.0));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pick(String branch) async {
    if (_tapped != null) return;
    setState(() => _tapped = branch);
    await context.read<AppStore>().setSelectedBranch(branch);
    await Future.delayed(const Duration(milliseconds: 220));
    widget.onSelected(branch);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final store = context.watch<AppStore>();

    // Bill counts from unfiltered data — always show real numbers for both branches
    final kovCount = store.billCountForBranch('Kovilambakkam');
    final ratCount = store.billCountForBranch('Rathinamangalam');

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) => Opacity(
            opacity: _fade.value,
            child: Transform.translate(
              offset: Offset(0, _slide.value),
              child: child,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                // Logo badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colors.border, width: 0.5),
                  ),
                  child: Text(
                    widget.isSwitching ? '⇄   SWITCH BRANCH' : '⊕   SELECT BRANCH',
                    style: jakarta(context,
                            size: 9,
                            weight: FontWeight.w800,
                            color: colors.textSub)
                        .copyWith(letterSpacing: 2),
                  ),
                ),
                const SizedBox(height: 20),
                Text.rich(TextSpan(children: [
                  TextSpan(
                      text: widget.isSwitching ? 'Switch ' : 'Choose your ',
                      style: GoogleFonts.playfairDisplay(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: colors.textMain)),
                  TextSpan(
                      text: 'Branch',
                      style: GoogleFonts.playfairDisplay(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: colors.brand,
                          fontStyle: FontStyle.italic)),
                ])),
                const SizedBox(height: 8),
                Text(
                  'All bills, clients, and reports will be\nscoped to the selected branch.',
                  style:
                      jakarta(context, size: 13, color: colors.textMuted),
                ),
                const SizedBox(height: 40),
                // Kovilambakkam card
                _BranchCard(
                  name: 'Kovilambakkam',
                  tagline: 'Main Branch · South Chennai',
                  icon: Icons.location_city_rounded,
                  billCount: kovCount,
                  isSelected: _tapped == 'Kovilambakkam' ||
                      (widget.isSwitching &&
                          store.selectedBranch == 'Kovilambakkam' &&
                          _tapped == null),
                  accentColor: colors.brand,
                  bgColor: isDark
                      ? const Color(0xFF14224A).withOpacity(0.5)
                      : const Color(0xFFF0F4FF),
                  borderColor: isDark
                      ? const Color(0xFF2548B5)
                      : const Color(0xFFD0DFFF),
                  isDark: isDark,
                  onTap: () => _pick('Kovilambakkam'),
                  colors: colors,
                ),
                const SizedBox(height: 16),
                // Rathinamangalam card
                _BranchCard(
                  name: 'Rathinamangalam',
                  tagline: 'Second Branch · South Chennai',
                  icon: Icons.storefront_rounded,
                  billCount: ratCount,
                  isSelected: _tapped == 'Rathinamangalam' ||
                      (widget.isSwitching &&
                          store.selectedBranch == 'Rathinamangalam' &&
                          _tapped == null),
                  accentColor: colors.teal,
                  bgColor: isDark
                      ? const Color(0xFF0A2E28).withOpacity(0.6)
                      : const Color(0xFFE6F7F5),
                  borderColor: isDark
                      ? const Color(0xFF145E50)
                      : const Color(0xFFBBEAE5),
                  isDark: isDark,
                  onTap: () => _pick('Rathinamangalam'),
                  colors: colors,
                ),
                const Spacer(),
                // Footer
                Center(
                  child: Text(
                    'PD CENTRING · SOUTH CHENNAI',
                    style: jakarta(context,
                            size: 9,
                            weight: FontWeight.w700,
                            color: colors.textMuted)
                        .copyWith(letterSpacing: 3),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  final String name;
  final String tagline;
  final IconData icon;
  final int billCount;
  final bool isSelected;
  final Color accentColor;
  final Color bgColor;
  final Color borderColor;
  final bool isDark;
  final VoidCallback onTap;
  final AppColors colors;

  const _BranchCard({
    required this.name,
    required this.tagline,
    required this.icon,
    required this.billCount,
    required this.isSelected,
    required this.accentColor,
    required this.bgColor,
    required this.borderColor,
    required this.isDark,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? bgColor : colors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? accentColor : colors.border,
            width: isSelected ? 1.5 : 0.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  )
                ]
              : [
                  BoxShadow(
                    color: colors.glow,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Row(
          children: [
            // Icon circle
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor.withOpacity(0.15)
                    : colors.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? accentColor.withOpacity(0.4)
                      : colors.border,
                  width: 0.5,
                ),
              ),
              child: Icon(icon,
                  size: 26,
                  color: isSelected ? accentColor : colors.textMuted),
            ),
            const SizedBox(width: 16),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? accentColor : colors.textMain)),
                  const SizedBox(height: 2),
                  Text(tagline,
                      style: jakarta(context,
                          size: 11, color: colors.textMuted)),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accentColor.withOpacity(0.12)
                          : colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$billCount bills',
                        style: jakarta(context,
                            size: 10,
                            weight: FontWeight.w700,
                            color: isSelected ? accentColor : colors.textSub)),
                  ),
                ],
              ),
            ),
            // Check indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected ? accentColor : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? accentColor : colors.border,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
