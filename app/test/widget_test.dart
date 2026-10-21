import 'package:adaptive_vpn/src/app.dart';
import 'package:adaptive_vpn/src/services/tunnel_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows direct-by-default connection overview', (tester) async {
    await tester.pumpWidget(
      AdaptiveVpnApp(tunnelService: _FakeTunnelService()),
    );
    await tester.pump();

    expect(find.text('Adaptive VPN'), findsOneWidget);
    expect(find.text('Disconnected'), findsOneWidget);
    expect(find.text('Direct'), findsOneWidget);
    expect(find.text('Tunnel adapter ready'), findsOneWidget);
  });

  testWidgets('imports and selects a profile', (tester) async {
    await tester.pumpWidget(
      AdaptiveVpnApp(tunnelService: _FakeTunnelService()),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.dns_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      '{"id":"test","name":"Test profile","outbound":{"type":"vless","server":"example.invalid"}}',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Import'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test profile'), findsOneWidget);
    expect(find.text('VLESS'), findsOneWidget);
  });
}

class _FakeTunnelService implements TunnelService {
  @override
  Future<TunnelCapability> capability() async {
    return const TunnelCapability(available: true, message: 'Ready for tests.');
  }

  @override
  Future<void> connect({
    required Map<String, Object?> profile,
    required Map<String, Object?> policy,
  }) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<RouteProbeResult> probe({
    required String domain,
    int port = 443,
    bool useTLS = true,
  }) async {
    return const RouteProbeResult(
      directSucceeded: true,
      proxyAttempted: false,
      proxySucceeded: false,
      learned: false,
      message: 'Direct path succeeded.',
    );
  }
}
