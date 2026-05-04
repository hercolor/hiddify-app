import 'dart:convert';
import 'dart:io';

import 'package:hiddify/core/config/locked_core_config.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:meta/meta.dart';

class FinalConfigGuardResult {
  const FinalConfigGuardResult({
    required this.parsedJson,
    required this.changed,
    required this.fakeIpBefore,
    required this.fakeIpAfter,
    required this.routeFinal,
    required this.dnsFinal,
    required this.dnsServerCount,
    required this.routeRuleCount,
    required this.removedFakeDnsServers,
    required this.removedIpv6DnsServers,
    required this.removedFakeDnsRules,
    required this.removedFakeRouteRules,
    required this.removedIpv6DnsRules,
    required this.removedIpv6RouteRules,
    required this.removedGeoRouteRules,
    required this.removedCatchAllRules,
    required this.removedIpv6TunValues,
    required this.forcedDnsDetours,
    required this.forcedDnsStrategies,
    required this.outboundTags,
    this.sanitizedContent,
  });

  final bool parsedJson;
  final bool changed;
  final bool fakeIpBefore;
  final bool fakeIpAfter;
  final String routeFinal;
  final String dnsFinal;
  final int dnsServerCount;
  final int routeRuleCount;
  final int removedFakeDnsServers;
  final int removedIpv6DnsServers;
  final int removedFakeDnsRules;
  final int removedFakeRouteRules;
  final int removedIpv6DnsRules;
  final int removedIpv6RouteRules;
  final int removedGeoRouteRules;
  final int removedCatchAllRules;
  final int removedIpv6TunValues;
  final int forcedDnsDetours;
  final int forcedDnsStrategies;
  final List<String> outboundTags;
  final String? sanitizedContent;

  bool get hasResidualFakeIp => fakeIpAfter;
}

class FinalConfigGuard with InfraLogger {
  const FinalConfigGuard();

  static const residualFakeIpMessage = '最终配置仍包含 fake-ip/198.18.x.x，已阻止启动。';

  Future<FinalConfigGuardResult> inspectAndSanitizeFile(String path, {required String stage}) async {
    final file = File(path);
    final content = await file.readAsString();
    final result = inspectAndSanitizeContent(content);
    if (result.changed && result.sanitizedContent != null) {
      await file.writeAsString(result.sanitizedContent!);
    }
    _logResult(stage, result);
    return result;
  }

  @visibleForTesting
  FinalConfigGuardResult inspectAndSanitizeContent(String content) {
    final fakeIpBefore = _containsFakeIpMarker(content);

    Object? decoded;
    try {
      decoded = jsonDecode(content);
    } catch (_) {
      return FinalConfigGuardResult(
        parsedJson: false,
        changed: false,
        fakeIpBefore: fakeIpBefore,
        fakeIpAfter: fakeIpBefore,
        routeFinal: 'unknown',
        dnsFinal: 'unknown',
        dnsServerCount: 0,
        routeRuleCount: 0,
        removedFakeDnsServers: 0,
        removedIpv6DnsServers: 0,
        removedFakeDnsRules: 0,
        removedFakeRouteRules: 0,
        removedIpv6DnsRules: 0,
        removedIpv6RouteRules: 0,
        removedGeoRouteRules: 0,
        removedCatchAllRules: 0,
        removedIpv6TunValues: 0,
        forcedDnsDetours: 0,
        forcedDnsStrategies: 0,
        outboundTags: const [],
      );
    }

    if (decoded is! Map<String, dynamic>) {
      return FinalConfigGuardResult(
        parsedJson: true,
        changed: false,
        fakeIpBefore: fakeIpBefore,
        fakeIpAfter: _containsFakeIpMarker(decoded),
        routeFinal: 'unknown',
        dnsFinal: 'unknown',
        dnsServerCount: 0,
        routeRuleCount: 0,
        removedFakeDnsServers: 0,
        removedIpv6DnsServers: 0,
        removedFakeDnsRules: 0,
        removedFakeRouteRules: 0,
        removedIpv6DnsRules: 0,
        removedIpv6RouteRules: 0,
        removedGeoRouteRules: 0,
        removedCatchAllRules: 0,
        removedIpv6TunValues: 0,
        forcedDnsDetours: 0,
        forcedDnsStrategies: 0,
        outboundTags: const [],
      );
    }

    final root = decoded;
    final stats = _SanitizeStats();
    final beforeJson = jsonEncode(root);

    _removeUnsafeKeysDeep(root);
    _sanitizeDns(_ensureDns(root, stats), stats);
    _sanitizeRoute(_ensureRoute(root), stats);
    _sanitizeTunInbounds(root['inbounds'], stats);

    final afterJson = jsonEncode(root);
    final changed = beforeJson != afterJson;
    final fakeIpAfter = _containsFakeIpMarker(root);
    final encoder = changed ? const JsonEncoder.withIndent('  ') : null;

    return FinalConfigGuardResult(
      parsedJson: true,
      changed: changed,
      fakeIpBefore: fakeIpBefore,
      fakeIpAfter: fakeIpAfter,
      routeFinal: _stringValue(_mapValue(root['route'])?['final']) ?? 'missing',
      dnsFinal: _stringValue(_mapValue(root['dns'])?['final']) ?? 'missing',
      dnsServerCount: _listValue(_mapValue(root['dns'])?['servers'])?.length ?? 0,
      routeRuleCount: _listValue(_mapValue(root['route'])?['rules'])?.length ?? 0,
      removedFakeDnsServers: stats.removedFakeDnsServers,
      removedIpv6DnsServers: stats.removedIpv6DnsServers,
      removedFakeDnsRules: stats.removedFakeDnsRules,
      removedFakeRouteRules: stats.removedFakeRouteRules,
      removedIpv6DnsRules: stats.removedIpv6DnsRules,
      removedIpv6RouteRules: stats.removedIpv6RouteRules,
      removedGeoRouteRules: stats.removedGeoRouteRules,
      removedCatchAllRules: stats.removedCatchAllRules,
      removedIpv6TunValues: stats.removedIpv6TunValues,
      forcedDnsDetours: stats.forcedDnsDetours,
      forcedDnsStrategies: stats.forcedDnsStrategies,
      outboundTags: _extractOutboundTags(root),
      sanitizedContent: changed ? encoder!.convert(root) : null,
    );
  }

