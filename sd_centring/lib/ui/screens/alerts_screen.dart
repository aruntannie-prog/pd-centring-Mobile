import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/brand.dart';
import '../../core/dates.dart';
import '../../domain/expiry.dart';
import '../../models/rental.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/rental_tile.dart';
import '../widgets/sync_banner.dart';
import 'deliveries_screen.dart';

/// Home screen: a dark hero with today's summary, four counters, then the
/// deliveries that need action, most urgent first.
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key, required this.onShowDeliveries});

  final void Function(DeliveryFilter filter) onShowDeliveries;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    final expired = app.withStatus(ExpiryStatus.expired);
    final today = app.withStatus(ExpiryStatus.dueToday);
    final soon = app.withStatus(ExpiryStatus.dueSoon);
    final active = app.withStatus(ExpiryStatus.active);
    final openCount =
        expired.length + today.length + soon.length + active.length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: !app.loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.zero,
                children: [
                  _Hero(
                    today: app.today,
                    failed: app.loadError != null,
                    attention: expired.length + today.length,
                    soon: soon.length,
                    counts: [
                      expired.length,
                      today.length,
                      soon.length,
                      active.length,
                    ],
                  ),
                  PageWidth(
                    child: Transform.translate(
                      offset: const Offset(0, -34),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _StatGrid(
                          children: [
                            _StatTile(
                              'Expired',
                              expired.length,
                              SdColors.expired,
                              Icons.error_rounded,
                              () => onShowDeliveries(DeliveryFilter.expired),
                            ),
                            _StatTile(
                              'Due today',
                              today.length,
                              SdColors.today,
                              Icons.today_rounded,
                              () => onShowDeliveries(DeliveryFilter.expiring),
                            ),
                            _StatTile(
                              'Next ${app.settings.leadDays} days',
                              soon.length,
                              SdColors.soon,
                              Icons.hourglass_bottom_rounded,
                              () => onShowDeliveries(DeliveryFilter.expiring),
                            ),
                            _StatTile(
                              'Out on rent',
                              openCount,
                              SdColors.active,
                              Icons.local_shipping_rounded,
                              () => onShowDeliveries(DeliveryFilter.open),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  PageWidth(
                    child: Transform.translate(
                      offset: const Offset(0, -22),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (app.isDemo)
                              const Notice(
                                icon: Icons.science_outlined,
                                color: SdColors.soon,
                                title: 'Demo mode',
                                message:
                                    'Firebase is not set up yet, so sample data is shown '
                                    'and changes are not saved. See README to connect a database.',
                              ),
                            const SyncBanner(),
                            if (app.loadError == null &&
                                expired.isEmpty &&
                                today.isEmpty &&
                                soon.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 24),
                                child: EmptyState(
                                  icon: Icons.verified_rounded,
                                  title: 'All clear',
                                  message:
                                      'Nothing is expired or expiring soon.',
                                ),
                              ),
                            ..._section(
                              'Expired — collect material',
                              expired,
                              SdColors.expired,
                            ),
                            ..._section('Due today', today, SdColors.today),
                            ..._section('Expiring soon', soon, SdColors.soon),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  List<Widget> _section(String title, List<Rental> list, Color color) {
    if (list.isEmpty) return const [];
    return [
      SectionHeader(title, color: color, count: list.length),
      for (final r in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: RentalTile(r),
        ),
    ];
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.today,
    required this.failed,
    required this.attention,
    required this.soon,
    required this.counts,
  });

  final DateTime today;

  /// Data could not be loaded: never claim "everything is on time".
  final bool failed;
  final int attention;
  final int soon;

  /// expired, today, soon, active.
  final List<int> counts;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final headline = failed
        ? 'Can’t reach the database'
        : attention > 0
        ? '$attention ${attention == 1 ? 'delivery needs' : 'deliveries need'} attention'
        : soon > 0
        ? '$soon expiring soon'
        : 'Everything is on time';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C1F25), SdColors.ink],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          // Warm glow in the corner.
          Positioned(
            right: -60,
            top: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    SdColors.ember.withValues(alpha: 0.45),
                    SdColors.ember.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: PageWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 58),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: SdColors.ember,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.construction_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            Brand.appName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            formatWeekday(today),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      _greeting,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      headline,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _StatusBar(counts: counts),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One bar split by status, with a legend: how the open rentals stand.
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.counts});

  final List<int> counts;

  static const _colors = [
    SdColors.expired,
    SdColors.today,
    SdColors.soon,
    SdColors.active,
  ];
  static const _labels = ['Expired', 'Today', 'Soon', 'On time'];

  @override
  Widget build(BuildContext context) {
    final total = counts.fold(0, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 10,
            child: total == 0
                ? Container(color: Colors.white12)
                : Row(
                    children: [
                      for (var i = 0; i < counts.length; i++)
                        if (counts[i] > 0)
                          Expanded(
                            flex: counts[i],
                            child: Container(
                              margin: const EdgeInsets.only(right: 2),
                              color: _colors[i],
                            ),
                          ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (var i = 0; i < counts.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _colors[i],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_labels[i]} ${counts[i]}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth >= 600 ? 4 : 2;
        final width = (c.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final w in children) SizedBox(width: width, child: w),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.label, this.count, this.color, this.icon, this.onTap);

  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dim = count == 0;
    final c = dim ? context.sd.muted : color;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: c, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    height: 1.05,
                    color: dim ? context.sd.muted : theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
