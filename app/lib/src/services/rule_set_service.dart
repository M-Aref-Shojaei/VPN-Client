import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

const _maximumManifestBytes = 64 * 1024;
const _maximumRuleSetBytes = 4 * 1024 * 1024;
const _maximumDomains = 100000;

class VerifiedRuleSet {
  const VerifiedRuleSet({
    required this.domains,
    required this.version,
    required this.manifestURL,
    required this.publicKey,
    required this.verifiedAt,
  });

  final List<String> domains;
  final int version;
  final Uri manifestURL;
  final String publicKey;
  final DateTime verifiedAt;
}

class RuleSetService {
  RuleSetService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<VerifiedRuleSet> update({
    required String manifestURL,
    required String publicKeyBase64,
    int currentVersion = 0,
  }) async {
    final manifestUri = _httpsUri(manifestURL, 'manifest');
    final keyBytes = _decodeFixedBase64(
      publicKeyBase64,
      32,
      'Ed25519 public key',
    );
    final manifestResponse = await _get(
      manifestUri,
      _maximumManifestBytes,
      'rule-set manifest',
    );
    final manifestValue = jsonDecode(utf8.decode(manifestResponse.bodyBytes));
    if (manifestValue is! Map<String, Object?>) {
      throw const FormatException('Rule-set manifest must be an object.');
    }
    final version = manifestValue['version'];
    final dataURL = manifestValue['data_url'];
    final expectedHash = manifestValue['sha256'];
    final signatureText = manifestValue['signature'];
    if (version is! int ||
        version <= currentVersion ||
        dataURL is! String ||
        expectedHash is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedHash) ||
        signatureText is! String) {
      throw const FormatException(
        'Rule-set manifest fields are invalid or stale.',
      );
    }
    final dataUri = manifestUri.resolve(dataURL);
    if (dataUri.scheme != 'https' ||
        dataUri.host != manifestUri.host ||
        dataUri.port != manifestUri.port ||
        dataUri.userInfo.isNotEmpty) {
      throw const FormatException(
        'Rule-set data must remain on the manifest HTTPS origin.',
      );
    }
    final dataResponse = await _get(
      dataUri,
      _maximumRuleSetBytes,
      'rule-set data',
    );
    final data = dataResponse.bodyBytes;
    final actualHash = hashes.sha256.convert(data).toString();
    if (actualHash != expectedHash) {
      throw const FormatException('Rule-set SHA-256 verification failed.');
    }
    final signatureBytes = _decodeFixedBase64(
      signatureText,
      64,
      'Ed25519 signature',
    );
    final verified = await Ed25519().verify(
      data,
      signature: Signature(
        signatureBytes,
        publicKey: SimplePublicKey(keyBytes, type: KeyPairType.ed25519),
      ),
    );
    if (!verified) {
      throw const FormatException('Rule-set signature verification failed.');
    }
    final payload = jsonDecode(utf8.decode(data));
    if (payload is! Map<String, Object?> ||
        payload['domains'] is! List<Object?>) {
      throw const FormatException('Signed rule-set payload is invalid.');
    }
    final rawDomains = payload['domains']! as List<Object?>;
    if (rawDomains.isEmpty || rawDomains.length > _maximumDomains) {
      throw const FormatException('Signed rule-set domain count is invalid.');
    }
    final domains = <String>{};
    for (final value in rawDomains) {
      if (value is! String) {
        throw const FormatException(
          'Signed rule-set contains a non-string domain.',
        );
      }
      final normalized = _normalizeDomain(value);
      if (normalized.isEmpty) {
        throw const FormatException(
          'Signed rule-set contains an invalid domain.',
        );
      }
      domains.add(normalized);
    }
    final sorted = domains.toList()..sort();
    return VerifiedRuleSet(
      domains: List.unmodifiable(sorted),
      version: version,
      manifestURL: manifestUri,
      publicKey: publicKeyBase64,
      verifiedAt: DateTime.now().toUtc(),
    );
  }

  Future<http.Response> _get(Uri uri, int maximumBytes, String label) async {
    final response = await _client
        .get(
          uri,
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'AdaptiveVPN/0.1',
          },
        )
        .timeout(const Duration(seconds: 20));
    final finalURL = response.request?.url ?? uri;
    if (finalURL.scheme != 'https' ||
        finalURL.host != uri.host ||
        finalURL.port != uri.port) {
      throw FormatException('$label redirected outside its HTTPS origin.');
    }
    if (response.statusCode != 200) {
      throw FormatException('$label returned HTTP ${response.statusCode}.');
    }
    final declared = int.tryParse(response.headers['content-length'] ?? '');
    if ((declared != null && declared > maximumBytes) ||
        response.bodyBytes.length > maximumBytes) {
      throw FormatException('$label exceeds its size limit.');
    }
    return response;
  }

  static Uri _httpsUri(String input, String label) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw FormatException('$label URL must use HTTPS without credentials.');
    }
    return uri;
  }

  static List<int> _decodeFixedBase64(
    String input,
    int expectedLength,
    String label,
  ) {
    try {
      final bytes = base64Decode(input.trim());
      if (bytes.length != expectedLength) {
        throw FormatException('$label has the wrong length.');
      }
      return bytes;
    } on FormatException {
      throw FormatException('$label is invalid.');
    }
  }

  static String _normalizeDomain(String input) {
    var value = input.trim().toLowerCase();
    while (value.endsWith('.')) {
      value = value.substring(0, value.length - 1);
    }
    if (value.isEmpty ||
        value.length > 253 ||
        value.contains('/') ||
        value.contains(' ') ||
        value
            .split('.')
            .any(
              (label) =>
                  label.isEmpty ||
                  label.length > 63 ||
                  label.startsWith('-') ||
                  label.endsWith('-'),
            )) {
      return '';
    }
    return value;
  }

  void close() => _client.close();
}
