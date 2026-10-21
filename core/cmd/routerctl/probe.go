package main

import (
	"context"
	"flag"
	"time"

	"adaptivevpn.local/core/networkscope"
	"adaptivevpn.local/core/observer"
	"adaptivevpn.local/core/router"
)

func probeRoute(args []string) {
	flags := flag.NewFlagSet("probe", flag.ExitOnError)
	domain := flags.String("domain", "", "destination domain")
	port := flags.Int("port", 443, "destination port")
	useTLS := flags.Bool("tls", true, "perform a TLS handshake")
	network := flags.String("network", "unknown", "network fingerprint")
	proxy := flags.String("proxy", "127.0.0.1:2080", "local SOCKS proxy address")
	timeout := flags.Duration("timeout", 8*time.Second, "timeout for each path")
	state := flags.String("state", defaultStatePath(), "learned-state path")
	rules := flags.String("rules", "", "live learned rule-set path")
	threshold := flags.Int("threshold", 2, "verified observations required")
	flags.Parse(args)
	resolvedNetwork := networkscope.Resolve(*network)

	learner := router.NewLearner(*threshold, defaultLearningTTL)
	if err := learner.Load(*state); err != nil {
		fail("load learned routes: %v", err)
	}
	learner.Prune()
	routeObserver, err := observer.New(observer.NetworkProber{
		ProxyAddress: *proxy,
		Timeout:      *timeout,
	}, learner, *state)
	if err != nil {
		fail("create route observer: %v", err)
	}
	result, err := routeObserver.Check(context.Background(), observer.Target{
		Domain:  *domain,
		Port:    *port,
		Network: resolvedNetwork,
		TLS:     *useTLS,
	})
	if err != nil {
		fail("probe route: %v", err)
	}
	if *rules != "" {
		if err := writeLearnedRuleSet(
			*rules,
			router.NewEngine(router.Policy{}, learner),
			resolvedNetwork,
		); err != nil {
			fail("refresh learned route rules: %v", err)
		}
	}
	writeJSON(result)
}
