import 'dart:convert';

import 'package:adaptive_vpn/src/services/subscription_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('loads a bounded HTTPS base64 link subscription', () async {
    const links =
        'trojan://password@one.example:443#One\n'
        'ssh://user:password@two.example:22#Two\n';
    final service = SubscriptionService(
      client: MockClient(
        (request) async => http.Response.bytes(
          base64Encode(utf8.encode(links)).codeUnits,
          200,
          request: request,
        ),
      ),
    );

    final result = await service.fetch('https://profiles.example/list');

    expect(result.profiles, hasLength(2));
    expect(result.profiles.map((profile) => profile.outboundType), [
      'trojan',
      'ssh',
    ]);
    service.close();
  });

  test('loads JSON profile envelopes', () async {
    final body = jsonEncode({
      'profiles': [
        {
          'id': 'json-profile',
          'name': 'JSON',
          'outbound': {
            'type': 'vless',
            'server': 'example.invalid',
            'server_port': 443,
            'uuid': '00000000-0000-0000-0000-000000000000',
          },
        },
      ],
    });
    final service = SubscriptionService(
      client: MockClient(
        (request) async => http.Response(body, 200, request: request),
      ),
    );

    final result = await service.fetch('https://profiles.example/list.json');

    expect(result.profiles.single.id, 'json-profile');
    service.close();
  });

  test('rejects insecure URLs, oversized bodies, and bad status', () async {
    final unused = SubscriptionService(
      client: MockClient((request) async => http.Response('', 200)),
    );
    await expectLater(
      unused.fetch('http://profiles.example/list'),
      throwsFormatException,
    );
    unused.close();

    final oversized = SubscriptionService(
      client: MockClient(
        (request) async => http.Response.bytes(
          const [],
          200,
          headers: {'content-length': '${3 * 1024 * 1024}'},
          request: request,
        ),
      ),
    );
    await expectLater(
      oversized.fetch('https://profiles.example/list'),
      throwsFormatException,
    );
    oversized.close();

    final failed = SubscriptionService(
      client: MockClient(
        (request) async => http.Response('', 503, request: request),
      ),
    );
    await expectLater(
      failed.fetch('https://profiles.example/list'),
      throwsFormatException,
    );
    failed.close();
  });
}
