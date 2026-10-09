import 'package:flutter/material.dart';
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

/// Home screen: what needs attention today, grouped by urgency.
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key, required this.onShowDeliveries});

  final void Function(DeliveryFilter filter) onShowDeliveries;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);

    final expired = app.withStatus(ExpiryStatus.expired);
    final today = app.withStatus(ExpiryStatus.dueToday);
    final soon = app.withStatus(ExpiryStatus.dueSoon);
    final openCount = app.rentals.where((r) => !r.isClosed).length;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(Brand.appName),
            Text(
              formatWeekday(app.today),
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
      body: PageWidth(
        child: !app.loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  if (app.isDemo) const _DemoBanner(),
                  const SyncBanner(),
                  const SizedBox(height: 8),
                  _StatGrid(
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
                  if (expired.isEmpty && today.isEmpty && soon.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: EmptyState(
                        icon: Icons.verified_rounded,
                        title: 'All clear',
                        message: 'Nothing is expired or expiring soon.',
                      ),
                    ),
                  ..._section(
                    'Expired — collect material',
                    expired,
                    SdColors.expired,
                  ),
                  ..._section('Expires today', today, SdColors.today),
                  ..._section('Expiring soon', soon, SdColors.soon),
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
          padding: const EdgeInsets.only(bottom: 8),
          child: RentalTile(r),
        ),
    ];
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: const ListTile(
        leading: Icon(Icons.science_outlined),
        title: Text('Demo mode'),
        subtitle: Text(
          'Firebase is not set up yet, so sample data is shown '
          'and changes are not saved. See README to connect a database.',
        ),
      ),
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
        final width = (c.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
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
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: dim ? theme.colorScheme.outline : color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: dim ? theme.colorScheme.outline : color,
                      ),
                    ),
                    Text(
                      label,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
