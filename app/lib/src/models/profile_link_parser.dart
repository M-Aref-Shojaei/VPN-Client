import 'dart:convert';
import 'dart:typed_data';

class ParsedProfileLink {
  const ParsedProfileLink({required this.name, required this.outbound});

  final String name;
  final Map<String, Object?> outbound;
}

class ProfileLinkParser {
  const ProfileLinkParser._();

  static const supportedSchemes = {
    'vless',
    'vmess',
    'trojan',
    'ss',
    'shadowsocks',
    'hysteria2',
    'hy2',
    'tuic',
    'wireguard',
    'wg',
    'ssh',
  };

  static ParsedProfileLink parse(String input) {
    final text = input.trim();
    if (text.length > 64 * 1024) {
      throw const FormatException('Profile link is too large.');
    }
    final scheme = Uri.tryParse(text)?.scheme.toLowerCase();
    if (scheme == null || !supportedSchemes.contains(scheme)) {
      throw FormatException(
        'Unsupported profile link scheme: ${scheme ?? "unknown"}.',
      );
    }
    return switch (scheme) {
      'vless' => _parseVless(text),
      'vmess' => _parseVmess(text),
      'trojan' => _parseTrojan(text),
      'ss' || 'shadowsocks' => _parseShadowsocks(text),
      'hysteria2' || 'hy2' => _parseHysteria2(text),
      'tuic' => _parseTuic(text),
      'wireguard' || 'wg' => _parseWireGuard(text),
      'ssh' => _parseSSH(text),
      _ => throw FormatException('Unsupported profile link scheme: $scheme.'),
    };
  }

  static ParsedProfileLink _parseVless(String text) {
    final uri = _serverUri(text, 'vless');
    final uuid = _decodedUserInfo(uri);
    if (uuid.isEmpty) {
      throw const FormatException('VLESS UUID is required.');
    }
    final query = uri.queryParameters;
    final outbound = <String, Object?>{
      'type': 'vless',
      'server': uri.host,
      'server_port': _port(uri),
      'uuid': uuid,
    };
    final flow = query['flow']?.trim();
    if (flow != null && flow.isNotEmpty) {
      outbound['flow'] = flow;
    }
    _addTLS(outbound, query);
    _addTransport(outbound, query);
    return ParsedProfileLink(
      name: _name(uri, 'VLESS ${uri.host}'),
      outbound: outbound,
    );
  }

  static ParsedProfileLink _parseVmess(String text) {
    final encoded = text.substring(text.indexOf('://') + 3).split('#').first;
    final decoded = utf8.decode(_decodeBase64(encoded));
    final value = jsonDecode(decoded);
    if (value is! Map<String, Object?>) {
      throw const FormatException('VMess payload must be a JSON object.');
    }
    final server = _requiredString(value['add'], 'VMess server');
    final port = _parsePortValue(value['port'], 'VMess port');
    final uuid = _requiredString(value['id'], 'VMess UUID');
    final outbound = <String, Object?>{
      'type': 'vmess',
      'server': server,
      'server_port': port,
      'uuid': uuid,
      'security': _optionalString(value['scy']) ?? 'auto',
    };
    final alterID = int.tryParse('${value['aid'] ?? 0}') ?? 0;
    if (alterID > 0) {
      outbound['alter_id'] = alterID;
    }
    final tlsMode = _optionalString(value['tls']);
    final query = <String, String>{};
    _putString(query, 'security', tlsMode);
    _putString(query, 'sni', _optionalString(value['sni']));
    _putString(query, 'fp', _optionalString(value['fp']));
    _putString(query, 'type', _optionalString(value['net']));
    _putString(query, 'path', _optionalString(value['path']));
    _putString(query, 'host', _optionalString(value['host']));
    _putString(query, 'alpn', _optionalString(value['alpn']));
    _addTLS(outbound, query);
    _addTransport(outbound, query);
    final name = _optionalString(value['ps']) ?? 'VMess $server';
    return ParsedProfileLink(name: name, outbound: outbound);
  }

