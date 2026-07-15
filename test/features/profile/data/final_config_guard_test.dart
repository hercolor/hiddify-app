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

    test('forces final core log level to locked production level', () {
      final content = jsonEncode({
        'log': {'level': 'warn'},
        'dns': {
          'servers': [
            {'tag': 'dns-remote', 'address': 'tcp://8.8.8.8'},
          ],
        },
        'route': {'rules': <Object?>[], 'final': 'proxy'},
        'outbounds': [
          {'tag': 'proxy', 'type': 'selector'},
          {'tag': 'direct', 'type': 'direct'},
        ],
      });

      final result = const FinalConfigGuard().inspectAndSanitizeContent(content);

      expect(result.coreLogLevel, LockedCoreConfig.coreLogLevel);
      expect(result.forcedCoreLogLevel, 1);
      final sanitized = jsonDecode(result.sanitizedContent!) as Map<String, dynamic>;
      expect((sanitized['log'] as Map)['level'], LockedCoreConfig.coreLogLevel);
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
            {'action': 'sniff'},
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
      expect(result.removedCatchAllRules, 2);
      expect(result.removedIpv6TunValues, greaterThanOrEqualTo(1));
      expect(result.forcedDnsDetours, 1);
      expect(result.forcedDnsStrategies, greaterThanOrEqualTo(1));

      final sanitized = jsonDecode(result.sanitizedContent!) as Map<String, dynamic>;
      final dnsServers = ((sanitized['dns'] as Map)['servers'] as List).cast<Map>();
      final dnsServer = dnsServers.firstWhere((item) => item['tag'] != 'dns-local');
      final localDnsServer = dnsServers.firstWhere((item) => item['tag'] == 'dns-local');
      final tunInbound = (sanitized['inbounds'] as List).cast<Map>().first;
      final routeRules = ((sanitized['route'] as Map)['rules'] as List).cast<Map>();
      expect(localDnsServer.containsKey('detour'), isFalse);
      expect(dnsServer['detour'], 'proxy');
      expect(tunInbound['sniff'], isTrue);
      expect(tunInbound['sniff_override_destination'], isTrue);
      expect(tunInbound['sniff_timeout'], '300ms');
      expect(tunInbound['domain_strategy'], LockedCoreConfig.dnsStrategy);
      expect(routeRules.any((rule) => rule['action'] == 'sniff'), isFalse);
      expect(dnsServer.containsKey('strategy'), isFalse);
      expect(dnsServer['type'], 'tcp');
      expect(dnsServer['server'], '8.8.8.8');
      expect((sanitized['dns'] as Map)['strategy'], 'ipv4_only');
      expect((sanitized['dns'] as Map)['reverse_mapping'], isTrue);
      expect(jsonEncode(sanitized), isNot(contains('::/0')));
      expect(jsonEncode(sanitized), isNot(contains('inet6_address')));
      final route = sanitized['route'] as Map;
      expect(route['final'], 'proxy');
      expect(route['default_domain_resolver'], 'dns-local');
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
      final dnsServers = ((sanitized['dns'] as Map)['servers'] as List).cast<Map>();
      final dnsServer = dnsServers.firstWhere((item) => item['tag'] != 'dns-local');
      final localDnsServer = dnsServers.firstWhere((item) => item['tag'] == 'dns-local');
      expect(dnsServer['tag'], 'dns-remote');
      expect(dnsServer['detour'], LockedCoreConfig.outboundTag);
      expect(localDnsServer.containsKey('detour'), isFalse);
      expect(dnsServer.containsKey('strategy'), isFalse);
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
      final dnsServers = ((sanitized['dns'] as Map)['servers'] as List).cast<Map>();
      final dnsServer = dnsServers.firstWhere((item) => item['tag'] != 'dns-local');
      final localDnsServer = dnsServers.firstWhere((item) => item['tag'] == 'dns-local');

      expect(proxy['default'], 'auto');
      expect(proxy['outbounds'], contains('auto'));
      expect(auto['outbounds'], contains('香港-IPEL'));
      expect(route['final'], LockedCoreConfig.routeFinal);
      final routeRuleSets = (route['rule_set'] as List).cast<Map>();
      expect(routeRuleSets.map((item) => item['tag']), containsAll(['geosite-cn', 'geoip-cn']));
      expect(routeRuleSets.map((item) => item['download_detour']), everyElement(LockedCoreConfig.outboundTag));
      expect(dnsServer['detour'], LockedCoreConfig.outboundTag);
      expect(localDnsServer.containsKey('detour'), isFalse);
      expect(encoded, isNot(contains('节点选择')));
      expect(encoded, isNot(contains('自动选择')));
      expect(encoded, contains('香港-IPEL'));
    });

    test('keeps local DNS on the native direct dialer while routing remote DNS through selected node', () {
      final content = jsonEncode({
        'dns': {
          'servers': [
            {'tag': 'remote', 'address': 'https://1.1.1.1/dns-query', 'detour': 'proxy'},
            {'tag': 'local', 'address': 'https://223.5.5.5/dns-query', 'detour': 'direct'},
            {'tag': 'block', 'address': 'rcode://success', 'detour': 'proxy'},
          ],
          'rules': [
            {
              'domain_suffix': ['cn'],
              'server': 'local',
            },
            {
              'domain': ['blocked.example'],
              'server': 'block',
              'strategy': 'prefer_ipv6',
              'disable_cache': true,
              'disable_optimistic_cache': true,
              'rewrite_ttl': 60,
              'client_subnet': '203.0.113.0/24',
              'bypass_if_failed': true,
            },
          ],
          'final': 'remote',
        },
        'outbounds': [
          {
            'tag': 'proxy',
            'type': 'selector',
            'default': 'auto',
            'outbounds': ['auto', '香港-IPEL'],
          },
          {
            'tag': 'auto',
            'type': 'urltest',
            'outbounds': ['香港-IPEL'],
          },
          {'tag': 'direct', 'type': 'direct'},
          {'tag': '香港-IPEL', 'type': 'shadowsocks'},
        ],
        'route': {'rules': [], 'final': 'proxy'},
      });

      final result = const FinalConfigGuard().inspectAndSanitizeContent(content, selectedOutboundTag: '香港-IPEL');
      final sanitized = jsonDecode(result.sanitizedContent!) as Map<String, dynamic>;
      final dns = sanitized['dns'] as Map;
      final servers = (dns['servers'] as List).cast<Map>();
      final rules = (dns['rules'] as List).cast<Map>();

      expect(servers.firstWhere((item) => item['tag'] == 'remote')['detour'], '香港-IPEL');
      expect(servers.firstWhere((item) => item['tag'] == 'local').containsKey('detour'), isFalse);
      expect(servers.any((item) => item['tag'] == 'block'), isFalse);
      final blockRule = rules.firstWhere((item) => (item['domain'] as List?)?.contains('blocked.example') == true);
      expect(blockRule['action'], 'predefined');
      expect(blockRule['rcode'], 'NOERROR');
      expect(blockRule.containsKey('server'), isFalse);
      expect(blockRule.containsKey('strategy'), isFalse);
      expect(blockRule.containsKey('disable_cache'), isFalse);
      expect(blockRule.containsKey('disable_optimistic_cache'), isFalse);
      expect(blockRule.containsKey('rewrite_ttl'), isFalse);
      expect(blockRule.containsKey('client_subnet'), isFalse);
      expect(blockRule.containsKey('bypass_if_failed'), isFalse);
    });

    test('migrates legacy DNS transports to the typed sing-box schema', () {
      final content = jsonEncode({
        'dns': {
          'servers': [
            {
              'tag': 'remote-tcp',
              'address': 'tcp://8.8.8.8:5353',
              'detour': 'proxy',
              'strategy': 'prefer_ipv6',
              'client_subnet': '203.0.113.0/24',
            },
            {'tag': 'bootstrap', 'address': '1.1.1.1', 'detour': 'direct'},
            {
              'tag': 'remote-tls',
              'address': 'tls://dns.google:8853',
              'address_resolver': 'bootstrap',
              'address_strategy': 'prefer_ipv6',
              'address_fallback_delay': '250ms',
              'detour': 'proxy',
            },
            {'tag': 'remote-doh', 'address': 'https://1.1.1.1/custom-query', 'detour': 'proxy'},
            {'tag': 'cloudflare', 'address': 'https://1.0.0.1/dns-query'},
            {'tag': 'system-local', 'address': 'local'},
            {'tag': 'dhcp-local', 'address': 'dhcp://auto'},
            {'tag': 'static-hosts', 'type': 'hosts', 'detour': 'proxy'},
            {'tag': 'remote-sdns', 'type': 'sdns', 'server': '1.1.1.1', 'stamp': 'sdns://example', 'detour': 'proxy'},
          ],
          'final': 'remote-tcp',
        },
        'outbounds': [
          {'tag': 'proxy', 'type': 'selector'},
          {'tag': 'direct', 'type': 'direct'},
        ],
        'route': {'rules': <Object?>[], 'final': 'proxy'},
      });

      const guard = FinalConfigGuard();
      final result = guard.inspectAndSanitizeContent(content);
      final sanitized = jsonDecode(result.sanitizedContent!) as Map<String, dynamic>;
      final dns = sanitized['dns'] as Map;
      final servers = (dns['servers'] as List).cast<Map>();
      final tcp = servers.firstWhere((item) => item['tag'] == 'remote-tcp');
      final udp = servers.firstWhere((item) => item['tag'] == 'bootstrap');
      final tls = servers.firstWhere((item) => item['tag'] == 'remote-tls');
      final doh = servers.firstWhere((item) => item['tag'] == 'remote-doh');
      final cloudflare = servers.firstWhere((item) => item['tag'] == 'cloudflare');
      final local = servers.firstWhere((item) => item['tag'] == 'system-local');
      final dhcp = servers.firstWhere((item) => item['tag'] == 'dhcp-local');
      final hosts = servers.firstWhere((item) => item['tag'] == 'static-hosts');
      final sdns = servers.firstWhere((item) => item['tag'] == 'remote-sdns');
      final smartLocal = servers.firstWhere((item) => item['tag'] == 'dns-local');

      for (final server in servers) {
        expect(server.containsKey('address'), isFalse);
        expect(server.containsKey('address_resolver'), isFalse);
        expect(server.containsKey('address_strategy'), isFalse);
        expect(server.containsKey('strategy'), isFalse);
        expect(server.containsKey('client_subnet'), isFalse);
      }
      expect(tcp, containsPair('type', 'tcp'));
      expect(tcp, containsPair('server', '8.8.8.8'));
      expect(tcp, containsPair('server_port', 5353));
      expect(udp, containsPair('type', 'udp'));
      expect(udp, containsPair('server', '1.1.1.1'));
      expect(tls, containsPair('type', 'tls'));
      expect(tls, containsPair('server', 'dns.google'));
      expect(tls, containsPair('server_port', 8853));
      expect(tls['domain_resolver'], {'server': 'bootstrap', 'strategy': 'ipv4_only'});
      expect(tls, containsPair('fallback_delay', '250ms'));
      expect(doh, containsPair('type', 'https'));
      expect(doh, containsPair('path', '/custom-query'));
      expect(cloudflare, containsPair('detour', 'proxy'));
      expect(local, containsPair('type', 'local'));
      expect(local.containsKey('server'), isFalse);
      expect(local.containsKey('detour'), isFalse);
      expect(dhcp, containsPair('type', 'dhcp'));
      expect(dhcp.containsKey('interface'), isFalse);
      expect(hosts, containsPair('type', 'hosts'));
      expect(hosts.containsKey('detour'), isFalse);
      expect(sdns, containsPair('type', 'sdns'));
      expect(sdns, containsPair('detour', 'proxy'));
      expect(smartLocal, containsPair('type', 'https'));
      expect(smartLocal, containsPair('server', '223.5.5.5'));
      expect(dns['strategy'], LockedCoreConfig.dnsStrategy);
      expect(result.dnsServerSummary.join(' ; '), contains('type=tcp'));
      expect(result.dnsServerSummary.join(' ; '), contains('server=8.8.8.8'));

      final secondPass = guard.inspectAndSanitizeContent(result.sanitizedContent!);
      expect(secondPass.changed, isFalse);
      expect(secondPass.sanitizedContent, isNull);
    });

    test('pins selector default to the app-selected node before core start', () {
      final content = jsonEncode({
        'dns': {
          'servers': [
            {'tag': 'remote', 'address': 'https://1.1.1.1/dns-query', 'detour': 'proxy'},
          ],
          'final': 'remote',
        },
        'outbounds': [
          {
            'tag': 'proxy',
            'type': 'selector',
            'default': 'auto',
            'outbounds': ['auto', '香港-IPEL', '美国-IPEL'],
          },
          {
            'tag': 'auto',
            'type': 'urltest',
            'outbounds': ['香港-IPEL', '美国-IPEL'],
          },
          {'tag': '香港-IPEL', 'type': 'shadowsocks'},
          {'tag': '美国-IPEL', 'type': 'shadowsocks'},
        ],
        'route': {
          'rules': [
            {
              'action': 'hijack-dns',
              'protocol': ['dns'],
            },
            {
              'domain_suffix': ['example.com'],
              'outbound': 'proxy',
            },
          ],
          'final': 'proxy',
          'rule_set': [
            {'tag': 'geosite-cn', 'type': 'remote', 'download_detour': 'proxy'},
          ],
        },
      });

      final result = const FinalConfigGuard().inspectAndSanitizeContent(content, selectedOutboundTag: '香港-IPEL');
      final sanitized = jsonDecode(result.sanitizedContent!) as Map<String, dynamic>;
      final outbounds = (sanitized['outbounds'] as List).cast<Map>();
      final proxy = outbounds.firstWhere((item) => item['tag'] == LockedCoreConfig.outboundTag);
      final dnsServers = ((sanitized['dns'] as Map)['servers'] as List).cast<Map>();
      final dnsServer = dnsServers.firstWhere((item) => item['tag'] != 'dns-local');
      final localDnsServer = dnsServers.firstWhere((item) => item['tag'] == 'dns-local');
      final route = sanitized['route'] as Map;
      final routeRules = (route['rules'] as List).cast<Map>();
      final routeRuleSets = (route['rule_set'] as List).cast<Map>();

      expect(proxy['default'], '香港-IPEL');
      expect(dnsServer['detour'], '香港-IPEL');
      expect(localDnsServer.containsKey('detour'), isFalse);
      expect(route['final'], '香港-IPEL');
      expect(routeRules.any((rule) => rule['action'] == 'sniff'), isFalse);
      expect(routeRules.firstWhere((rule) => rule['domain_suffix'] is List)['outbound'], '香港-IPEL');
      expect(routeRuleSets.map((item) => item['download_detour']), everyElement('香港-IPEL'));
      expect(result.forcedSelectorDefaults, 1);
      expect(result.forcedSelectedOutboundReferences, 5);
      expect(result.removedUnselectedOutbounds, 0);
    });

    test('keeps unselected proxy outbounds available when a node is selected', () {
      final content = jsonEncode({
        'dns': {
          'servers': [
            {'tag': 'dns-remote', 'address': 'tcp://8.8.8.8', 'detour': 'proxy'},
          ],
        },
        'outbounds': [
          {
            'tag': 'proxy',
            'type': 'selector',
            'default': 'auto',
            'outbounds': ['auto', '香港-IPEL', '美国-IPEL'],
          },
          {
            'tag': 'auto',
            'type': 'urltest',
            'outbounds': ['香港-IPEL', '美国-IPEL'],
          },
          {'tag': '香港-IPEL', 'type': 'shadowsocks'},
          {'tag': '美国-IPEL', 'type': 'shadowsocks'},
          {'tag': 'direct', 'type': 'direct'},
          {'tag': 'block', 'type': 'block'},
        ],
        'route': {
          'rules': [
            {
              'domain_suffix': ['example.com'],
              'outbound': 'proxy',
            },
          ],
          'final': 'proxy',
        },
      });

      final result = const FinalConfigGuard().inspectAndSanitizeContent(content, selectedOutboundTag: '香港-IPEL');
      final sanitized = jsonDecode(result.sanitizedContent!) as Map<String, dynamic>;
      final outbounds = (sanitized['outbounds'] as List).cast<Map>();
      final outboundTags = outbounds.map((item) => item['tag']).toList();
      final selector = outbounds.firstWhere((item) => item['tag'] == 'proxy');
      final auto = outbounds.firstWhere((item) => item['tag'] == 'auto');

      expect(outboundTags, containsAll(['proxy', 'auto', '香港-IPEL', '美国-IPEL', 'direct', 'block']));
      expect(selector['default'], '香港-IPEL');
      expect(selector['outbounds'], ['auto', '香港-IPEL', '美国-IPEL']);
      expect(auto['outbounds'], ['香港-IPEL', '美国-IPEL']);
      expect(result.removedUnselectedOutbounds, 0);
    });

    test('keeps all proxy outbounds when selected outbound locking is disabled', () {
      final content = jsonEncode({
        'outbounds': [
          {
            'tag': 'proxy',
            'type': 'selector',
            'default': 'auto',
            'outbounds': ['auto', '香港-IPEL', '美国-IPEL'],
          },
          {
            'tag': 'auto',
            'type': 'urltest',
            'outbounds': ['香港-IPEL', '美国-IPEL'],
          },
          {'tag': '香港-IPEL', 'type': 'shadowsocks'},
          {'tag': '美国-IPEL', 'type': 'shadowsocks'},
          {'tag': 'direct', 'type': 'direct'},
          {'tag': 'block', 'type': 'block'},
        ],
        'route': {
          'rules': [
            {
              'domain_suffix': ['example.com'],
              'outbound': 'proxy',
            },
          ],
          'final': 'proxy',
        },
      });

      final result = const FinalConfigGuard().inspectAndSanitizeContent(
        content,
        selectedOutboundTag: '香港-IPEL',
        lockSelectedOutboundReferences: false,
      );
      final sanitized = jsonDecode(result.sanitizedContent!) as Map<String, dynamic>;
      final outbounds = (sanitized['outbounds'] as List).cast<Map>();
      final outboundTags = outbounds.map((item) => item['tag']).toList();
      final selector = outbounds.firstWhere((item) => item['tag'] == 'proxy');
      final route = sanitized['route'] as Map;

      expect(outboundTags, containsAll(['proxy', 'auto', '香港-IPEL', '美国-IPEL', 'direct', 'block']));
      expect(selector['outbounds'], ['auto', '香港-IPEL', '美国-IPEL']);
      expect(route['final'], 'proxy');
      expect(result.forcedSelectedOutboundReferences, 0);
      expect(result.removedUnselectedOutbounds, 0);
    });

    test('locks resolve destination on for smart routing analysis', () {
      final content = jsonEncode({
        'outbounds': [
          {'tag': 'proxy', 'type': 'selector'},
        ],
        'route': {'rules': [], 'final': 'proxy'},
      });

      final result = const FinalConfigGuard().inspectAndSanitizeContent(content);
      final sanitized = jsonDecode(result.sanitizedContent!) as Map<String, dynamic>;

      expect(LockedCoreConfig.resolveDestination, isTrue);
      expect(sanitized.containsKey('route'), isTrue);
    });

    test('global mode removes split route rules but keeps dns routing', () {
      final content = jsonEncode({
        'outbounds': [
          {'tag': 'proxy', 'type': 'selector'},
        ],
        'route': {
          'rules': [
            {
              'action': 'hijack-dns',
              'protocol': ['dns'],
            },
            {'ip_is_private': true, 'outbound': 'direct'},
            {
              'domain_suffix': ['cn'],
              'outbound': 'direct',
            },
          ],
          'final': 'proxy',
        },
      });

      final result = const FinalConfigGuard().inspectAndSanitizeContent(content, globalRouteMode: true);
      final sanitized = jsonDecode(result.sanitizedContent!) as Map<String, dynamic>;
      final routeRules = ((sanitized['route'] as Map)['rules'] as List).cast<Map>();

      expect(routeRules, hasLength(1));
      expect(routeRules.single['protocol'], ['dns']);
      expect(result.removedGlobalModeRules, 2);
    });

    test('normalizes scalar sing-box rule matchers before core import', () {
      final content = jsonEncode({
        'dns': {
          'servers': [
            {'tag': 'remote', 'address': 'https://1.1.1.1/dns-query', 'detour': 'proxy'},
          ],
          'rules': [
            {'outbound': 'any', 'query_type': 'A', 'server': 'remote'},
            {'clash_mode': 'global', 'server': 'remote'},
          ],
          'final': 'remote',
        },
        'route': {
          'rules': [
            {'outbound': 'dns-out', 'protocol': 'dns'},
            {'domain_suffix': 'cn', 'outbound': 'direct'},
            {'clash_mode': 'global', 'outbound': 'proxy'},
          ],
          'final': 'proxy',
        },
        'outbounds': [
          {'tag': 'proxy', 'type': 'selector'},
          {'tag': 'dns-out', 'type': 'dns'},
        ],
      });

      final result = const FinalConfigGuard().inspectAndSanitizeContent(content);
      final sanitized = jsonDecode(result.sanitizedContent!) as Map<String, dynamic>;
      final dnsRules = ((sanitized['dns'] as Map)['rules'] as List).cast<Map>();
      final routeRules = ((sanitized['route'] as Map)['rules'] as List).cast<Map>();
      final outbounds = (sanitized['outbounds'] as List).cast<Map>();

      expect(dnsRules, hasLength(5));
      expect(dnsRules.first['outbound'], ['any']);
      expect(dnsRules.first['query_type'], ['A']);
      expect(routeRules, hasLength(6));
      expect(routeRules.first['protocol'], ['dns']);
      expect(routeRules.first['action'], 'hijack-dns');
      expect(routeRules.first.containsKey('outbound'), isFalse);
      expect(routeRules[1]['domain_suffix'], contains('cn'));
      expect(routeRules[1]['domain_suffix'], contains('api.skk.moe'));
      expect(routeRules.any((rule) => (rule['domain'] as List?)?.contains('ip138.com') == true), isTrue);
      expect(routeRules.any((rule) => rule['ip_is_private'] == true), isTrue);
      expect(routeRules.any((rule) => rule['domain_keyword'] is List), isTrue);
      expect(routeRules.any((rule) => rule['rule_set'] is List), isTrue);
      expect(result.removedClashModeRules, 2);
      expect(outbounds.where((item) => item['type'] == 'dns'), isEmpty);
      expect(outbounds.map((item) => item['tag']), isNot(contains('dns-out')));
    });

    test('migrates custom legacy DNS outbound references before core import', () {
      final content = jsonEncode({
        'dns': {
          'servers': [
            {'tag': 'dns-remote', 'address': 'tcp://8.8.8.8', 'detour': 'legacy-dns'},
          ],
          'final': 'dns-remote',
        },
        'route': {
          'rules': [
            {
              'protocol': ['dns'],
              'outbound': 'legacy-dns',
            },
            {
              'domain': ['example.com'],
              'outbound': 'legacy-dns',
            },
          ],
          'final': 'legacy-dns',
          'rule_set': [
            {
              'tag': 'custom-rules',
              'type': 'remote',
              'url': 'https://example.com/rules.srs',
              'download_detour': 'legacy-dns',
            },
          ],
        },
        'outbounds': [
          {
            'tag': 'proxy',
            'type': 'selector',
            'outbounds': ['legacy-dns', 'node'],
            'default': 'legacy-dns',
          },
          {'tag': 'node', 'type': 'vless', 'detour': 'legacy-dns'},
          {'tag': 'legacy-dns', 'type': 'DNS'},
        ],
      });

      const guard = FinalConfigGuard();
      final result = guard.inspectAndSanitizeContent(content);
      final sanitized = jsonDecode(result.sanitizedContent!) as Map<String, dynamic>;
      final outbounds = (sanitized['outbounds'] as List).cast<Map>();
      final selector = outbounds.firstWhere((item) => item['tag'] == 'proxy');
      final route = sanitized['route'] as Map;
      final routeRules = (route['rules'] as List).cast<Map>();
      final ruleSets = (route['rule_set'] as List).cast<Map>();
      final dnsRule = routeRules.firstWhere((rule) => (rule['protocol'] as List?)?.contains('dns') == true);
      final dnsServers = ((sanitized['dns'] as Map)['servers'] as List).cast<Map>();
      final node = outbounds.firstWhere((item) => item['tag'] == 'node');
      final customRuleSet = ruleSets.firstWhere((item) => item['tag'] == 'custom-rules');
      final remoteDnsServer = dnsServers.firstWhere((item) => item['tag'] == 'dns-remote');

      expect(outbounds.where((item) => item['type'].toString().toLowerCase() == 'dns'), isEmpty);
      expect(selector['outbounds'], ['node']);
      expect(selector.containsKey('default'), isFalse);
      expect(route['final'], 'proxy');
      expect(dnsRule['action'], 'hijack-dns');
      expect(dnsRule.containsKey('outbound'), isFalse);
      expect(routeRules.any((rule) => rule['outbound'] == 'legacy-dns'), isFalse);
      expect(
        routeRules.any((rule) => rule['domain'] is List && (rule['domain'] as List).contains('example.com')),
        isFalse,
      );
      expect(remoteDnsServer['detour'], 'proxy');
      expect(node.containsKey('detour'), isFalse);
      expect(customRuleSet.containsKey('download_detour'), isFalse);

      final secondPass = guard.inspectAndSanitizeContent(result.sanitizedContent!);
      expect(secondPass.changed, isFalse);
      expect(secondPass.sanitizedContent, isNull);
    });

    test('keeps an unusable DNS-only selector profile fail-closed', () {
      final content = jsonEncode({
        'route': {'rules': <Object?>[], 'final': 'proxy'},
        'outbounds': [
          {
            'tag': 'proxy',
            'type': 'selector',
            'outbounds': ['legacy-dns'],
            'default': 'legacy-dns',
          },
          {
            'tag': 'auto',
            'type': 'urltest',
            'outbounds': ['legacy-dns'],
            'default': 'legacy-dns',
          },
          {'tag': 'legacy-dns', 'type': 'dns'},
        ],
      });

      final result = const FinalConfigGuard().inspectAndSanitizeContent(content, globalRouteMode: true);
      final sanitized = jsonDecode(result.sanitizedContent!) as Map<String, dynamic>;
      final groups = (sanitized['outbounds'] as List).cast<Map>();

      expect(groups, hasLength(3));
      expect(groups.where((group) => group['type'] == 'dns'), hasLength(1));
      expect(groups.where((group) => group['type'] != 'dns'), everyElement(containsPair('outbounds', ['legacy-dns'])));
    });

    test('injects smart direct rules when generated final config has no route rules', () {
      final content = jsonEncode({
        'dns': {
          'servers': [
            {'tag': 'dns-remote', 'address': 'tcp://8.8.8.8', 'detour': 'proxy'},
          ],
          'final': 'dns-remote',
        },
        'outbounds': [
          {'tag': 'proxy', 'type': 'selector'},
        ],
        'route': {'rules': [], 'final': 'proxy'},
      });

      final result = const FinalConfigGuard().inspectAndSanitizeContent(content, selectedOutboundTag: '香港-IPEL');
      final sanitized = jsonDecode(result.sanitizedContent!) as Map<String, dynamic>;
      final route = sanitized['route'] as Map;
      final routeRules = (route['rules'] as List).cast<Map>();
      final outbounds = (sanitized['outbounds'] as List).cast<Map>();
      final dns = sanitized['dns'] as Map;
      final dnsServers = (dns['servers'] as List).cast<Map>();
      final dnsRules = (dns['rules'] as List).cast<Map>();

      expect(route['final'], 'proxy');
      expect(routeRules, hasLength(6));
      expect(routeRules[0]['protocol'], ['dns']);
      expect(routeRules[0]['action'], 'hijack-dns');
      expect(routeRules[0].containsKey('outbound'), isFalse);
      expect(routeRules[1]['ip_is_private'], isTrue);
      expect(routeRules[1]['action'], 'route');
      expect(routeRules[2]['domain'], contains('ip138.com'));
      expect(routeRules[2]['domain'], contains('www.ip.cn'));
      expect(routeRules[2]['outbound'], 'direct');
      expect(routeRules[2]['action'], 'route');
      expect(routeRules[3]['domain_suffix'], contains('baidu.com'));
      expect(routeRules[3]['outbound'], 'direct');
      expect(routeRules[3]['action'], 'route');
      expect(routeRules[4]['domain_keyword'], contains('baidu'));
      expect(routeRules[5]['rule_set'], ['geosite-cn', 'geoip-cn']);
      expect(routeRules[5]['action'], 'route');
      final ruleSets = (route['rule_set'] as List).cast<Map>();
      expect(ruleSets.map((item) => item['url']), everyElement(contains('/rules/sing-box/')));
      expect(dnsServers.any((item) => item['tag'] == 'dns-local' && !item.containsKey('detour')), isTrue);
      final localDns = dnsServers.firstWhere((item) => item['tag'] == 'dns-local');
      expect(localDns, containsPair('type', 'https'));
      expect(localDns, containsPair('server', '223.5.5.5'));
      expect(localDns.containsKey('address'), isFalse);
      expect(localDns.containsKey('strategy'), isFalse);
      expect(dns['reverse_mapping'], isTrue);
      expect(route['default_domain_resolver'], 'dns-local');
      expect(dnsRules.any((item) => (item['domain'] as List?)?.contains('www.ip138.com') == true), isTrue);
      expect(dnsRules.any((item) => (item['domain_suffix'] as List?)?.contains('ip138.com') == true), isTrue);
      expect(dnsRules.any((item) => (item['rule_set'] as List?)?.contains('geosite-cn') == true), isTrue);
      expect(outbounds.any((item) => item['tag'] == 'direct' && item['type'] == 'direct'), isTrue);
    });

    test('merges diagnostic test domains into existing direct rules', () {
      final content = jsonEncode({
        'dns': {
          'servers': [
            {'tag': 'dns-remote', 'address': 'tcp://8.8.8.8', 'detour': 'proxy'},
            {'tag': 'dns-local', 'address': 'https://223.5.5.5/dns-query', 'detour': 'direct'},
          ],
          'rules': [
            {
              'domain': ['ip138.com'],
              'server': 'dns-local',
            },
            {
              'domain_suffix': ['ip.cn'],
              'server': 'dns-local',
            },
          ],
          'final': 'dns-remote',
        },
        'outbounds': [
          {'tag': 'proxy', 'type': 'selector'},
          {'tag': 'direct', 'type': 'direct'},
        ],
        'route': {
          'rules': [
            {
              'domain': ['ip138.com'],
              'outbound': 'direct',
            },
            {
              'domain_suffix': ['ip.cn'],
              'outbound': 'direct',
            },
          ],
          'final': 'proxy',
        },
      });

      final result = const FinalConfigGuard().inspectAndSanitizeContent(content);
      final sanitized = jsonDecode(result.sanitizedContent!) as Map<String, dynamic>;
      final routeRules = ((sanitized['route'] as Map)['rules'] as List).cast<Map>();
      final dnsRules = ((sanitized['dns'] as Map)['rules'] as List).cast<Map>();
      final routeDomainRule = routeRules.firstWhere((rule) => rule['domain'] is List);
      final routeSuffixRule = routeRules.firstWhere((rule) => rule['domain_suffix'] is List);
      final dnsDomainRule = dnsRules.firstWhere((rule) => rule['domain'] is List);
      final dnsSuffixRule = dnsRules.firstWhere((rule) => rule['domain_suffix'] is List);

      expect(routeDomainRule['domain'], contains('2026.ip138.com'));
      expect(routeDomainRule['domain'], contains('my.ip.cn'));
      expect(routeDomainRule['domain'], contains('ipv4-ip.api.skk.moe'));
      expect(routeDomainRule['domain'], contains('ip.api.skk.moe'));
      expect(routeSuffixRule['domain_suffix'], contains('api.skk.moe'));
      expect(dnsDomainRule['domain'], contains('2026.ip138.com'));
      expect(dnsDomainRule['domain'], contains('ip.api.skk.moe'));
      expect(dnsSuffixRule['domain_suffix'], contains('api.skk.moe'));
    });

    test('keeps mixed inbound domain visible for route rule matching', () {
      final content = jsonEncode({
        'dns': {
          'servers': [
            {'tag': 'dns-remote', 'address': 'tcp://8.8.8.8', 'detour': 'proxy'},
          ],
          'final': 'dns-remote',
        },
        'outbounds': [
          {'tag': 'proxy', 'type': 'selector'},
          {'tag': 'direct', 'type': 'direct'},
        ],
        'route': {'rules': [], 'final': 'proxy'},
        'inbounds': [
          {
            'type': 'mixed',
            'tag': 'mixed-in',
            'listen': '127.0.0.1',
            'listen_port': 12334,
            'domain_strategy': 'ipv4_only',
          },
          {'type': 'tun', 'tag': 'tun-in'},
        ],
      });

      final result = const FinalConfigGuard().inspectAndSanitizeContent(content);
      final sanitized = jsonDecode(result.sanitizedContent!) as Map<String, dynamic>;
      final inbounds = (sanitized['inbounds'] as List).cast<Map>();
      final mixed = inbounds.firstWhere((item) => item['type'] == 'mixed');
      final tun = inbounds.firstWhere((item) => item['type'] == 'tun');

      expect(mixed['sniff'], isTrue);
      expect(mixed['sniff_override_destination'], isTrue);
      expect(mixed['sniff_timeout'], '300ms');
      expect(mixed.containsKey('domain_strategy'), isFalse);
      expect(tun['domain_strategy'], LockedCoreConfig.dnsStrategy);
      expect(result.inboundSummary.join(' ; '), contains('type=mixed'));
      expect(result.inboundSummary.join(' ; '), isNot(contains('type=mixed domain_strategy')));
    });

    test('does not synthesize Android raw inbounds unless requested', () {
      final content = jsonEncode({
        'dns': {
          'servers': [
            {'tag': 'dns-remote', 'address': 'tcp://8.8.8.8', 'detour': 'proxy'},
          ],
          'final': 'dns-remote',
        },
        'outbounds': [
          {'tag': 'proxy', 'type': 'selector'},
          {'tag': 'direct', 'type': 'direct'},
        ],
        'route': {'rules': [], 'final': 'proxy'},
      });

      final result = const FinalConfigGuard().inspectAndSanitizeContent(content);
      final sanitized = jsonDecode(result.sanitizedContent!) as Map<String, dynamic>;

      expect(sanitized.containsKey('inbounds'), isFalse);
      expect(result.inboundSummary, isEmpty);
    });

    test('synthesizes Android raw mixed and tun inbounds for runtime start', () {
      final content = jsonEncode({
        'dns': {
          'servers': [
            {'tag': 'dns-remote', 'address': 'tcp://8.8.8.8', 'detour': 'proxy'},
          ],
          'final': 'dns-remote',
        },
        'outbounds': [
          {'tag': 'proxy', 'type': 'selector'},
          {'tag': 'direct', 'type': 'direct'},
        ],
        'route': {'rules': [], 'final': 'proxy'},
      });

      final result = const FinalConfigGuard().inspectAndSanitizeContent(content, ensureAndroidRawInbounds: true);
      final sanitized = jsonDecode(result.sanitizedContent!) as Map<String, dynamic>;
      final inbounds = (sanitized['inbounds'] as List).cast<Map>();
      final mixed = inbounds.firstWhere((item) => item['type'] == 'mixed');
      final tun = inbounds.firstWhere((item) => item['type'] == 'tun');

      expect(mixed['listen'], '127.0.0.1');
      expect(mixed['listen_port'], LockedCoreConfig.mixedPort);
      expect(mixed['sniff'], isTrue);
      expect(mixed['sniff_override_destination'], isTrue);
      expect(mixed.containsKey('domain_strategy'), isFalse);
      expect(tun['address'], contains('172.19.0.1/30'));
      expect(tun['mtu'], LockedCoreConfig.mtu);
      expect(tun['auto_route'], isTrue);
      expect(tun['strict_route'], isTrue);
      expect(tun['stack'], 'gvisor');
      expect(tun['domain_strategy'], LockedCoreConfig.dnsStrategy);
      expect(result.inboundSummary.join(' ; '), contains('type=mixed'));
      expect(result.inboundSummary.join(' ; '), contains('type=tun'));
    });

    test('does not inject smart direct rules in global route mode', () {
      final content = jsonEncode({
        'outbounds': [
          {'tag': 'proxy', 'type': 'selector'},
        ],
        'route': {'rules': [], 'final': 'proxy'},
      });

      final result = const FinalConfigGuard().inspectAndSanitizeContent(content, globalRouteMode: true);
      final sanitized = jsonDecode(result.sanitizedContent!) as Map<String, dynamic>;
      final route = sanitized['route'] as Map;

      expect(route['rules'], isEmpty);
    });

    test('adds typed defaults when an existing DNS object has no servers', () {
      final content = jsonEncode({
        'dns': <String, Object?>{},
        'outbounds': [
          {'tag': 'proxy', 'type': 'selector'},
        ],
        'route': {'rules': <Object?>[], 'final': 'proxy'},
      });

      final result = const FinalConfigGuard().inspectAndSanitizeContent(content);
      final sanitized = jsonDecode(result.sanitizedContent!) as Map<String, dynamic>;
      final dns = sanitized['dns'] as Map;
      final servers = (dns['servers'] as List).cast<Map>();

      expect(servers.firstWhere((item) => item['tag'] == 'dns-remote'), {
        'tag': 'dns-remote',
        'type': 'tcp',
        'server': '8.8.8.8',
        'detour': 'proxy',
      });
      expect(servers.firstWhere((item) => item['tag'] == 'dns-local'), {
        'tag': 'dns-local',
        'type': 'https',
        'server': '223.5.5.5',
      });
      expect(dns['final'], 'dns-remote');
      expect(dns['strategy'], LockedCoreConfig.dnsStrategy);
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
      final dnsServers = (dns['servers'] as List).cast<Map>();
      final dnsServer = dnsServers.firstWhere((item) => item['tag'] != 'dns-local');
      final localDnsServer = dnsServers.firstWhere((item) => item['tag'] == 'dns-local');
      expect(dnsServer['detour'], LockedCoreConfig.outboundTag);
      expect(dnsServer, containsPair('type', 'tcp'));
      expect(dnsServer, containsPair('server', '8.8.8.8'));
      expect(dnsServer.containsKey('address'), isFalse);
      expect(dnsServer.containsKey('strategy'), isFalse);
      expect(localDnsServer.containsKey('detour'), isFalse);
      expect(localDnsServer, containsPair('type', 'https'));
      expect(localDnsServer, containsPair('server', '223.5.5.5'));
      expect(localDnsServer.containsKey('address'), isFalse);
      expect(localDnsServer.containsKey('strategy'), isFalse);
      expect(route['final'], LockedCoreConfig.routeFinal);
      expect(route['rules'], isNotEmpty);
      final routeRules = (route['rules'] as List).cast<Map>();
      expect(routeRules.any((rule) => rule['action'] == 'sniff'), isFalse);
      expect(routeRules[0]['action'], 'hijack-dns');
      expect(dns['reverse_mapping'], isTrue);
      expect(route['default_domain_resolver'], 'dns-local');
      expect(jsonEncode(route['rules']), contains('domain_suffix'));
      expect(jsonEncode(route['rules']), contains('baidu.com'));
    });
  });
}
