import 'dart:async';

import 'package:dio/dio.dart';
import 'package:hiddify/core/config/client_route_policy.dart';
import 'package:hiddify/core/http_client/dio_http_client.dart';
import 'package:hiddify/core/http_client/http_client_provider.dart';
import 'package:hiddify/features/diagnostics/diagnostic_event_buffer.dart';
import 'package:hiddify/features/diagnostics/diagnostic_sanitizer.dart';
import 'package:hiddify/features/profile/data/final_config_guard.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/data/client_node_store.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final diagnosticsProbeProvider = StateNotifierProvider<DiagnosticsProbeNotifier, AsyncValue<List<DiagProbeResult>>>(
  (ref) => DiagnosticsProbeNotifier(ref),
);

class DiagnosticsProbeNotifier extends StateNotifier<AsyncValue<List<DiagProbeResult>>> {
  DiagnosticsProbeNotifier(this._ref) : super(const AsyncData([]));

  final Ref _ref;

  DioHttpClient get _client => _ref.read(httpClientProvider);

  Future<List<DiagProbeResult>> run() async {
    state = const AsyncLoading();
    DiagnosticEventBuffer.add('diagProbe start');
    await _emitActiveFinalConfigSnapshot();
    final results = await DiagnosticsProbeService(_client).run();
    state = AsyncData(results);
    for (final result in results) {
      DiagnosticEventBuffer.addSafe(result.toDiagnosticLine());
    }
    return results;
  }

  Future<void> _emitActiveFinalConfigSnapshot() async {
    try {
      final profile = await _ref.read(activeProfileProvider.future);
      if (profile == null) {
        DiagnosticEventBuffer.add('probe final config: no active profile');
        return;
      }
      final file = _ref.read(profilePathResolverProvider).file(profile.id);
      if (!await file.exists()) {
        DiagnosticEventBuffer.add('probe final config: missing file profile=${profile.name}');
        return;
      }
      final selection =
          _ref.read(clientNodeSelectionProvider).valueOrNull ??
          await _ref.read(clientNodeSelectionProvider.notifier).ensureLoaded();
      final result = const FinalConfigGuard().inspectAndSanitizeContent(
        await file.readAsString(),
        globalRouteMode: _ref.read(ConfigOptions.globalRouteMode),
        selectedOutboundTag: selection.selectedNode?.id,
      );
      DiagnosticEventBuffer.add(
        'probe final config check: parsedJson=${result.parsedJson}, sanitized=${result.changed}, '
        'routeFinal=${result.routeFinal}, routeRules=${result.routeRuleCount}, '
        'routeDefaultDomainResolver=${result.routeDefaultDomainResolver}, dnsReverseMapping=${result.dnsReverseMapping}, '
        'dnsServers=${result.dnsServerCount}, coreLogLevel=${result.coreLogLevel}, fakeIpAfter=${result.fakeIpAfter}',
      );
      DiagnosticEventBuffer.add('probe final config route rules: ${result.routeRuleSummary.join(' ; ')}');
      DiagnosticEventBuffer.add('probe final config dns servers: ${result.dnsServerSummary.join(' ; ')}');
      DiagnosticEventBuffer.add('probe final config dns rules: ${result.dnsRuleSummary.join(' ; ')}');
      DiagnosticEventBuffer.add('probe final config rule sets: ${result.routeRuleSetSummary.join(' ; ')}');
      DiagnosticEventBuffer.add('probe final config inbounds: ${result.inboundSummary.join(' ; ')}');
      DiagnosticEventBuffer.add('probe final config outbounds: ${result.outboundTags.join(' | ')}');
    } catch (error) {
      DiagnosticEventBuffer.add('probe final config error=$error');
    }
  }
}

class DiagnosticsProbeService {
  DiagnosticsProbeService(this._client);

  final DioHttpClient _client;