  static ParsedProfileLink _parseTrojan(String text) {
    final uri = _serverUri(text, 'trojan');
    final password = _decodedUserInfo(uri);
    if (password.isEmpty) {
      throw const FormatException('Trojan password is required.');
    }
    final outbound = <String, Object?>{
      'type': 'trojan',
      'server': uri.host,
      'server_port': _port(uri),
      'password': password,
    };
    _addTLS(outbound, {...uri.queryParameters, 'security': 'tls'});
    _addTransport(outbound, uri.queryParameters);
    return ParsedProfileLink(
      name: _name(uri, 'Trojan ${uri.host}'),
      outbound: outbound,
    );
  }

  static ParsedProfileLink _parseShadowsocks(String text) {
    var body = text.substring(text.indexOf('://') + 3);
    final fragmentIndex = body.indexOf('#');
    final fragment = fragmentIndex >= 0
        ? body.substring(fragmentIndex + 1)
        : '';
    if (fragmentIndex >= 0) {
      body = body.substring(0, fragmentIndex);
    }
    final queryIndex = body.indexOf('?');
    final queryText = queryIndex >= 0 ? body.substring(queryIndex + 1) : '';
    if (queryIndex >= 0) {
      body = body.substring(0, queryIndex);
    }

    String credentials;
    String endpoint;
    if (body.contains('@')) {
      final separator = body.lastIndexOf('@');
      credentials = body.substring(0, separator);
      endpoint = body.substring(separator + 1);
      if (!credentials.contains(':')) {
        credentials = utf8.decode(_decodeBase64(credentials));
      } else {
        credentials = Uri.decodeComponent(credentials);
      }
    } else {
      final decoded = utf8.decode(_decodeBase64(body));
      final separator = decoded.lastIndexOf('@');
      if (separator < 0) {
        throw const FormatException('Invalid Shadowsocks link.');
      }
      credentials = decoded.substring(0, separator);
      endpoint = decoded.substring(separator + 1);
    }
    final credentialSeparator = credentials.indexOf(':');
    if (credentialSeparator <= 0) {
      throw const FormatException(
        'Shadowsocks method and password are required.',
      );
    }
    final method = credentials.substring(0, credentialSeparator);
    final password = credentials.substring(credentialSeparator + 1);
    final uri = _serverUri('ss://placeholder@$endpoint', 'shadowsocks');
    final query = Uri.splitQueryString(queryText);
    if (query['plugin']?.isNotEmpty == true) {
      throw const FormatException(
        'Shadowsocks plugin links are not supported yet.',
      );
    }
    return ParsedProfileLink(
      name: fragment.isEmpty
          ? 'Shadowsocks ${uri.host}'
          : Uri.decodeComponent(fragment),
      outbound: {
        'type': 'shadowsocks',
        'server': uri.host,
        'server_port': _port(uri),
        'method': method,
        'password': password,
      },
    );
  }

  static ParsedProfileLink _parseHysteria2(String text) {
    final uri = _serverUri(text, 'hysteria2');
    final password = _decodedUserInfo(uri);
    if (password.isEmpty) {
      throw const FormatException('Hysteria2 password is required.');
    }
    final query = uri.queryParameters;
    final outbound = <String, Object?>{
      'type': 'hysteria2',
      'server': uri.host,
      'server_port': _port(uri),
      'password': password,
    };
    _addTLS(outbound, {...query, 'security': 'tls'});
    final obfs = query['obfs'];
    final obfsPassword = query['obfs-password'] ?? query['obfs_password'];
    if (obfs != null && obfs.isNotEmpty) {
      final settings = <String, Object?>{'type': obfs};
      if (obfsPassword != null) {
        settings['password'] = obfsPassword;
      }
      outbound['obfs'] = settings;
    }
    return ParsedProfileLink(
      name: _name(uri, 'Hysteria2 ${uri.host}'),
      outbound: outbound,
    );
  }

