import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../config/brand.dart';
import '../domain/reminders.dart';

/// Schedules expiry reminders as notifications on this device.
abstract class ReminderScheduler {
  /// Whether this platform can show scheduled notifications at all.
  bool get supported;

  Future<void> init({required void Function(String rentalId) onOpenRental});

  /// Asks the OS for notification permission. Returns true when granted.
  Future<bool> requestPermission();

  /// Replaces every pending reminder with [plan].
  Future<void> apply(List<PlannedReminder> plan);

  Future<void> showTest();

  /// Rental id from the notification that launched the app, if any.
  Future<String?> launchRentalId();

  factory ReminderScheduler.forPlatform() {
    final mobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    return mobile ? LocalReminderScheduler() : NoopReminderScheduler();
  }
}

/// Used on web and in tests; the Alerts screen still works everywhere.
class NoopReminderScheduler implements ReminderScheduler {
  List<PlannedReminder> lastPlan = const [];

  @override
  bool get supported => false;
  @override
  Future<void> init({
    required void Function(String rentalId) onOpenRental,
  }) async {}
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> apply(List<PlannedReminder> plan) async => lastPlan = plan;
  @override
  Future<void> showTest() async {}
  @override
  Future<String?> launchRentalId() async => null;
}

class LocalReminderScheduler implements ReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'expiry_reminders',
    'Expiry reminders',
    channelDescription:
        'Alerts when rented material is about to expire or has expired',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const _details = NotificationDetails(
    android: _channel,
    iOS: DarwinNotificationDetails(),
  );

  @override
  bool get supported => true;

  @override
  Future<void> init({
    required void Function(String rentalId) onOpenRental,
  }) async {
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation(Brand.timeZone));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          final id = response.payload;
          if (id != null && id.isNotEmpty) onOpenRental(id);
        },
      );
      _ready = true;
    } catch (e) {
      debugPrint('ReminderScheduler: init failed: $e');
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    } catch (e) {
      debugPrint('ReminderScheduler: permission request failed: $e');
    }
    return false;
  }

  @override
  Future<void> apply(List<PlannedReminder> plan) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAllPendingNotifications();
      for (final r in plan) {
        final when = tz.TZDateTime(
          tz.local,
          r.fireAt.year,
          r.fireAt.month,
          r.fireAt.day,
          r.fireAt.hour,
          r.fireAt.minute,
        );
        await _plugin.zonedSchedule(
          id: r.id,
          title: r.title,
          body: r.body,
          scheduledDate: when,
          notificationDetails: _details,
          // Inexact is fine for a daily reminder and needs no special
          // "exact alarm" permission on Android 14+.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: r.rentalId,
        );
      }
    } catch (e) {
      debugPrint('ReminderScheduler: scheduling failed: $e');
    }
  }

  @override
  Future<void> showTest() async {
    if (!_ready) return;
    await _plugin.show(
      id: 0,
      title: '${Brand.appName} reminders are on',
      body: 'You will be alerted before deliveries expire.',
      notificationDetails: _details,
    );
  }

  @override
  Future<String?> launchRentalId() async {
    if (!_ready) return null;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        final id = details!.notificationResponse?.payload;
        if (id != null && id.isNotEmpty) return id;
      }
    } catch (e) {
      debugPrint('ReminderScheduler: launch details failed: $e');
    }
    return null;
  }
}
