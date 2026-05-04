enum ClientConnectionPhase {
  initializing,
  loggedOut,
  disconnected,
  preparing,
  requestingVpnPermission,
  connecting,
  connected,
  reconnecting,
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
    ClientConnectionPhase.reconnecting => false,
  };

  bool get isBusy => switch (phase) {
    ClientConnectionPhase.preparing ||
    ClientConnectionPhase.requestingVpnPermission ||
    ClientConnectionPhase.connecting ||
    ClientConnectionPhase.reconnecting => true,
    _ => false,
  };

  String get buttonLabel => switch (phase) {
    ClientConnectionPhase.initializing => '初始化中',
    ClientConnectionPhase.loggedOut => '登录后加速',
    ClientConnectionPhase.disconnected => '一键加速',
    ClientConnectionPhase.preparing ||
    ClientConnectionPhase.requestingVpnPermission ||
    ClientConnectionPhase.connecting => '连接中',
    ClientConnectionPhase.connected => '停止加速',
    ClientConnectionPhase.reconnecting => '正在重连',
    ClientConnectionPhase.failed => '重新连接',
  };

  @override
  String toString() => 'ClientConnectionState(${phase.name}${message == null ? '' : ', message: $message'})';
}
