import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/profile.dart';

const _maximumSubscriptionBytes = 2 * 1024 * 1024;
const _maximumSubscriptionProfiles = 500;

class SubscriptionResult {
  const SubscriptionResult({required this.profiles, required this.source});

  final List<VpnProfile> profiles;
  final Uri source;
}

class SubscriptionService {
  SubscriptionService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<SubscriptionResult> fetch(String input) async {
    final requested = Uri.tryParse(input.trim());
    if (requested == null ||
        requested.scheme != 'https' ||
        requested.host.isEmpty ||
        requested.userInfo.isNotEmpty) {
      throw const FormatException(
        'Subscription URL must be HTTPS and must not contain credentials.',
      );
    }
    final response = await _client
        .get(
          requested,
          headers: const {
            'Accept': 'text/plain, application/json',
            'User-Agent': 'AdaptiveVPN/0.1',
          },
        )
        .timeout(const Duration(seconds: 20));
    final finalURL = response.request?.url ?? requested;
    if (finalURL.scheme != 'https' || finalURL.userInfo.isNotEmpty) {
      throw const FormatException('Subscription redirected to an unsafe URL.');
    }
    if (response.statusCode != 200) {
      throw FormatException(
        'Subscription returned HTTP ${response.statusCode}.',
      );
    }
    final declaredLength = int.tryParse(
      response.headers['content-length'] ?? '',
    );
    if ((declaredLength != null &&
            declaredLength > _maximumSubscriptionBytes) ||
        response.bodyBytes.length > _maximumSubscriptionBytes) {
      throw const FormatException('Subscription exceeds the 2 MiB limit.');
    }
    final text = utf8.decode(response.bodyBytes, allowMalformed: false).trim();
    if (text.isEmpty) {
      throw const FormatException('Subscription is empty.');
    }
    final profiles = _parsePayload(text);
    return SubscriptionResult(profiles: profiles, source: finalURL);
  }

  List<VpnProfile> _parsePayload(String payload) {
    Object? jsonValue;
    if (payload.startsWith('{') || payload.startsWith('[')) {
      try {
        jsonValue = jsonDecode(payload);
      } on FormatException {
        throw const FormatException('Subscription JSON is invalid.');
      }
    }
    final entries = <Object?>[];
    if (jsonValue is List<Object?>) {
      entries.addAll(jsonValue);
    } else if (jsonValue is Map<String, Object?>) {
      final profiles = jsonValue['profiles'];
      if (profiles is! List<Object?>) {
        throw const FormatException(
          'Subscription JSON must contain a profiles list.',
        );
      }
      entries.addAll(profiles);
    } else {
      var linkText = payload;
      if (!linkText.contains('://')) {
        try {
          var normalized = linkText
              .replaceAll(RegExp(r'\s+'), '')
              .replaceAll('-', '+')
              .replaceAll('_', '/');
          normalized += '=' * ((4 - normalized.length % 4) % 4);
          linkText = utf8.decode(base64Decode(normalized));
        } on FormatException {
          throw const FormatException(
            'Subscription is neither JSON nor a valid link list.',
          );
        }
      }
      entries.addAll(
        const LineSplitter()
            .convert(linkText)
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty && !line.startsWith('#')),
      );
    }
    if (entries.isEmpty) {
      throw const FormatException('Subscription contains no profiles.');
    }
    if (entries.length > _maximumSubscriptionProfiles) {
      throw const FormatException(
        'Subscription contains more than 500 profiles.',
      );
    }
    final unique = <String, VpnProfile>{};
    for (final entry in entries) {
      final profile = entry is String
          ? VpnProfile.fromInput(entry)
          : VpnProfile.fromJson(entry);
      unique[profile.id] = profile;
    }
    return List.unmodifiable(unique.values);
  }

  void close() => _client.close();
}
