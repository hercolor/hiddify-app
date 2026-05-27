import 'package:hiddify/core/config/locked_core_config.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesMigration with InfraLogger {
  PreferencesMigration({required this.sharedPreferences});

  final SharedPreferences sharedPreferences;

  static const versionKey = "preferences_version";

  Future<void> migrate() async {
    final currentVersion = sharedPreferences.getInt(versionKey) ?? 0;

    final List<PreferencesMigrationStep> migrationSteps = [
      PreferencesVersion1Migration(sharedPreferences),
      PreferencesVersion2Migration(sharedPreferences),
    ];

    if (currentVersion == migrationSteps.length) {
      loggy.debug("already using the latest version (v$currentVersion)");
    } else {
      final stopWatch = Stopwatch()..start();
      loggy.debug("migrating from v[$currentVersion] to v[${migrationSteps.length}]");
      for (int i = currentVersion; i < migrationSteps.length; i++) {
        loggy.debug("step [$i](v${i + 1})");
        await migrationSteps[i].migrate();
        await sharedPreferences.setInt(versionKey, i + 1);
      }
      stopWatch.stop();
      loggy.debug("migration took [${stopWatch.elapsedMilliseconds}]ms");
    }

    await ConsumerConfigSchemaMigration(sharedPreferences).migrate();
  }
}

abstract interface class PreferencesMigrationStep {
  PreferencesMigrationStep(this.sharedPreferences);

  final SharedPreferences sharedPreferences;

  Future<void> migrate();
}

class PreferencesVersion1Migration extends PreferencesMigrationStep with InfraLogger {
  PreferencesVersion1Migration(super.sharedPreferences);

  @override
  Future<void> migrate() async {
    if (sharedPreferences.getString("service-mode") case final String serviceMode) {
      final newMode = switch (serviceMode) {
        "proxy" || "system-proxy" || "vpn" => serviceMode,
        "systemProxy" => "system-proxy",
        "tun" => "vpn",
        _ => PlatformUtils.isDesktop ? "system-proxy" : "vpn",
      };
      loggy.debug("changing service-mode from [$serviceMode] to [$newMode]");
      await sharedPreferences.setString("service-mode", newMode);
    }

    if (sharedPreferences.getString("ipv6-mode") case final String ipv6Mode) {
      loggy.debug("changing ipv6-mode from [$ipv6Mode] to [${_ipv6Mapper(ipv6Mode)}]");
      await sharedPreferences.setString("ipv6-mode", _ipv6Mapper(ipv6Mode));
    }

    if (sharedPreferences.getString("remote-domain-dns-strategy") case final String remoteDomainStrategy) {
      loggy.debug(
        "changing [remote-domain-dns-strategy] = [$remoteDomainStrategy] to [remote-dns-domain-strategy] = [${_domainStrategyMapper(remoteDomainStrategy)}]",
      );
      await sharedPreferences.remove("remote-domain-dns-strategy");
      await sharedPreferences.setString("remote-dns-domain-strategy", _domainStrategyMapper(remoteDomainStrategy));
    }

    if (sharedPreferences.getString("direct-domain-dns-strategy") case final String directDomainStrategy) {
      loggy.debug(
        "changing [direct-domain-dns-strategy] = [$directDomainStrategy] to [direct-dns-domain-strategy] = [${_domainStrategyMapper(directDomainStrategy)}]",
      );
      await sharedPreferences.remove("direct-domain-dns-strategy");
      await sharedPreferences.setString("direct-dns-domain-strategy", _domainStrategyMapper(directDomainStrategy));
    }

    if (sharedPreferences.getInt("localDns-port") case final int directPort) {
      loggy.debug("changing [localDns-port] to [direct-port]");
      await sharedPreferences.remove("localDns-port");
      await sharedPreferences.setInt("direct-port", directPort);
    }

    await sharedPreferences.remove("execute-config-as-is");
    await sharedPreferences.remove("enable-tun");
    await sharedPreferences.remove("set-system-proxy");

    await sharedPreferences.remove("cron_profiles_update");
  }

