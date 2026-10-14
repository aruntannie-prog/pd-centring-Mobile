// Features that talk to the phone or to Firebase Auth, tested through fake
// platform implementations: camera / gallery / file pickers, opening links
// (calls, WhatsApp, PDFs), sign-in, saved settings and drafts.
import 'dart:typed_data';

import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:sd_centring/data/file_store.dart';
import 'package:sd_centring/data/memory_repository.dart';
import 'package:sd_centring/domain/reminders.dart';
import 'package:sd_centring/models/customer.dart';
import 'package:sd_centring/services/media_picker.dart';
import 'package:sd_centring/services/reminder_scheduler.dart';
import 'package:sd_centring/state/app_state.dart';
import 'package:sd_centring/state/drafts.dart';
import 'package:sd_centring/state/settings.dart';
import 'package:sd_centring/ui/screens/customer_detail_screen.dart';
import 'package:sd_centring/ui/screens/document_viewer.dart';
import 'package:sd_centring/ui/screens/login_screen.dart';
import 'package:sd_centring/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

// ── Fakes ──────────────────────────────────────────────────────────────────

class FakeLauncher extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  final opened = <String>[];
  bool result = true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    opened.add(url);
    return result;
  }

  @override
  Future<bool> canLaunch(String url) async => true;
}

class FakeImagePicker extends ImagePickerPlatform
    with MockPlatformInterfaceMixin {
  FakeImagePicker(this.bytes);
  final Uint8List? bytes;
  ImageSource? source;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    this.source = source;
    if (bytes == null) return null; // user cancelled
    return XFile.fromData(bytes!, name: 'IMG_0001.jpg', mimeType: 'image/jpeg');
  }
}

final class FakePlatformFile extends PlatformFile {
  FakePlatformFile(this.name, this.bytes);
  @override
  final String name;
  final Uint8List bytes;
  @override
  Uri get uri => Uri.parse('memory:///$name');
  @override
  XFile get xFile => XFile.fromData(bytes, name: name);
  @override
  int? lengthSync() => bytes.length;
  @override
  Future<int?> length() async => bytes.length;
  @override
  Future<Uint8List> readAsBytes() async => bytes;
  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);
}

class FakeFilePicker extends FilePickerPlatform
    with MockPlatformInterfaceMixin {
  FakeFilePicker(this.files);
  final List<PlatformFile> files;
  List<String>? allowed;

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    allowed = allowedExtensions;
    return files;
  }
}

Uint8List jpeg(int w, int h) {
  final image = img.Image(width: w, height: h);
  for (var y = 0; y < h; y += 1) {
    for (var x = 0; x < w; x += 1) {
      image.setPixelRgb(x, y, (x * 3) % 256, (y * 7) % 256, (x ^ y) % 256);
    }
  }
  return img.encodeJpg(image, quality: 95);
}

/// Like a phone screenshot or scanner PNG: real detail, so it is large.
Uint8List pngPhoto(int w, int h) {
  final image = img.Image(width: w, height: h);
  var seed = 7;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      final n = seed % 40;
      image.setPixelRgb(x, y, (x % 256) ~/ 2 + n, (y % 256) ~/ 2 + n, 120 + n);
    }
  }
  return img.encodePng(image);
}

Widget wrap(Widget child, AppState app) => MultiProvider(
  providers: [
    ChangeNotifierProvider<ReminderSettings>.value(value: app.settings),
    ChangeNotifierProvider<AppState>.value(value: app),
  ],
  child: MaterialApp(theme: buildTheme(Brightness.light), home: child),
);

AppState appWith(List<Customer> customers, {MemoryFileStore? files}) =>
    AppState(
      repo: MemoryRepository(customers: customers),
      settings: ReminderSettings.inMemory(),
      scheduler: NoopReminderScheduler(),
      files: files,
    );