  void _logResult(String stage, FinalConfigGuardResult result) {
    final tags = result.outboundTags.take(8).map(_safeLogValue).join(',');
    loggy.debug(
      'final config check [$stage]: '
      'parsedJson=${result.parsedJson}, '
      'dnsMode=${LockedCoreConfig.dnsMode}, '
      'dnsStrategy=${LockedCoreConfig.dnsStrategy}, '
      'ipv6=${LockedCoreConfig.ipv6}, '
      'fakeIpBefore=${result.fakeIpBefore}, '
      'fakeIpAfter=${result.fakeIpAfter}, '
      'sanitized=${result.changed}, '
      'dnsFinal=${_safeLogValue(result.dnsFinal)}, '
      'dnsServers=${result.dnsServerCount}, '
      'routeFinal=${_safeLogValue(result.routeFinal)}, '
      'routeRules=${result.routeRuleCount}, '
      'removedFakeDnsServers=${result.removedFakeDnsServers}, '
      'removedIpv6DnsServers=${result.removedIpv6DnsServers}, '
      'removedFakeDnsRules=${result.removedFakeDnsRules}, '
      'removedFakeRouteRules=${result.removedFakeRouteRules}, '
      'removedIpv6DnsRules=${result.removedIpv6DnsRules}, '
      'removedIpv6RouteRules=${result.removedIpv6RouteRules}, '
      'removedGeoRouteRules=${result.removedGeoRouteRules}, '
      'removedCatchAllRules=${result.removedCatchAllRules}, '
      'removedIpv6TunValues=${result.removedIpv6TunValues}, '
      'forcedDnsDetours=${result.forcedDnsDetours}, '
      'forcedDnsStrategies=${result.forcedDnsStrategies}, '
      'nodeCount=${result.outboundTags.length}, '
      'outboundTags=[$tags], '
      'coreConfigVersion=${LockedCoreConfig.schemaVersion}',
    );
    if (result.hasResidualFakeIp) {
      loggy.warning('final config check [$stage]: residual fake-ip marker detected after sanitize');
    }
  }

