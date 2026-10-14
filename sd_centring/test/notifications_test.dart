// Phone reminders, through the real notifications plugin with its Android
// channel recorded: what is cancelled and scheduled, in what order.
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sd_centring/domain/reminders.dart';
import 'package:sd_centring/services/reminder_scheduler.dart';

const channel = MethodChannel('dexterous.com/flutter/local_notifications');

PlannedReminder reminder(int id, Duration inFuture, {String rental = 'r1'}) =>
    PlannedReminder(
      id: id,
      rentalId: rental,
      kind: ReminderKind.onExpiry,
      fireAt: DateTime.now().add(inFuture),
      title: 'Expires today: SD-$id',
      body: 'Props 25',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<MethodCall> calls;
  int? failId;

  setUp(() {
    calls = [];
    failId = null;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          // Each call takes a moment, like a real platform round trip.
          await Future<void>.delayed(const Duration(milliseconds: 2));
          calls.add(call);
          if (call.method == 'zonedSchedule' &&
              (call.arguments as Map)['id'] == failId) {
            throw PlatformException(code: 'boom');
          }
          return switch (call.method) {
            'initialize' => true,
            'requestNotificationsPermission' => true,
            'getNotificationAppLaunchDetails' => null,
            _ => null,
          };
        });
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  Future<LocalReminderScheduler> ready() async {
    final s = LocalReminderScheduler();
    await s.init(onOpenRental: (_) {});
    calls.clear();
    return s;
  }

  List<String> names() => calls.map((c) => c.method).toList();
  List<Object?> scheduledIds() => [
    for (final c in calls)
      if (c.method == 'zonedSchedule') (c.arguments as Map)['id'],
  ];

  test('starts the plugin', () async {
    final s = LocalReminderScheduler();
    await s.init(onOpenRental: (_) {});
    expect(names(), contains('initialize'));
    expect(s.supported, isTrue);
  });

  test('asks for notification permission', () async {
    final s = await ready();
    expect(await s.requestPermission(), isTrue);
    expect(names(), ['requestNotificationsPermission']);
  });

  test(
    'clears old reminders, then schedules the plan with its delivery',
    () async {
      final s = await ready();
      await s.apply([
        reminder(11, const Duration(hours: 2)),
        reminder(12, const Duration(days: 1), rental: 'r2'),
      ]);
      expect(names(), [
        'cancelAllPendingNotifications',
        'zonedSchedule',
        'zonedSchedule',
      ]);
      final first = calls[1].arguments as Map;
      expect(first['id'], 11);
      expect(first['title'], 'Expires today: SD-11');
      expect(first['payload'], 'r1'); // tapping opens this delivery
      expect((calls[2].arguments as Map)['payload'], 'r2');
    },
  );

  test('reminders already in the past are skipped', () async {
    final s = await ready();
    await s.apply([
      reminder(1, const Duration(minutes: -5)),
      reminder(2, const Duration(hours: 1)),
    ]);
    expect(scheduledIds(), [2]);
  });

  test('one failing reminder does not stop the others', () async {
    final s = await ready();
    failId = 2;
    await s.apply([
      reminder(1, const Duration(hours: 1)),
      reminder(2, const Duration(hours: 2)),
      reminder(3, const Duration(hours: 3)),
    ]);
    expect(scheduledIds(), [1, 2, 3]); // 2 was attempted and failed
  });

  test('a newer plan stops an older one still being scheduled', () async {
    final s = await ready();
    final old = [for (var i = 1; i <= 30; i++) reminder(i, Duration(hours: i))];
    final first = s.apply(old);
    await Future<void>.delayed(const Duration(milliseconds: 15));
    final second = s.apply(const []); // e.g. signing out
    await Future.wait([first, second]);
    // After the last "cancel all", nothing from the old plan was scheduled.
    final lastCancel = names().lastIndexOf('cancelAllPendingNotifications');
    expect(names().sublist(lastCancel + 1), isEmpty);
    expect(scheduledIds().length, lessThan(30));
  });

  test('plans are applied one at a time, latest wins', () async {
    final s = await ready();
    final a = s.apply([reminder(1, const Duration(hours: 1))]);
    final b = s.apply([reminder(2, const Duration(hours: 1))]);
    await Future.wait([a, b]);
    final lastCancel = names().lastIndexOf('cancelAllPendingNotifications');
    expect(
      calls
          .sublist(lastCancel + 1)
          .map((c) => (c.arguments as Map)['id'])
          .toList(),
      [2],
    );
  });

  test('test notification uses id 0, which reminders never use', () async {
    final s = await ready();
    await s.showTest();
    expect(names(), ['show']);
    expect((calls.single.arguments as Map)['id'], 0);
    expect(reminderId('any', ReminderKind.onExpiry), isNot(0));
  });

  test('nothing is sent before the plugin is ready', () async {
    final s = LocalReminderScheduler(); // init not called
    await s.apply([reminder(1, const Duration(hours: 1))]);
    await s.showTest();
    expect(calls, isEmpty);
  });
}
