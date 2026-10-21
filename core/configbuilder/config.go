package configbuilder

import (
	"encoding/json"
	"errors"
	"fmt"

	"adaptivevpn.local/core/router"
)

type Profile struct {
	ID       string          `json:"id"`
	Name     string          `json:"name"`
	Outbound json.RawMessage `json:"outbound"`
}

type Options struct {
	EnableTUN          bool
	EnableMixed        bool
	MixedPort          int
	LogLevel           string
	RemoteDNSServer    string
	LearnedRuleSetPath string
}

func DefaultOptions() Options {
	return Options{
		EnableTUN:       true,
		EnableMixed:     true,
		MixedPort:       2080,
		LogLevel:        "warn",
		RemoteDNSServer: "1.1.1.1",
	}
}

func Build(profile Profile, route router.SingBoxRoute, options Options) ([]byte, error) {
	proxy, err := decodeOutbound(profile.Outbound)
	if err != nil {
		return nil, err
	}
	proxy["tag"] = "proxy"
	proxyType, _ := proxy["type"].(string)
	isEndpoint := proxyType == "wireguard"

	if options.MixedPort < 1 || options.MixedPort > 65535 {
		return nil, errors.New("mixed proxy port must be between 1 and 65535")
	}
	if options.LogLevel == "" {
		options.LogLevel = "warn"
	}
	if options.RemoteDNSServer == "" {
		options.RemoteDNSServer = "1.1.1.1"
	}

	inbounds := make([]map[string]any, 0, 2)
	if options.EnableTUN {
		inbounds = append(inbounds, map[string]any{
			"type":         "tun",
			"tag":          "tun-in",
			"address":      []string{"172.19.0.1/30", "fdfe:dcba:9876::1/126"},
			"auto_route":   true,
			"strict_route": true,
			"stack":        "system",
		})
	}
	if options.EnableMixed {
		inbounds = append(inbounds, map[string]any{
			"type":        "mixed",
			"tag":         "mixed-in",
			"listen":      "127.0.0.1",
			"listen_port": options.MixedPort,
		})
	}
	if len(inbounds) == 0 {
		return nil, errors.New("at least one inbound must be enabled")
	}

	route.AutoDetectInterface = true
	route.DefaultDomainResolver = "local-dns"
	prefixRules := []router.SingBoxRule{{
		Protocol: "dns",
		Action:   "hijack-dns",
	}}
	if options.EnableMixed {
		prefixRules = append(prefixRules, router.SingBoxRule{
			Inbound:  []string{"mixed-in"},
			Action:   "route",
			Outbound: "proxy",
		})
	}
	route.Rules = append(prefixRules, route.Rules...)
	if options.LearnedRuleSetPath != "" {
		route.RuleSets = append(route.RuleSets, router.SingBoxRuleSet{
			Type:   "local",
			Tag:    "adaptive-learned",
			Format: "source",
			Path:   options.LearnedRuleSetPath,
		})
		route.Rules = append(route.Rules, router.SingBoxRule{
			RuleSet:  []string{"adaptive-learned"},
			Action:   "route",
			Outbound: "proxy",
		})
	}

	outbounds := []any{map[string]any{"type": "direct", "tag": "direct"}}
	endpoints := []any{}
	if isEndpoint {
		endpoints = append(endpoints, proxy)
	} else {
		outbounds = append([]any{proxy}, outbounds...)
	}

	config := map[string]any{
		"log": map[string]any{
			"level":     options.LogLevel,
			"timestamp": true,
		},
		"dns": map[string]any{
			"servers": []map[string]any{
				{"type": "local", "tag": "local-dns"},
				{
					"type":        "https",
					"tag":         "remote-dns",
					"server":      options.RemoteDNSServer,
					"server_port": 443,
					"path":        "/dns-query",
					"tls": map[string]any{
						"enabled":     true,
						"server_name": "cloudflare-dns.com",
					},
					"detour": "proxy",
				},
			},
			"final":           "remote-dns",
			"strategy":        "prefer_ipv4",
			"reverse_mapping": true,
		},
		"inbounds":  inbounds,
		"outbounds": outbounds,
		"route":     route,
	}
	if len(endpoints) > 0 {
		config["endpoints"] = endpoints
	}

	return json.MarshalIndent(config, "", "  ")
}

func decodeOutbound(raw json.RawMessage) (map[string]any, error) {
	if len(raw) == 0 {
		return nil, errors.New("profile outbound is required")
	}
	var outbound map[string]any
	if err := json.Unmarshal(raw, &outbound); err != nil {
		return nil, fmt.Errorf("parse profile outbound: %w", err)
	}
	outboundType, ok := outbound["type"].(string)
	if !ok || outboundType == "" {
		return nil, errors.New("profile outbound type is required")
	}
	switch outboundType {
	case "direct", "block", "dns", "selector", "urltest":
		return nil, fmt.Errorf("outbound type %q cannot be used as a proxy profile", outboundType)
	}
	return outbound, nil
}
