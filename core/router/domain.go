package router

import (
	"net"
	"net/url"
	"strings"
)

func NormalizeDomain(value string) string {
	value = strings.TrimSpace(strings.ToLower(value))
	if value == "" {
		return ""
	}

	if parsed, err := url.Parse(value); err == nil && parsed.Hostname() != "" {
		value = parsed.Hostname()
	} else if host, _, err := net.SplitHostPort(value); err == nil {
		value = host
	}

	return strings.TrimSuffix(strings.Trim(value, "[]"), ".")
}

func matchesDomain(domain, rule string) bool {
	domain = NormalizeDomain(domain)
	rule = NormalizeDomain(rule)
	if domain == "" || rule == "" {
		return false
	}
	return domain == rule || strings.HasSuffix(domain, "."+rule)
}

func matchingRule(domain string, rules []string) string {
	for _, rule := range rules {
		if matchesDomain(domain, rule) {
			return NormalizeDomain(rule)
		}
	}
	return ""
}