  static ParsedProfileLink _parseTuic(String text) {
    final uri = _serverUri(text, 'tuic');
    final parts = _decodedUserInfo(uri).split(':');
    if (parts.length != 2 || parts.any((part) => part.isEmpty)) {
      throw const FormatException('TUIC UUID and password are required.');
    }
    final query = uri.queryParameters;
    final outbound = <String, Object?>{
      'type': 'tuic',
      'server': uri.host,
      'server_port': _port(uri),
      'uuid': parts[0],
      'password': parts[1],
    };
    _putObject(outbound, 'congestion_control', query['congestion_control']);
    _putObject(outbound, 'udp_relay_mode', query['udp_relay_mode']);
    _addTLS(outbound, {...query, 'security': 'tls'});
    return ParsedProfileLink(
      name: _name(uri, 'TUIC ${uri.host}'),
      outbound: outbound,
    );
  }

  static ParsedProfileLink _parseSSH(String text) {
    final uri = _serverUri(text, 'ssh');
    final userInfo = _decodedUserInfo(uri);
    final separator = userInfo.indexOf(':');
    final user = separator < 0 ? userInfo : userInfo.substring(0, separator);
    final password = separator < 0 ? null : userInfo.substring(separator + 1);
    if (user.isEmpty) {
      throw const FormatException('SSH username is required.');
    }
    final outbound = <String, Object?>{
      'type': 'ssh',
      'server': uri.host,
      'server_port': uri.hasPort ? _port(uri) : 22,
      'user': user,
    };
    if (password != null && password.isNotEmpty) {
      outbound['password'] = password;
    }
    return ParsedProfileLink(
      name: _name(uri, 'SSH ${uri.host}'),
      outbound: outbound,
    );
  }

  static ParsedProfileLink _parseWireGuard(String text) {
    final uri = _serverUri(text, 'wireguard');
    final privateKey = _decodedUserInfo(uri);
    final query = uri.queryParameters;
    final publicKey = query['public_key'] ?? query['publickey'];
    final addresses = _csv(query['address']);
    final allowedIPs = _csv(query['allowed_ips'] ?? query['allowedips']);
    if (privateKey.isEmpty || publicKey == null || publicKey.isEmpty) {
      throw const FormatException(
        'WireGuard private and peer public keys are required.',
      );
    }
    if (addresses.isEmpty || allowedIPs.isEmpty) {
      throw const FormatException(
        'WireGuard address and allowed_ips are required.',
      );
    }
    final peer = <String, Object?>{
      'address': uri.host,
      'port': _port(uri),
      'public_key': publicKey,
      'allowed_ips': allowedIPs,
    };
    _putObject(
      peer,
      'pre_shared_key',
      query['pre_shared_key'] ?? query['presharedkey'],
    );
    final reserved = _csv(
      query['reserved'],
    ).map(int.tryParse).whereType<int>().toList(growable: false);
    if (reserved.isNotEmpty) {
      if (reserved.length != 3 ||
          reserved.any((value) => value < 0 || value > 255)) {
        throw const FormatException(
          'WireGuard reserved must contain three bytes.',
        );
      }
      peer['reserved'] = reserved;
    }
    final endpoint = <String, Object?>{
      'type': 'wireguard',
      'system': false,
      'address': addresses,
      'private_key': privateKey,
      'peers': [peer],
    };
    final mtu = int.tryParse(query['mtu'] ?? '');
    if (mtu != null) {
      if (mtu < 576 || mtu > 9000) {
        throw const FormatException('WireGuard MTU is outside the safe range.');
      }
      endpoint['mtu'] = mtu;
    }
    return ParsedProfileLink(
      name: _name(uri, 'WireGuard ${uri.host}'),
      outbound: endpoint,
    );
  }

