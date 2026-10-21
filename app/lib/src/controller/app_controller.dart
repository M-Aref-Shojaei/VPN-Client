import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/profile.dart';
import '../models/routing.dart';
import '../models/rule_set.dart';
import '../models/subscription.dart';
import '../services/profile_store.dart';
import '../services/rule_set_service.dart';
import '../services/subscription_service.dart';
import '../services/tunnel_service.dart';

class AppController extends ChangeNotifier {
  AppController({
    required this.tunnelService,
    required this.profileStore,
    required this.subscriptionService,
    required this.ruleSetService,
  });

  final TunnelService tunnelService;
  final ProfileStore profileStore;
  final SubscriptionService subscriptionService;
  final RuleSetService ruleSetService;
  final RoutingPolicy policy = RoutingPolicy(manualDirect: ['localhost']);
  final List<VpnProfile> profiles = [];
  final List<VpnSubscription> subscriptions = [];

  TunnelStatus status = TunnelStatus.disconnected;
  TunnelCapability capability = const TunnelCapability(
    available: false,
    message: 'Checking tunnel support…',
  );
  String? activeProfileID;
  String? lastError;
  RuleSetConfiguration? ruleSet;

  VpnProfile? get activeProfile {
    for (final profile in profiles) {
      if (profile.id == activeProfileID) {
        return profile;
      }
    }
    return null;
  }

  bool get canConnect =>
      capability.available &&
      activeProfile != null &&
      status == TunnelStatus.disconnected;

  Future<void> initialize() async {
    try {
      final snapshot = await profileStore.load();
      profiles
        ..clear()
        ..addAll(snapshot.profiles);
      subscriptions
        ..clear()
        ..addAll(snapshot.subscriptions);
      ruleSet = snapshot.ruleSet;
      activeProfileID = snapshot.activeProfileID;
      if (!profiles.any((profile) => profile.id == activeProfileID)) {
        activeProfileID = profiles.firstOrNull?.id;
      }
      policy.manualDirect
        ..clear()
        ..addAll(snapshot.manualDirect);
      policy.manualProxy
        ..clear()
        ..addAll(snapshot.manualProxy);
      policy.knownBlocked
        ..clear()
        ..addAll(snapshot.knownBlocked);
    } catch (_) {
      lastError = 'Secure profile storage could not be opened.';
    }
    capability = await tunnelService.capability();
    if (capability.running) {
      status = TunnelStatus.connected;
    }
    notifyListeners();
  }

  Future<String?> importProfile(String input) async {
    try {
      final profile = VpnProfile.fromInput(input);
      final existingIndex = profiles.indexWhere(
        (candidate) => candidate.id == profile.id,
      );
      if (existingIndex >= 0) {
        profiles[existingIndex] = profile;
      } else {
        profiles.add(profile);
      }
      activeProfileID ??= profile.id;
      lastError = null;
      if (!await _persist()) {
        notifyListeners();
        return lastError;
      }
      notifyListeners();
      return null;
    } on FormatException catch (error) {
      return error.message;
    } catch (error) {
      return 'Could not import profile: $error';
    }
  }

  Future<void> selectProfile(String id) async {
    activeProfileID = id;
    await _persist();
    notifyListeners();
  }

  Future<void> removeProfile(String id) async {
    profiles.removeWhere((profile) => profile.id == id);
    if (activeProfileID == id) {
      activeProfileID = profiles.firstOrNull?.id;
    }
    await _persist();
    notifyListeners();
  }

  Future<String?> updateSubscription({
    required String name,
    required String url,
  }) async {
    try {
      final result = await subscriptionService.fetch(url);
      final normalizedName = name.trim().isEmpty
          ? result.source.host
          : name.trim();
      final id = _subscriptionID(result.source);
      final existingIndex = subscriptions.indexWhere(
        (subscription) => subscription.id == id,
      );
      final previousIDs = existingIndex < 0
          ? const <String>[]
          : subscriptions[existingIndex].profileIDs;
      final incomingIDs = result.profiles.map((profile) => profile.id).toSet();
      profiles.removeWhere(
        (profile) =>
            previousIDs.contains(profile.id) &&
            !incomingIDs.contains(profile.id),
      );
      for (final profile in result.profiles) {
        final index = profiles.indexWhere(
          (candidate) => candidate.id == profile.id,
        );
        if (index < 0) {
          profiles.add(profile);
        } else {
          profiles[index] = profile;
        }
      }
      final subscription = VpnSubscription(
        id: id,
        name: normalizedName,
        url: result.source,
        profileIDs: incomingIDs.toList(growable: false),
        updatedAt: DateTime.now().toUtc(),
      );
      if (existingIndex < 0) {
        subscriptions.add(subscription);
      } else {
        subscriptions[existingIndex] = subscription;
      }
      activeProfileID ??= profiles.firstOrNull?.id;
      lastError = null;
      if (!await _persist()) {
        notifyListeners();
        return lastError;
      }
      notifyListeners();
      return null;
    } on FormatException catch (error) {
      return error.message;
    } on Object {
      return 'Subscription update failed.';
    }
  }

