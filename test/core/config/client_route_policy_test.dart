import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/config/client_route_policy.dart';
import 'package:hiddify/singbox/model/singbox_rule.dart';

void main() {
  group('ClientRoutePolicy', () {
    test('smart mode injects explicit bypass rules for known local routes only', () {
      final rules = ClientRoutePolicy.rulesFor(globalRouteMode: false);

      expect(rules, hasLength(1));
      expect(rules.single.outbound, RuleOutbound.bypass);
      expect(rules.single.domains, contains('domain:.cn'));
      expect(rules.single.domains, contains('domain:baidu.com'));
      expect(rules.single.domains, contains('domain:qq.com'));
      expect(rules.single.ip, contains('10.0.0.0/8'));
      expect(rules.single.ip, contains('192.168.0.0/16'));
      expect(rules.single.domains, isNot(contains('geosite:')));
      expect(rules.single.ip, isNot(contains('geoip:')));
    });

    test('global mode injects no bypass rules', () {
      expect(ClientRoutePolicy.rulesFor(globalRouteMode: true), isEmpty);
    });

    test('locked rules reject profile override route changes', () {
      const injected = SingboxRule(domains: 'domain:example.com', outbound: RuleOutbound.bypass);

      expect(ClientRoutePolicy.lockedRules([...ClientRoutePolicy.smartRules, injected]), ClientRoutePolicy.smartRules);
    });
  });
}
