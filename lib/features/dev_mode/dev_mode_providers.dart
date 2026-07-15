import 'package:hiddify/features/connection/model/client_connection_state.dart';
import 'package:hiddify/features/proxy/model/client_node.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final devModeProvider = Provider<bool>((ref) {
  // 临时启用测试模式，让 release 版本也能显示测试节点
  // 正式发布前改回: return kDebugMode;
  return true;
});

final mockClientNodeSelectionProvider = StateNotifierProvider<MockClientNodeSelectionNotifier, ClientNodeSelection>(
  (ref) => MockClientNodeSelectionNotifier(),
);

class MockClientNodeSelectionNotifier extends StateNotifier<ClientNodeSelection> {
  MockClientNodeSelectionNotifier() : super(_mockSelection);

  static final _mockNodes = [
    ClientNode(id: 'hk-01', name: '香港-01', delay: 28),
    ClientNode(id: 'hk-02', name: '香港-02', delay: 35),
    ClientNode(id: 'us-01', name: '美国-01', delay: 120),
    ClientNode(id: 'us-02', name: '美国-02', delay: 135),
    ClientNode(id: 'jp-01', name: '日本-01', delay: 68),
    ClientNode(id: 'jp-02', name: '日本-02', delay: 75),
    ClientNode(id: 'sg-01', name: '新加坡-01', delay: 45),
    ClientNode(id: 'sg-02', name: '新加坡-02', delay: 52),
    ClientNode(id: 'kr-01', name: '韩国-01', delay: 58),
    ClientNode(id: 'kr-02', name: '韩国-02', delay: 62),
    ClientNode(id: 'gb-01', name: '英国-01', delay: 180),
    ClientNode(id: 'de-01', name: '德国-01', delay: 165),
    ClientNode(id: 'au-01', name: '澳大利亚-01', delay: 220),
    ClientNode(id: 'ca-01', name: '加拿大-01', delay: 145),
    ClientNode(id: 'tw-01', name: '台湾-01', delay: 38),
    ClientNode(id: 'cn-01', name: '中国-01', delay: 15),
  ];

  static final _mockSelection = ClientNodeSelection(nodes: _mockNodes, selectedNodeId: 'hk-01', profileName: 'BflyVPN');

  void selectNode(String nodeId) {
    state = state.copyWith(selectedNodeId: nodeId);
  }
}

final mockClientConnectionStateProvider = StateNotifierProvider<MockConnectionStateNotifier, ClientConnectionState>(
  (ref) => MockConnectionStateNotifier(),
);

class MockConnectionStateNotifier extends StateNotifier<ClientConnectionState> {
  MockConnectionStateNotifier() : super(const ClientConnectionState.disconnected());

  bool _isConnected = false;

  void toggle() {
    if (_isConnected) {
      disconnect();
    } else {
      connect();
    }
  }

  void connect() {
    _isConnected = true;
    state = const ClientConnectionState.connecting();
  }

  void connected() {
    _isConnected = true;
    state = const ClientConnectionState.connected();
  }

  void disconnect() {
    _isConnected = false;
    state = const ClientConnectionState.disconnected();
  }

  void fail(String message) {
    _isConnected = false;
    state = ClientConnectionState.failed(message);
  }
}
