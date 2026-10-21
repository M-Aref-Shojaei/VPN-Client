package configbuilder

import (
	"encoding/json"
	"testing"

	"adaptivevpn.local/core/router"
)

func TestBuildCreatesRunnableShapeWithoutChangingCredentials(t *testing.T) {
	profile := Profile{
		ID:   "profile-1",
		Name: "Example",
		Outbound: json.RawMessage(`{
			"type": "vless",
			"server": "example.invalid",
			"server_port": 443,
			"uuid": "00000000-0000-0000-0000-000000000000"
		}`),
	}
	engine := router.NewEngine(router.Policy{
		ManualDirect: []string{"bank.example"},
		KnownBlocked: []string{"blocked.example"},
	}, nil)

	data, err := Build(profile, engine.SingBoxRoute("home"), DefaultOptions())
	if err != nil {
		t.Fatal(err)
	}

	var config map[string]any
	if err := json.Unmarshal(data, &config); err != nil {
		t.Fatal(err)
	}
	outbounds := config["outbounds"].([]any)
	proxy := outbounds[0].(map[string]any)
	if proxy["tag"] != "proxy" || proxy["server"] != "example.invalid" {
		t.Fatalf("unexpected proxy outbound: %#v", proxy)
	}
	route := config["route"].(map[string]any)
	if route["final"] != "direct" ||
		route["auto_detect_interface"] != true ||
		route["default_domain_resolver"] != "local-dns" {
		t.Fatalf("unexpected route defaults: %#v", route)
	}
}

func TestBuildRejectsUnsafeOrIncompleteProfiles(t *testing.T) {
	tests := []Profile{
		{},
		{Outbound: json.RawMessage(`{"type":"direct"}`)},
		{Outbound: json.RawMessage(`{"server":"example.invalid"}`)},
	}
	for _, profile := range tests {
		if _, err := Build(profile, router.SingBoxRoute{}, DefaultOptions()); err == nil {
			t.Fatalf("expected profile to fail: %s", profile.Outbound)
		}
	}
}

func TestBuildPlacesWireGuardInEndpoints(t *testing.T) {
	profile := Profile{
		ID:   "wireguard-1",
		Name: "WireGuard",
		Outbound: json.RawMessage(`{
			"type": "wireguard",
			"address": ["10.0.0.2/32"],
			"private_key": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
			"peers": [{
				"address": "example.invalid",
				"port": 51820,
				"public_key": "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=",
				"allowed_ips": ["0.0.0.0/0"]
			}]
		}`),
	}
	data, err := Build(
		profile,
		router.NewEngine(router.Policy{}, nil).SingBoxRoute("test"),
		DefaultOptions(),
	)
	if err != nil {
		t.Fatal(err)
	}
	var config map[string]any
	if err := json.Unmarshal(data, &config); err != nil {
		t.Fatal(err)
	}
	endpoints, ok := config["endpoints"].([]any)
	if !ok || len(endpoints) != 1 {
		t.Fatalf("wireguard endpoint missing: %#v", config["endpoints"])
	}
	outbounds := config["outbounds"].([]any)
	if len(outbounds) != 1 ||
		outbounds[0].(map[string]any)["tag"] != "direct" {
		t.Fatalf("unexpected wireguard outbounds: %#v", outbounds)
	}
}

func TestBuildAddsReloadableLearnedRuleSetAfterDirectOverrides(t *testing.T) {
	profile := Profile{Outbound: json.RawMessage(`{
		"type":"vless","server":"example.invalid","server_port":443,
		"uuid":"00000000-0000-0000-0000-000000000000"
	}`)}
	options := DefaultOptions()
	options.LearnedRuleSetPath = "/private/learned-routes.rules.json"
	data, err := Build(
		profile,
		router.NewEngine(router.Policy{ManualDirect: []string{"safe.example"}}, nil).SingBoxRoute("home"),
		options,
	)
	if err != nil {
		t.Fatal(err)
	}
	var config map[string]any
	if err := json.Unmarshal(data, &config); err != nil {
		t.Fatal(err)
	}
	route := config["route"].(map[string]any)
	ruleSets := route["rule_set"].([]any)
	if len(ruleSets) != 1 ||
		ruleSets[0].(map[string]any)["path"] != options.LearnedRuleSetPath {
		t.Fatalf("unexpected local rule-set: %#v", ruleSets)
	}
	rules := route["rules"].([]any)
	directIndex, learnedIndex := -1, -1
	for index, item := range rules {
		rule := item.(map[string]any)
		if _, ok := rule["domain_suffix"]; ok && rule["outbound"] == "direct" {
			directIndex = index
		}
		if _, ok := rule["rule_set"]; ok && rule["outbound"] == "proxy" {
			learnedIndex = index
		}
	}
	if directIndex < 0 || learnedIndex <= directIndex {
		t.Fatalf("direct override must precede learned proxy rule: %#v", rules)
	}
}

func TestBuildForcesObserverMixedInboundThroughProxy(t *testing.T) {
	profile := Profile{Outbound: json.RawMessage(`{
		"type":"vless","server":"example.invalid","server_port":443,
		"uuid":"00000000-0000-0000-0000-000000000000"
	}`)}
	data, err := Build(profile, router.SingBoxRoute{Final: "direct"}, DefaultOptions())
	if err != nil {
		t.Fatal(err)
	}
	var config map[string]any
	if err := json.Unmarshal(data, &config); err != nil {
		t.Fatal(err)
	}
	rules := config["route"].(map[string]any)["rules"].([]any)
	if len(rules) < 2 {
		t.Fatalf("missing mixed inbound rule: %#v", rules)
	}
	mixedRule := rules[1].(map[string]any)
	if mixedRule["outbound"] != "proxy" {
		t.Fatalf("mixed inbound must use the real proxy outbound: %#v", mixedRule)
	}
	inbounds := mixedRule["inbound"].([]any)
	if len(inbounds) != 1 || inbounds[0] != "mixed-in" {
		t.Fatalf("unexpected mixed inbound match: %#v", mixedRule)
	}
}