  static void _sanitizeDns(Object? value, _SanitizeStats stats) {
    final dns = _mapValue(value);
    if (dns == null) return;

    _removeFakeIpKeys(dns);

    final removedFakeTags = <String>{};
    final removedIpv6Tags = <String>{};
    final servers = _listValue(dns['servers']);
    if (servers != null) {
      final keptServers = <Object?>[];
      for (final server in servers) {
        if (_isFakeDnsServer(server)) {
          final tag = _stringValue(_mapValue(server)?['tag']);
          if (tag != null && tag.isNotEmpty) removedFakeTags.add(tag);
          stats.removedFakeDnsServers += 1;
        } else if (_isIpv6DnsServer(server)) {
          final tag = _stringValue(_mapValue(server)?['tag']);
          if (tag != null && tag.isNotEmpty) removedIpv6Tags.add(tag);
          stats.removedIpv6DnsServers += 1;
        } else {
          final serverMap = _mapValue(server);
          if (serverMap != null) {
            if (serverMap['detour'] != LockedCoreConfig.outboundTag) {
              serverMap['detour'] = LockedCoreConfig.outboundTag;
              stats.forcedDnsDetours += 1;
            }
            if (serverMap['strategy'] != LockedCoreConfig.dnsStrategy) {
              serverMap['strategy'] = LockedCoreConfig.dnsStrategy;
              stats.forcedDnsStrategies += 1;
            }
          }
          keptServers.add(server);
        }
      }
      if (keptServers.length != servers.length) {
        dns['servers'] = keptServers;
      }
      if (keptServers.isEmpty) {
        dns['servers'] = [_defaultDnsServer()];
        stats.forcedDnsDetours += 1;
        stats.forcedDnsStrategies += 1;
      }
    }

    final rules = _listValue(dns['rules']);
    if (rules != null) {
      final keptRules = <Object?>[];
      for (final rule in rules) {
        if (_referencesFakeIp(rule, removedFakeTags)) {
          stats.removedFakeDnsRules += 1;
        } else if (_referencesFakeIp(rule, removedIpv6Tags) || _referencesIpv6Route(rule)) {
          stats.removedIpv6DnsRules += 1;
        } else {
          keptRules.add(rule);
        }
      }
      if (keptRules.length != rules.length) {
        dns['rules'] = keptRules;
      }
    }

    final dnsFinal = _stringValue(dns['final']);
    if (dnsFinal == null ||
        removedFakeTags.contains(dnsFinal) ||
        removedIpv6Tags.contains(dnsFinal) ||
        _containsFakeIpMarker(dnsFinal)) {
      dns['final'] = _firstDnsServerTag(dns) ?? 'dns-remote';
    }
    if (dns['strategy'] != LockedCoreConfig.dnsStrategy) {
      dns['strategy'] = LockedCoreConfig.dnsStrategy;
      stats.forcedDnsStrategies += 1;
    }
  }

  static void _sanitizeRoute(Object? value, _SanitizeStats stats) {
    final route = _mapValue(value);
    if (route == null) return;

    if (route['final'] != LockedCoreConfig.routeFinal) {
      route['final'] = LockedCoreConfig.routeFinal;
    }

    if (route.containsKey('rule_set')) {
      route['rule_set'] = <Object?>[];
      stats.removedGeoRouteRules += 1;
    }

    final rules = _listValue(route['rules']);
    if (rules == null) {
      route['rules'] = <Object?>[];
      return;
    }
    final keptRules = <Object?>[];
    for (final rule in rules) {
      if (_referencesFakeIp(rule, const {})) {
        stats.removedFakeRouteRules += 1;
      } else if (_referencesIpv6Route(rule)) {
        stats.removedIpv6RouteRules += 1;
      } else if (_referencesGeoRule(rule)) {
        stats.removedGeoRouteRules += 1;
      } else if (_isDefaultBlockOrDirectRule(rule)) {
        stats.removedCatchAllRules += 1;
      } else {
        keptRules.add(rule);
      }
    }
    if (keptRules.length != rules.length) {
      route['rules'] = keptRules;
    }
  }

  static void _sanitizeTunInbounds(Object? value, _SanitizeStats stats) {
    final inbounds = _listValue(value);
    if (inbounds == null) return;
    for (final inbound in inbounds) {
      final map = _mapValue(inbound);
      if (map == null) continue;
      final keys = map.keys.toList();
      for (final key in keys) {
        final normalized = _normalizeKey(key);
        if (normalized.contains('inet6') || normalized == 'localaddressipv6') {
          map.remove(key);
          stats.removedIpv6TunValues += 1;
        } else if (map[key] is List && normalized.contains('route')) {
          final original = _listValue(map[key]) ?? const [];
          final filtered = original.where((item) => !_referencesIpv6Route(item)).toList(growable: false);
          if (filtered.length != original.length) {
            map[key] = filtered;
            stats.removedIpv6TunValues += original.length - filtered.length;
          }
        }
      }
    }
  }

