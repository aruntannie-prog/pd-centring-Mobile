import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/brand.dart';
import '../../core/dates.dart';
import '../../state/app_state.dart';
import '../../state/settings.dart';
import '../widgets/rental_tile.dart';
import '../widgets/sync_banner.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final settings = context.watch<ReminderSettings>();
    final scheduler = app.scheduler;
    final time = TimeOfDay(hour: settings.hour, minute: settings.minute);
    final plan = app.loaded ? app.currentPlan() : const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: PageWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const SectionHeader('Expiry reminders'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: const Text('Remind me before expiry'),
                    subtitle: const Text(
                      'Also used for “Expiring soon” on Alerts',
                    ),
                    trailing: DropdownButton<int>(
                      value: settings.leadDays,
                      underline: const SizedBox.shrink(),
                      items: [
                        for (final d in ReminderSettings.leadDayOptions)
                          DropdownMenuItem(
                            value: d,
                            child: Text(d == 1 ? '1 day' : '$d days'),
                          ),
                      ],
                      onChanged: (d) {
                        if (d != null) settings.setLeadDays(d);
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.schedule),
                    title: const Text('Reminder time'),
                    trailing: Text(
                      time.format(context),
                      style: Theme.of(context).textTheme.titleMedium,
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
                  const Divider(height: 1),
                  if (scheduler.supported) ...[
                    ListTile(
                      leading: const Icon(Icons.verified_user_outlined),
                      title: const Text('Allow notifications'),
                      subtitle: const Text(
                        'Needed for reminders on this phone',
                      ),
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
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.send_outlined),
                      title: const Text('Send a test notification'),
                      onTap: scheduler.showTest,
                    ),
                  ] else
                    const ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text(
                        'Phone reminders are available in the Android and iOS app',
                      ),
                      subtitle: Text('In the browser, check the Alerts tab.'),
                    ),
                ],
              ),
            ),
            if (plan.isNotEmpty) ...[
              const SectionHeader('Upcoming reminders'),
              Card(
                child: Column(
                  children: [
                    for (final r in plan.take(5))
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.alarm),
                        title: Text(r.title),
                        subtitle: Text(
                          '${formatWeekday(r.fireAt)} · '
                          '${TimeOfDay.fromDateTime(r.fireAt).format(context)}',
                        ),
                      ),
                    if (plan.length > 5)
                      ListTile(
                        dense: true,
                        title: Text('+ ${plan.length - 5} more'),
                      ),
                  ],
                ),
              ),
            ],
            const SectionHeader('Account'),
            const Card(child: SyncStatusTile()),
            const SizedBox(height: 8),
            Card(
              child: app.signOut == null
                  ? const ListTile(
                      leading: Icon(Icons.science_outlined),
                      title: Text('Demo mode'),
                      subtitle: Text(
                        'Connect Firebase to sign in and save data. See README.',
                      ),
                    )
                  : ListTile(
                      leading: const Icon(Icons.logout),
                      title: const Text('Sign out'),
                      subtitle: Text(app.accountEmail ?? ''),
                      onTap: () => _signOut(context, app),
                    ),
            ),
            const SectionHeader('About'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.apartment),
                title: const Text(Brand.appName),
                subtitle: Text(
                  [
                    Brand.tagline,
                    if (Brand.ownerName.isNotEmpty) Brand.ownerName,
                    if (Brand.phone.isNotEmpty) Brand.phone,
                    if (Brand.address.isNotEmpty) Brand.address,
                  ].join('\n'),
                ),
              ),
            ),
          ],
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
