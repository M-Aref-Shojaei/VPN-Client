import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

enum TunnelStatus { disconnected, connecting, connected, disconnecting }

class RouteProbeResult {
  const RouteProbeResult({
    required this.directSucceeded,
    required this.proxyAttempted,
    required this.proxySucceeded,
    required this.learned,
    required this.message,
  });

  final bool directSucceeded;
  final bool proxyAttempted;
  final bool proxySucceeded;
  final bool learned;
  final String message;
}

class TunnelCapability {
  const TunnelCapability({
    required this.available,
    required this.message,
    this.running = false,
  });

  final bool available;
  final String message;
  final bool running;
}

abstract interface class TunnelService {
  Future<TunnelCapability> capability();
  Future<void> connect({
    required Map<String, Object?> profile,
    required Map<String, Object?> policy,
  });
  Future<void> disconnect();
  Future<RouteProbeResult> probe({
    required String domain,
    int port = 443,
    bool useTLS = true,
  });
}

class MethodChannelTunnelService implements TunnelService {
  static const _channel = MethodChannel('dev.adaptivevpn/tunnel');

  @override
  Future<TunnelCapability> capability() async {
    try {
      final response = await _channel.invokeMapMethod<String, Object?>(
        'capability',
      );
      return TunnelCapability(
        available: response?['available'] == true,
        message:
            response?['message'] as String? ?? 'Tunnel adapter unavailable.',
        running: response?['running'] == true,
      );
    } on MissingPluginException {
      return const TunnelCapability(
        available: false,
        message:
            'This development build has no native tunnel adapter installed.',
      );
    } on PlatformException catch (error) {
      return TunnelCapability(
        available: false,
        message: error.message ?? 'Tunnel adapter check failed.',
      );
    }
  }

  @override
  Future<void> connect({
    required Map<String, Object?> profile,
    required Map<String, Object?> policy,
  }) {
    return _channel.invokeMethod<void>('connect', {
      'profile': profile,
      'policy': policy,
    });
  }

  @override
  Future<void> disconnect() => _channel.invokeMethod<void>('disconnect');

  @override
  Future<RouteProbeResult> probe({
    required String domain,
    int port = 443,
    bool useTLS = true,
  }) async {
    final response = await _channel.invokeMapMethod<String, Object?>('probe', {
      'domain': domain,
      'port': port,
      'tls': useTLS,
    });
    return _decodeProbe(response ?? const {});
  }
}

class ControlProcessResult {
  const ControlProcessResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

abstract interface class ControlProcessRunner {
  Future<ControlProcessResult> run(
    String executable,
    List<String> arguments, {
    String? stdinText,
  });
}

class IoControlProcessRunner implements ControlProcessRunner {
  const IoControlProcessRunner();

  @override
  Future<ControlProcessResult> run(
    String executable,
    List<String> arguments, {
    String? stdinText,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      mode: ProcessStartMode.normal,
      environment: {
        ...Platform.environment,
        'ADAPTIVE_VPN_REQUIRE_SERVICE': '1',
      },
    );
    if (stdinText != null) {
      process.stdin.write(stdinText);
    }
    await process.stdin.close();
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.transform(utf8.decoder).join();
    final results = await Future.wait<Object>([
      process.exitCode,
      output,
      errors,
    ]);
    return ControlProcessResult(
      exitCode: results[0] as int,
      stdout: results[1] as String,
      stderr: results[2] as String,
    );
  }
}

class DesktopProcessTunnelService implements TunnelService {
  DesktopProcessTunnelService({
    required this._controlPath,
    ControlProcessRunner? runner,
  }) : _runner = runner ?? const IoControlProcessRunner();

  final String _controlPath;
  final ControlProcessRunner _runner;

  @override
  Future<TunnelCapability> capability() async {
    if (_controlPath.isEmpty) {
      return const TunnelCapability(
        available: false,
        message:
            'routerctl was not found. Build the Go control binary or set '
            'ADAPTIVE_VPN_ROUTERCTL.',
      );
    }
    try {
      final response = await _runJson(const ['capability']);
      return TunnelCapability(
        available: response['available'] == true,
        message:
            response['message'] as String? ?? 'Tunnel adapter unavailable.',
        running: response['running'] == true,
      );
    } on Object catch (error) {
      return TunnelCapability(
        available: false,
        message: _cleanProcessError(error),
      );
    }
  }

  @override
  Future<void> connect({
    required Map<String, Object?> profile,
    required Map<String, Object?> policy,
  }) async {
    await _runJson(
      const ['start'],
      stdinText: jsonEncode({
        'profile': profile,
        'policy': policy,
        'network': 'unknown',
        'tun': true,
      }),
    );
  }

  @override
  Future<void> disconnect() async {
    await _runJson(const ['stop']);
  }

  @override
  Future<RouteProbeResult> probe({
    required String domain,
    int port = 443,
    bool useTLS = true,
  }) async {
    final response = await _runJson([
      'probe',
      '-domain',
      domain,
      '-port',
      '$port',
      '-tls=$useTLS',
    ]);
    return _decodeProbe(response);
  }

  Future<Map<String, Object?>> _runJson(
    List<String> arguments, {
    String? stdinText,
  }) async {
    final result = await _runner.run(
      _controlPath,
      arguments,
      stdinText: stdinText,
    );
    if (result.exitCode != 0) {
      final message = result.stderr.trim().isNotEmpty
          ? result.stderr.trim()
          : 'routerctl exited with code ${result.exitCode}.';
      throw StateError(message);
    }
    final decoded = jsonDecode(result.stdout);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('routerctl returned an invalid response.');
    }
    return decoded;
  }
}

class LinuxProcessTunnelService extends DesktopProcessTunnelService {
  LinuxProcessTunnelService({String? controlPath, super.runner})
    : super(controlPath: controlPath ?? _discoverControlPath(windows: false));
}

class WindowsProcessTunnelService extends DesktopProcessTunnelService {
  WindowsProcessTunnelService({String? controlPath, super.runner})
    : super(controlPath: controlPath ?? _discoverControlPath(windows: true));
}

TunnelService createTunnelService() {
  if (Platform.isLinux) {
    return LinuxProcessTunnelService();
  }
  if (Platform.isWindows) {
    return WindowsProcessTunnelService();
  }
  return MethodChannelTunnelService();
}

String _discoverControlPath({required bool windows}) {
  final configured = Platform.environment['ADAPTIVE_VPN_ROUTERCTL']?.trim();
  if (configured != null && configured.isNotEmpty) {
    return configured;
  }
  final executableDirectory = File(
    Platform.resolvedExecutable,
  ).parent.absolute.path;
  final workingDirectory = Directory.current.absolute.path;
  final executableName = windows ? 'routerctl.exe' : 'routerctl';
  final candidates = <String>[
    '$executableDirectory/$executableName',
    '$executableDirectory/lib/$executableName',
    '$executableDirectory/lib/adaptive_vpn/$executableName',
    '$workingDirectory/core/$executableName',
    '$workingDirectory/../core/$executableName',
  ];
  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }
  return '';
}

String _cleanProcessError(Object error) {
  return error.toString().replaceFirst(
    RegExp(r'^[A-Za-z]+(?:Error|Exception):\s*'),
    '',
  );
}

RouteProbeResult _decodeProbe(Map<String, Object?> response) {
  return RouteProbeResult(
    directSucceeded: response['direct_succeeded'] == true,
    proxyAttempted: response['proxy_attempted'] == true,
    proxySucceeded: response['proxy_succeeded'] == true,
    learned: response['learned'] == true,
    message: response['message'] as String? ?? 'Route probe completed.',
  );
}