  static void _removeFakeIpKeys(Map<String, dynamic> map) {
    final keys = map.keys.toList();
    for (final key in keys) {
      final normalized = _normalizeKey(key);
      if (normalized == 'fakeip' || normalized == 'fakeiprange') {
        map.remove(key);
      } else if (normalized == 'enhancedmode' && _containsFakeIpMarker(map[key])) {
        map.remove(key);
      }
    }
  }

  static bool _isFakeDnsServer(Object? value) {
    if (_containsFakeIpMarker(value)) return true;
    final map = _mapValue(value);
    if (map == null) return false;
    final type = _stringValue(map['type']);
    final address = _stringValue(map['address']);
    return _containsFakeIpMarker(type) || _containsFakeIpMarker(address);
  }

  static bool _isIpv6DnsServer(Object? value) {
    final map = _mapValue(value);
    if (map == null) return _looksLikeIpv6Text(value?.toString() ?? '');
    final address = _stringValue(map['address']) ?? _stringValue(map['server']);
    if (address != null && _looksLikeIpv6Text(_uriHostOrRaw(address))) return true;
    return false;
  }

  static bool _referencesFakeIp(Object? value, Set<String> fakeTags) {
    if (_containsFakeIpMarker(value)) return true;
    if (fakeTags.isEmpty) return false;
    if (value is Map) {
      for (final entry in value.entries) {
        if (fakeTags.contains(entry.value?.toString())) return true;
      }
    } else if (value is Iterable) {
      return value.any((item) => _referencesFakeIp(item, fakeTags));
    }
    return false;
  }

  static bool _referencesIpv6Route(Object? value) {
    if (value == null) return false;
    if (value is Map) {
      for (final entry in value.entries) {
        final key = _normalizeKey(entry.key.toString());
        if (key == 'ipversion' && entry.value?.toString() == '6') return true;
        if (key.contains('inet6') || key == 'localaddressipv6') return true;
        if (_referencesIpv6Route(entry.value)) return true;
      }
      return false;
    }
    if (value is Iterable && value is! String) {
      return value.any(_referencesIpv6Route);
    }
    final text = value.toString().trim().toLowerCase();
    return text == '::/0' ||
        text == '::' ||
        text.contains('ipv6_only') ||
        text.contains('prefer_ipv6') ||
        _looksLikeIpv6Text(text);
  }

  static bool _referencesGeoRule(Object? value) {
    if (value == null) return false;
    if (value is Map) {
      for (final entry in value.entries) {
        final key = _normalizeKey(entry.key.toString());
        if (key == 'ruleset' || key == 'geosite' || key == 'geoip') return true;
        if (_referencesGeoRule(entry.value)) return true;
      }
      return false;
    }
    if (value is Iterable && value is! String) {
      return value.any(_referencesGeoRule);
    }
    final text = value.toString().toLowerCase();
    return text.contains('geosite:') || text.contains('geoip:');
  }

  static bool _isDefaultBlockOrDirectRule(Object? value) {
    final map = _mapValue(value);
    if (map == null) return false;
    final outbound = _stringValue(map['outbound']) ?? _stringValue(map['action']);
    if (outbound != 'block' && outbound != 'direct' && outbound != 'reject') return false;
    if (_containsCatchAllCidr(map['ip_cidr']) || _containsCatchAllCidr(map['ip_cidr_match_source'])) return true;
    const matcherKeys = {
      'domain',
      'domain_suffix',
      'domain_keyword',
      'domain_regex',
      'ip_cidr',
      'port',
      'protocol',
      'network',
      'process_name',
      'package_name',
      'clash_mode',
      'rule_set',
      'geosite',
      'geoip',
    };
    return map.keys.every((key) => !matcherKeys.contains(key));
  }

  static Object _ensureDns(Map<String, dynamic> root, _SanitizeStats stats) {
    final existing = _mapValue(root['dns']);
    if (existing != null) {
      root['dns'] = existing;
      return existing;
    }
    final dns = <String, dynamic>{
      'servers': [_defaultDnsServer()],
      'final': 'dns-remote',
      'strategy': LockedCoreConfig.dnsStrategy,
      'independent_cache': true,
    };
    root['dns'] = dns;
    stats.forcedDnsDetours += 1;
    stats.forcedDnsStrategies += 1;
    return dns;
  }

  static Object _ensureRoute(Map<String, dynamic> root) {
    final existing = _mapValue(root['route']);
    if (existing != null) {
      root['route'] = existing;
      return existing;
    }
    final route = <String, dynamic>{'rules': <Object?>[], 'final': LockedCoreConfig.routeFinal};
    root['route'] = route;
    return route;
  }

