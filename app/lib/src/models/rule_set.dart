class RuleSetConfiguration {
  const RuleSetConfiguration({
    required this.manifestURL,
    required this.publicKey,
    required this.version,
    required this.verifiedAt,
  });

  final Uri manifestURL;
  final String publicKey;
  final int version;
  final DateTime verifiedAt;

  factory RuleSetConfiguration.fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('Rule-set configuration must be an object.');
    }
    final manifestURL = Uri.tryParse('${value['manifest_url'] ?? ''}');
    final publicKey = value['public_key'];
    final version = value['version'];
    final verifiedAt = DateTime.tryParse('${value['verified_at'] ?? ''}');
    if (manifestURL == null ||
        manifestURL.scheme != 'https' ||
        manifestURL.userInfo.isNotEmpty ||
        publicKey is! String ||
        publicKey.isEmpty ||
        version is! int ||
        version < 1 ||
        verifiedAt == null) {
      throw const FormatException('Rule-set configuration is invalid.');
    }
    return RuleSetConfiguration(
      manifestURL: manifestURL,
      publicKey: publicKey,
      version: version,
      verifiedAt: verifiedAt.toUtc(),
    );
  }

  Map<String, Object?> toJson() => {
    'manifest_url': manifestURL.toString(),
    'public_key': publicKey,
    'version': version,
    'verified_at': verifiedAt.toUtc().toIso8601String(),
  };
}
