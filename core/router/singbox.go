package router

import (
	"encoding/json"
	"sort"
)

type SingBoxRoute struct {
	Rules                 []SingBoxRule    `json:"rules"`
	RuleSets              []SingBoxRuleSet `json:"rule_set,omitempty"`
	Final                 string           `json:"final"`
	AutoDetectInterface   bool             `json:"auto_detect_interface,omitempty"`
	DefaultDomainResolver string           `json:"default_domain_resolver,omitempty"`
}

type SingBoxRule struct {
	DomainSuffix []string `json:"domain_suffix,omitempty"`
	RuleSet      []string `json:"rule_set,omitempty"`
	Inbound      []string `json:"inbound,omitempty"`
	IPIsPrivate  bool     `json:"ip_is_private,omitempty"`
	Protocol     string   `json:"protocol,omitempty"`
	Action       string   `json:"action"`
	Outbound     string   `json:"outbound,omitempty"`
}

type SingBoxRuleSet struct {
	Type   string `json:"type"`
	Tag    string `json:"tag"`
	Format string `json:"format"`
	Path   string `json:"path"`
}

type SingBoxRuleSetSource struct {
	Version int                   `json:"version"`
	Rules   []SingBoxHeadlessRule `json:"rules"`
}

type SingBoxHeadlessRule struct {
	DomainSuffix []string `json:"domain_suffix,omitempty"`
}

func (e *Engine) SingBoxRoute(network string) SingBoxRoute {
	proxyDomains := append([]string{}, e.policy.ManualProxy...)
	proxyDomains = append(proxyDomains, e.policy.KnownBlocked...)
	for _, entry := range e.learner.Entries() {
		if entry.Network == NormalizeDomain(network) && e.learner.IsBlocked(network, entry.Domain) {
			proxyDomains = append(proxyDomains, entry.Domain)
		}
	}

	rules := make([]SingBoxRule, 0, 3)
	if len(e.policy.ManualDirect) > 0 {
		rules = append(rules, SingBoxRule{
			DomainSuffix: e.policy.ManualDirect,
			Action:       "route",
			Outbound:     "direct",
		})
	}
	rules = append(rules, SingBoxRule{
		IPIsPrivate: true,
		Action:      "route",
		Outbound:    "direct",
	})
	if proxyDomains = normalizedRules(proxyDomains); len(proxyDomains) > 0 {
		rules = append(rules, SingBoxRule{
			DomainSuffix: proxyDomains,
			Action:       "route",
			Outbound:     "proxy",
		})
	}

	return SingBoxRoute{
		Rules: rules,
		Final: "direct",
	}
}

func (e *Engine) MarshalSingBoxRoute(network string) ([]byte, error) {
	route := e.SingBoxRoute(network)
	for index := range route.Rules {
		sort.Strings(route.Rules[index].DomainSuffix)
	}
	return json.MarshalIndent(map[string]SingBoxRoute{"route": route}, "", "  ")
}

func (e *Engine) LearnedRuleSet(network string) SingBoxRuleSetSource {
	domains := make([]string, 0)
	for _, entry := range e.learner.Entries() {
		if entry.Network == NormalizeDomain(network) && e.learner.IsBlocked(network, entry.Domain) {
			domains = append(domains, entry.Domain)
		}
	}
	domains = normalizedRules(domains)
	rules := make([]SingBoxHeadlessRule, 0, 1)
	if len(domains) > 0 {
		rules = append(rules, SingBoxHeadlessRule{DomainSuffix: domains})
	}
	return SingBoxRuleSetSource{Version: 3, Rules: rules}
}

func (e *Engine) MarshalLearnedRuleSet(network string) ([]byte, error) {
	return json.MarshalIndent(e.LearnedRuleSet(network), "", "  ")
}