  static Map<String, dynamic> _defaultDnsServer() => {
    'tag': 'dns-remote',
    'address': LockedCoreConfig.remoteDnsAddress,
    'detour': LockedCoreConfig.outboundTag,
    'strategy': LockedCoreConfig.dnsStrategy,
  };

  static void _removeUnsafeKeysDeep(Object? value) {
    if (value is Map) {
      for (final key in value.keys.toList()) {
        final normalized = _normalizeKey(key.toString());
        if (normalized.contains('fakeip') || normalized == 'enhancedmode') {
          value.remove(key);
        } else {
          _removeUnsafeKeysDeep(value[key]);
        }
      }
    } else if (value is Iterable && value is! String) {
      for (final item in value) {
        _removeUnsafeKeysDeep(item);
      }
    }
  }

  static bool _containsCatchAllCidr(Object? value) {
    if (value is Iterable && value is! String) return value.any(_containsCatchAllCidr);
    final text = value?.toString().trim().toLowerCase();
    return text == '0.0.0.0/0' || text == '::/0';
  }

  static bool _containsFakeIpMarker(Object? value) {
    if (value == null) return false;
    if (value is Map) {
      for (final entry in value.entries) {
        if (_isFakeIpText(entry.key.toString()) || _containsFakeIpMarker(entry.value)) return true;
      }
      return false;
    }
    if (value is Iterable && value is! String) {
      return value.any(_containsFakeIpMarker);
    }
    return _isFakeIpText(value.toString());
  }

  static bool _isFakeIpText(String value) {
    final lower = value.toLowerCase();
    return lower.contains('fake-ip') ||
        lower.contains('fake_ip') ||
        lower.contains('fakeip') ||
        RegExp(r'\b198\.(18|19)\.').hasMatch(lower);
  }

  static String? _firstDnsServerTag(Map<String, dynamic> dns) {
    final servers = _listValue(dns['servers']);
    if (servers == null) return null;
    for (final server in servers) {
      final tag = _stringValue(_mapValue(server)?['tag']);
      if (tag != null && tag.isNotEmpty && !_containsFakeIpMarker(tag)) return tag;
    }
    return null;
  }

  static List<String> _extractOutboundTags(Map<String, dynamic> root) {
    final tags = <String>[];
    for (final key in const ['outbounds', 'endpoints']) {
      final entries = _listValue(root[key]);
      if (entries == null) continue;
      for (final entry in entries) {
        final tag = _stringValue(_mapValue(entry)?['tag']);
        if (tag != null && tag.isNotEmpty) tags.add(tag);
      }
    }
    return tags;
  }

  static Map<String, dynamic>? _mapValue(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, value) => MapEntry(key.toString(), value));
    return null;
  }

  static List<Object?>? _listValue(Object? value) {
    if (value is List<Object?>) return value;
    if (value is List) return value.cast<Object?>();
    return null;
  }

  static String? _stringValue(Object? value) {
    if (value == null) return null;
    return value.toString();
  }

  static String _normalizeKey(String value) => value.toLowerCase().replaceAll(RegExp('[-_]'), '');

  static String _uriHostOrRaw(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.host.isNotEmpty) return uri.host;
    return value.replaceAll('[', '').replaceAll(']', '');
  }

  static bool _looksLikeIpv6Text(String value) {
    final text = value.toLowerCase();
    return RegExp(
      r'(^|[\s\[,/])([0-9a-f]{0,4}:){2,}[0-9a-f]{0,4}(/[0-9]{1,3})?($|[\s\],/])',
      caseSensitive: false,
    ).hasMatch(text);
  }

  static String _safeLogValue(String value) {
    var sanitized = value
        .replaceAll(RegExp(r'Bearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false), 'Bearer ***')
        .replaceAll(RegExp(r'''(authorization["']?\s*[:=]\s*["']?)[^,\s"']+''', caseSensitive: false), r'$1***')
        .replaceAll(RegExp(r'https?://[^\s,\]]+'), 'https://***');
    if (sanitized.length > 48) sanitized = '${sanitized.substring(0, 48)}…';
    return sanitized;
  }
}

class _SanitizeStats {
  int removedFakeDnsServers = 0;
  int removedIpv6DnsServers = 0;
  int removedFakeDnsRules = 0;
  int removedFakeRouteRules = 0;
  int removedIpv6DnsRules = 0;
  int removedIpv6RouteRules = 0;
  int removedGeoRouteRules = 0;
  int removedCatchAllRules = 0;
  int removedIpv6TunValues = 0;
  int forcedDnsDetours = 0;
  int forcedDnsStrategies = 0;
}
