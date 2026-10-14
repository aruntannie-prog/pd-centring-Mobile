// Host-side driver for `flutter drive`: waits for the integration tests
// running inside the app (see integration_test/) and prints one PASS/FAIL
// line per test, from the results the tests attach to the response (see
// `reportResultsToDriver` in integration_test/support.dart).
// ignore_for_file: avoid_print
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    final results = (data?['results'] as Map<String, dynamic>?) ?? const {};
    var passed = 0;
    var failed = 0;
    for (final e in results.entries) {
      final ok = e.value == 'success';
      ok ? passed++ : failed++;
      print('${ok ? 'PASS' : 'FAIL'}: ${e.key}');
    }
    final why = (data?['why'] as Map<String, dynamic>?) ?? const {};
    for (final e in why.entries) {
      print('WHY ${e.key}:\n${e.value}\n');
    }
    print('Summary: $passed passed, $failed failed, ${results.length} total');
    await writeResponseData(data);
  },
);
