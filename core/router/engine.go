package router

import (
	"net"
	"sort"
)

type Policy struct {
	ManualDirect []string `json:"manual_direct"`
	ManualProxy  []string `json:"manual_proxy"`
	KnownBlocked []string `json:"known_blocked"`
}

type Engine struct {
	policy  Policy
	learner *Learner
}

func NewEngine(policy Policy, learner *Learner) *Engine {
	if learner == nil {
		learner = NewLearner(2, 0)
	}
	policy.ManualDirect = normalizedRules(policy.ManualDirect)
	policy.ManualProxy = normalizedRules(policy.ManualProxy)
	policy.KnownBlocked = normalizedRules(policy.KnownBlocked)
	return &Engine{policy: policy, learner: learner}
}

func normalizedRules(rules []string) []string {
	unique := make(map[string]struct{}, len(rules))
	for _, rule := range rules {
		if normalized := NormalizeDomain(rule); normalized != "" {
			unique[normalized] = struct{}{}
		}
	}
	result := make([]string, 0, len(unique))
	for rule := range unique {
		result = append(result, rule)
	}
	sort.Strings(result)
	return result
}

func (e *Engine) Decide(network string, destination Destination) Decision {
	domain := NormalizeDomain(destination.Domain)

	if match := matchingRule(domain, e.policy.ManualDirect); match != "" {
		return Decision{Route: RouteDirect, Reason: ReasonManualDirect, Match: match}
	}
	if match := matchingRule(domain, e.policy.ManualProxy); match != "" {
		return Decision{Route: RouteProxy, Reason: ReasonManualProxy, Match: match}
	}
	if isPrivate(destination.IP) || isLocalDomain(domain) {
		return Decision{Route: RouteDirect, Reason: ReasonPrivate}
	}
	if e.learner.IsBlocked(network, domain) {
		return Decision{Route: RouteProxy, Reason: ReasonLearned, Match: domain}
	}
	if match := matchingRule(domain, e.policy.KnownBlocked); match != "" {
		return Decision{Route: RouteProxy, Reason: ReasonKnownBlocked, Match: match}
	}
	return Decision{Route: RouteDirect, Reason: ReasonDefault}
}

func isPrivate(value string) bool {
	ip := net.ParseIP(value)
	return ip != nil && (ip.IsPrivate() || ip.IsLoopback() || ip.IsLinkLocalUnicast() || ip.IsUnspecified())
}

func isLocalDomain(domain string) bool {
	return domain == "localhost" || matchesDomain(domain, "local")
}
