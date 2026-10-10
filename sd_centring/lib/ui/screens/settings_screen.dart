import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/brand.dart';
import '../../core/dates.dart';
import '../../state/app_state.dart';
import '../../state/settings.dart';
import '../theme.dart';
import '../widgets/rental_tile.dart';
import '../widgets/sync_banner.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final settings = context.watch<ReminderSettings>();
    final scheduler = app.scheduler;
    final theme = Theme.of(context);
    final time = TimeOfDay(hour: settings.hour, minute: settings.minute);
    final plan = app.loaded ? app.currentPlan() : const [];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: PageWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('Settings', style: theme.textTheme.headlineMedium),
              ),
              const SectionHeader('Expiry reminders'),
              SoftCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _Tile(
                      icon: Icons.notifications_active_rounded,
                      color: SdColors.ember,
                      title: 'Remind me before expiry',
                      subtitle: 'Also used for “Expiring soon” on Alerts',
                      below: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final d in ReminderSettings.leadDayOptions)
                            ChoiceChip(
                              label: Text(d == 1 ? '1 day' : '$d days'),
                              selected: settings.leadDays == d,
                              onSelected: (_) => settings.setLeadDays(d),
                            ),
                        ],
                      ),
                    ),
                    const Divider(indent: 68),
                    _Tile(
                      icon: Icons.schedule_rounded,
                      color: const Color(0xFF2F6FED),
                      title: 'Reminder time',
                      subtitle: 'When reminders arrive each day',
                      trailing: Text(
                        time.format(context),
                        style: theme.textTheme.titleMedium,
                      ),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: time,
                        );
                        if (picked != null) {
                          settings.setReminderTime(picked.hour, picked.minute);
                        }
                      },
                    ),
                    const Divider(indent: 68),
                    if (scheduler.supported) ...[
                      _Tile(
                        icon: Icons.verified_user_rounded,
                        color: SdColors.active,
                        title: 'Allow notifications',
                        subtitle: 'Needed for reminders on this phone',
                        onTap: () async {
                          final ok = await scheduler.requestPermission();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok ? 'Notifications allowed' : 'Notifications are off. Enable them in phone settings.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      const Divider(indent: 68),
                      _Tile(
                        icon: Icons.send_rounded,
                        color: const Color(0xFF8B5CF6),
                        title: 'Send a test notification',
                        onTap: scheduler.showTest,
                      ),
                    ] else
                      const _Tile(
                        icon: Icons.info_rounded,
                        color: SdColors.closed,
                        title: 'Phone reminders are in the Android and iOS app',
                        subtitle: 'In the browser, check the Alerts tab.',
                      ),
                  ],
                ),
              ),
              if (plan.isNotEmpty) ...[
                SectionHeader('Upcoming reminders', count: plan.length),
                SoftCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      for (final r in plan.take(5))
                        ListTile(
                          leading: Icon(
                            Icons.alarm_rounded,
                            color: context.sd.muted,
                          ),
                          title: Text(r.title),
                          subtitle: Text(
                            '${formatWeekday(r.fireAt)} · '
                            '${TimeOfDay.fromDateTime(r.fireAt).format(context)}',
                          ),
                        ),
                      if (plan.length > 5)
                        ListTile(
                          title: Text(
                            '+ ${plan.length - 5} more',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SectionHeader('Account'),
              SoftCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    const SyncStatusTile(),
                    const Divider(indent: 16, endIndent: 16),
                    app.signOut == null
                        ? const ListTile(
                            leading: Icon(Icons.science_rounded),
                            title: Text('Demo mode'),
                            subtitle: Text(
                              'Connect Firebase to sign in and save data. See README.',
                            ),
                          )
                        : ListTile(
                            leading: const Icon(Icons.logout_rounded),
                            title: const Text('Sign out'),
                            subtitle: Text(app.accountEmail ?? ''),
                            onTap: () => _signOut(context, app),
                          ),
                  ],
                ),
              ),
              const SectionHeader('About'),
              SoftCard(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: SdColors.ember,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.construction_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Brand.appName,
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            [
                              Brand.tagline,
                              if (Brand.ownerName.isNotEmpty) Brand.ownerName,
                              if (Brand.phone.isNotEmpty) Brand.phone,
                              if (Brand.address.isNotEmpty) Brand.address,
                            ].join('\n'),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
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

  Future<void> _signOut(BuildContext context, AppState app) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Reminders on this phone will stop until you sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // Clear this business's reminders from the device before leaving.
    await app.scheduler.apply(const []);
    await app.signOut?.call();
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.trailing,
    this.below,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? below;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(fontSize: 15),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: theme.textTheme.bodySmall),
                  ],
                  if (below != null) ...[const SizedBox(height: 12), below!],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}
