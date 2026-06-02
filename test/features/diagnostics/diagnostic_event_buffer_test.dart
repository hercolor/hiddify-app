import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/diagnostics/diagnostic_event_buffer.dart';

void main() {
  test('addSafe still sanitizes sensitive diagnostic text', () {
    DiagnosticEventBuffer.addSafe(
      'diagProbe subscribe=https://api.example.test/xlink/secret-token?token=abcdef1234567890 authData=abcdef1234567890abcdef1234567890',
    );

    final latest = DiagnosticEventBuffer.recent(limit: 1).single;

    expect(latest, contains('diagProbe'));
    expect(latest, contains('subscribe=https://***'));
    expect(latest, contains('authData=***'));
    expect(latest, isNot(contains('secret-token')));
    expect(latest, isNot(contains('abcdef1234567890abcdef1234567890')));
  });
}
