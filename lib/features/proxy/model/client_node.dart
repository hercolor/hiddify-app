import 'dart:convert';

import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';

class ClientNode {
  const ClientNode({required this.id, required this.name, this.delay});

  final String id;
  final String name;
  final int? delay;

  ClientNode copyWith({String? id, String? name, int? delay}) =>
      ClientNode(id: id ?? this.id, name: name ?? this.name, delay: delay ?? this.delay);

  Map<String, Object?> toJson() => {'id': id, 'name': name, if (delay != null) 'delay': delay};

  static ClientNode? fromJson(Object? value) {
    if (value is! Map) return null;
    final id = value['id']?.toString().trim();
    final name = value['name']?.toString().trim();
    if (id == null || id.isEmpty || name == null || name.isEmpty) return null;
    return ClientNode(id: id, name: name, delay: int.tryParse(value['delay']?.toString() ?? ''));
  }
}

class ClientNodeSelection {
  const ClientNodeSelection({required this.nodes, this.selectedNodeId, this.profileName});

  const ClientNodeSelection.empty() : nodes = const [], selectedNodeId = null, profileName = null;

  final List<ClientNode> nodes;
  final String? selectedNodeId;
  final String? profileName;

  int get nodeCount => nodes.length;

  ClientNode? get selectedNode {
    if (nodes.isEmpty) return null;
    final id = selectedNodeId?.trim();
    if (id != null && id.isNotEmpty) {
      for (final node in nodes) {
        if (node.id == id) return node;
      }
    }
    return nodes.first;
  }

  String? get effectiveSelectedNodeId => selectedNode?.id;

  ClientNodeSelection normalized() {
    final deduped = <String, ClientNode>{};
    for (final node in nodes) {
      final id = node.id.trim();
      final name = node.name.trim();
      if (id.isEmpty || name.isEmpty) continue;
      deduped.putIfAbsent(id, () => ClientNode(id: id, name: name, delay: node.delay));
    }
    final list = List<ClientNode>.unmodifiable(deduped.values);
    final selected = selectedNodeId?.trim();
    final nextSelected = selected != null && deduped.containsKey(selected)
        ? selected
        : list.isNotEmpty
        ? list.first.id
        : null;
    return ClientNodeSelection(nodes: list, selectedNodeId: nextSelected, profileName: profileName);
  }

  ClientNodeSelection copyWith({List<ClientNode>? nodes, String? selectedNodeId, String? profileName}) =>
      ClientNodeSelection(
        nodes: nodes ?? this.nodes,
        selectedNodeId: selectedNodeId ?? this.selectedNodeId,
        profileName: profileName ?? this.profileName,
      ).normalized();

  ClientNodeSelection mergeRuntimeNodes(List<ClientNode> runtimeNodes) {
    final current = normalized();
    final runtime = ClientNodeSelection(nodes: runtimeNodes).normalized();
    if (runtime.nodes.isEmpty) return current;
    if (current.nodes.isEmpty) {
      return ClientNodeSelection(
        nodes: runtime.nodes,
        selectedNodeId: selectedNodeId,
        profileName: profileName,
      ).normalized();
    }

    final runtimeById = <String, ClientNode>{for (final node in runtime.nodes) node.id.trim(): node};
    final seen = <String>{};
    final merged = <ClientNode>[];
    for (final node in current.nodes) {
      final id = node.id.trim();
      seen.add(id);
      final runtimeNode = runtimeById[id];
      merged.add(
        runtimeNode == null ? node : ClientNode(id: node.id, name: node.name, delay: runtimeNode.delay ?? node.delay),
      );
    }
    for (final runtimeNode in runtime.nodes) {
      if (seen.add(runtimeNode.id.trim())) merged.add(runtimeNode);
    }
    return ClientNodeSelection(
      nodes: merged,
      selectedNodeId: current.selectedNodeId,
      profileName: current.profileName,
    ).normalized();
  }

  String encodeNodes() => jsonEncode(nodes.map((node) => node.toJson()).toList());

  static List<ClientNode> decodeNodes(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded.map(ClientNode.fromJson).whereType<ClientNode>().toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}

abstract final class ClientNodeParser {
  static const _systemTags = {
    'direct',
    'block',
    'dns',
    'dns-out',
    'dns-remote',
    'dns-direct',
    'proxy',
    'select',
    'selector',
    'auto',
    'urltest',
    'url-test',
    'bypass',
  };

  static const _groupTypes = {'selector', 'urltest', 'url-test', 'direct', 'block', 'dns'};

  static List<ClientNode> parse(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return const [];
    return _dedupe([
      ..._parseJson(trimmed),
      ..._parseClashYaml(trimmed),
      ..._parseUriLines(_decodeBase64IfNeeded(trimmed)),
    ]);
  }

  static List<ClientNode> fromOutboundGroup(OutboundGroup group) {
    return _dedupe(
      group.items.where(_isUserVisibleOutbound).map((item) {
        final name = _cleanName(item.tagDisplay.isNotEmpty ? item.tagDisplay : item.tag);
        return ClientNode(
          id: item.tag.isNotEmpty ? item.tag : name,
          name: name,
          delay: item.urlTestDelay == 0 ? null : item.urlTestDelay,
        );
      }),
    );
  }

  static bool isUserVisibleOutbound(OutboundInfo item) => _isUserVisibleOutbound(item);

