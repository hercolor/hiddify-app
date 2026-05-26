import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/singbox/model/singbox_rule.dart';

void main() {
  group('SingboxRule JSON', () {
    test('emits matcher fields as arrays for hiddify-core settings import', () {
      const rule = SingboxRule(
        domains: 'domain:cn, domain:.cn',
        ip: '10.0.0.0/8,172.16.0.0/12',
        port: '53, 853',
        protocol: 'dns',
        outbound: RuleOutbound.bypass,
      );

      final json = rule.toJson();

      expect(json['domains'], ['domain:cn', 'domain:.cn']);
      expect(json['ip'], ['10.0.0.0/8', '172.16.0.0/12']);
      expect(json['port'], ['53', '853']);
      expect(json['protocol'], ['dns']);
      expect(json['network'], 'all');
      expect(json['outbound'], 'bypass');
    });

    test('accepts matcher arrays from profile overrides while preserving app model text', () {
      final rule = SingboxRule.fromJson({
        'domains': ['domain:cn', 'domain:.cn'],
        'ip': ['10.0.0.0/8', '172.16.0.0/12'],
        'port': ['53', '853'],
        'protocol': ['dns'],
        'network': 'all',
        'outbound': 'bypass',
      });

      expect(rule.domains, 'domain:cn,domain:.cn');
      expect(rule.ip, '10.0.0.0/8,172.16.0.0/12');
      expect(rule.port, '53,853');
      expect(rule.protocol, 'dns');
      expect(rule.network, RuleNetwork.tcpAndUdp);
      expect(rule.outbound, RuleOutbound.bypass);
    });
  });
}