  String _ipv6Mapper(String persisted) => switch (persisted) {
    "ipv4_only" || "prefer_ipv4" || "prefer_ipv4" || "ipv6_only" => persisted,
    "disable" => "ipv4_only",
    "enable" => "prefer_ipv4",
    "prefer" => "prefer_ipv6",
    "only" => "ipv6_only",
    _ => "ipv4_only",
  };

  String _domainStrategyMapper(String persisted) => switch (persisted) {
    "ipv4_only" || "prefer_ipv4" || "prefer_ipv4" || "ipv6_only" => persisted,
    "auto" => "",
    "preferIpv6" => "prefer_ipv6",
    "preferIpv4" => "prefer_ipv4",
    "ipv4Only" => "ipv4_only",
    "ipv6Only" => "ipv6_only",
    _ => "",
  };
}

class PreferencesVersion2Migration extends PreferencesMigrationStep with InfraLogger {
  PreferencesVersion2Migration(super.sharedPreferences);

  @override
  Future<void> migrate() async {
    loggy.debug("locking consumer startup and network config preferences");
    await sharedPreferences.setBool("intro_completed", true);

    for (final key in const [
      "dnsMode",
      "dns-mode",
      "routeMode",
      "route-mode",
      "customConfig",
      "custom-config",
      "custom_config",
      "fake-ip",
      "fake_ip",
      "fakeip",
      "fake-ip-range",
      "fakeIpRange",
      "enhanced-mode",
      "enhancedMode",
      "enable-dns-routing",
      "route-rules",
      "rules",
    ]) {
      await sharedPreferences.remove(key);
    }

    await sharedPreferences.setBool("enable-fake-dns", false);
    await sharedPreferences.setString("ipv6-mode", "ipv4_only");
    await sharedPreferences.setString("remote-dns-domain-strategy", "ipv4_only");
    await sharedPreferences.setString("direct-dns-domain-strategy", "ipv4_only");
    await sharedPreferences.setBool("bypass-lan", false);
    await sharedPreferences.setBool("allow-connection-from-lan", false);
    await sharedPreferences.setBool("block-ads", false);
    await sharedPreferences.setBool("resolve-destination", LockedCoreConfig.resolveDestination);
  }
}

class ConsumerConfigSchemaMigration extends PreferencesMigrationStep with InfraLogger {
  ConsumerConfigSchemaMigration(super.sharedPreferences);

  static const _preservedKeyFragments = [
    'authdata',
    'auth_data',
    'subscribetoken',
    'subscribe_token',
    'selectednodeid',
    'selected_node_id',
    'nodelist',
    'node_list',
  ];

  static const _unsafeExactKeys = {
    'dnsMode',
    'dns-mode',
    'dns_mode',
    'routeMode',
    'route-mode',
    'route_mode',
    'customConfig',
    'custom-config',
    'custom_config',
    'fake-ip',
    'fake_ip',
    'fakeip',
    'fake-ip-range',
    'fakeIpRange',
    'fake_ip_range',
    'enhanced-mode',
    'enhancedMode',
    'enhanced_mode',
    'enable-dns-routing',
    'enable_dns_routing',
    'route-rules',
    'route_rules',
    'rules',
    'ipv6',
    'ipv6-mode',
    'ipv6Mode',
    'enable-ipv6',
    'enable_ipv6',
    'tunSettings',
    'tun-settings',
    'tun_settings',
    'tun-implementation',
    'tunImplementation',
    'tun_implementation',
    'mixedPort',
    'mixed-port',
    'mixed_port',
    'tproxy-port',
    'tproxyPort',
    'tproxy_port',
    'direct-port',
    'directPort',
    'direct_port',
    'redirect-port',
    'redirectPort',
    'redirect_port',
    'clash-api-port',
    'clashApiPort',
    'clash_api_port',
    'enable-clash-api',
    'enableClashApi',
    'enable_clash_api',
    'logLevel',
    'log-level',
    'log_level',
    'custom-route',
    'customRoute',
    'custom_route',
    'custom-dns',
    'customDns',
    'custom_dns',
  };