  static const targets = [
    DiagProbeTarget(label: 'SKK home', url: 'https://ipv4-ip.api.skk.moe/v1/home'),
    DiagProbeTarget(label: 'SKK simple', url: 'https://ip.api.skk.moe/v1/ipinfo-simple'),
    DiagProbeTarget(label: 'SKK cf geoip', url: 'https://ip.api.skk.moe/cf-geoip'),
    DiagProbeTarget(label: 'CN ip138', url: 'https://2026.ip138.com/'),
    DiagProbeTarget(label: 'CN ip.cn', url: 'https://my.ip.cn/'),
  ];

  Future<List<DiagProbeResult>> run() async {
    final results = <DiagProbeResult>[];
    for (final target in targets) {
      results
        ..add(await _probe(target, DiagProbeMode.route))
        ..add(await _probe(target, DiagProbeMode.direct))
        ..add(await _probe(target, DiagProbeMode.proxy));
    }
    return results;
  }

  Future<DiagProbeResult> _probe(DiagProbeTarget target, DiagProbeMode mode) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _client
          .get<Object>(
            target.url,
            proxyOnly: mode == DiagProbeMode.route || mode == DiagProbeMode.proxy,
            directOnly: mode == DiagProbeMode.direct,
            headers: const {'Accept': 'application/json,text/plain,text/html;q=0.8,*/*;q=0.5'},
          )
          .timeout(const Duration(seconds: 12));
      stopwatch.stop();
      final host = Uri.parse(target.url).host;
      return DiagProbeResult(
        label: target.label,
        urlHost: host,
        mode: mode.name,
        ok: true,
        statusCode: response.statusCode,
        elapsedMs: stopwatch.elapsedMilliseconds,
        summary: '${_modeTrace(mode, host, _client)} ${_summarizeResponse(target.url, response)}',
      );
    } catch (error) {
      stopwatch.stop();
      final host = Uri.parse(target.url).host;
      return DiagProbeResult(
        label: target.label,
        urlHost: host,
        mode: mode.name,
        ok: false,
        statusCode: error is DioException ? error.response?.statusCode : null,
        elapsedMs: stopwatch.elapsedMilliseconds,
        summary: '${_modeTrace(mode, host, _client)} ${_summarizeError(error)}',
      );
    }
  }

  static String _modeTrace(DiagProbeMode mode, String host, DioHttpClient client) {
    final policyTrace = _policyTrace(host);
    return switch (mode) {
      DiagProbeMode.route =>
        'actualMode=route viaCoreProxy=${client.diagnosticRouteProxyEndpoint} noDirectFallback=true policyTrace=$policyTrace actualExit=body-ip',
      DiagProbeMode.direct => 'actualMode=forcedDirect policyApplied=false policyTrace=$policyTrace actualExit=body-ip',
      DiagProbeMode.proxy =>
        'actualMode=coreOnly viaCoreProxy=${client.diagnosticRouteProxyEndpoint} policyApplied=false policyTrace=$policyTrace actualExit=body-ip',
    };
  }

  static String _policyTrace(String host) {
    final trace = DiagnosticsRouteTrace(host);
    return trace.matched ? 'expectedDirect:${trace.matcher}' : 'expectedProxy:final';
  }

  static String _summarizeResponse(String url, Response<Object> response) {
    final type = response.headers.value('content-type') ?? 'unknown';
    final server = response.headers.value('server');
    final body = _extractBodySignal(Uri.parse(url), response.data);
    return DiagnosticSanitizer.sanitize(
      'status=${response.statusCode} contentType=$type${server == null ? '' : ' server=$server'} body=$body',
    );
  }

  static String _extractBodySignal(Uri uri, Object? data) {
    final fields = switch (data) {
      final Map value => value.map((key, value) => MapEntry(key.toString(), value)),
      _ => null,
    };
    if (fields != null) {
      final normalized = _normalizeJsonSignal(uri, fields);
      if (normalized.isNotEmpty) return _truncate(normalized);
    }
    final raw = switch (data) {
      final Map value => value.entries.take(8).map((entry) => '${entry.key}=${entry.value}').join(', '),
      final List value => value.take(8).join(', '),
      null => '',
      _ => data.toString(),
    };
    final normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return '<empty>';
    return _truncate(normalized);
  }

  static String _normalizeJsonSignal(Uri uri, Map<String, Object?> fields) {
    final pieces = <String>[];
    for (final key in const [
      'ip',
      'country',
      'countryCode',
      'city',
      'region',
      'org',
      'asn',
      'hostname',
      'colo',
      'regionCode',
    ]) {
      final value = fields[key];
      if (value != null && value.toString().isNotEmpty) pieces.add('$key=$value');
    }
    if (uri.host.contains('skk.moe')) {
      for (final key in const ['ip', 'country', 'region', 'city', 'regionName', 'countryCode', 'as', 'asn', 'query']) {
        final value = fields[key];
        if (value != null && value.toString().isNotEmpty) pieces.add('$key=$value');
      }
      for (final nestedKey in const ['data', 'geo', 'ipinfo']) {
        final nested = fields[nestedKey];
        if (nested is Map) {
          final nestedMap = nested.map((key, value) => MapEntry(key.toString(), value));
          pieces.add(_normalizeJsonSignal(uri, nestedMap));
        }
      }
    }
    return pieces.where((e) => e.isNotEmpty).join(', ');
  }

  static String _truncate(String value) {
    if (value.length <= 220) return value;
    return '${value.substring(0, 219)}…';
  }

  static String _summarizeError(Object error) {
    if (error is DioException) {
      final message = error.message ?? error.error?.toString() ?? error.type.name;
      return DiagnosticSanitizer.sanitize(
        'dio=${error.type.name} status=${error.response?.statusCode ?? '--'} message=$message',
      );
    }
    if (error is TimeoutException) return 'timeout';
    return DiagnosticSanitizer.sanitize(error.toString());
  }
}

