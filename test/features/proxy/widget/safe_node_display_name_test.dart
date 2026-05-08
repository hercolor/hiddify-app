import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/proxy/widget/safe_node_display_name.dart';

void main() {
  group('safeNodeDisplayName', () {
    test('keeps friendly commercial node names', () {
      expect(safeNodeDisplayName('香港-01'), '香港-01');
      expect(safeNodeDisplayName('日本 Premium 02'), '日本 Premium 02');
    });

    test('falls back for blank or raw config fragments', () {
      expect(safeNodeDisplayName(null), '未命名节点');
      expect(safeNodeDisplayName('   '), '未命名节点');
      expect(safeNodeDisplayName('{"server":"hk.example.com","port":443,"cipher":"auto"}'), '未命名节点');
    });

    test('masks URLs and protocol-like prefixes', () {
      expect(safeNodeDisplayName('香港 https://hk.example.com:443'), '香港');
      expect(safeNodeDisplayName('vmess://abcdefg'), '未命名节点');
      expect(safeNodeDisplayName('客服 mailto:test@example.com'), '客服');
    });

    test('masks IPv4 and IPv6 literals', () {
      expect(safeNodeDisplayName('香港 192.168.1.1:443'), '香港');
      expect(safeNodeDisplayName('香港 2001:db8::1'), '香港');
    });

    test('masks domain and domain port forms', () {
      expect(safeNodeDisplayName('香港 hk.example.com'), '香港');
      expect(safeNodeDisplayName('hk.example.com:443'), '未命名节点');
    });

    test('masks protocol tokens and server assignments', () {
      expect(safeNodeDisplayName('香港 vmess 01'), '香港 01');
      expect(safeNodeDisplayName('香港 server=hk.example.com port=443'), '未命名节点');
    });

    test('supports custom fallback and truncates overlong friendly names', () {
      expect(safeNodeDisplayName('', fallback: '暂无可用节点'), '暂无可用节点');
      final value = safeNodeDisplayName('香港节点${'好' * 80}');
      expect(value.endsWith('…'), isTrue);
      expect(value.length, 49);
    });
  });
}