void main() {
  late FakeLauncher launcher;
  setUp(() {
    launcher = FakeLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  group('camera, gallery and file picking', () {
    test('a gallery photo is shrunk to 1024 px for the profile', () async {
      final fake = FakeImagePicker(jpeg(3000, 2000));
      ImagePickerPlatform.instance = fake;
      final p = await const MediaPicker().photo(camera: false);
      expect(fake.source, ImageSource.gallery);
      final d = img.decodeJpg(p!.bytes)!;
      expect(d.width, 1024);
      expect(p.contentType, 'image/jpeg');
    });

    test('a camera photo of an ID keeps 2000 px for small print', () async {
      final fake = FakeImagePicker(jpeg(4000, 3000));
      ImagePickerPlatform.instance = fake;
      final p = await const MediaPicker().documentPhoto(camera: true);
      expect(fake.source, ImageSource.camera);
      expect(img.decodeJpg(p!.bytes)!.width, 2000);
    });

    test('cancelling the camera returns nothing', () async {
      ImagePickerPlatform.instance = FakeImagePicker(null);
      expect(await const MediaPicker().photo(camera: true), isNull);
    });

    test('an image chosen as a file is shrunk and renamed .jpg', () async {
      final big = pngPhoto(3000, 2400);
      final fake = FakeFilePicker([FakePlatformFile('scan.png', big)]);
      FilePickerPlatform.instance = fake;
      final p = await const MediaPicker().documentFile();
      expect(fake.allowed, containsAll(['pdf', 'jpg', 'png']));
      expect(big.length, greaterThan(700 * 1024)); // big enough to shrink
      expect(p!.name, 'scan.jpg');
      expect(p.contentType, 'image/jpeg');
      expect(p.bytes.length, lessThan(big.length));
      expect(img.decodeJpg(p.bytes)!.width, 2000);
    });

    test('a PDF chosen as a file is uploaded exactly as it is', () async {
      final pdf = Uint8List.fromList(List.generate(5000, (i) => i % 251));
      FilePickerPlatform.instance = FakeFilePicker([
        FakePlatformFile('bill.pdf', pdf),
      ]);
      final p = await const MediaPicker().documentFile();
      expect(p!.contentType, 'application/pdf');
      expect(p.bytes, same(pdf));
    });

    test('closing the file chooser returns nothing', () async {
      FilePickerPlatform.instance = FakeFilePicker([]);
      expect(await const MediaPicker().documentFile(), isNull);
    });

    test('file types are recognised from the name', () {
      expect(contentTypeFor('a.PDF'), 'application/pdf');
      expect(contentTypeFor('a.png'), 'image/png');
      expect(contentTypeFor('a.webp'), 'image/webp');
      expect(contentTypeFor('a.jpeg'), 'image/jpeg');
    });
  });

  group('sign-in', () {
    Future<MockFirebaseAuth> pumpLogin(
      WidgetTester tester, {
      MockFirebaseAuth? auth,
    }) async {
      final a = auth ?? MockFirebaseAuth();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: LoginScreen(auth: a),
        ),
      );
      return a;
    }

    Finder field(String label) => find.widgetWithText(TextFormField, label);

    testWidgets('empty fields are explained', (tester) async {
      final auth = await pumpLogin(tester);
      await tester.tap(find.text('Sign in').last);
      await tester.pump();
      expect(find.text('Enter your email'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
      expect(auth.currentUser, isNull);
    });

    testWidgets('correct details sign in', (tester) async {
      final auth = await pumpLogin(tester);
      await tester.enterText(field('Email'), 'owner@sd.example');
      await tester.enterText(field('Password'), 'secret123');
      await tester.tap(find.text('Sign in').last);
      await tester.pumpAndSettle();
      expect(auth.currentUser, isNotNull);
    });

    testWidgets('a wrong password gives a plain message', (tester) async {
      final auth = MockFirebaseAuth();
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'invalid-credential'));
      await pumpLogin(tester, auth: auth);
      await tester.enterText(field('Email'), 'owner@sd.example');
      await tester.enterText(field('Password'), 'wrong');
      await tester.tap(find.text('Sign in').last);
      await tester.pumpAndSettle();
      expect(find.text('Email or password is incorrect.'), findsOneWidget);
      expect(auth.currentUser, isNull);
    });

    testWidgets('no internet is explained', (tester) async {
      final auth = MockFirebaseAuth();
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'network-request-failed'));
      await pumpLogin(tester, auth: auth);
      await tester.enterText(field('Email'), 'owner@sd.example');
      await tester.enterText(field('Password'), 'x');
      await tester.tap(find.text('Sign in').last);
      await tester.pumpAndSettle();
      expect(find.text('No internet connection.'), findsOneWidget);
    });

    testWidgets('password reset asks for the email first', (tester) async {
      await pumpLogin(tester);
      await tester.tap(find.text('Forgot password'));
      await tester.pump();
      expect(find.textContaining('Enter your email first'), findsOneWidget);
    });

    testWidgets('password reset sends the email', (tester) async {
      await pumpLogin(tester);
      await tester.enterText(field('Email'), 'owner@sd.example');
      await tester.tap(find.text('Forgot password'));
      await tester.pumpAndSettle();
      expect(
        find.text('Password reset email sent to owner@sd.example'),
        findsOneWidget,
      );
    });

    testWidgets('a failed password reset is explained', (tester) async {
      final auth = MockFirebaseAuth();
      whenCalling(Invocation.method(#sendPasswordResetEmail, null))
          .on(auth)
          .thenThrow(Exception('offline'));
      await pumpLogin(tester, auth: auth);
      await tester.enterText(field('Email'), 'owner@sd.example');
      await tester.tap(find.text('Forgot password'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not send the email'), findsOneWidget);
    });
  });

  group('documents and links', () {
    CustomerDoc doc(String url, String type, {String kind = 'Aadhaar'}) =>
        CustomerDoc(
          id: 'd',
          kind: kind,
          fileName: 'f',
          url: url,
          contentType: type,
          sizeBytes: 1,
          uploadedAt: DateTime(2026),
        );

    Future<BuildContext> host(WidgetTester tester, AppState app) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        wrap(
          Scaffold(
            body: Builder(
              builder: (c) {
                ctx = c;
                return const SizedBox();
              },
            ),
          ),
          app,
        ),
      );
      return ctx;
    }

    testWidgets('an image document opens full screen with its type', (
      tester,
    ) async {
      final files = MemoryFileStore();
      final url = await files.upload(
        path: 'customers/c/docs/a.png',
        bytes: pngPhoto(8, 8),
        contentType: 'image/png',
      );
      final app = appWith([], files: files);
      final ctx = await host(tester, app);
      openDocument(ctx, doc(url, 'image/png', kind: 'Voter ID'));
      await tester.pumpAndSettle();
      expect(find.text('Voter ID'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });

    testWidgets('a stored PDF opens in the phone\'s PDF viewer', (
      tester,
    ) async {
      final app = appWith([]);
      final ctx = await host(tester, app);
      await openDocument(ctx, doc('https://x/b.pdf', 'application/pdf'));
      await tester.pump();
      expect(launcher.opened, ['https://x/b.pdf']);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });

    testWidgets('a PDF that cannot open is explained', (tester) async {
      launcher.result = false;
      final app = appWith([]);
      final ctx = await host(tester, app);
      await openDocument(ctx, doc('https://x/b.pdf', 'application/pdf'));
      await tester.pump();
      expect(find.text('Could not open this PDF on this device.'), findsOne);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });

    testWidgets('demo-mode PDFs say why they cannot open', (tester) async {
      final app = appWith([]);
      final ctx = await host(tester, app);
      await openDocument(ctx, doc('memory://x/b.pdf', 'application/pdf'));
      await tester.pump();
      expect(launcher.opened, isEmpty);
      expect(find.textContaining('PDFs open once'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });
  });

  group('customer page', () {
    final c = Customer(
      id: 'c1',
      name: 'Bala Traders',
      phone: '+91 98765 43210',
      createdAt: DateTime(2026, 3, 1),
    );

    Future<AppState> pumpCustomer(WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = appWith([c]);
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => CustomerDetailScreen.open(ctx, 'c1'),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          app,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return app;
    }

    testWidgets('Call dials the customer', (tester) async {
      final app = await pumpCustomer(tester);
      await tester.tap(find.text('Call'));
      await tester.pump();
      expect(launcher.opened.single, 'tel:+919876543210');
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });

    testWidgets('WhatsApp opens a chat with the customer', (tester) async {
      final app = await pumpCustomer(tester);
      await tester.tap(find.text('WhatsApp'));
      await tester.pump();
      expect(launcher.opened.single, 'https://wa.me/919876543210');
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });

    testWidgets('shows the date added and no-documents state', (tester) async {
      final app = await pumpCustomer(tester);
      expect(find.text('Added 1 Mar 2026'), findsOneWidget);
      expect(find.text('No documents yet.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });

    testWidgets('a customer without deliveries can be deleted', (tester) async {
      final app = await pumpCustomer(tester);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete customer'));
      await tester.pumpAndSettle();
      expect(find.textContaining('cannot be undone'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(app.customerById('c1'), isNull);
      expect(find.text('open'), findsOneWidget); // back on the previous page
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });
  });

  group('kept on the phone', () {
    test(
      'reminder settings survive a restart; bad values are ignored',
      () async {
        SharedPreferences.setMockInitialValues({});
        final s1 = await ReminderSettings.load();
        expect((s1.leadDays, s1.hour, s1.minute), (3, 9, 0));
        await s1.setLeadDays(5);
        await s1.setReminderTime(18, 30);
        final s2 = await ReminderSettings.load();
        expect((s2.leadDays, s2.hour, s2.minute), (5, 18, 30));

        SharedPreferences.setMockInitialValues({
          'reminder_lead_days': 4, // not an option
          'reminder_hour': 99,
          'reminder_minute': -1,
        });
        final s3 = await ReminderSettings.load();
        expect((s3.leadDays, s3.hour, s3.minute), (3, 9, 0));
      },
    );

    test('drafts survive a restart and can be cleared', () async {
      SharedPreferences.setMockInitialValues({});
      final d1 = await DraftStore.load();
      d1.write('k', {'name': 'Ravi', 'phone': '98'});
      final d2 = await DraftStore.load();
      expect(d2.read('k'), {'name': 'Ravi', 'phone': '98'});
      d2.clear('k');
      expect((await DraftStore.load()).read('k'), isNull);
    });

    test('a corrupted draft is ignored, not crashed on', () async {
      SharedPreferences.setMockInitialValues({'draft_k': '{not json'});
      expect((await DraftStore.load()).read('k'), isNull);
    });
  });

  group('reminder schedulers', () {
    test('demo mode never schedules sample reminders', () async {
      final inner = NoopReminderScheduler();
      final demo = DemoReminderScheduler(inner);
      final plan = [
        PlannedReminder(
          id: 1,
          rentalId: 'r',
          kind: ReminderKind.onExpiry,
          fireAt: DateTime.now().add(const Duration(days: 1)),
          title: 't',
          body: 'b',
        ),
      ];
      await demo.apply(plan);
      expect(inner.lastPlan, isEmpty);
      expect(await demo.launchRentalId(), isNull);
    });
  });
}
