import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sd_centring/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('smoke: app starts', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    expect(find.text('Demo mode'), findsOneWidget);
  });
}