class DiagnosticsRouteTrace {
  factory DiagnosticsRouteTrace(String host) {
    final normalized = host.toLowerCase().trim();
    for (final domain in ClientRoutePolicy.cnBypassExactDomains) {
      if (normalized == domain) {
        return DiagnosticsRouteTrace._(host: host, matched: true, matcher: 'domain:$domain');
      }
    }
    for (final suffix in ClientRoutePolicy.cnBypassDomainSuffixes) {
      final normalizedSuffix = suffix.toLowerCase().trim();
      if (normalized == normalizedSuffix || normalized.endsWith('.$normalizedSuffix')) {
        return DiagnosticsRouteTrace._(host: host, matched: true, matcher: 'domain_suffix:$suffix');
      }
    }
    for (final keyword in ClientRoutePolicy.cnBypassDomainKeywords) {
      if (normalized.contains(keyword.toLowerCase().trim())) {
        return DiagnosticsRouteTrace._(host: host, matched: true, matcher: 'domain_keyword:$keyword');
      }
    }
    return DiagnosticsRouteTrace._(host: host, matched: false, matcher: 'final:proxy');
  }

  const DiagnosticsRouteTrace._({required this.host, required this.matched, required this.matcher});

  final String host;
  final bool matched;
  final String matcher;
}

class DiagProbeTarget {
  const DiagProbeTarget({required this.label, required this.url});

  final String label;
  final String url;
}

enum DiagProbeMode { route, direct, proxy }

class DiagProbeResult {
  const DiagProbeResult({
    required this.label,
    required this.urlHost,
    required this.mode,
    required this.ok,
    required this.statusCode,
    required this.elapsedMs,
    required this.summary,
  });

  final String label;
  final String urlHost;
  final String mode;
  final bool ok;
  final int? statusCode;
  final int elapsedMs;
  final String summary;

  String toDiagnosticLine() => DiagnosticSanitizer.sanitize(
    'diagProbe label=$label host=$urlHost mode=$mode ok=$ok status=${statusCode ?? '--'} elapsedMs=$elapsedMs summary=$summary',
  );
}
