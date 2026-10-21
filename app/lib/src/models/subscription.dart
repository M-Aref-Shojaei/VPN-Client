class VpnSubscription {
  const VpnSubscription({
    required this.id,
    required this.name,
    required this.url,
    required this.profileIDs,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final Uri url;
  final List<String> profileIDs;
  final DateTime updatedAt;

  factory VpnSubscription.fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('Subscription must be an object.');
    }
    final id = value['id'];
    final name = value['name'];
    final url = Uri.tryParse('${value['url'] ?? ''}');
    final profileIDs = value['profile_ids'];
    final updatedAt = DateTime.tryParse('${value['updated_at'] ?? ''}');
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.isEmpty ||
        url == null ||
        url.scheme != 'https' ||
        url.userInfo.isNotEmpty ||
        profileIDs is! List<Object?> ||
        updatedAt == null) {
      throw const FormatException('Subscription is invalid.');
    }
    return VpnSubscription(
      id: id,
      name: name,
      url: url,
      profileIDs: profileIDs.whereType<String>().toList(growable: false),
      updatedAt: updatedAt.toUtc(),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'url': url.toString(),
    'profile_ids': profileIDs,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}