  static bool _isUserVisibleOutbound(OutboundInfo item) {
    final name = _cleanName(item.tagDisplay.isNotEmpty ? item.tagDisplay : item.tag);
    final type = item.type.toLowerCase();
    final tag = item.tag.toLowerCase();
    if (name.isEmpty || item.isGroup || item.isVisible == false) return false;
    if (_groupTypes.contains(type) || _systemTags.contains(tag) || _systemTags.contains(name.toLowerCase())) {
      return false;
    }
    return true;
  }

  static List<ClientNode> _parseJson(String content) {
    if (!content.startsWith('{') && !content.startsWith('[')) return const [];
    try {
      final decoded = jsonDecode(content);
      final root = decoded is Map ? decoded : <String, Object?>{};
      final proxies = root['proxies'];
      if (proxies is List) {
        final nodes = proxies
            .whereType<Map>()
            .map((item) => item['name']?.toString().trim())
            .whereType<String>()
            .where((name) => name.isNotEmpty)
            .map((name) => ClientNode(id: name, name: _cleanName(name)));
        final parsed = _dedupe(nodes);
        if (parsed.isNotEmpty) return parsed;
      }

      final outbounds = root['outbounds'];
      if (outbounds is! List) return const [];

      final byTag = <String, ClientNode>{};
      final preferredOrder = <String>[];
      for (final item in outbounds.whereType<Map>()) {
        final tag = item['tag']?.toString().trim();
        final type = item['type']?.toString().toLowerCase().trim() ?? '';
        if (tag == null || tag.isEmpty) continue;
        if (item['outbounds'] is List) {
          preferredOrder.addAll((item['outbounds'] as List).map((e) => e.toString()).where((e) => e.trim().isNotEmpty));
        }
        if (_groupTypes.contains(type) || _systemTags.contains(tag.toLowerCase())) continue;
        byTag[tag] = ClientNode(id: tag, name: _cleanName(tag));
      }
      if (preferredOrder.isEmpty) return _dedupe(byTag.values);
      final ordered = <ClientNode>[];
      for (final tag in preferredOrder) {
        final node = byTag[tag];
        if (node != null) ordered.add(node);
      }
      ordered.addAll(byTag.values.where((node) => !ordered.any((existing) => existing.id == node.id)));
      return _dedupe(ordered);
    } catch (_) {
      return const [];
    }
  }

  static List<ClientNode> _parseClashYaml(String content) {
    final nodes = <ClientNode>[];
    final blockMatch = RegExp(
      r'^proxies:\s*(.*?)(?:^proxy-groups:|^rules:|\z)',
      multiLine: true,
      dotAll: true,
    ).firstMatch(content);
    final block = blockMatch?.group(1) ?? '';
    if (block.isEmpty) return const [];

    for (final match in RegExp(
      r'''^\s*-\s*name\s*:\s*(?:"([^"]+)"|'([^']+)'|([^#\n]+))''',
      multiLine: true,
    ).allMatches(block)) {
      final name = _cleanName(match.group(1) ?? match.group(2) ?? match.group(3) ?? '');
      if (name.isNotEmpty) nodes.add(ClientNode(id: name, name: name));
    }
    for (final match in RegExp(
      r'''^\s*-\s*\{[^}\n]*(?:"name"|'name'|name)\s*:\s*(?:"([^"]+)"|'([^']+)'|([^,}\n#]+))''',
      multiLine: true,
    ).allMatches(block)) {
      final name = _cleanName(match.group(1) ?? match.group(2) ?? match.group(3) ?? '');
      if (name.isNotEmpty) nodes.add(ClientNode(id: name, name: name));
    }
    return _dedupe(nodes);
  }

  static List<ClientNode> _parseUriLines(String content) {
    final nodes = <ClientNode>[];
    for (final rawLine in content.split(RegExp(r'[\r\n]+'))) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final uri = Uri.tryParse(line);
      if (uri == null || uri.scheme.isEmpty) continue;
      if (!{
        'ss',
        'ssconf',
        'vmess',
        'vless',
        'trojan',
        'tuic',
        'hy2',
        'hysteria2',
        'hy',
        'hysteria',
        'ssh',
        'wg',
        'shadowtls',
      }.contains(uri.scheme.toLowerCase())) {
        continue;
      }
      final name = uri.hasFragment ? _cleanName(Uri.decodeComponent(uri.fragment.split(' -> ').first)) : '';
      if (name.isNotEmpty) nodes.add(ClientNode(id: name, name: name));
    }
    return _dedupe(nodes);
  }

  static String _decodeBase64IfNeeded(String content) {
    if (content.contains('\n') || content.contains('{') || content.contains('proxies:')) return content;
    try {
      final normalized = base64.normalize(content);
      final decoded = utf8.decode(base64.decode(normalized), allowMalformed: true);
      return decoded.trim().isEmpty ? content : decoded;
    } catch (_) {
      return content;
    }
  }

  static String _cleanName(String value) {
    return value.replaceAll(RegExp(r'\s+#.*$'), '').replaceAll(RegExp(r'''^['"]|['"]$'''), '').trim();
  }

  static List<ClientNode> _dedupe(Iterable<ClientNode> nodes) {
    final map = <String, ClientNode>{};
    for (final node in nodes) {
      final id = node.id.trim();
      final name = node.name.trim();
      if (id.isEmpty || name.isEmpty || _systemTags.contains(name.toLowerCase())) continue;
      map.putIfAbsent(id, () => ClientNode(id: id, name: name, delay: node.delay));
    }
    return List.unmodifiable(map.values);
  }
}
