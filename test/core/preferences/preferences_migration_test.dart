import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/config/locked_core_config.dart';
import 'package:hiddify/core/preferences/preferences_migration.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ConsumerConfigSchemaMigration', () {
    test('cleans unsafe legacy core settings and preserves auth/node cache keys', () async {
      SharedPreferences.setMockInitialValues({
        LockedCoreConfig.schemaVersionKey: 0,
        'enable-fake-dns': true,
        'ipv6-mode': 'prefer_ipv6',
        'remote-dns-domain-strategy': 'prefer_ipv6',
        'direct-dns-domain-strategy': 'ipv6_only',
        'dnsMode': 'fake-ip',
        'routeMode': 'direct',
        'customConfig': 'enhanced-mode: fake-ip\nfake-ip-range: 198.18.0.1/16',
        'tunSettings': '{"ipv6":true}',
        'mixed-port': 5555,
        'log-level': 'trace',
        'legacyBlob': '198.18.0.9',
        'authData': 'Bearer preserved',
        'subscribeToken': 'subscribe-token-preserved',
        'selectedNodeId': 'node-1',
        'nodeList': 'cached-nodes-even-if-value-has-198.18.1.1',
      });
      final preferences = await SharedPreferences.getInstance();

      await ConsumerConfigSchemaMigration(preferences).migrate();

      expect(preferences.getInt(LockedCoreConfig.schemaVersionKey), LockedCoreConfig.schemaVersion);
      expect(preferences.getBool('enable-fake-dns'), isFalse);
      expect(preferences.getString('ipv6-mode'), LockedCoreConfig.dnsStrategy);
      expect(preferences.getString('remote-dns-domain-strategy'), LockedCoreConfig.dnsStrategy);
      expect(preferences.getString('direct-dns-domain-strategy'), LockedCoreConfig.dnsStrategy);
      expect(preferences.getBool('bypass-lan'), isFalse);
      expect(preferences.getBool('block-ads'), isFalse);
      expect(preferences.containsKey('dnsMode'), isFalse);
      expect(preferences.containsKey('routeMode'), isFalse);
      expect(preferences.containsKey('customConfig'), isFalse);
      expect(preferences.containsKey('tunSettings'), isFalse);
      expect(preferences.containsKey('mixed-port'), isFalse);
      expect(preferences.containsKey('log-level'), isFalse);
      expect(preferences.containsKey('legacyBlob'), isFalse);
      expect(preferences.getString('authData'), 'Bearer preserved');
      expect(preferences.getString('subscribeToken'), 'subscribe-token-preserved');
      expect(preferences.getString('selectedNodeId'), 'node-1');
      expect(preferences.getString('nodeList'), 'cached-nodes-even-if-value-has-198.18.1.1');
    });
  });
}
