import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/quantity.dart';
import '../../domain/expiry.dart';
import '../../models/rental.dart';
import '../../state/app_state.dart';
import '../screens/delivery_detail_screen.dart';
import '../theme.dart';
import 'stored_image.dart';

// ── Surfaces ───────────────────────────────────────────────────────────────

/// Rounded card with a soft shadow (light) or hairline border (dark).
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final sd = context.sd;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: color == null ? sd.shadow : const [],
        border: dark && color == null ? Border.all(color: sd.line) : null,
      ),
      child: Material(
        color: color ?? sd.card,
        borderRadius: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Keeps page content at a readable width on tablets and desktop browsers;
/// on phones it changes nothing.
class PageWidth extends StatelessWidget {
  const PageWidth({super.key, required this.child});

  static const maxWidth = 880.0;
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

// ── Status visuals ─────────────────────────────────────────────────────────

/// Big countdown block: "4 / days late", "2 / days left", "Today", "Done".
class DayBadge extends StatelessWidget {
  const DayBadge(this.info, {super.key, this.size = 60});

  final ExpiryInfo info;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(info.status);
    // Today and done get an icon; otherwise the number of days.
    final IconData? icon = switch (info.status) {
      ExpiryStatus.closed => Icons.check_rounded,
      ExpiryStatus.dueToday => Icons.today_rounded,
      _ => null,
    };
    final (String big, String small) = switch (info.status) {
      ExpiryStatus.closed => ('', 'done'),
      ExpiryStatus.dueToday => ('', 'today'),
      ExpiryStatus.expired => (
        '${-info.daysLeft}',
        -info.daysLeft == 1 ? 'day late' : 'days late',
      ),
      _ => ('${info.daysLeft}', info.daysLeft == 1 ? 'day left' : 'days left'),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      padding: const EdgeInsets.all(4),
      // A fixed-size graphic: shrink its contents rather than overflow when
      // the phone uses large text.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(icon, color: color, size: size * 0.42)
            else
              Text(
                big,
                style: TextStyle(
                  fontSize: size * 0.4,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: color,
                ),
              ),
            const SizedBox(height: 2),
            Text(
              small,
              maxLines: 1,
              style: TextStyle(
                fontSize: size * 0.16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small status pill: icon + "3 days left" / "Expires today" / "5 days overdue".
class ExpiryPill extends StatelessWidget {
  const ExpiryPill(
    this.info, {
    super.key,
    this.large = false,
    this.onDark = false,
  });

  final ExpiryInfo info;
  final bool large;

  /// White pill for use on coloured hero backgrounds.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(info.status);
    final fg = onDark ? color : color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : 9,
        vertical: large ? 7 : 4,
      ),
      decoration: BoxDecoration(
        color: onDark ? Colors.white : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon(info.status), size: large ? 16 : 13, color: fg),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              info.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w800,
                fontSize: large ? 13.5 : 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Issue date → expiry date bar with a "today" marker.
class ExpiryTimeline extends StatelessWidget {
  const ExpiryTimeline({
    super.key,
    required this.rental,
    required this.today,
    this.onDark = false,
  });

  final Rental rental;
  final DateTime today;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final total = daysBetween(
      rental.issuedOn,
      rental.expiresOn,
    ).clamp(1, 100000);
    final elapsed = daysBetween(rental.issuedOn, today);
    final progress = (elapsed / total).clamp(0.0, 1.0);
    final fg = onDark ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final muted = onDark ? Colors.white70 : context.sd.muted;
    final track = onDark ? Colors.white24 : context.sd.field;

    Widget label(String top, String bottom, CrossAxisAlignment align) =>
        Flexible(
          child: Column(
            crossAxisAlignment: align,
            children: [
              Text(
                top.toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w800,
                  color: muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                bottom,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ],
          ),
        );

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final x = c.maxWidth * progress;
            return SizedBox(
              height: 18,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: track,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Container(
                    height: 6,
                    width: x,
                    decoration: BoxDecoration(
                      color: onDark ? Colors.white : SdColors.ember,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Positioned(
                    left: (x - 9).clamp(0.0, c.maxWidth - 18),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: onDark ? Colors.white : SdColors.ember,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: onDark ? Colors.black26 : Colors.white,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            label(
              'Issued',
              formatDay(rental.issuedOn),
              CrossAxisAlignment.start,
            ),
            const Spacer(),
            label(
              'Expiry',
              formatDay(rental.expiresOn),
              CrossAxisAlignment.end,
            ),
          ],
        ),
      ],
    );
  }
}

// ── People and items ───────────────────────────────────────────────────────

/// Initials on a colour picked from the name, so each customer is
/// recognisable at a glance.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(
    this.name, {
    super.key,
    this.size = 44,
    this.photoUrl = '',
  });

  final String name;
  final double size;

  /// Shown instead of the initials when set.
  final String photoUrl;

  static const _palette = [
    Color(0xFFEE5A24),
    Color(0xFF2F6FED),
    Color(0xFF1E9E63),
    Color(0xFF8B5CF6),
    Color(0xFFD48A00),
    Color(0xFF0EA5A4),
    Color(0xFFE5484D),
    Color(0xFF475467),
  ];

  @override
  Widget build(BuildContext context) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final initials = words.isEmpty
        ? '?'
        : words.take(2).map((w) => w.characters.first.toUpperCase()).join();
    final color = _palette[name.hashCode.abs() % _palette.length];
    final letters = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.36,
          letterSpacing: -0.3,
        ),
      ),
    );
    if (photoUrl.isEmpty) return letters;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.32),
      child: SizedBox(
        width: size,
        height: size,
        // Keyed by URL so a reused row never shows the previous face, and
        // falls back to the initials when the photo cannot load (offline).
        child: StoredImage(
          photoUrl,
          key: ValueKey(photoUrl),
          decodeSize: size,
          error: letters,
        ),
      ),
    );
  }
}