  @override
  Future<void> migrate() async {
    final storedVersion = sharedPreferences.getInt(LockedCoreConfig.schemaVersionKey) ?? 0;
    final shouldRunSchemaCleanup = storedVersion < LockedCoreConfig.schemaVersion;

    if (shouldRunSchemaCleanup) {
      loggy.debug("migrating core config schema from v[$storedVersion] to v[${LockedCoreConfig.schemaVersion}]");
      await _removeUnsafeAdvancedPreferences(removeValueMarkers: true);
      await sharedPreferences.setInt(LockedCoreConfig.schemaVersionKey, LockedCoreConfig.schemaVersion);
    } else {
      loggy.debug("core config schema already v${LockedCoreConfig.schemaVersion}");
      await _removeUnsafeAdvancedPreferences(removeValueMarkers: false);
    }

    await _writeLockedConsumerPreferences();
    loggy.debug(
      'core config schema enforced: '
      'fakeIp=${LockedCoreConfig.fakeIp}, '
      'ipv6=${LockedCoreConfig.ipv6}, '
      'dnsStrategy=${LockedCoreConfig.dnsStrategy}, '
      'routeFinal=${LockedCoreConfig.routeFinal}, '
      'coreConfigVersion=${LockedCoreConfig.schemaVersion}',
    );
  }

  Future<void> _removeUnsafeAdvancedPreferences({required bool removeValueMarkers}) async {
    final removed = <String>[];
    for (final key in sharedPreferences.getKeys().toList(growable: false)) {
      if (_isPreservedKey(key)) continue;
      if (_isUnsafeKey(key) || (removeValueMarkers && _containsUnsafeMarker(sharedPreferences.get(key)))) {
        await sharedPreferences.remove(key);
        removed.add(key);
      }
    }
    if (removed.isNotEmpty) {
      loggy.debug("removed locked core config prefs: ${removed.map(_sanitizeKeyForLog).join(',')}");
    }
  }

  Future<void> _writeLockedConsumerPreferences() async {
    await sharedPreferences.setBool("intro_completed", true);
    await sharedPreferences.setBool("enable-fake-dns", LockedCoreConfig.fakeIp);
    await sharedPreferences.setString("ipv6-mode", LockedCoreConfig.dnsStrategy);
    await sharedPreferences.setString("remote-dns-domain-strategy", LockedCoreConfig.dnsStrategy);
    await sharedPreferences.setString("direct-dns-domain-strategy", LockedCoreConfig.dnsStrategy);
    await sharedPreferences.setBool("bypass-lan", false);
    await sharedPreferences.setBool("allow-connection-from-lan", false);
    await sharedPreferences.setBool("block-ads", false);
    await sharedPreferences.setBool("resolve-destination", LockedCoreConfig.resolveDestination);
  }

  static bool _isUnsafeKey(String key) {
    if (_unsafeExactKeys.contains(key)) return true;
    final normalized = _normalizeKey(key);
    return normalized.contains('fakeip') ||
        normalized.contains('19818') ||
        normalized.contains('enhancedmode') ||
        normalized.contains('routemode') ||
        normalized.contains('dnsmode') ||
        normalized.contains('customconfig') ||
        normalized.contains('tunsettings') ||
        normalized == 'ipv6' ||
        normalized == 'enableipv6';
  }

  static bool _isPreservedKey(String key) {
    final normalized = _normalizeKey(key);
    return _preservedKeyFragments.any((fragment) => normalized.contains(fragment));
  }

  static bool _containsUnsafeMarker(Object? value) {
    if (value == null) return false;
    if (value is Iterable && value is! String) return value.any(_containsUnsafeMarker);
    final lower = value.toString().toLowerCase();
    return lower.contains('fake-ip') ||
        lower.contains('fake_ip') ||
        lower.contains('fakeip') ||
        lower.contains('enhanced-mode') ||
        lower.contains('enhanced_mode') ||
        lower.contains('198.18.') ||
        lower.contains('198.19.');
  }

  static String _normalizeKey(String value) => value.toLowerCase().replaceAll(RegExp('[-_\\.]'), '');

  static String _sanitizeKeyForLog(String value) {
    if (value.length <= 48) return value;
    return '${value.substring(0, 48)}…';
  }
}
