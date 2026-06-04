import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/connection/model/client_connection_state.dart';
import 'package:hiddify/features/connection/model/connection_error_mapper.dart';

void main() {
  group('ClientConnectionStatePolicy', () {
    test('preserves VPN permission pending state when auth refresh computes disconnected', () {
      final shouldPreserve = ClientConnectionStatePolicy.shouldPreserveActiveState(
        userRequestedConnection: true,
        current: const ClientConnectionState.requestingVpnPermission(),
        computed: const ClientConnectionState.disconnected(),
      );

      expect(shouldPreserve, isTrue);
    });

    test('preserves connecting state when auth/bootstrap refresh computes initializing or failed', () {
      expect(
        ClientConnectionStatePolicy.shouldPreserveActiveState(
          userRequestedConnection: true,
          current: const ClientConnectionState.connecting(),
          computed: const ClientConnectionState.initializing(),
        ),
        isTrue,
      );
      expect(
        ClientConnectionStatePolicy.shouldPreserveActiveState(
          userRequestedConnection: true,
          current: const ClientConnectionState.connecting(),
          computed: const ClientConnectionState.failed(ConnectionErrorMapper.coreStartFailed),
        ),
        isTrue,
      );
    });

    test('does not preserve active state after user intent is cleared', () {
      final shouldPreserve = ClientConnectionStatePolicy.shouldPreserveActiveState(
        userRequestedConnection: false,
        current: const ClientConnectionState.connecting(),
        computed: const ClientConnectionState.disconnected(),
      );

      expect(shouldPreserve, isFalse);
    });

    test('does not preserve non-busy current states', () {
      final shouldPreserve = ClientConnectionStatePolicy.shouldPreserveActiveState(
        userRequestedConnection: true,
        current: const ClientConnectionState.connected(),
        computed: const ClientConnectionState.disconnected(),
      );

      expect(shouldPreserve, isFalse);
    });

    test('preserves reconnecting state during core restart events', () {
      expect(
        ClientConnectionStatePolicy.shouldPreserveReconnectDuringCoreRestart(
          userRequestedConnection: true,
          manualDisconnecting: false,
          current: const ClientConnectionState.reconnecting(),
        ),
        isTrue,
      );
      expect(
        ClientConnectionStatePolicy.shouldPreserveReconnectDuringCoreRestart(
          userRequestedConnection: false,
          manualDisconnecting: false,
          current: const ClientConnectionState.reconnecting(),
        ),
        isFalse,
      );
      expect(
        ClientConnectionStatePolicy.shouldPreserveReconnectDuringCoreRestart(
          userRequestedConnection: true,
          manualDisconnecting: true,
          current: const ClientConnectionState.reconnecting(),
        ),
        isFalse,
      );
      expect(
        ClientConnectionStatePolicy.shouldPreserveReconnectDuringCoreRestart(
          userRequestedConnection: true,
          manualDisconnecting: false,
          current: const ClientConnectionState.disconnected(),
        ),
        isFalse,
      );
    });

    test('suppresses disconnect failure only for manual or already-disconnecting paths', () {
      expect(
        ClientConnectionStatePolicy.shouldSuppressDisconnectFailure(manualDisconnecting: true, wasDisconnecting: false),
        isTrue,
      );
      expect(
        ClientConnectionStatePolicy.shouldSuppressDisconnectFailure(manualDisconnecting: false, wasDisconnecting: true),
        isTrue,
      );
      expect(
        ClientConnectionStatePolicy.shouldSuppressDisconnectFailure(
          manualDisconnecting: false,
          wasDisconnecting: false,
        ),
        isFalse,
      );
    });
  });
}
