import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/config/client_route_policy.dart';
import 'package:hiddify/singbox/model/singbox_rule.dart';

void main() {
  group('ClientRoutePolicy', () {
    test('smart mode delegates routing rules to imported subscription config', () {
      final rules = ClientRoutePolicy.rulesFor(globalRouteMode: false);

      expect(rules, isEmpty);
    });

    test('global mode injects no bypass rules', () {
      expect(ClientRoutePolicy.rulesFor(globalRouteMode: true), isEmpty);
    });

    test('locked rules reject profile override route changes', () {
      const injected = SingboxRule(domains: 'domain:example.com', outbound: RuleOutbound.bypass);

      expect(ClientRoutePolicy.lockedRules([...ClientRoutePolicy.smartRules, injected]), isEmpty);
    });
  });
}
