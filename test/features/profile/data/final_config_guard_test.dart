import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/profile/data/final_config_guard.dart';

void main() {
  group('FinalConfigGuard', () {
    test('removes fake-ip DNS server and fake-ip route rules from final config', () {
      final content = jsonEncode({
        'dns': {
          'servers': [
            {'tag': 'dns-fakeip', 'address': 'fakeip'},
            {'tag': 'dns-remote', 'address': 'tcp://8.8.8.8'},
          ],
          'rules': [
            {
              'query_type': ['A', 'AAAA'],
              'server': 'dns-fakeip',
            },
            {'server': 'dns-remote'},
          ],
          'final': 'dns-fakeip',
          'fakeip': {'enabled': true, 'inet4_range': '198.18.0.0/15'},
        },
        'route': {
          'rules': [
            {
              'ip_cidr': ['198.18.0.0/15'],
              'outbound': 'proxy',
            },
            {
              'domain': ['example.com'],
              'outbound': 'proxy',
            },
          ],
          'final': 'block',
        },
        'outbounds': [
          {'tag': 'proxy', 'type': 'selector'},
          {'tag': 'block', 'type': 'block'},
        ],
      });

      final result = const FinalConfigGuard().inspectAndSanitizeContent(content);

      expect(result.fakeIpBefore, isTrue);
      expect(result.fakeIpAfter, isFalse);
      expect(result.changed, isTrue);
      expect(result.dnsFinal, 'dns-remote');
      expect(result.routeFinal, 'proxy');
      expect(result.removedFakeDnsServers, 1);
      expect(result.removedFakeDnsRules, 1);
      expect(result.removedFakeRouteRules, 1);

      final sanitized = jsonDecode(result.sanitizedContent!) as Map<String, dynamic>;
      expect(jsonEncode(sanitized), isNot(contains('fakeip')));
      expect(jsonEncode(sanitized), isNot(contains('198.18.')));
    });

    test('locks DNS to proxy detour, IPv4 only, and removes IPv6/default block rules', () {
      final content = jsonEncode({
        'dns': {
          'servers': [
            {'tag': 'dns-remote', 'address': 'tcp://8.8.8.8', 'detour': 'direct'},
          ],
          'rules': [
            {'ip_version': 6, 'server': 'dns-remote'},
          ],
          'final': 'dns-remote',
        },
        'route': {
          'rules': [
            {'ip_version': 6, 'outbound': 'direct'},
            {
              'geosite': ['cn'],
              'outbound': 'direct',
            },
            {'outbound': 'block'},
            {
              'domain': ['example.com'],
              'outbound': 'proxy',
            },
          ],
          'rule_set': [
            {'tag': 'geoip-cn'},
          ],
          'final': 'direct',
        },
        'inbounds': [
          {
            'type': 'tun',
            'inet4_address': ['172.19.0.1/30'],
            'inet6_address': ['fdfe::1/126'],
            'route_address': ['0.0.0.0/0', '::/0'],
          },
        ],
      });

      final result = const FinalConfigGuard().inspectAndSanitizeContent(content);

      expect(result.fakeIpAfter, isFalse);
      expect(result.routeFinal, 'proxy');
      expect(result.removedIpv6DnsRules, 1);
      expect(result.removedIpv6RouteRules, 1);
      expect(result.removedGeoRouteRules, greaterThanOrEqualTo(1));
      expect(result.removedCatchAllRules, 1);
      expect(result.removedIpv6TunValues, greaterThanOrEqualTo(1));
      expect(result.forcedDnsDetours, 1);
      expect(result.forcedDnsStrategies, greaterThanOrEqualTo(1));

      final sanitized = jsonDecode(result.sanitizedContent!) as Map<String, dynamic>;
      final dnsServer = ((sanitized['dns'] as Map)['servers'] as List).single as Map;
      expect(dnsServer['detour'], 'proxy');
      expect(dnsServer['strategy'], 'ipv4_only');
      expect((sanitized['dns'] as Map)['strategy'], 'ipv4_only');
      expect(jsonEncode(sanitized), isNot(contains('::/0')));
      expect(jsonEncode(sanitized), isNot(contains('inet6_address')));
      expect((sanitized['route'] as Map)['final'], 'proxy');
    });
  });
}
