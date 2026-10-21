import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:adaptive_vpn/src/services/rule_set_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('accepts a same-origin, hashed, Ed25519-signed rule set', () async {
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final payload = utf8.encode(
      jsonEncode({
        'domains': ['Blocked.Example', 'video.example', 'blocked.example'],
      }),
    );
    final signature = await algorithm.sign(payload, keyPair: keyPair);
    final manifest = jsonEncode({
      'version': 2,
      'data_url': '/rules-v2.json',
      'sha256': sha256.convert(payload).toString(),
      'signature': base64Encode(signature.bytes),
    });
    final service = RuleSetService(
      client: MockClient((request) async {
        if (request.url.path == '/manifest.json') {
          return http.Response(manifest, 200, request: request);
        }
        return http.Response.bytes(payload, 200, request: request);
      }),
    );

    final result = await service.update(
      manifestURL: 'https://rules.example/manifest.json',
      publicKeyBase64: base64Encode(publicKey.bytes),
      currentVersion: 1,
    );

    expect(result.version, 2);
    expect(result.domains, ['blocked.example', 'video.example']);
    service.close();
  });

  test(
    'rejects stale manifests, cross-origin data, and bad signatures',
    () async {
      final algorithm = Ed25519();
      final keyPair = await algorithm.newKeyPair();
      final publicKey = await keyPair.extractPublicKey();
      final payload = utf8.encode(
        jsonEncode({
          'domains': ['blocked.example'],
        }),
      );
      final signature = await algorithm.sign(payload, keyPair: keyPair);

      Future<void> expectManifestFailure(Map<String, Object?> manifest) async {
        final service = RuleSetService(
          client: MockClient((request) async {
            if (request.url.path == '/manifest.json') {
              return http.Response(jsonEncode(manifest), 200, request: request);
            }
            return http.Response.bytes(payload, 200, request: request);
          }),
        );
        await expectLater(
          service.update(
            manifestURL: 'https://rules.example/manifest.json',
            publicKeyBase64: base64Encode(publicKey.bytes),
            currentVersion: 1,
          ),
          throwsFormatException,
        );
        service.close();
      }

      await expectManifestFailure({
        'version': 1,
        'data_url': '/rules.json',
        'sha256': sha256.convert(payload).toString(),
        'signature': base64Encode(signature.bytes),
      });
      await expectManifestFailure({
        'version': 2,
        'data_url': 'https://other.example/rules.json',
        'sha256': sha256.convert(payload).toString(),
        'signature': base64Encode(signature.bytes),
      });
      await expectManifestFailure({
        'version': 2,
        'data_url': '/rules.json',
        'sha256': sha256.convert(payload).toString(),
        'signature': base64Encode(List<int>.filled(64, 0)),
      });
    },
  );
}