  Future<void> removeSubscription(String id) async {
    final index = subscriptions.indexWhere(
      (subscription) => subscription.id == id,
    );
    if (index < 0) {
      return;
    }
    final subscription = subscriptions.removeAt(index);
    final sharedIDs = subscriptions
        .expand((candidate) => candidate.profileIDs)
        .toSet();
    profiles.removeWhere(
      (profile) =>
          subscription.profileIDs.contains(profile.id) &&
          !sharedIDs.contains(profile.id),
    );
    if (!profiles.any((profile) => profile.id == activeProfileID)) {
      activeProfileID = profiles.firstOrNull?.id;
    }
    await _persist();
    notifyListeners();
  }

  Future<bool> addRule(RouteTarget target, String domain) async {
    final changed = policy.addRule(target, domain);
    if (changed) {
      await _persist();
      notifyListeners();
    }
    return changed;
  }

  Future<void> removeRule(RouteTarget target, String domain) async {
    policy.removeRule(target, domain);
    await _persist();
    notifyListeners();
  }

  Future<String?> updateRuleSet({
    required String manifestURL,
    required String publicKey,
  }) async {
    try {
      final previousDomains = List<String>.of(policy.knownBlocked);
      final previousRuleSet = ruleSet;
      final verified = await ruleSetService.update(
        manifestURL: manifestURL,
        publicKeyBase64: publicKey,
        currentVersion: ruleSet?.version ?? 0,
      );
      policy.knownBlocked
        ..clear()
        ..addAll(verified.domains);
      ruleSet = RuleSetConfiguration(
        manifestURL: verified.manifestURL,
        publicKey: verified.publicKey,
        version: verified.version,
        verifiedAt: verified.verifiedAt,
      );
      lastError = null;
      if (!await _persist()) {
        policy.knownBlocked
          ..clear()
          ..addAll(previousDomains);
        ruleSet = previousRuleSet;
        notifyListeners();
        return lastError;
      }
      notifyListeners();
      return null;
    } on FormatException catch (error) {
      return error.message;
    } on Object {
      return 'Signed rule-set update failed.';
    }
  }

  Future<String> probeDomain(String input) async {
    final domain = normalizeDomain(input);
    if (domain.isEmpty) {
      return 'Enter a valid domain first.';
    }
    if (status != TunnelStatus.connected) {
      return 'Connect the tunnel before testing both paths.';
    }
    try {
      final result = await tunnelService.probe(domain: domain);
      if (result.learned && !policy.learnedBlocked.contains(domain)) {
        policy.learnedBlocked.add(domain);
        policy.learnedBlocked.sort();
      }
      notifyListeners();
      return result.message;
    } catch (error) {
      return _readablePlatformError(error);
    }
  }

  Future<void> connect() async {
    final profile = activeProfile;
    if (!canConnect || profile == null) {
      return;
    }
    status = TunnelStatus.connecting;
    lastError = null;
    notifyListeners();
    try {
      await tunnelService.connect(
        profile: profile.outbound,
        policy: {
          'manual_direct': policy.manualDirect,
          'manual_proxy': policy.manualProxy,
          'known_blocked': policy.knownBlocked,
        },
      );
      status = TunnelStatus.connected;
    } catch (error) {
      status = TunnelStatus.disconnected;
      lastError = _readablePlatformError(error);
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    if (status != TunnelStatus.connected) {
      return;
    }
    status = TunnelStatus.disconnecting;
    notifyListeners();
    try {
      await tunnelService.disconnect();
      status = TunnelStatus.disconnected;
    } catch (error) {
      status = TunnelStatus.connected;
      lastError = _readablePlatformError(error);
    }
    notifyListeners();
  }

  String exportPolicy() {
    return const JsonEncoder.withIndent('  ').convert({
      'manual_direct': policy.manualDirect,
      'manual_proxy': policy.manualProxy,
      'known_blocked': policy.knownBlocked,
    });
  }

  Future<bool> _persist() async {
    try {
      await profileStore.save(
        ProfileSnapshot(
          profiles: List.unmodifiable(profiles),
          activeProfileID: activeProfileID,
          manualDirect: List.unmodifiable(policy.manualDirect),
          manualProxy: List.unmodifiable(policy.manualProxy),
          knownBlocked: List.unmodifiable(policy.knownBlocked),
          subscriptions: List.unmodifiable(subscriptions),
          ruleSet: ruleSet,
        ),
      );
      return true;
    } catch (_) {
      lastError = 'Changes could not be saved to secure storage.';
      return false;
    }
  }

  @override
  void dispose() {
    subscriptionService.close();
    ruleSetService.close();
    super.dispose();
  }
}

String _readablePlatformError(Object error) {
  final text = error.toString();
  return text.replaceFirst(RegExp(r'^[A-Za-z]+Exception:\s*'), '');
}

String _subscriptionID(Uri uri) {
  var hash = 0xcbf29ce484222325;
  for (final byte in utf8.encode(uri.toString())) {
    hash ^= byte;
    hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
  }
  return 'subscription-${hash.toRadixString(16)}';
}
