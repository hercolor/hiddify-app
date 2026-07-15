import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/http_client/dio_http_client.dart';
import 'package:hiddify/features/diagnostics/diagnostics_probe.dart';

void main() {
  test('runs route direct and proxy probes for each target', () async {
    final client = _FakeProbeClient();
    final results = await DiagnosticsProbeService(client).run();

    expect(results, hasLength(15));
    expect(client.requests, hasLength(15));
    expect(client.requests.take(3).map((request) => (proxyOnly: request.proxyOnly, directOnly: request.directOnly)), [
      (proxyOnly: true, directOnly: false),
      (proxyOnly: false, directOnly: true),
      (proxyOnly: true, directOnly: false),
    ]);
    expect(results.where((result) => result.ok), hasLength(15));

    final routeResults = results.where((result) => result.mode == 'route').toList();
    final directResults = results.where((result) => result.mode == 'direct').toList();
    final proxyResults = results.where((result) => result.mode == 'proxy').toList();

    expect(routeResults, hasLength(5));
    expect(directResults, hasLength(5));
    expect(proxyResults, hasLength(5));
    expect(routeResults.first.label, 'SKK home');
    expect(routeResults.first.summary, contains('contentType=application/json'));
    expect(routeResults.first.summary, contains('actualMode=route'));
    expect(routeResults.first.summary, contains('viaCoreProxy=localhost:unset'));
    expect(routeResults.first.summary, contains('noDirectFallback=true'));
    expect(routeResults.first.summary, contains('policyTrace=expectedProxy:domain_suffix:api.skk.moe'));
    expect(routeResults.first.summary, contains('country=HK'));
    expect(directResults.first.summary, contains('actualMode=forcedDirect'));
    expect(directResults.first.summary, contains('policyApplied=false'));
    expect(directResults.first.summary, contains('policyTrace=expectedProxy:domain_suffix:api.skk.moe'));
    expect(directResults.first.summary, contains('country=CN'));
    expect(proxyResults.first.summary, contains('actualMode=coreOnly'));
    expect(proxyResults.first.summary, contains('policyApplied=false'));
    expect(proxyResults.first.summary, contains('policyTrace=expectedProxy:domain_suffix:api.skk.moe'));
    expect(proxyResults.first.summary, contains('country=HK'));
    expect(results.last.label, 'CN ip.cn');
    expect(results.last.mode, 'proxy');
  });

  test('explains expected proxy overrides for public IP probe hosts', () {
    expect(DiagnosticsRouteTrace('2026.ip138.com').matcher, 'domain_suffix:ip138.com');
    expect(DiagnosticsRouteTrace('my.ip.cn').matcher, 'domain_suffix:ip.cn');
    expect(DiagnosticsRouteTrace('ip.api.skk.moe').matcher, 'domain_suffix:api.skk.moe');
    expect(DiagnosticsRouteTrace('ip.api.skk.moe').matched, isFalse);
    expect(DiagnosticsRouteTrace('unknown.example').matched, isFalse);
  });
}

class _FakeProbeClient extends DioHttpClient {
  _FakeProbeClient() : super(timeout: const Duration(seconds: 1), userAgent: 'test-agent', debug: false);

  final List<String> modes = [];
  final List<({bool proxyOnly, bool directOnly})> requests = [];

  @override
  Future<Response<T>> get<T>(
    String url, {
    CancelToken? cancelToken,
    String? userAgent,
    ({String username, String password})? credentials,
    Map<String, dynamic>? headers,
    bool proxyOnly = false,
    bool directOnly = false,
  }) async {
    requests.add((proxyOnly: proxyOnly, directOnly: directOnly));
    final mode = directOnly
        ? 'direct'
        : proxyOnly
        ? 'core'
        : 'fallback';
    modes.add(mode);
    final host = Uri.parse(url).host;
    final data =
        switch (host) {
              'ipv4-ip.api.skk.moe' => {
                'ip': mode == 'direct' ? '171.211.0.1' : '202.60.0.1',
                'country': mode == 'direct' ? 'CN' : 'HK',
              },
              'ip.api.skk.moe' => {
                'data': {
                  'ip': mode == 'direct' ? '171.211.0.1' : '202.60.0.1',
                  'country': mode == 'direct' ? 'CN' : 'HK',
                },
              },
              '2026.ip138.com' => {
                'ip': mode == 'direct' ? '171.211.0.1' : '202.60.0.1',
                'country': mode == 'direct' ? 'CN' : 'HK',
              },
              'my.ip.cn' => {
                'ip': mode == 'direct' ? '171.211.0.1' : '202.60.0.1',
                'country': mode == 'direct' ? 'CN' : 'HK',
              },
              _ => {'ip': mode == 'direct' ? '171.211.0.1' : '202.60.0.1', 'country': mode == 'direct' ? 'CN' : 'HK'},
            }
            as T;
    return Response<T>(
      data: data,
      statusCode: 200,
      headers: Headers.fromMap({
        'content-type': ['application/json'],
        'server': ['test-server'],
      }),
      requestOptions: RequestOptions(path: url),
    );
  }
}
