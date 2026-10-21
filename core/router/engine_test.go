package router

import (
	"encoding/json"
	"path/filepath"
	"testing"
	"time"
)

func TestDecisionPrecedence(t *testing.T) {
	learner := NewLearner(1, time.Hour)
	learner.now = func() time.Time { return time.Unix(1000, 0) }
	learner.Observe(Observation{
		Domain:         "learned.example",
		Network:        "home",
		Signal:         SignalTimeout,
		ProxySucceeded: true,
	})
	engine := NewEngine(Policy{
		ManualDirect: []string{"safe.example"},
		ManualProxy:  []string{"forced.example"},
		KnownBlocked: []string{"blocked.example"},
	}, learner)

	tests := []struct {
		name        string
		destination Destination
		wantRoute   Route
		wantReason  Reason
	}{
		{"manual direct includes subdomains", Destination{Domain: "api.safe.example"}, RouteDirect, ReasonManualDirect},
		{"manual proxy", Destination{Domain: "forced.example"}, RouteProxy, ReasonManualProxy},
		{"private ip", Destination{IP: "192.168.1.1"}, RouteDirect, ReasonPrivate},
		{"learned blocked", Destination{Domain: "learned.example"}, RouteProxy, ReasonLearned},
		{"known blocked", Destination{Domain: "blocked.example"}, RouteProxy, ReasonKnownBlocked},
		{"unknown defaults direct", Destination{Domain: "open.example"}, RouteDirect, ReasonDefault},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			got := engine.Decide("home", test.destination)
			if got.Route != test.wantRoute || got.Reason != test.wantReason {
				t.Fatalf("got %s/%s, want %s/%s", got.Route, got.Reason, test.wantRoute, test.wantReason)
			}
		})
	}
}

func TestLearnerRequiresStrongSuccessfulFallbackEvidence(t *testing.T) {
	learner := NewLearner(2, time.Hour)
	now := time.Unix(1000, 0)
	learner.now = func() time.Time { return now }

	if _, learned := learner.Observe(Observation{Domain: "example.com", Signal: SignalTimeout}); learned {
		t.Fatal("observation without proxy success must be ignored")
	}
	if _, learned := learner.Observe(Observation{
		Domain: "example.com", Signal: SignalTimeout, ProxySucceeded: true, PayloadForwarded: true,
	}); learned {
		t.Fatal("observation after payload forwarding must be ignored")
	}

	observation := Observation{
		Domain: "example.com", Network: "isp-a", Signal: SignalTCPReset, ProxySucceeded: true,
	}
	learner.Observe(observation)
	if learner.IsBlocked("isp-a", "example.com") {
		t.Fatal("one observation must not reach the threshold")
	}
	learner.Observe(observation)
	if !learner.IsBlocked("isp-a", "example.com") {
		t.Fatal("two observations should mark the domain blocked")
	}
	if learner.IsBlocked("isp-b", "example.com") {
		t.Fatal("learning must be isolated by network")
	}
}

func TestLearnerRoundTrip(t *testing.T) {
	path := filepath.Join(t.TempDir(), "learned.json")
	learner := NewLearner(1, time.Hour)
	learner.Observe(Observation{
		Domain: "example.com", Network: "home", Signal: SignalTLSFailure, ProxySucceeded: true,
	})
	if err := learner.Save(path); err != nil {
		t.Fatal(err)
	}

	loaded := NewLearner(1, time.Hour)
	if err := loaded.Load(path); err != nil {
		t.Fatal(err)
	}
	if len(loaded.Entries()) != 1 {
		t.Fatalf("got %d entries, want 1", len(loaded.Entries()))
	}
}

func TestNormalizeDomain(t *testing.T) {
	tests := map[string]string{
		"HTTPS://Example.COM/path": "example.com",
		"example.com.":             "example.com",
		"example.com:443":          "example.com",
		" [2001:db8::1] ":          "2001:db8::1",
	}
	for input, want := range tests {
		if got := NormalizeDomain(input); got != want {
			t.Fatalf("NormalizeDomain(%q) = %q, want %q", input, got, want)
		}
	}
}

func TestSingBoxRouteOmitsEmptyDomainRules(t *testing.T) {
	engine := NewEngine(Policy{}, nil)
	route := engine.SingBoxRoute("home")
	if len(route.Rules) != 1 {
		t.Fatalf("got %d rules, want only the private-IP rule", len(route.Rules))
	}
	if !route.Rules[0].IPIsPrivate || route.Final != "direct" {
		t.Fatalf("unexpected direct-by-default route: %#v", route)
	}
}

func TestLearnedRuleSetContainsOnlyActiveNetworkEntries(t *testing.T) {
	learner := NewLearner(1, time.Hour)
	learner.Observe(Observation{
		Domain: "blocked.example", Network: "home", Signal: SignalTimeout, ProxySucceeded: true,
	})
	learner.Observe(Observation{
		Domain: "other.example", Network: "office", Signal: SignalTimeout, ProxySucceeded: true,
	})
	data, err := NewEngine(Policy{}, learner).MarshalLearnedRuleSet("home")
	if err != nil {
		t.Fatal(err)
	}
	var source SingBoxRuleSetSource
	if err := json.Unmarshal(data, &source); err != nil {
		t.Fatal(err)
	}
	if source.Version != 3 || len(source.Rules) != 1 ||
		len(source.Rules[0].DomainSuffix) != 1 ||
		source.Rules[0].DomainSuffix[0] != "blocked.example" {
		t.Fatalf("unexpected learned rule-set: %#v", source)
	}
}
