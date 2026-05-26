import 'dart:async';

import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/proxy/model/client_node.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClientNodeStore {
  ClientNodeStore(this._preferences);

  static const nodeListKey = 'nodeList';
  static const selectedNodeIdKey = 'selectedNodeId';
  static const profileNameKey = 'profileName';

  final SharedPreferences _preferences;

  Future<ClientNodeSelection> read() async {
    final nodes = ClientNodeSelection.decodeNodes(_preferences.getString(nodeListKey));
    return ClientNodeSelection(
      nodes: nodes,
      selectedNodeId: _preferences.getString(selectedNodeIdKey),
      profileName: _preferences.getString(profileNameKey),
    ).normalized();
  }

  Future<void> save(ClientNodeSelection selection) async {
    final normalized = selection.normalized();
    await _preferences.setString(nodeListKey, normalized.encodeNodes());
    final selectedNodeId = normalized.effectiveSelectedNodeId;
    if (selectedNodeId == null || selectedNodeId.isEmpty) {
      await _preferences.remove(selectedNodeIdKey);
    } else {
      await _preferences.setString(selectedNodeIdKey, selectedNodeId);
    }
    final profileName = normalized.profileName?.trim();
    if (profileName == null || profileName.isEmpty) {
      await _preferences.remove(profileNameKey);
    } else {
      await _preferences.setString(profileNameKey, profileName);
    }
  }

  Future<void> clear() async {
    await _preferences.remove(nodeListKey);
    await _preferences.remove(selectedNodeIdKey);
    await _preferences.remove(profileNameKey);
  }
}

final clientNodeStoreProvider = Provider<ClientNodeStore>((ref) {
  return ClientNodeStore(ref.watch(sharedPreferencesProvider).requireValue);
});

final clientNodeSelectionProvider = StateNotifierProvider<ClientNodeSelectionNotifier, AsyncValue<ClientNodeSelection>>(
  ClientNodeSelectionNotifier.new,
);

class ClientNodeSelectionNotifier extends StateNotifier<AsyncValue<ClientNodeSelection>> with AppLogger {
  ClientNodeSelectionNotifier(this._ref) : super(const AsyncLoading()) {
    unawaited(load());
  }

  final Ref _ref;

  Future<ClientNodeSelection> load() async {
    final stopwatch = Stopwatch()..start();
    try {
      final selection = await _ref.read(clientNodeStoreProvider).read();
      state = AsyncData(selection);
      _logSelection('cached nodes loaded', selection, loadCachedNodesMs: stopwatch.elapsedMilliseconds);
      return selection;
    } catch (error, stackTrace) {
      loggy.warning('failed to load cached client nodes', error, stackTrace);
      const selection = ClientNodeSelection.empty();
      state = const AsyncData(selection);
      return selection;
    } finally {
      stopwatch.stop();
    }
  }

  Future<ClientNodeSelection> ensureLoaded() async {
    final value = state.valueOrNull;
    if (value != null) return value;
    return load();
  }

  Future<void> cacheNodes(List<ClientNode> nodes, {String? profileName, String? preferredSelectedNodeId}) async {
    final previous = state.valueOrNull ?? await _ref.read(clientNodeStoreProvider).read();
    final selection = ClientNodeSelection(
      nodes: nodes,
      selectedNodeId: preferredSelectedNodeId ?? previous.selectedNodeId,
      profileName: profileName ?? previous.profileName,
    ).normalized();
    await _ref.read(clientNodeStoreProvider).save(selection);
    state = AsyncData(selection);
    _logSelection('client nodes cached', selection);
  }

  Future<void> cacheFromOutboundGroup(OutboundGroup group) async {
    final nodes = ClientNodeParser.fromOutboundGroup(group);
    if (nodes.isEmpty) return;
    // The core group selection can be changed by urltest/selector defaults while
    // profiles are refreshed or route mode is toggled. Preserve the user-visible
    // selected node stored by the app; only fall back to the first node when the
    // previous selection no longer exists.
    await cacheNodes(nodes);
  }

  Future<void> selectNode(String nodeId) async {
    final current = state.valueOrNull ?? await _ref.read(clientNodeStoreProvider).read();
    final selection = current.copyWith(selectedNodeId: nodeId);
    await _ref.read(clientNodeStoreProvider).save(selection);
    state = AsyncData(selection);
    _logSelection('client selected node updated', selection);
  }

  Future<void> clear() async {
    await _ref.read(clientNodeStoreProvider).clear();
    state = const AsyncData(ClientNodeSelection.empty());
  }

  void _logSelection(String event, ClientNodeSelection selection, {int? loadCachedNodesMs}) {
    final selectedNode = selection.selectedNode;
    loggy.debug(
      '$event: '
      'profileName=${_safe(selection.profileName ?? '--')}, '
      'nodeCount=${selection.nodeCount}, '
      'selectedNodeId=${_safe(selection.effectiveSelectedNodeId ?? '--')}, '
      'selectedNodeName=${_safe(selectedNode?.name ?? '--')}'
      '${loadCachedNodesMs == null ? '' : ', loadCachedNodesMs=$loadCachedNodesMs'}',
    );
  }

  String _safe(String value) {
    final sanitized = value.replaceAll(RegExp(r'https?://[^\s]+'), 'https://***');
    if (sanitized.length > 64) return '${sanitized.substring(0, 64)}…';
    return sanitized;
  }
}
