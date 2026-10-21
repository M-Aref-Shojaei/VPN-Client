import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/profile.dart';
import '../models/routing.dart';
import '../models/rule_set.dart';
import '../models/subscription.dart';

const _storageKey = 'adaptive_vpn.state.v1';
const _maximumStateBytes = 1024 * 1024;

class ProfileSnapshot {
  const ProfileSnapshot({
    required this.profiles,
    required this.activeProfileID,
    required this.manualDirect,
    required this.manualProxy,
    required this.knownBlocked,
    required this.subscriptions,
    this.ruleSet,
  });

  const ProfileSnapshot.empty()
    : profiles = const [],
      activeProfileID = null,
      manualDirect = const ['localhost'],
      manualProxy = const [],
      knownBlocked = const [],
      subscriptions = const [],
      ruleSet = null;

  final List<VpnProfile> profiles;
  final String? activeProfileID;
  final List<String> manualDirect;
  final List<String> manualProxy;
  final List<String> knownBlocked;
  final List<VpnSubscription> subscriptions;
  final RuleSetConfiguration? ruleSet;

  Map<String, Object?> toJson() => {
    'version': 1,
    'profiles': profiles.map((profile) => profile.toJson()).toList(),
    'active_profile_id': activeProfileID,
    'subscriptions': subscriptions
        .map((subscription) => subscription.toJson())
        .toList(),
    'rule_set': ruleSet?.toJson(),
    'policy': {
      'manual_direct': manualDirect,
      'manual_proxy': manualProxy,
      'known_blocked': knownBlocked,
    },
  };

  factory ProfileSnapshot.fromJson(Object? value) {
    if (value is! Map<String, Object?> || value['version'] != 1) {
      throw const FormatException('Unsupported secure-state format.');
    }
    final rawProfiles = value['profiles'];
    final rawPolicy = value['policy'];
    final rawSubscriptions = value['subscriptions'] ?? const <Object?>[];
    if (rawProfiles is! List<Object?> ||
        rawSubscriptions is! List<Object?> ||
        rawPolicy is! Map<String, Object?>) {
      throw const FormatException('Secure state is incomplete.');
    }
    if (rawProfiles.length > 500) {
      throw const FormatException('Secure state contains too many profiles.');
    }
    final profiles = rawProfiles.map(VpnProfile.fromJson).toList();
    if (rawSubscriptions.length > 100) {
      throw const FormatException(
        'Secure state contains too many subscriptions.',
      );
    }
    final activeProfileID = value['active_profile_id'];
    return ProfileSnapshot(
      profiles: profiles,
      activeProfileID: activeProfileID is String ? activeProfileID : null,
      manualDirect: _stringList(rawPolicy['manual_direct']),
      manualProxy: _stringList(rawPolicy['manual_proxy']),
      knownBlocked: _stringList(rawPolicy['known_blocked']),
      subscriptions: rawSubscriptions.map(VpnSubscription.fromJson).toList(),
      ruleSet: value['rule_set'] == null
          ? null
          : RuleSetConfiguration.fromJson(value['rule_set']),
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is! List<Object?> || value.length > 10000) {
      throw const FormatException('Secure routing policy is invalid.');
    }
    final result = <String>[];
    for (final entry in value) {
      if (entry is! String) {
        throw const FormatException('Secure routing policy is invalid.');
      }
      final normalized = normalizeDomain(entry);
      if (normalized.isNotEmpty && !result.contains(normalized)) {
        result.add(normalized);
      }
    }
    result.sort();
    return result;
  }
}

abstract interface class ProfileStore {
  Future<ProfileSnapshot> load();
  Future<void> save(ProfileSnapshot snapshot);
  Future<void> clear();
}

class SecureProfileStore implements ProfileStore {
  const SecureProfileStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<ProfileSnapshot> load() async {
    final encoded = await _storage.read(key: _storageKey);
    if (encoded == null || encoded.isEmpty) {
      return const ProfileSnapshot.empty();
    }
    if (utf8.encode(encoded).length > _maximumStateBytes) {
      throw const FormatException('Secure state exceeds the size limit.');
    }
    return ProfileSnapshot.fromJson(jsonDecode(encoded));
  }

  @override
  Future<void> save(ProfileSnapshot snapshot) async {
    final encoded = jsonEncode(snapshot.toJson());
    if (utf8.encode(encoded).length > _maximumStateBytes) {
      throw const FormatException('Secure state exceeds the size limit.');
    }
    await _storage.write(key: _storageKey, value: encoded);
  }

  @override
  Future<void> clear() => _storage.delete(key: _storageKey);
}

class MemoryProfileStore implements ProfileStore {
  ProfileSnapshot snapshot = const ProfileSnapshot.empty();

  @override
  Future<ProfileSnapshot> load() async => snapshot;

  @override
  Future<void> save(ProfileSnapshot snapshot) async {
    this.snapshot = ProfileSnapshot.fromJson(snapshot.toJson());
  }

  @override
  Future<void> clear() async {
    snapshot = const ProfileSnapshot.empty();
  }
}