/// Outstanding material as compact chips, e.g. "Props 25".
class ItemChips extends StatelessWidget {
  const ItemChips(this.rental, {super.key, this.max = 3});

  final Rental rental;
  final int max;

  @override
  Widget build(BuildContext context) {
    final sd = context.sd;
    final out = rental.outstandingItems;
    final shown = out.isEmpty ? rental.items : out;
    final style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.onSurface,
    );
    Widget chip(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: sd.field,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    if (out.isEmpty) {
      return chip(
        'All ${rental.items.length} item${rental.items.length == 1 ? '' : 's'} returned',
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final i in shown.take(max))
          chip('${i.name} ${formatQty(rental.outstandingQty(i))}'),
        if (shown.length > max) chip('+${shown.length - max} more'),
      ],
    );
  }
}

// ── Lists ──────────────────────────────────────────────────────────────────

/// A delivery in a list: countdown badge, customer, DC number, site and the
/// material still out.
class RentalTile extends StatelessWidget {
  const RentalTile(this.rental, {super.key, this.showCustomer = true});

  final Rental rental;
  final bool showCustomer;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final info = app.expiry(rental);
    final theme = Theme.of(context);
    final muted = context.sd.muted;

    return SoftCard(
      padding: const EdgeInsets.all(14),
      onTap: () => DeliveryDetailScreen.open(context, rental.id),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DayBadge(info),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showCustomer)
                  Text(
                    app.customerNameOf(rental),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      rental.dcNumber,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: showCustomer
                            ? muted
                            : theme.colorScheme.onSurface,
                        fontSize: showCustomer ? 12.5 : 15,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        [
                          if (rental.site.isNotEmpty) rental.site,
                          'Exp ${formatShortDay(rental.expiresOn)}',
                        ].map((s) => '  ·  $s').join(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ItemChips(rental),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4),
            child: Icon(Icons.chevron_right_rounded, color: muted),
          ),
        ],
      ),
    );
  }
}

/// Section title with an optional count bubble, e.g. "Expired  2".
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.text, {
    super.key,
    this.color,
    this.count,
    this.trailing,
  });

  final String text;
  final Color? color;
  final int? count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(
        children: [
          if (color != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
          ],
          // Title and count take the free space; the trailing action keeps
          // its natural width at the far right.
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    text,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: (color ?? context.sd.muted).withValues(
                        alpha: 0.12,
                      ),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: color ?? context.sd.muted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
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
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: SdColors.ember.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: SdColors.ember),
            ),
            const SizedBox(height: 16),
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

/// Coloured notice used for demo mode and sync warnings.
class Notice extends StatelessWidget {
  const Notice({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(color: color),
                ),
                const SizedBox(height: 2),
                Text(message, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Square action button: icon in a tinted circle with a label below.
class QuickAction extends StatelessWidget {
  const QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final c = enabled ? color : context.sd.muted;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: c, size: 18),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: c, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
