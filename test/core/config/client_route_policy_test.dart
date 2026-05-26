import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/config/client_route_policy.dart';
import 'package:hiddify/singbox/model/singbox_rule.dart';

void main() {
  group('ClientRoutePolicy', () {
    test('smart mode injects locked bypass rules for domestic traffic', () {
      final rules = ClientRoutePolicy.rulesFor(globalRouteMode: false);

      expect(rules, ClientRoutePolicy.smartRules);
      expect(rules, isNotEmpty);
      expect(rules.first.domains, contains('domain:baidu.com'));
      expect(rules.first.outbound, RuleOutbound.bypass);
    });

    test('global mode injects no bypass rules', () {
      expect(ClientRoutePolicy.rulesFor(globalRouteMode: true), isEmpty);
    });

    test('locked rules keep only app-owned smart rules and reject profile override route changes', () {
      const injected = SingboxRule(domains: 'domain:example.com', outbound: RuleOutbound.bypass);

      expect(ClientRoutePolicy.lockedRules([...ClientRoutePolicy.smartRules, injected]), ClientRoutePolicy.smartRules);
    });
  });
}
