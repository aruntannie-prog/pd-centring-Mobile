import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repository.dart';
import '../../state/app_state.dart';
import '../theme.dart';

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
        SyncState.synced || SyncState.demo => const SizedBox.shrink(),
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
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        color: color.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withValues(alpha: 0.6)),
        ),
        child: ListTile(
          leading: Icon(icon, color: color),
          title: Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(message),
        ),
      ),
    );
  }
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