  static Uri _serverUri(String text, String label) {
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) {
      throw FormatException('$label server is required.');
    }
    return uri;
  }

  static int _port(Uri uri) {
    if (!uri.hasPort || uri.port < 1 || uri.port > 65535) {
      throw const FormatException('Server port must be between 1 and 65535.');
    }
    return uri.port;
  }

  static int _parsePortValue(Object? value, String label) {
    final port = value is int ? value : int.tryParse('$value');
    if (port == null || port < 1 || port > 65535) {
      throw FormatException('$label must be between 1 and 65535.');
    }
    return port;
  }

  static String _decodedUserInfo(Uri uri) {
    return Uri.decodeComponent(uri.userInfo);
  }

  static String _name(Uri uri, String fallback) {
    return uri.fragment.isEmpty ? fallback : Uri.decodeComponent(uri.fragment);
  }

  static void _addTLS(
    Map<String, Object?> outbound,
    Map<String, String> query,
  ) {
    final security = query['security']?.toLowerCase();
    if (security != 'tls' && security != 'reality' && security != 'xtls') {
      return;
    }
    final tls = <String, Object?>{'enabled': true};
    _putObject(tls, 'server_name', query['sni'] ?? query['serverName']);
    if (_isTrue(query['allowInsecure'] ?? query['insecure'])) {
      tls['insecure'] = true;
    }
    final alpn = query['alpn']
        ?.split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (alpn != null && alpn.isNotEmpty) {
      tls['alpn'] = alpn;
    }
    final fingerprint = query['fp'];
    if (fingerprint != null && fingerprint.isNotEmpty) {
      tls['utls'] = {'enabled': true, 'fingerprint': fingerprint};
    }
    if (security == 'reality') {
      final publicKey = query['pbk'] ?? query['publicKey'];
      if (publicKey == null || publicKey.isEmpty) {
        throw const FormatException('Reality public key is required.');
      }
      final reality = <String, Object?>{
        'enabled': true,
        'public_key': publicKey,
      };
      _putObject(reality, 'short_id', query['sid'] ?? query['shortId']);
      tls['reality'] = reality;
    }
    outbound['tls'] = tls;
  }

  static void _addTransport(
    Map<String, Object?> outbound,
    Map<String, String> query,
  ) {
    final type = query['type']?.toLowerCase();
    switch (type) {
      case null || '' || 'tcp':
        return;
      case 'ws':
        final transport = <String, Object?>{'type': 'ws'};
        _putObject(transport, 'path', query['path']);
        if (query['host'] case final host?) {
          transport['headers'] = {'Host': host};
        }
        outbound['transport'] = transport;
      case 'grpc':
        final transport = <String, Object?>{'type': 'grpc'};
        _putObject(
          transport,
          'service_name',
          query['serviceName'] ?? query['service_name'] ?? query['path'],
        );
        outbound['transport'] = transport;
      case 'httpupgrade':
        final transport = <String, Object?>{'type': 'httpupgrade'};
        _putObject(transport, 'path', query['path']);
        _putObject(transport, 'host', query['host']);
        outbound['transport'] = transport;
      default:
        throw FormatException('Unsupported transport type: $type.');
    }
  }

  static Uint8List _decodeBase64(String value) {
    var normalized = Uri.decodeComponent(
      value.trim(),
    ).replaceAll('-', '+').replaceAll('_', '/');
    normalized += '=' * ((4 - normalized.length % 4) % 4);
    try {
      return base64Decode(normalized);
    } on FormatException {
      throw const FormatException('Profile contains invalid base64 data.');
    }
  }

  static String _requiredString(Object? value, String label) {
    final result = _optionalString(value);
    if (result == null) {
      throw FormatException('$label is required.');
    }
    return result;
  }

  static String? _optionalString(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }

  static bool _isTrue(String? value) {
    return value == '1' || value?.toLowerCase() == 'true';
  }

  static List<String> _csv(String? value) {
    if (value == null) {
      return const [];
    }
    return value
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  static void _putString(
    Map<String, String> target,
    String key,
    String? value,
  ) {
    if (value != null) {
      target[key] = value;
    }
  }

  static void _putObject(
    Map<String, Object?> target,
    String key,
    Object? value,
  ) {
    if (value != null) {
      target[key] = value;
    }
  }
}
