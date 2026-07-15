import 'dart:convert';
import 'dart:io';

import 'package:hiddify/core/config/client_route_policy.dart';
import 'package:hiddify/core/config/locked_core_config.dart';
import 'package:hiddify/utils/custom_loggers.dart';

class FinalConfigGuardResult {
  const FinalConfigGuardResult({
    required this.parsedJson,
    required this.changed,
    required this.fakeIpBefore,
    required this.fakeIpAfter,
    required this.routeFinal,
    required this.routeDefaultDomainResolver,
    required this.dnsFinal,
    required this.dnsReverseMapping,
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
    required this.removedClashModeRules,
    required this.removedGlobalModeRules,
    required this.forcedSelectorDefaults,
    required this.forcedSelectedOutboundReferences,
    required this.removedUnselectedOutbounds,
    required this.forcedCoreLogLevel,
    required this.coreLogLevel,
    required this.outboundTags,
    required this.routeRuleSummary,
    required this.dnsServerSummary,
    required this.dnsRuleSummary,
    required this.routeRuleSetSummary,
    required this.inboundSummary,
    this.sanitizedContent,
  });

  final bool parsedJson;
  final bool changed;
  final bool fakeIpBefore;
  final bool fakeIpAfter;
  final String routeFinal;
  final String routeDefaultDomainResolver;
  final String dnsFinal;
  final bool dnsReverseMapping;
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
  final int removedClashModeRules;
  final int removedGlobalModeRules;
  final int forcedSelectorDefaults;
  final int forcedSelectedOutboundReferences;
  final int removedUnselectedOutbounds;
  final int forcedCoreLogLevel;
  final String coreLogLevel;
  final List<String> outboundTags;
  final List<String> routeRuleSummary;
  final List<String> dnsServerSummary;
  final List<String> dnsRuleSummary;
  final List<String> routeRuleSetSummary;
  final List<String> inboundSummary;
  final String? sanitizedContent;

  bool get hasResidualFakeIp => fakeIpAfter;
}

class FinalConfigGuard with InfraLogger {
  const FinalConfigGuard();

  static const residualFakeIpMessage = '最终配置仍包含 fake-ip/198.18.x.x，已阻止启动。';

  Future<FinalConfigGuardResult> inspectAndSanitizeFile(
    String path, {
    required String stage,
    bool globalRouteMode = false,
    String? selectedOutboundTag,
    bool ensureAndroidRawInbounds = false,
    bool lockSelectedOutboundReferences = true,
  }) async {
    final file = File(path);
    final content = await file.readAsString();
    final result = inspectAndSanitizeContent(
      content,
      globalRouteMode: globalRouteMode,
      selectedOutboundTag: selectedOutboundTag,
      ensureAndroidRawInbounds: ensureAndroidRawInbounds,
      lockSelectedOutboundReferences: lockSelectedOutboundReferences,
    );
    if (result.changed && result.sanitizedContent != null) {
      await file.writeAsString(result.sanitizedContent!);
    }
    _logResult(stage, result);
    return result;
  }

