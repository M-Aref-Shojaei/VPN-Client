import 'package:adaptive_vpn/src/models/profile.dart';
import 'package:adaptive_vpn/src/models/subscription.dart';
import 'package:adaptive_vpn/src/services/profile_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'memory store validates and round trips the versioned snapshot',
    () async {
      final profile = VpnProfile.fromInput(
        'trojan://password@example.com:443#Example',
      );
      final store = MemoryProfileStore();
      await store.save(
        ProfileSnapshot(
          profiles: [profile],
          activeProfileID: profile.id,
          manualDirect: const ['localhost'],
          manualProxy: const ['blocked.example'],
          knownBlocked: const [],
          subscriptions: [
            VpnSubscription(
              id: 'subscription-1',
              name: 'Example',
              url: Uri.parse('https://profiles.example/list'),
              profileIDs: [profile.id],
              updatedAt: DateTime.utc(2026, 7, 19),
            ),
          ],
          ruleSet: null,
        ),
      );

      final restored = await store.load();

      expect(restored.profiles.single.outbound, profile.outbound);
      expect(restored.activeProfileID, profile.id);
      expect(restored.manualProxy, ['blocked.example']);
      expect(restored.subscriptions.single.profileIDs, [profile.id]);
    },
  );
}
