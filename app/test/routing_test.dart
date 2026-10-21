import 'package:adaptive_vpn/src/models/routing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RoutingPolicy', () {
    test('uses safe direct-by-default precedence', () {
      final policy = RoutingPolicy(
        manualDirect: ['safe.example'],
        manualProxy: ['forced.example'],
        knownBlocked: ['blocked.example'],
        learnedBlocked: ['learned.example'],
      );

      expect(
        policy.decide('https://api.safe.example/path').reason,
        RouteReason.manualDirect,
      );
      expect(policy.decide('forced.example').reason, RouteReason.manualProxy);
      expect(
        policy.decide('learned.example').reason,
        RouteReason.learnedBlocked,
      );
      expect(policy.decide('blocked.example').reason, RouteReason.knownBlocked);
      expect(
        policy.decide('unknown.example').reason,
        RouteReason.defaultDirect,
      );
    });

    test('normalizes rules and matches only domain boundaries', () {
      final policy = RoutingPolicy();
      expect(
        policy.addRule(RouteTarget.proxy, 'HTTPS://Example.COM/path'),
        true,
      );
      expect(policy.manualProxy, ['example.com']);
      expect(policy.decide('api.example.com').target, RouteTarget.proxy);
      expect(policy.decide('notexample.com').target, RouteTarget.direct);
    });
  });
}
