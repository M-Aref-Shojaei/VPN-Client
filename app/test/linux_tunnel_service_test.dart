import 'dart:convert';

import 'package:adaptive_vpn/src/services/tunnel_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('capability reports verified process adapter state', () async {
    final runner = _FakeRunner(
      response: const ControlProcessResult(
        exitCode: 0,
        stdout: '{"available":true,"running":true,"message":"Verified core."}',
        stderr: '',
      ),
    );
    final service = LinuxProcessTunnelService(
      controlPath: '/test/routerctl',
      runner: runner,
    );

    final capability = await service.capability();

    expect(capability.available, isTrue);
    expect(capability.running, isTrue);
    expect(runner.arguments, ['capability']);
  });

  test(
    'Windows adapter uses the same credential-safe desktop contract',
    () async {
      final runner = _FakeRunner(
        response: const ControlProcessResult(
          exitCode: 0,
          stdout: '{"available":true,"running":false,"message":"Ready."}',
          stderr: '',
        ),
      );
      final service = WindowsProcessTunnelService(
        controlPath: r'C:\Program Files\Adaptive VPN\routerctl.exe',
        runner: runner,
      );

      final capability = await service.capability();

      expect(capability.available, isTrue);
      expect(runner.arguments, ['capability']);
    },
  );

  test('connect sends credentials through stdin and never arguments', () async {
    final runner = _FakeRunner(
      response: const ControlProcessResult(
        exitCode: 0,
        stdout: '{"running":true}',
        stderr: '',
      ),
    );
    final service = LinuxProcessTunnelService(
      controlPath: '/test/routerctl',
      runner: runner,
    );

    await service.connect(
      profile: const {
        'type': 'vless',
        'server': 'example.invalid',
        'uuid': 'secret-credential',
      },
      policy: const {
        'manual_direct': ['local.example'],
        'manual_proxy': <String>[],
        'known_blocked': <String>[],
      },
    );

    expect(runner.arguments, ['start']);
    expect(runner.arguments.join(' '), isNot(contains('secret-credential')));
    final request = jsonDecode(runner.stdinText!) as Map<String, Object?>;
    final profile = request['profile'] as Map<String, Object?>;
    expect(profile['uuid'], 'secret-credential');
    expect(request['tun'], isTrue);
  });

  test('non-zero exit is returned as a readable failure', () async {
    final service = LinuxProcessTunnelService(
      controlPath: '/test/routerctl',
      runner: _FakeRunner(
        response: const ControlProcessResult(
          exitCode: 1,
          stdout: '',
          stderr: 'permission is required',
        ),
      ),
    );

    await expectLater(
      service.disconnect(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'permission is required',
        ),
      ),
    );
  });

  test('probe uses a normalized argument-only control request', () async {
    final runner = _FakeRunner(
      response: const ControlProcessResult(
        exitCode: 0,
        stdout:
            '{"direct_succeeded":false,"proxy_attempted":true,'
            '"proxy_succeeded":true,"learned":true,"message":"Learned."}',
        stderr: '',
      ),
    );
    final service = LinuxProcessTunnelService(
      controlPath: '/test/routerctl',
      runner: runner,
    );

    final result = await service.probe(domain: 'blocked.example');

    expect(result.learned, isTrue);
    expect(
      runner.arguments,
      containsAllInOrder(['probe', '-domain', 'blocked.example']),
    );
    expect(runner.stdinText, isNull);
  });
}

class _FakeRunner implements ControlProcessRunner {
  _FakeRunner({required this.response});

  final ControlProcessResult response;
  List<String> arguments = const [];
  String? stdinText;

  @override
  Future<ControlProcessResult> run(
    String executable,
    List<String> arguments, {
    String? stdinText,
  }) async {
    this.arguments = List.of(arguments);
    this.stdinText = stdinText;
    return response;
  }
}
