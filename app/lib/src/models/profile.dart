import 'dart:convert';

import 'profile_link_parser.dart';

class VpnProfile {
  const VpnProfile({
    required this.id,
    required this.name,
    required this.outboundType,
    required this.outbound,
  });

  final String id;
  final String name;
  final String outboundType;
  final Map<String, Object?> outbound;

  factory VpnProfile.fromJsonText(String text) {
    final decoded = jsonDecode(text);
    return VpnProfile.fromJson(decoded);
  }

  factory VpnProfile.fromInput(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Profile input is empty.');
    }
    if (trimmed.startsWith('{')) {
      return VpnProfile.fromJsonText(trimmed);
    }
    final parsed = ProfileLinkParser.parse(trimmed);
    return VpnProfile(
      id: _stableID(parsed.outbound, parsed.name),
      name: parsed.name,
      outboundType: parsed.outbound['type']! as String,
      outbound: Map.unmodifiable(parsed.outbound),
    );
  }

  factory VpnProfile.fromJson(Object? decoded) {
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Profile must be a JSON object.');
    }
    final outbound = decoded['outbound'];
    if (outbound is! Map<String, Object?>) {
      throw const FormatException('Profile must contain an outbound object.');
    }
    final type = outbound['type'];
    if (type is! String || type.trim().isEmpty) {
      throw const FormatException('Outbound type is required.');
    }
    if (const {
      'direct',
      'block',
      'dns',
      'selector',
      'urltest',
    }.contains(type)) {
      throw FormatException('$type cannot be used as a proxy profile.');
    }

    final name = decoded['name'];
    final id = decoded['id'];
    return VpnProfile(
      id: id is String && id.trim().isNotEmpty
          ? id.trim()
          : DateTime.now().microsecondsSinceEpoch.toString(),
      name: name is String && name.trim().isNotEmpty
          ? name.trim()
          : type.toUpperCase(),
      outboundType: type,
      outbound: Map.unmodifiable(outbound),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'outbound': outbound,
  };
}

String _stableID(Map<String, Object?> outbound, String name) {
  final identity =
      '${outbound['type']}|${outbound['server']}|${outbound['server_port']}|$name';
  var hash = 0xcbf29ce484222325;
  for (final byte in utf8.encode(identity)) {
    hash ^= byte;
    hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
  }
  return 'profile-${hash.toRadixString(16)}';
}