  FinalConfigGuardResult inspectAndSanitizeContent(
    String content, {
    bool globalRouteMode = false,
    String? selectedOutboundTag,
    bool ensureAndroidRawInbounds = false,
    bool lockSelectedOutboundReferences = true,
  }) {
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
        routeDefaultDomainResolver: 'unknown',
        dnsFinal: 'unknown',
        dnsReverseMapping: false,
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
        removedClashModeRules: 0,
        removedGlobalModeRules: 0,
        forcedSelectorDefaults: 0,
        forcedSelectedOutboundReferences: 0,
        removedUnselectedOutbounds: 0,
        forcedCoreLogLevel: 0,
        coreLogLevel: 'unknown',
        outboundTags: const [],
        routeRuleSummary: const [],
        dnsServerSummary: const [],
        dnsRuleSummary: const [],
        routeRuleSetSummary: const [],
        inboundSummary: const [],
      );
    }

    if (decoded is! Map<String, dynamic>) {
      return FinalConfigGuardResult(
        parsedJson: true,
        changed: false,
        fakeIpBefore: fakeIpBefore,
        fakeIpAfter: _containsFakeIpMarker(decoded),
        routeFinal: 'unknown',
        routeDefaultDomainResolver: 'unknown',
        dnsFinal: 'unknown',
        dnsReverseMapping: false,
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
        removedClashModeRules: 0,
        removedGlobalModeRules: 0,
        forcedSelectorDefaults: 0,
        forcedSelectedOutboundReferences: 0,
        removedUnselectedOutbounds: 0,
        forcedCoreLogLevel: 0,
        coreLogLevel: 'unknown',
        outboundTags: const [],
        routeRuleSummary: const [],
        dnsServerSummary: const [],
        dnsRuleSummary: const [],
        routeRuleSetSummary: const [],
        inboundSummary: const [],
      );
    }

    final root = decoded;
    final stats = _SanitizeStats();
    final beforeJson = jsonEncode(root);

    _removeUnsafeKeysDeep(root);
    _ensureDiagnosticLogLevel(root, stats);
    _normalizeLockedOutboundTags(root);
    _migrateDeprecatedDnsOutbounds(root);
    _normalizeSingBoxRuleListFields(root);
    _sanitizeDns(_ensureDns(root, stats), stats, globalRouteMode: globalRouteMode);
    _sanitizeRoute(_ensureRoute(root), stats, globalRouteMode: globalRouteMode);
    _ensureSmartRouteFallback(root, globalRouteMode: globalRouteMode);
    if (ensureAndroidRawInbounds) _ensureAndroidRawInbounds(root);
    _ensureInboundSniff(root['inbounds']);
    if (lockSelectedOutboundReferences) {
      _lockSelectedOutboundReferences(root, selectedOutboundTag, stats);
    }
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
      routeDefaultDomainResolver: _stringValue(_mapValue(root['route'])?['default_domain_resolver']) ?? 'missing',
      dnsFinal: _stringValue(_mapValue(root['dns'])?['final']) ?? 'missing',
      dnsReverseMapping: _mapValue(root['dns'])?['reverse_mapping'] == true,
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
      removedClashModeRules: stats.removedClashModeRules,
      removedGlobalModeRules: stats.removedGlobalModeRules,
      forcedSelectorDefaults: stats.forcedSelectorDefaults,
      forcedSelectedOutboundReferences: stats.forcedSelectedOutboundReferences,
      removedUnselectedOutbounds: stats.removedUnselectedOutbounds,
      forcedCoreLogLevel: stats.forcedCoreLogLevel,
      coreLogLevel: _stringValue(_mapValue(root['log'])?['level']) ?? 'missing',
      outboundTags: _extractOutboundTags(root),
      routeRuleSummary: _summarizeRules(_listValue(_mapValue(root['route'])?['rules'])),
      dnsServerSummary: _summarizeDnsServers(_listValue(_mapValue(root['dns'])?['servers'])),
      dnsRuleSummary: _summarizeRules(_listValue(_mapValue(root['dns'])?['rules'])),
      routeRuleSetSummary: _summarizeRuleSets(_listValue(_mapValue(root['route'])?['rule_set'])),
      inboundSummary: _summarizeInbounds(_listValue(root['inbounds'])),
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
      'routeDefaultDomainResolver=${_safeLogValue(result.routeDefaultDomainResolver)}, '
      'routeRules=${result.routeRuleCount}, '
      'dnsReverseMapping=${result.dnsReverseMapping}, '
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
      'removedClashModeRules=${result.removedClashModeRules}, '
      'removedGlobalModeRules=${result.removedGlobalModeRules}, '
      'forcedSelectorDefaults=${result.forcedSelectorDefaults}, '
      'forcedSelectedOutboundReferences=${result.forcedSelectedOutboundReferences}, '
      'removedUnselectedOutbounds=${result.removedUnselectedOutbounds}, '
      'forcedCoreLogLevel=${result.forcedCoreLogLevel}, '
      'coreLogLevel=${_safeLogValue(result.coreLogLevel)}, '
      'nodeCount=${result.outboundTags.length}, '
      'outboundTags=[$tags], '
      'inbounds=[${result.inboundSummary.join(';')}], '
      'coreConfigVersion=${LockedCoreConfig.schemaVersion}',
    );
    if (result.hasResidualFakeIp) {
      loggy.warning('final config check [$stage]: residual fake-ip marker detected after sanitize');
    }
  }

  static void _ensureDiagnosticLogLevel(Map<String, dynamic> root, _SanitizeStats stats) {
    final log = _mapValue(root['log']) ?? <String, dynamic>{};
    if (log['level'] != LockedCoreConfig.coreLogLevel) {
      log['level'] = LockedCoreConfig.coreLogLevel;
      stats.forcedCoreLogLevel += 1;
    }
    root['log'] = log;
  }

  static void _normalizeLockedOutboundTags(Map<String, dynamic> root) {
    final outbounds = _listValue(root['outbounds']);
    if (outbounds == null || outbounds.isEmpty) return;

    _renameOutboundTagIfMissing(
      root: root,
      outbounds: outbounds,
      requiredTag: LockedCoreConfig.outboundTag,
      preferredLegacyTag: '节点选择',
      type: 'selector',
    );
    _renameOutboundTagIfMissing(
      root: root,
      outbounds: outbounds,
      requiredTag: 'auto',
      preferredLegacyTag: '自动选择',
      type: 'urltest',
    );
  }

  /// Sing-box 1.11+ routes DNS through the DNS engine instead of a `dns`
  /// outbound. Remove legacy entries before the core parses the profile.
  static void _migrateDeprecatedDnsOutbounds(Map<String, dynamic> root) {
    final outbounds = _listValue(root['outbounds']);
    if (outbounds == null || outbounds.isEmpty) return;

    final deprecatedTags = <String>{};
    final keptOutbounds = <Object?>[];
    var removedDeprecatedOutbound = false;
    for (final outbound in outbounds) {
      final map = _mapValue(outbound);
      final type = _stringValue(map?['type'])?.trim().toLowerCase();
      if (type == 'dns') {
        removedDeprecatedOutbound = true;
        final tag = _stringValue(map?['tag'])?.trim();
        if (tag != null && tag.isNotEmpty) deprecatedTags.add(tag);
      } else {
        keptOutbounds.add(outbound);
      }
    }
    if (!removedDeprecatedOutbound) return;

    // Do not turn an unusable legacy profile into an empty selector/urltest.
    // The core should reject that profile instead of starting without a route.
    for (final outbound in keptOutbounds) {
      final map = _mapValue(outbound);
      final choices = _listValue(map?['outbounds']);
      if (choices == null || !choices.any((choice) => deprecatedTags.contains(_stringValue(choice)?.trim()))) {
        continue;
      }
      if (choices.every((choice) => deprecatedTags.contains(_stringValue(choice)?.trim()))) return;
    }

    root['outbounds'] = keptOutbounds;

    // Selector and urltest groups must not retain removed candidates/defaults.
    for (final outbound in keptOutbounds) {
      final map = _mapValue(outbound);
      if (map == null) continue;
      final choices = _listValue(map['outbounds']);
      if (choices != null) {
        final filtered = choices
            .where((choice) => !deprecatedTags.contains(_stringValue(choice)?.trim()))
            .toList(growable: true);
        if (filtered.length != choices.length) map['outbounds'] = filtered;
      }
      if (deprecatedTags.contains(_stringValue(map['default'])?.trim())) map.remove('default');
    }

    final route = _mapValue(root['route']);
    if (route != null) {
      // _sanitizeRoute applies the locked route final after this migration.
      if (deprecatedTags.contains(_stringValue(route['final'])?.trim())) route.remove('final');
      final rules = _listValue(route['rules']);
      if (rules != null) {
        final keptRules = <Object?>[];
        for (final rule in rules) {
          final map = _mapValue(rule);
          if (map == null) {
            keptRules.add(rule);
            continue;
          }
          final outbound = _stringValue(map['outbound'])?.trim();
          if (deprecatedTags.contains(outbound) && _isDnsProtocolRule(map)) {
            map['action'] = 'hijack-dns';
            map.remove('outbound');
          } else if (deprecatedTags.contains(outbound)) {
            // A non-DNS rule targeting the removed outbound has no safe equivalent.
            continue;
          }
          final outboundChoices = _listValue(map['outbounds']);
          if (outboundChoices != null) {
            final filteredChoices = outboundChoices
                .where((choice) => !deprecatedTags.contains(_stringValue(choice)?.trim()))
                .toList(growable: true);
            if (filteredChoices.length != outboundChoices.length) {
              if (filteredChoices.isEmpty) {
                map.remove('outbounds');
              } else {
                map['outbounds'] = filteredChoices;
              }
            }
          }
          keptRules.add(rule);
        }
        route['rules'] = keptRules;
      }
    }

    _removeDeprecatedDetourReferences(root, deprecatedTags);
  }

  static void _removeDeprecatedDetourReferences(Object? value, Set<String> deprecatedTags) {
    if (value is Map) {
      for (final key in value.keys.toList()) {
        final normalizedKey = _normalizeKey(key.toString());
        final child = value[key];
        if (const {'detour', 'downloaddetour', 'externaluidownloaddetour'}.contains(normalizedKey) &&
            deprecatedTags.contains(_stringValue(child)?.trim())) {
          value.remove(key);
        } else {
          _removeDeprecatedDetourReferences(child, deprecatedTags);
        }
      }
    } else if (value is Iterable && value is! String) {
      for (final child in value) {
        _removeDeprecatedDetourReferences(child, deprecatedTags);
      }
    }
  }

  static void _renameOutboundTagIfMissing({
    required Map<String, dynamic> root,
    required List<Object?> outbounds,
    required String requiredTag,
    required String preferredLegacyTag,
    required String type,
  }) {
    if (_hasOutboundTag(outbounds, requiredTag)) return;

    final target = _findOutboundByTag(outbounds, preferredLegacyTag) ?? _findFirstOutboundByType(outbounds, type);
    if (target == null) return;

    final previousTag = _stringValue(target['tag']);
    if (previousTag == null || previousTag.isEmpty || previousTag == requiredTag) return;

    _replaceExactStringValues(root, previousTag, requiredTag);
    target['tag'] = requiredTag;
  }

  static bool _hasOutboundTag(List<Object?> outbounds, String tag) =>
      outbounds.any((item) => _stringValue(_mapValue(item)?['tag']) == tag);

  static Map<String, dynamic>? _findOutboundByTag(List<Object?> outbounds, String tag) {
    for (final item in outbounds) {
      final map = _mapValue(item);
      if (map != null && _stringValue(map['tag']) == tag) return map;
    }
    return null;
  }

  static Map<String, dynamic>? _findFirstOutboundByType(List<Object?> outbounds, String type) {
    for (final item in outbounds) {
      final map = _mapValue(item);
      if (map != null && _stringValue(map['type']) == type) return map;
    }
    return null;
  }

  static void _replaceExactStringValues(Object? value, String from, String to) {
    if (from == to || from.isEmpty) return;
    if (value is Map) {
      for (final key in value.keys.toList()) {
        final child = value[key];
        if (child is String) {
          if (child == from) value[key] = to;
        } else {
          _replaceExactStringValues(child, from, to);
        }
      }
    } else if (value is List) {
      for (var index = 0; index < value.length; index += 1) {
        final child = value[index];
        if (child is String) {
          if (child == from) value[index] = to;
        } else {
          _replaceExactStringValues(child, from, to);
        }
      }
    }
  }

  static void _normalizeSingBoxRuleListFields(Map<String, dynamic> root) {
    _normalizeRuleListEntries(_mapValue(root['dns'])?['rules'], _dnsRuleListFields);
    _normalizeRuleListEntries(_mapValue(root['route'])?['rules'], _routeRuleListFields);
  }

  static void _normalizeRuleListEntries(Object? value, Set<String> listFields) {
    final rules = _listValue(value);
    if (rules == null) return;
    for (final rule in rules) {
      final map = _mapValue(rule);
      if (map == null) continue;
      for (final key in map.keys.toList()) {
        if (!listFields.contains(_normalizeKey(key))) continue;
        final child = map[key];
        if (child == null || child is List || child is Map || child is bool) continue;
        map[key] = [child];
      }
    }
  }

  static const _sharedRuleListFields = {
    'inbound',
    'inbounds',
    'network',
    'networks',
    'authuser',
    'authusers',
    'clashmode',
    'clashmodes',
    'protocol',
    'protocols',
    'domain',
    'domains',
    'domainsuffix',
    'domainsuffixes',
    'domainkeyword',
    'domainkeywords',
    'domainregex',
    'domainregexes',
    'geosite',
    'geoip',
    'sourcegeoip',
    'ipcidr',
    'ipcidrs',
    'sourceipcidr',
    'sourceipcidrs',
    'port',
    'ports',
    'portrange',
    'portranges',
    'sourceport',
    'sourceports',
    'sourceportrange',
    'sourceportranges',
    'processname',
    'processnames',
    'processpath',
    'processpaths',
    'processpathregex',
    'processpathregexes',
    'packagename',
    'packagenames',
    'user',
    'users',
    'userid',
    'userids',
    'ruleset',
    'rulesets',
    'wifissid',
    'wifissids',
    'wifibssid',
    'wifibssids',
  };

  static const _routeRuleListFields = _sharedRuleListFields;

  static const _dnsRuleListFields = {..._sharedRuleListFields, 'outbound', 'outbounds', 'querytype', 'querytypes'};

  /// Converts the DNS server format removed by the bundled sing-box fork.
  /// Typed DNS servers reject legacy fields such as `address` and `strategy`.
  static void _migrateLegacyDnsServers(Map<String, dynamic> dns, _SanitizeStats stats) {
    final servers = _listValue(dns['servers']);
    if (servers == null || servers.isEmpty) return;

    final migratedServers = <Object?>[];
    final rcodeServers = <String, String>{};
    for (final server in servers) {
      final map = _mapValue(server);
      if (map == null) {
        migratedServers.add(server);
        continue;
      }

      final type = _stringValue(map['type'])?.trim().toLowerCase();
      final isLegacy = type == null || type.isEmpty || type == 'legacy' || type == 'dns';
      if (isLegacy) {
        final rcode = _migrateLegacyDnsServer(map);
        if (rcode != null) {
          final tag = _stringValue(map['tag'])?.trim();
          if (tag != null && tag.isNotEmpty) rcodeServers[tag] = rcode;
          continue;
        }
      }

      final migratedType = _stringValue(map['type'])?.trim();
      if (migratedType == null || migratedType.isEmpty || migratedType == 'legacy' || migratedType == 'dns') {
        // Keep malformed or unknown legacy transports fail-closed instead of
        // silently changing where DNS is sent.
        migratedServers.add(server);
        continue;
      }

      _migrateLegacyDnsDialFields(map);
      if (map.containsKey('strategy')) {
        map.remove('strategy');
        stats.forcedDnsStrategies += 1;
      }
      map.remove('address');
      map.remove('client_subnet');
      migratedServers.add(map);
    }

    dns['servers'] = migratedServers;
    if (rcodeServers.isNotEmpty) {
      _rewriteLegacyRcodeDnsRules(dns['rules'], rcodeServers);
      final dnsFinal = _stringValue(dns['final'])?.trim();
      if (dnsFinal != null && rcodeServers.containsKey(dnsFinal)) dns.remove('final');
    }
  }

  /// Returns an RCODE when the legacy server must be replaced by a rule action.
  static String? _migrateLegacyDnsServer(Map<String, dynamic> server) {
    final address = _stringValue(server['address'])?.trim();
    if (address == null || address.isEmpty) return null;

    final normalizedAddress = address.toLowerCase();
    if (normalizedAddress == 'local') {
      server['type'] = 'local';
      server.remove('address');
      return null;
    }
    if (normalizedAddress == 'fakeip' || normalizedAddress == 'fake-ip') {
      server['type'] = 'fakeip';
      server.remove('address');
      return null;
    }

    final hasScheme = address.contains('://');
    var scheme = 'udp';
    Uri? uri;
    if (hasScheme) {
      uri = Uri.tryParse(address);
      scheme = uri?.scheme.toLowerCase() ?? '';
    } else if (_looksLikeIpv6Text(address)) {
      server['type'] = 'udp';
      server['server'] = address.replaceAll('[', '').replaceAll(']', '');
      server.remove('address');
      return null;
    } else {
      uri = Uri.tryParse('udp://$address');
    }

    if (scheme == 'rcode') {
      final rcode = _legacyDnsRcode(uri?.host);
      if (rcode == null) return null;
      server.remove('address');
      return rcode;
    }
    if (scheme == 'dhcp') {
      if (uri == null) return null;
      server['type'] = 'dhcp';
      if (uri.host.isNotEmpty && uri.host.toLowerCase() != 'auto') {
        server['interface'] = uri.host;
      }
      server.remove('address');
      return null;
    }

    if (scheme == 'http3') scheme = 'h3';
    const remoteTypes = {'udp', 'tcp', 'tls', 'https', 'quic', 'h3'};
    if (uri == null || !remoteTypes.contains(scheme) || uri.host.isEmpty) return null;

    final defaultPort = switch (scheme) {
      'udp' || 'tcp' => 53,
      'tls' || 'quic' => 853,
      'https' || 'h3' => 443,
      _ => 0,
    };
    server['type'] = scheme;
    server['server'] = uri.host;
    if (uri.hasPort && uri.port != defaultPort) {
      server['server_port'] = uri.port;
    } else {
      server.remove('server_port');
    }
    if ((scheme == 'https' || scheme == 'h3') && uri.path.isNotEmpty && uri.path != '/dns-query') {
      server['path'] = uri.path;
    }
    server.remove('address');
    return null;
  }

  static void _migrateLegacyDnsDialFields(Map<String, dynamic> server) {
    final addressResolver = _stringValue(server.remove('address_resolver'))?.trim();
    final addressStrategy = _stringValue(server.remove('address_strategy'))?.trim();
    final fallbackDelay = server.remove('address_fallback_delay');

    final currentResolver = server['domain_resolver'];
    if (addressResolver != null && addressResolver.isNotEmpty && currentResolver == null) {
      server['domain_resolver'] = addressStrategy == null || addressStrategy.isEmpty
          ? addressResolver
          : <String, Object>{'server': addressResolver, 'strategy': LockedCoreConfig.dnsStrategy};
    } else if (addressStrategy != null && addressStrategy.isNotEmpty && currentResolver is String) {
      server['domain_resolver'] = <String, Object>{'server': currentResolver, 'strategy': LockedCoreConfig.dnsStrategy};
    } else if (addressStrategy != null && addressStrategy.isNotEmpty) {
      final resolverMap = _mapValue(currentResolver);
      if (resolverMap != null && !resolverMap.containsKey('strategy')) {
        resolverMap['strategy'] = LockedCoreConfig.dnsStrategy;
        server['domain_resolver'] = resolverMap;
      }
    }

    final resolverMap = _mapValue(server['domain_resolver']);
    if (resolverMap != null && resolverMap.containsKey('strategy')) {
      resolverMap['strategy'] = LockedCoreConfig.dnsStrategy;
      server['domain_resolver'] = resolverMap;
    }
    server.remove('domain_strategy');

    if (fallbackDelay != null && !server.containsKey('fallback_delay')) {
      server['fallback_delay'] = fallbackDelay;
    }
  }

  static void _rewriteLegacyRcodeDnsRules(Object? value, Map<String, String> rcodeServers) {
    final rules = _listValue(value);
    if (rules == null) return;
    for (final rule in rules) {
      final map = _mapValue(rule);
      if (map == null) continue;
      final server = _stringValue(map['server'])?.trim();
      final rcode = server == null ? null : rcodeServers[server];
      if (rcode != null) {
        map['action'] = 'predefined';
        map['rcode'] = rcode;
        map.remove('server');
        for (final key in const [
          'strategy',
          'disable_cache',
          'disable_optimistic_cache',
          'rewrite_ttl',
          'client_subnet',
          'bypass_if_failed',
        ]) {
          map.remove(key);
        }
      }
      _rewriteLegacyRcodeDnsRules(map['rules'], rcodeServers);
    }
  }

  static String? _legacyDnsRcode(String? value) => switch (value?.trim().toLowerCase()) {
    'success' => 'NOERROR',
    'format_error' => 'FORMERR',
    'server_failure' => 'SERVFAIL',
    'name_error' => 'NXDOMAIN',
    'not_implemented' => 'NOTIMP',
    'refused' => 'REFUSED',
    _ => null,
  };

  static void _sanitizeDns(Object? value, _SanitizeStats stats, {required bool globalRouteMode}) {
    final dns = _mapValue(value);
    if (dns == null) return;

    _removeFakeIpKeys(dns);
    _migrateLegacyDnsServers(dns, stats);

    final removedFakeTags = <String>{};
    final removedIpv6Tags = <String>{};
    final servers = _listValue(dns['servers']);
    if (servers == null) {
      dns['servers'] = [_defaultDnsServer()];
      stats.forcedDnsDetours += 1;
    } else {
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
            final desiredDetour = _desiredDnsServerDetour(serverMap);
            if (desiredDetour == null) {
              if (serverMap.containsKey('detour')) {
                serverMap.remove('detour');
                stats.forcedDnsDetours += 1;
              }
            } else if (serverMap['detour'] != desiredDetour) {
              serverMap['detour'] = desiredDetour;
              stats.forcedDnsDetours += 1;
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
        } else if (_hasClashModeRule(rule)) {
          stats.removedClashModeRules += 1;
        } else {
          keptRules.add(rule);
        }
      }
      if (keptRules.length != rules.length) {
        dns['rules'] = keptRules;
      }
    }

    final dnsFinal = _stringValue(dns['final']);
    final dnsServerTags = _listValue(
      dns['servers'],
    )?.map((server) => _stringValue(_mapValue(server)?['tag'])).whereType<String>().toSet();
    if (dnsFinal == null ||
        removedFakeTags.contains(dnsFinal) ||
        removedIpv6Tags.contains(dnsFinal) ||
        dnsServerTags == null ||
        !dnsServerTags.contains(dnsFinal) ||
        _containsFakeIpMarker(dnsFinal)) {
      dns['final'] = _firstDnsServerTag(dns) ?? 'dns-remote';
    }
    if (dns['strategy'] != LockedCoreConfig.dnsStrategy) {
      dns['strategy'] = LockedCoreConfig.dnsStrategy;
      stats.forcedDnsStrategies += 1;
    }
    if (dns['reverse_mapping'] != true) {
      dns['reverse_mapping'] = true;
    }
  }

  static void _sanitizeRoute(Object? value, _SanitizeStats stats, {required bool globalRouteMode}) {
    final route = _mapValue(value);
    if (route == null) return;

    if (route['final'] != LockedCoreConfig.routeFinal) {
      route['final'] = LockedCoreConfig.routeFinal;
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
      } else if (_isDefaultBlockOrDirectRule(rule)) {
        stats.removedCatchAllRules += 1;
      } else if (_hasClashModeRule(rule)) {
        stats.removedClashModeRules += 1;
      } else if (_isSniffActionRule(rule)) {
        stats.removedCatchAllRules += 1;
      } else if (globalRouteMode && !_isDnsProtocolRule(rule)) {
        stats.removedGlobalModeRules += 1;
      } else {
        keptRules.add(rule);
      }
    }
    if (keptRules.length != rules.length) {
      route['rules'] = keptRules;
    }
  }

  static void _lockSelectedOutboundReferences(
    Map<String, dynamic> root,
    String? selectedOutboundTag,
    _SanitizeStats stats,
  ) {
    final selected = selectedOutboundTag?.trim();
    if (selected == null || selected.isEmpty) return;

    final outbounds = _listValue(root['outbounds']);
    if (outbounds == null || outbounds.isEmpty) return;
    if (!_hasOutboundTag(outbounds, selected)) return;

    final selector =
        _findOutboundByTag(outbounds, LockedCoreConfig.outboundTag) ??
        _findOutboundByTag(outbounds, '节点选择') ??
        _findFirstOutboundByType(outbounds, 'selector');
    if (selector != null) {
      final choices = _listValue(selector['outbounds']);
      if ((choices == null || choices.isEmpty || choices.any((item) => item?.toString() == selected)) &&
          _stringValue(selector['default']) != selected) {
        selector['default'] = selected;
        stats.forcedSelectorDefaults += 1;
      }
    }

    _lockDnsDetours(root['dns'], selected, stats);
    _lockRouteOutbounds(root['route'], selected, stats);
  }

  static void _lockDnsDetours(Object? value, String selected, _SanitizeStats stats) {
    final dns = _mapValue(value);
    if (dns == null) return;
    final servers = _listValue(dns['servers']);
    if (servers == null) return;
    for (final server in servers) {
      final map = _mapValue(server);
      if (map == null) continue;
      if (_isProxySelectorReference(map['detour'])) {
        map['detour'] = selected;
        stats.forcedSelectedOutboundReferences += 1;
      }
    }
  }

  static void _lockRouteOutbounds(Object? value, String selected, _SanitizeStats stats) {
    final route = _mapValue(value);
    if (route == null) return;

    if (_isProxySelectorReference(route['final'])) {
      route['final'] = selected;
      stats.forcedSelectedOutboundReferences += 1;
    }

    final rules = _listValue(route['rules']);
    if (rules != null) {
      for (final rule in rules) {
        final map = _mapValue(rule);
        if (map == null) continue;
        if (_isProxySelectorReference(map['outbound'])) {
          map['outbound'] = selected;
          stats.forcedSelectedOutboundReferences += 1;
        }
      }
    }

    final ruleSets = _listValue(route['rule_set']);
    if (ruleSets != null) {
      for (final ruleSet in ruleSets) {
        final map = _mapValue(ruleSet);
        if (map == null) continue;
        if (_isProxySelectorReference(map['download_detour'])) {
          map['download_detour'] = selected;
          stats.forcedSelectedOutboundReferences += 1;
        }
      }
    }
  }

  static void _ensureSmartRouteFallback(Map<String, dynamic> root, {required bool globalRouteMode}) {
    if (globalRouteMode) return;

    final route = _mapValue(root['route']);
    if (route == null) return;

    _ensureDirectOutbound(root);
    _ensureRuleSetEntries(route);
    _ensureSmartDnsRules(root);
    route['default_domain_resolver'] = 'dns-local';

    final rules = _listValue(route['rules']) ?? <Object?>[];
    _ensureDnsHijackRouteRule(rules);
    _addRouteRuleIfMissing(rules, 'ip_is_private', {'ip_is_private': true, 'outbound': 'direct', 'action': 'route'});
    _ensureRouteRuleValues(rules, 'domain', ClientRoutePolicy.cnBypassExactDomains);
    _ensureRouteRuleValues(rules, 'domain_suffix', ClientRoutePolicy.cnBypassDomainSuffixes);
    _ensureRouteRuleValues(rules, 'domain_keyword', ClientRoutePolicy.cnBypassDomainKeywords);
    _addRouteRuleIfMissing(rules, 'rule_set', {
      'rule_set': ['geosite-cn', 'geoip-cn'],
      'outbound': 'direct',
      'action': 'route',
    });
    route['rules'] = rules;
  }

  static void _ensureRuleSetEntries(Map<String, dynamic> route) {
    final ruleSets = _listValue(route['rule_set']) ?? <Object?>[];
    _addRuleSetEntryIfMissing(ruleSets, {
      'tag': 'geosite-cn',
      'type': 'remote',
      'format': 'binary',
      'url': '${LockedCoreConfig.rulesBaseUrl}/rules/sing-box/geosite-cn.srs',
      'download_detour': LockedCoreConfig.outboundTag,
    });
    _addRuleSetEntryIfMissing(ruleSets, {
      'tag': 'geoip-cn',
      'type': 'remote',
      'format': 'binary',
      'url': '${LockedCoreConfig.rulesBaseUrl}/rules/sing-box/geoip-cn.srs',
      'download_detour': LockedCoreConfig.outboundTag,
    });
    route['rule_set'] = ruleSets;
  }

  static void _addRuleSetEntryIfMissing(List<Object?> ruleSets, Map<String, Object> entry) {
    final tag = entry['tag']?.toString();
    if (tag == null || tag.isEmpty) return;
    final exists = ruleSets.any((item) => _stringValue(_mapValue(item)?['tag']) == tag);
    if (!exists) ruleSets.add(entry);
  }

  static void _ensureRouteRuleValues(List<Object?> rules, String matcherKey, List<String> values) {
    for (final item in rules) {
      final map = _mapValue(item);
      if (map == null || _stringValue(map['outbound']) != 'direct' || !map.containsKey(matcherKey)) continue;
      map['action'] = 'route';
      map[matcherKey] = _mergedStringList(map[matcherKey], values);
      return;
    }
    rules.add({matcherKey: values, 'outbound': 'direct', 'action': 'route'});
  }

  static void _addRouteRuleIfMissing(List<Object?> rules, String matcherKey, Map<String, Object> rule) {
    final exists = rules.any((item) {
      final map = _mapValue(item);
      if (map == null || _stringValue(map['outbound']) != 'direct' || !map.containsKey(matcherKey)) return false;
      map['action'] = 'route';
      return true;
    });
    if (!exists) rules.add(rule);
  }

  static void _ensureAndroidRawInbounds(Map<String, dynamic> root) {
    final inbounds = _listValue(root['inbounds']) ?? <Object?>[];
    if (!_hasInboundType(inbounds, 'mixed')) {
      inbounds.insert(0, {
        'type': 'mixed',
        'tag': 'mixed-in',
        'listen': '127.0.0.1',
        'listen_port': LockedCoreConfig.mixedPort,
      });
    }
    if (!_hasInboundType(inbounds, 'tun')) {
      inbounds.add({
        'type': 'tun',
        'tag': 'tun-in',
        'address': ['172.19.0.1/30'],
        'mtu': LockedCoreConfig.mtu,
        'auto_route': true,
        'strict_route': true,
        'stack': 'gvisor',
      });
    }
    root['inbounds'] = inbounds;
  }

  static bool _hasInboundType(List<Object?> inbounds, String type) {
    final normalized = type.toLowerCase().trim();
    return inbounds.any((item) => _stringValue(_mapValue(item)?['type'])?.toLowerCase().trim() == normalized);
  }

  static void _ensureInboundSniff(Object? value) {
    final inbounds = _listValue(value);
    if (inbounds == null) return;
    for (final inbound in inbounds) {
      final map = _mapValue(inbound);
      if (map == null) continue;
      final type = _stringValue(map['type'])?.toLowerCase().trim();
      if (type == null || !const {'mixed', 'tun', 'tproxy', 'redirect'}.contains(type)) continue;
      map['sniff'] = true;
      map['sniff_override_destination'] = true;
      map['sniff_timeout'] = '300ms';
      if (type == 'mixed') {
        map.remove('domain_strategy');
      } else {
        map['domain_strategy'] = LockedCoreConfig.dnsStrategy;
      }
    }
  }

  static void _ensureDnsHijackRouteRule(List<Object?> rules) {
    for (final rule in rules) {
      final map = _mapValue(rule);
      if (map == null || !_isDnsProtocolRule(map)) continue;
      map['action'] = 'hijack-dns';
      map.remove('outbound');
      return;
    }
    rules.insert(0, {
      'protocol': ['dns'],
      'action': 'hijack-dns',
    });
  }

  static void _ensureSmartDnsRules(Map<String, dynamic> root) {
    final dns = _mapValue(root['dns']);
    if (dns == null) return;

    final servers = _listValue(dns['servers']) ?? <Object?>[];
    _addDnsServerIfMissing(servers, {'tag': 'dns-local', 'type': 'https', 'server': '223.5.5.5'});
    dns['servers'] = servers;

    final rules = _listValue(dns['rules']) ?? <Object?>[];
    _ensureDnsRuleValues(rules, 'domain', ClientRoutePolicy.cnBypassExactDomains);
    _ensureDnsRuleValues(rules, 'domain_suffix', ClientRoutePolicy.cnBypassDomainSuffixes);
    _ensureDnsRuleValues(rules, 'domain_keyword', ClientRoutePolicy.cnBypassDomainKeywords);
    _addDnsRuleIfMissing(rules, 'rule_set', {
      'rule_set': ['geosite-cn'],
      'server': 'dns-local',
    });
    dns['rules'] = rules;
  }

  static void _addDnsServerIfMissing(List<Object?> servers, Map<String, Object> server) {
    final tag = server['tag']?.toString();
    if (tag == null || tag.isEmpty) return;
    final exists = servers.any((item) => _stringValue(_mapValue(item)?['tag']) == tag);
    if (!exists) servers.add(server);
  }

  static void _ensureDnsRuleValues(List<Object?> rules, String matcherKey, List<String> values) {
    for (final item in rules) {
      final map = _mapValue(item);
      if (map == null || _stringValue(map['server']) != 'dns-local' || !map.containsKey(matcherKey)) continue;
      map[matcherKey] = _mergedStringList(map[matcherKey], values);
      return;
    }
    rules.add({matcherKey: values, 'server': 'dns-local'});
  }

  static void _addDnsRuleIfMissing(List<Object?> rules, String matcherKey, Map<String, Object> rule) {
    final exists = rules.any((item) {
      final map = _mapValue(item);
      return map != null && _stringValue(map['server']) == 'dns-local' && map.containsKey(matcherKey);
    });
    if (!exists) rules.add(rule);
  }

  static void _ensureDirectOutbound(Map<String, dynamic> root) {
    final outbounds = _listValue(root['outbounds']);
    if (outbounds == null) return;
    if (_hasOutboundTag(outbounds, 'direct')) return;
    outbounds.add({'tag': 'direct', 'type': 'direct'});
  }

  static bool _isProxySelectorReference(Object? value) {
    final text = _stringValue(value)?.trim();
    return text == LockedCoreConfig.outboundTag || text == '节点选择' || text == 'auto' || text == '自动选择';
  }

  static String? _desiredDnsServerDetour(Map<String, dynamic> server) {
    final tag = _stringValue(server['tag'])?.trim().toLowerCase();
    final type = _stringValue(server['type'])?.trim().toLowerCase();
    final address = (_stringValue(server['server']) ?? _stringValue(server['address']))?.trim().toLowerCase() ?? '';
    final detour = _stringValue(server['detour'])?.trim();
    final normalizedDetour = detour?.toLowerCase();

    if (address.startsWith('rcode://') || type == 'rcode' || tag == 'block') {
      return null;
    }

    const dialTypes = {'udp', 'tcp', 'tls', 'https', 'quic', 'h3', 'local', 'dhcp', 'mdns', 'multi', 'sdns'};
    if (type == null || !dialTypes.contains(type)) return null;

    if (tag != null && tag.contains('remote')) {
      return LockedCoreConfig.outboundTag;
    }

    if (normalizedDetour == 'direct' ||
        type == 'local' ||
        type == 'dhcp' ||
        tag?.contains('local') == true ||
        tag?.contains('direct') == true ||
        tag?.contains('bootstrap') == true ||
        tag?.contains('system') == true) {
      // An empty direct outbound is the core's native direct dialer. The
      // bundled core rejects an explicit detour to that empty outbound.
      return null;
    }

    if (detour != null && detour.isNotEmpty) return detour;
    return LockedCoreConfig.outboundTag;
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

  static bool _hasClashModeRule(Object? value) {
    final map = _mapValue(value);
    if (map == null) return false;
    for (final key in map.keys) {
      if (_normalizeKey(key) == 'clashmode') return true;
    }
    return false;
  }

  static bool _isDnsProtocolRule(Object? value) {
    final map = _mapValue(value);
    if (map == null) return false;
    final protocol = map['protocol'];
    if (protocol is Iterable && protocol is! String) {
      return protocol.any((item) => item?.toString().toLowerCase() == 'dns');
    }
    return protocol?.toString().toLowerCase() == 'dns';
  }

  static bool _isSniffActionRule(Object? value) {
    final map = _mapValue(value);
    if (map == null) return false;
    return _stringValue(map['action'])?.toLowerCase().trim() == 'sniff';
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
      'ip_is_private',
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
    'type': 'tcp',
    'server': '8.8.8.8',
    'detour': LockedCoreConfig.outboundTag,
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

  static List<String> _summarizeRules(List<Object?>? rules) {
    if (rules == null) return const [];
    return rules
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final map = _mapValue(entry.value);
          if (map == null) return '$index:<non-map>';
          final parts = <String>['#$index'];
          for (final key in const [
            'action',
            'outbound',
            'server',
            'protocol',
            'ip_is_private',
            'domain',
            'domain_suffix',
            'domain_keyword',
            'rule_set',
          ]) {
            if (!map.containsKey(key)) continue;
            parts.add('$key=${_summarizeValue(map[key])}');
          }
          return parts.join(' ');
        })
        .toList(growable: false);
  }

  static List<String> _summarizeDnsServers(List<Object?>? servers) {
    if (servers == null) return const [];
    return servers
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final map = _mapValue(entry.value);
          if (map == null) return '$index:<non-map>';
          final endpoint = map['server'] ?? map['address'];
          return '#$index tag=${_summarizeValue(map['tag'])} type=${_summarizeValue(map['type'])} server=${_summarizeAddress(endpoint)} port=${_summarizeValue(map['server_port'])} detour=${_summarizeValue(map['detour'])}';
        })
        .toList(growable: false);
  }

  static List<String> _summarizeRuleSets(List<Object?>? ruleSets) {
    if (ruleSets == null) return const [];
    return ruleSets
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final map = _mapValue(entry.value);
          if (map == null) return '$index:<non-map>';
          return '#$index tag=${_summarizeValue(map['tag'])} url=${_summarizeAddress(map['url'])} detour=${_summarizeValue(map['download_detour'])}';
        })
        .toList(growable: false);
  }

  static List<String> _summarizeInbounds(List<Object?>? inbounds) {
    if (inbounds == null) return const [];
    return inbounds
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final map = _mapValue(entry.value);
          if (map == null) return '$index:<non-map>';
          final parts = <String>['#$index'];
          for (final key in const [
            'type',
            'tag',
            'listen',
            'listen_port',
            'sniff',
            'sniff_override_destination',
            'sniff_timeout',
            'domain_strategy',
          ]) {
            if (!map.containsKey(key)) continue;
            parts.add('$key=${_summarizeValue(map[key])}');
          }
          return parts.join(' ');
        })
        .toList(growable: false);
  }

  static String _summarizeValue(Object? value) {
    if (value == null) return '-';
    if (value is Iterable && value is! String) {
      final list = value.map((item) => item?.toString() ?? '').where((item) => item.isNotEmpty).toList(growable: false);
      final shown = list.take(6).join('|');
      return list.length > 6 ? '[$shown|+${list.length - 6}]' : '[$shown]';
    }
    return value.toString();
  }

  static String _summarizeAddress(Object? value) {
    final text = value?.toString() ?? '-';
    if (text.length <= 80) return text;
    return '${text.substring(0, 77)}...';
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

  static List<String> _mergedStringList(Object? current, List<String> requiredValues) {
    final merged = <String>[];
    void add(String value) {
      final normalized = value.trim();
      if (normalized.isNotEmpty && !merged.contains(normalized)) merged.add(normalized);
    }

    if (current is Iterable && current is! String) {
      for (final item in current) {
        add(item?.toString() ?? '');
      }
    } else if (current != null) {
      add(current.toString());
    }
    for (final value in requiredValues) {
      add(value);
    }
    return merged;
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
  int removedClashModeRules = 0;
  int removedGlobalModeRules = 0;
  int forcedSelectorDefaults = 0;
  int forcedSelectedOutboundReferences = 0;
  int removedUnselectedOutbounds = 0;
  int forcedCoreLogLevel = 0;
}
