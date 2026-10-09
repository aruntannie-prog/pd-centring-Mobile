import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/quantity.dart';
import '../../domain/expiry.dart';
import '../../models/rental.dart';
import '../../state/app_state.dart';
import '../screens/delivery_detail_screen.dart';
import '../theme.dart';

/// Countdown pill: "3 days left", "Expires today", "5 days overdue".
class ExpiryPill extends StatelessWidget {
  const ExpiryPill(this.info, {super.key, this.large = false});

  final ExpiryInfo info;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(info.status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : 8,
        vertical: large ? 6 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon(info.status), size: large ? 18 : 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              info.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: large ? 14 : 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A delivery in a list: coloured status stripe on the left, DC number,
/// customer, site, outstanding items and the countdown.
class RentalTile extends StatelessWidget {
  const RentalTile(this.rental, {super.key, this.showCustomer = true});

  final Rental rental;
  final bool showCustomer;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final info = app.expiry(rental);
    final color = statusColor(info.status);
    final theme = Theme.of(context);
    final out = rental.outstandingItems;
    final summary = out.isEmpty
        ? '${rental.items.length} item${rental.items.length == 1 ? '' : 's'} · all returned'
        : out
              .map((i) => '${i.name} ${formatQty(rental.outstandingQty(i))}')
              .join(' · ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => DeliveryDetailScreen.open(context, rental.id),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              rental.dcNumber,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Capped so a long label can't push the DC number off a small phone.
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 170),
                            child: ExpiryPill(info),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (showCustomer)
                        Text(
                          app.customerNameOf(rental),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      Text(
                        [
                          if (rental.site.isNotEmpty) rental.site,
                          'Expiry ${formatDay(rental.expiresOn)}',
                        ].join(' · '),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(
                message!,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Section header used in lists ("EXPIRED · 2").
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.color, this.count});

  final String text;
  final Color? color;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        count == null ? text.toUpperCase() : '${text.toUpperCase()} · $count',
        style: theme.textTheme.labelMedium?.copyWith(
          color: color ?? theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

/// Keeps page content at a readable width on tablets and desktop browsers;
/// on phones it changes nothing.
class PageWidth extends StatelessWidget {
  const PageWidth({super.key, required this.child});

  static const maxWidth = 920.0;
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
