enum ClientConnectionPhase {
  initializing,
  loggedOut,
  disconnected,
  preparing,
  requestingVpnPermission,
  connecting,
  connected,
  reconnecting,
  stopping,
  failed,
}

class ClientConnectionState {
  const ClientConnectionState(this.phase, {this.message});

  const ClientConnectionState.initializing() : this(ClientConnectionPhase.initializing);

  const ClientConnectionState.loggedOut() : this(ClientConnectionPhase.loggedOut);

  const ClientConnectionState.disconnected() : this(ClientConnectionPhase.disconnected);

  const ClientConnectionState.preparing() : this(ClientConnectionPhase.preparing);

  const ClientConnectionState.requestingVpnPermission() : this(ClientConnectionPhase.requestingVpnPermission);

  const ClientConnectionState.connecting() : this(ClientConnectionPhase.connecting);

  const ClientConnectionState.connected() : this(ClientConnectionPhase.connected);

  const ClientConnectionState.reconnecting() : this(ClientConnectionPhase.reconnecting);

  const ClientConnectionState.stopping() : this(ClientConnectionPhase.stopping);

  const ClientConnectionState.failed(String message) : this(ClientConnectionPhase.failed, message: message);

  final ClientConnectionPhase phase;
  final String? message;

  bool get canTap => switch (phase) {
    ClientConnectionPhase.loggedOut ||
    ClientConnectionPhase.disconnected ||
    ClientConnectionPhase.connected ||
    ClientConnectionPhase.failed => true,
    ClientConnectionPhase.initializing ||
    ClientConnectionPhase.preparing ||
    ClientConnectionPhase.requestingVpnPermission ||
    ClientConnectionPhase.connecting ||
    ClientConnectionPhase.reconnecting ||
    ClientConnectionPhase.stopping => false,
  };

  bool get isBusy => switch (phase) {
    ClientConnectionPhase.preparing ||
    ClientConnectionPhase.requestingVpnPermission ||
    ClientConnectionPhase.connecting ||
    ClientConnectionPhase.reconnecting ||
    ClientConnectionPhase.stopping => true,
    _ => false,
  };

  String get buttonLabel => switch (phase) {
    ClientConnectionPhase.initializing => '初始化中',
    ClientConnectionPhase.loggedOut => '登录后加速',
    ClientConnectionPhase.disconnected => '开始加速',
    ClientConnectionPhase.preparing ||
    ClientConnectionPhase.requestingVpnPermission ||
    ClientConnectionPhase.connecting => '连接中',
    ClientConnectionPhase.connected => '停止加速',
    ClientConnectionPhase.reconnecting => '正在重连',
    ClientConnectionPhase.stopping => '正在停止',
    ClientConnectionPhase.failed => '重新连接',
  };

  @override
  String toString() => 'ClientConnectionState(${phase.name}${message == null ? '' : ', message: $message'})';
}

abstract final class ClientConnectionStatePolicy {
  static bool shouldPreserveActiveState({
    required bool userRequestedConnection,
    required ClientConnectionState current,
    required ClientConnectionState computed,
  }) {
    if (current.phase == ClientConnectionPhase.stopping) {
      return computed.phase == ClientConnectionPhase.connected ||
          computed.phase == ClientConnectionPhase.connecting ||
          computed.phase == ClientConnectionPhase.failed;
    }
    if (!userRequestedConnection) return false;
    if (!current.isBusy) return false;
    return computed.phase == ClientConnectionPhase.disconnected ||
        computed.phase == ClientConnectionPhase.initializing ||
        computed.phase == ClientConnectionPhase.failed;
  }

  static bool shouldPreserveReconnectDuringCoreRestart({
    required bool userRequestedConnection,
    required bool manualDisconnecting,
    required ClientConnectionState current,
  }) {
    return userRequestedConnection && !manualDisconnecting && current.phase == ClientConnectionPhase.reconnecting;
  }

  static bool shouldSuppressDisconnectFailure({required bool manualDisconnecting, required bool wasDisconnecting}) {
    return manualDisconnecting || wasDisconnecting;
  }
}
