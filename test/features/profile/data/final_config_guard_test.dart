import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/config/locked_core_config.dart';
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

    test('locks DNS to proxy detour, IPv4 only, and keeps smart route rule sets', () {
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
      expect(result.removedGeoRouteRules, 0);
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
      final route = sanitized['route'] as Map;
      expect(route['final'], 'proxy');
      expect(route['rule_set'], isNotEmpty);
      expect(jsonEncode(route['rules']), contains('geosite'));
    });

    test('removes inherited Clash fake-ip and IPv6 DNS while keeping real-ip proxy DNS', () {
      final content = jsonEncode({
        'dns': {
          'enhanced-mode': 'fake-ip',
          'fake-ip-range': '198.18.0.1/16',
          'servers': [
            {'tag': 'dns-fake', 'type': 'fakeip', 'address': 'fakeip'},
            {'tag': 'dns-ipv6', 'address': 'udp://[2001:4860:4860::8888]'},
            {'tag': 'dns-remote', 'address': 'tcp://8.8.8.8', 'detour': 'direct', 'strategy': 'prefer_ipv6'},
          ],
          'rules': [
            {'server': 'dns-fake'},
            {'query_type': 'AAAA', 'server': 'dns-ipv6'},
          ],
          'final': 'dns-fake',
        },
        'route': {
          'rules': [
            {
              'ip_cidr': ['0.0.0.0/0'],
              'outbound': 'direct',
            },
            {
              'ip_cidr': ['::/0'],
              'outbound': 'block',
            },
          ],
          'final': 'block',
        },
        'outbounds': [
          {'tag': 'proxy', 'type': 'selector'},
        ],
      });

      final result = const FinalConfigGuard().inspectAndSanitizeContent(content);

      expect(result.fakeIpBefore, isTrue);
      expect(result.fakeIpAfter, isFalse);
      expect(result.removedFakeDnsServers, 1);
      expect(result.removedIpv6DnsServers, 1);
      expect(result.removedFakeDnsRules, 1);
      expect(result.removedIpv6DnsRules, 1);
      expect(result.removedCatchAllRules, 1);
      expect(result.routeFinal, LockedCoreConfig.routeFinal);

      final sanitized = jsonDecode(result.sanitizedContent!) as Map<String, dynamic>;
      final sanitizedJson = jsonEncode(sanitized);
      expect(sanitizedJson, isNot(contains('fake-ip')));
      expect(sanitizedJson, isNot(contains('fakeip')));
      expect(sanitizedJson, isNot(contains('198.18.')));
      expect(sanitizedJson, isNot(contains('2001:4860')));
      final dnsServer = ((sanitized['dns'] as Map)['servers'] as List).single as Map;
      expect(dnsServer['tag'], 'dns-remote');
      expect(dnsServer['detour'], LockedCoreConfig.outboundTag);
      expect(dnsServer['strategy'], LockedCoreConfig.dnsStrategy);
      expect((sanitized['dns'] as Map)['strategy'], LockedCoreConfig.dnsStrategy);
      expect((sanitized['route'] as Map)['final'], LockedCoreConfig.routeFinal);
    });

    test('normalizes legacy Chinese selector tags to locked proxy tags', () {
      final content = jsonEncode({
        'dns': {
          'servers': [
            {'tag': 'remote', 'address': 'https://1.1.1.1/dns-query', 'detour': '节点选择'},
          ],
          'rules': [
            {
              'rule_set': ['geosite-cn'],
              'server': 'remote',
            },
          ],
          'final': 'remote',
        },
        'outbounds': [
          {
            'tag': '节点选择',
            'type': 'selector',
            'default': '自动选择',
            'outbounds': ['自动选择', '香港-IPEL'],
          },
          {
            'tag': '自动选择',
            'type': 'urltest',
            'outbounds': ['香港-IPEL'],
          },
          {'tag': '香港-IPEL', 'type': 'shadowsocks'},
        ],
        'route': {
          'rules': [
            {'clash_mode': 'global', 'outbound': '节点选择'},
            {
              'rule_set': ['geosite-cn', 'geoip-cn'],
              'outbound': 'direct',
            },
          ],
          'final': '节点选择',
          'rule_set': [
            {
              'tag': 'geosite-cn',
              'type': 'remote',
              'format': 'binary',
              'url': 'https://example.test/geosite-cn.srs',
              'download_detour': '节点选择',
            },
          ],
        },
      });

      final result = const FinalConfigGuard().inspectAndSanitizeContent(content);
      final sanitized = jsonDecode(result.sanitizedContent!) as Map<String, dynamic>;
      final encoded = jsonEncode(sanitized);
      final outbounds = (sanitized['outbounds'] as List).cast<Map>();
      final proxy = outbounds.firstWhere((item) => item['tag'] == LockedCoreConfig.outboundTag);
      final auto = outbounds.firstWhere((item) => item['tag'] == 'auto');
      final route = sanitized['route'] as Map;
      final dnsServer = ((sanitized['dns'] as Map)['servers'] as List).single as Map;

      expect(proxy['default'], 'auto');
      expect(proxy['outbounds'], contains('auto'));
      expect(auto['outbounds'], contains('香港-IPEL'));
      expect(route['final'], LockedCoreConfig.routeFinal);
      expect((route['rule_set'] as List).single['download_detour'], LockedCoreConfig.outboundTag);
      expect(dnsServer['detour'], LockedCoreConfig.outboundTag);
      expect(encoded, isNot(contains('节点选择')));
      expect(encoded, isNot(contains('自动选择')));
      expect(encoded, contains('香港-IPEL'));
    });

    test('creates locked DNS and route defaults when final config omits them', () {
      final content = jsonEncode({
        'outbounds': [
          {'tag': 'proxy', 'type': 'selector'},
        ],
      });

      final result = const FinalConfigGuard().inspectAndSanitizeContent(content);

      expect(result.changed, isTrue);
      expect(result.fakeIpAfter, isFalse);
      expect(result.dnsFinal, 'dns-remote');
      expect(result.routeFinal, LockedCoreConfig.routeFinal);

      final sanitized = jsonDecode(result.sanitizedContent!) as Map<String, dynamic>;
      final dns = sanitized['dns'] as Map;
      final route = sanitized['route'] as Map;
      expect(dns['strategy'], LockedCoreConfig.dnsStrategy);
      final dnsServer = (dns['servers'] as List).single as Map;
      expect(dnsServer['detour'], LockedCoreConfig.outboundTag);
      expect(route['final'], LockedCoreConfig.routeFinal);
      expect(route['rules'], isEmpty);
    });
  });
}
