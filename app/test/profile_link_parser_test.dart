import 'dart:convert';

import 'package:adaptive_vpn/src/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProfileLinkParser', () {
    test('parses VLESS Reality and WebSocket options', () {
      final profile = VpnProfile.fromInput(
        'vless://00000000-0000-0000-0000-000000000000@edge.example:443'
        '?security=reality&sni=origin.example&pbk=public-key&sid=abcd'
        '&fp=chrome&type=ws&path=%2Fvpn&host=cdn.example#Home',
      );

      expect(profile.name, 'Home');
      expect(profile.outboundType, 'vless');
      expect(profile.outbound['server_port'], 443);
      final tls = profile.outbound['tls'] as Map<String, Object?>;
      expect(tls['server_name'], 'origin.example');
      expect(tls['reality'], containsPair('public_key', 'public-key'));
      final transport = profile.outbound['transport'] as Map<String, Object?>;
      expect(transport['type'], 'ws');
      expect(transport['path'], '/vpn');
    });

    test('parses VMess base64 JSON', () {
      final payload = base64Url
          .encode(
            utf8.encode(
              jsonEncode({
                'v': '2',
                'ps': 'VMess profile',
                'add': 'vmess.example',
                'port': '443',
                'id': '00000000-0000-0000-0000-000000000000',
                'aid': '0',
                'scy': 'auto',
                'net': 'grpc',
                'path': 'service',
                'tls': 'tls',
                'sni': 'origin.example',
              }),
            ),
          )
          .replaceAll('=', '');

      final profile = VpnProfile.fromInput('vmess://$payload');

      expect(profile.name, 'VMess profile');
      expect(profile.outbound['server'], 'vmess.example');
      expect(
        profile.outbound['transport'],
        containsPair('service_name', 'service'),
      );
    });

    test('parses Trojan, Shadowsocks, Hysteria2, TUIC, WireGuard, and SSH', () {
      final shadowsocksCredentials = base64Url
          .encode(utf8.encode('aes-256-gcm:password'))
          .replaceAll('=', '');
      final cases = <String, String>{
        'trojan://password@trojan.example:443?sni=origin.example#Trojan':
            'trojan',
        'ss://$shadowsocksCredentials@ss.example:8388#Shadowsocks':
            'shadowsocks',
        'hysteria2://password@hy.example:443?sni=origin.example#Hysteria':
            'hysteria2',
        'tuic://00000000-0000-0000-0000-000000000000:password@tuic.example:443?sni=origin.example#TUIC':
            'tuic',
        'wireguard://private-key@wg.example:51820?public_key=public-key'
                '&address=10.0.0.2%2F32&allowed_ips=0.0.0.0%2F0#WireGuard':
            'wireguard',
        'ssh://user:password@ssh.example:22#SSH': 'ssh',
      };

      for (final MapEntry(key: link, value: type) in cases.entries) {
        expect(VpnProfile.fromInput(link).outboundType, type);
      }
    });

    test('rejects unsupported, incomplete, and plugin links', () {
      expect(
        () => VpnProfile.fromInput('ftp://example.com/file'),
        throwsFormatException,
      );
      expect(
        () => VpnProfile.fromInput(
          'vless://00000000-0000-0000-0000-000000000000@example.com',
        ),
        throwsFormatException,
      );
      expect(
        () => VpnProfile.fromInput(
          'ss://YWVzLTI1Ni1nY206cGFzc3dvcmQ@ss.example:8388'
          '?plugin=unsafe',
        ),
        throwsFormatException,
      );
    });

    test('round trips the secure-storage JSON envelope', () {
      final original = VpnProfile.fromInput(
        'trojan://password@example.com:443#Example',
      );
      final restored = VpnProfile.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.outbound, original.outbound);
    });
  });
}
