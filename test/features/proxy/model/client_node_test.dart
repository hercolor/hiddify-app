import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/proxy/model/client_node.dart';

void main() {
  group('ClientNodeParser', () {
    test('parses Clash YAML nodes without exposing server fields', () {
      const yaml = '''
proxies:
  - name: 香港-01
    type: vmess
    server: hk.example.com
    port: 443
  - {name: 日本-02, type: trojan, server: jp.example.com, port: 443}
proxy-groups:
  - name: 自动选择
    type: select
''';

      final nodes = ClientNodeParser.parse(yaml);

      expect(nodes.map((e) => e.name), ['香港-01', '日本-02']);
      expect(nodes.map((e) => e.id), ['香港-01', '日本-02']);
    });

    test('parses XBoard Clash YAML JSON-style proxy rows', () {
      const yaml = '''
proxies:
  - {"name":"香港-01","type":"vmess","server":"hk.example.com","port":443}
  - {'name':'日本-02','type':'trojan','server':'jp.example.com','port':443}
proxy-groups:
  - name: 节点选择
    type: select
''';

      final nodes = ClientNodeParser.parse(yaml);

      expect(nodes.map((e) => e.name), ['香港-01', '日本-02']);
    });

    test('parses Clash JSON proxies list', () {
      const json = '''
{
  "proxies": [
    {"name":"香港-01","type":"vmess","server":"hk.example.com"},
    {"name":"日本-02","type":"trojan","server":"jp.example.com"}
  ]
}
''';

      final nodes = ClientNodeParser.parse(json);

      expect(nodes.map((e) => e.name), ['香港-01', '日本-02']);
    });

    test('parses sing-box outbound tags and ignores system outbounds', () {
      const json = '''
{
  "outbounds": [
    {"type":"selector", "tag":"select", "outbounds":["香港-01", "日本-02"]},
    {"type":"vmess", "tag":"香港-01", "server":"hk.example.com"},
    {"type":"trojan", "tag":"日本-02", "server":"jp.example.com"},
    {"type":"direct", "tag":"direct"},
    {"type":"block", "tag":"block"}
  ]
}
''';

      final nodes = ClientNodeParser.parse(json);

      expect(nodes.map((e) => e.name), ['香港-01', '日本-02']);
    });

    test('defaults selected node to first cached node when selected id is absent', () {
      const selection = ClientNodeSelection(
        nodes: [
          ClientNode(id: 'hk-01', name: '香港-01'),
          ClientNode(id: 'jp-02', name: '日本-02'),
        ],
      );

      expect(selection.normalized().effectiveSelectedNodeId, 'hk-01');
      expect(selection.normalized().selectedNode?.name, '香港-01');
    });

    test('merges runtime nodes without dropping subscription nodes', () {
      const selection = ClientNodeSelection(
        nodes: [
          ClientNode(id: '香港-IPEL', name: '香港-IPEL'),
          ClientNode(id: '日本-02', name: '日本-02'),
        ],
        selectedNodeId: '香港-IPEL',
        profileName: '蝴蝶加速',
      );

      final merged = selection.mergeRuntimeNodes([const ClientNode(id: '香港-IPEL', name: '香港-IPEL', delay: 123)]);

      expect(merged.nodes.map((node) => node.id), ['香港-IPEL', '日本-02']);
      expect(merged.nodes.first.delay, 123);
      expect(merged.nodes.last.delay, isNull);
      expect(merged.effectiveSelectedNodeId, '香港-IPEL');
      expect(merged.profileName, '蝴蝶加速');
    });

    test('uses runtime nodes when no subscription nodes are cached yet', () {
      const selection = ClientNodeSelection.empty();

      final merged = selection.mergeRuntimeNodes([const ClientNode(id: '香港-IPEL', name: '香港-IPEL', delay: 123)]);

      expect(merged.nodes.map((node) => node.id), ['香港-IPEL']);
      expect(merged.effectiveSelectedNodeId, '香港-IPEL');
    });
  });
}
