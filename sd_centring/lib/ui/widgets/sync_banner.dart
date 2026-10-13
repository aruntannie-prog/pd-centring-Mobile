import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repository.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import 'rental_tile.dart';

/// Tells the user, in plain words, whether their entries are safely in the
/// cloud. Hidden when everything is synced.
class SyncBanner extends StatelessWidget {
  const SyncBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.loadError != null) {
      return _banner(
        context,
        Icons.cloud_off,
        SdColors.expired,
        'Not saving to cloud',
        app.loadError!,
      );
    }
    return ValueListenableBuilder<SyncState>(
      valueListenable: app.repo.sync,
      builder: (context, state, _) => switch (state) {
        SyncState.synced ||
        SyncState.demo ||
        SyncState.connecting => const SizedBox.shrink(),
        SyncState.pending => _banner(
          context,
          Icons.cloud_upload_outlined,
          SdColors.soon,
          'Waiting to sync',
          'Recent changes are saved on this phone and will upload when online.',
        ),
        SyncState.offline => _banner(
          context,
          Icons.wifi_off,
          SdColors.closed,
          'Offline',
          'Showing saved data. New entries will upload when you are back online.',
        ),
      },
    );
  }

  Widget _banner(
    BuildContext context,
    IconData icon,
    Color color,
    String title,
    String message,
  ) => Notice(icon: icon, color: color, title: title, message: message);
}

/// One-line sync status for the Settings screen.
class SyncStatusTile extends StatelessWidget {
  const SyncStatusTile({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return ValueListenableBuilder<SyncState>(
      valueListenable: app.repo.sync,
      builder: (context, state, _) {
        final (icon, color, text) = app.loadError != null
            ? (Icons.cloud_off, SdColors.expired, 'Not saving to cloud')
            : switch (state) {
                SyncState.synced => (
                  Icons.cloud_done,
                  SdColors.active,
                  'All changes saved to cloud',
                ),
                SyncState.pending => (
                  Icons.cloud_upload_outlined,
                  SdColors.soon,
                  'Waiting to upload changes',
                ),
                SyncState.offline => (
                  Icons.wifi_off,
                  SdColors.closed,
                  'Offline — showing saved data',
                ),
                SyncState.connecting => (
                  Icons.cloud_sync_outlined,
                  SdColors.closed,
                  'Connecting…',
                ),
                SyncState.demo => (
                  Icons.science_outlined,
                  SdColors.closed,
                  'Demo mode — nothing is saved',
                ),
              };
        return ListTile(
          leading: Icon(icon, color: color),
          title: const Text('Cloud sync'),
          subtitle: Text(text),
        );
      },
    );
  }
}
