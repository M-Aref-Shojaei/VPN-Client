enum RouteTarget { direct, proxy }

enum RouteReason {
  manualDirect,
  manualProxy,
  privateDestination,
  knownBlocked,
  learnedBlocked,
  defaultDirect,
}

class RouteDecision {
  const RouteDecision(this.target, this.reason, [this.match]);

  final RouteTarget target;
  final RouteReason reason;
  final String? match;
}

class RoutingPolicy {
  RoutingPolicy({
    List<String>? manualDirect,
    List<String>? manualProxy,
    List<String>? knownBlocked,
    List<String>? learnedBlocked,
  }) : manualDirect = manualDirect ?? <String>[],
       manualProxy = manualProxy ?? <String>[],
       knownBlocked = knownBlocked ?? <String>[],
       learnedBlocked = learnedBlocked ?? <String>[];

  final List<String> manualDirect;
  final List<String> manualProxy;
  final List<String> knownBlocked;
  final List<String> learnedBlocked;

  RouteDecision decide(String input) {
    final domain = normalizeDomain(input);
    if (domain.isEmpty) {
      return const RouteDecision(RouteTarget.direct, RouteReason.defaultDirect);
    }

    final direct = _matchingRule(domain, manualDirect);
    if (direct != null) {
      return RouteDecision(
        RouteTarget.direct,
        RouteReason.manualDirect,
        direct,
      );
    }
    final proxy = _matchingRule(domain, manualProxy);
    if (proxy != null) {
      return RouteDecision(RouteTarget.proxy, RouteReason.manualProxy, proxy);
    }
    if (domain == 'localhost' || domain.endsWith('.local')) {
      return const RouteDecision(
        RouteTarget.direct,
        RouteReason.privateDestination,
      );
    }
    final learned = _matchingRule(domain, learnedBlocked);
    if (learned != null) {
      return RouteDecision(
        RouteTarget.proxy,
        RouteReason.learnedBlocked,
        learned,
      );
    }
    final blocked = _matchingRule(domain, knownBlocked);
    if (blocked != null) {
      return RouteDecision(
        RouteTarget.proxy,
        RouteReason.knownBlocked,
        blocked,
      );
    }
    return const RouteDecision(RouteTarget.direct, RouteReason.defaultDirect);
  }

  bool addRule(RouteTarget target, String input) {
    final domain = normalizeDomain(input);
    if (domain.isEmpty) {
      return false;
    }
    final rules = target == RouteTarget.direct ? manualDirect : manualProxy;
    if (rules.contains(domain)) {
      return false;
    }
    rules.add(domain);
    rules.sort();
    return true;
  }

  void removeRule(RouteTarget target, String domain) {
    final rules = target == RouteTarget.direct ? manualDirect : manualProxy;
    rules.remove(domain);
  }
}

String normalizeDomain(String input) {
  var value = input.trim().toLowerCase();
  final uri = Uri.tryParse(value);
  if (uri != null && uri.host.isNotEmpty) {
    value = uri.host;
  } else {
    final colon = value.lastIndexOf(':');
    if (colon > 0 && !value.contains(']')) {
      final possiblePort = int.tryParse(value.substring(colon + 1));
      if (possiblePort != null) {
        value = value.substring(0, colon);
      }
    }
  }
  while (value.endsWith('.')) {
    value = value.substring(0, value.length - 1);
  }
  return value;
}

String? _matchingRule(String domain, List<String> rules) {
  for (final rule in rules) {
    if (domain == rule || domain.endsWith('.$rule')) {
      return rule;
    }
  }
  return null;
}
