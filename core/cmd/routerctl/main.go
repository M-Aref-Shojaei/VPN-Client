package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"adaptivevpn.local/core/configbuilder"
	"adaptivevpn.local/core/router"
)

func main() {
	if len(os.Args) < 2 {
		fail("usage: routerctl <serve|service|capability|start|stop|status|probe|decide|learn|export|build> [options]")
	}
	if forwardToService(os.Args[1], os.Args[2:]) {
		return
	}

	switch os.Args[1] {
	case "serve":
		serveTunnel(os.Args[2:])
	case "service":
		platformService(os.Args[2:])
	case "capability":
		tunnelCapability(os.Args[2:])
	case "start":
		startTunnel(os.Args[2:])
	case "stop":
		stopTunnel(os.Args[2:])
	case "status":
		tunnelStatus(os.Args[2:])
	case "probe":
		probeRoute(os.Args[2:])
	case "decide":
		decide(os.Args[2:])
	case "learn":
		learn(os.Args[2:])
	case "export":
		exportRoute(os.Args[2:])
	case "build":
		buildConfig(os.Args[2:])
	default:
		fail("unknown command %q", os.Args[1])
	}
}

func buildConfig(args []string) {
	flags := flag.NewFlagSet("build", flag.ExitOnError)
	profilePath := flags.String("profile", "", "profile JSON path")
	network := flags.String("network", "unknown", "network fingerprint")
	state := flags.String("state", defaultStatePath(), "learned-state path")
	policyPath := flags.String("policy", "", "policy JSON path")
	tun := flags.Bool("tun", true, "enable TUN inbound")
	mixed := flags.Bool("mixed", true, "enable local mixed proxy inbound")
	mixedPort := flags.Int("mixed-port", 2080, "local mixed proxy port")
	flags.Parse(args)
	if *profilePath == "" {
		fail("profile path is required")
	}

	data, err := os.ReadFile(*profilePath)
	if err != nil {
		fail("read profile: %v", err)
	}
	var profile configbuilder.Profile
	if err := json.Unmarshal(data, &profile); err != nil {
		fail("parse profile: %v", err)
	}
	options := configbuilder.DefaultOptions()
	options.EnableTUN = *tun
	options.EnableMixed = *mixed
	options.MixedPort = *mixedPort
	config, err := configbuilder.Build(
		profile,
		loadEngine(*policyPath, *state).SingBoxRoute(*network),
		options,
	)
	if err != nil {
		fail("build config: %v", err)
	}
	fmt.Println(string(config))
}

func decide(args []string) {
	flags := flag.NewFlagSet("decide", flag.ExitOnError)
	domain := flags.String("domain", "", "destination domain")
	ip := flags.String("ip", "", "destination IP")
	network := flags.String("network", "unknown", "network fingerprint")
	state := flags.String("state", defaultStatePath(), "learned-state path")
	policyPath := flags.String("policy", "", "policy JSON path")
	flags.Parse(args)

	engine := loadEngine(*policyPath, *state)
	writeJSON(engine.Decide(*network, router.Destination{Domain: *domain, IP: *ip}))
}

func learn(args []string) {
	flags := flag.NewFlagSet("learn", flag.ExitOnError)
	domain := flags.String("domain", "", "destination domain")
	network := flags.String("network", "unknown", "network fingerprint")
	signal := flags.String("signal", "", "blocking signal")
	proxySucceeded := flags.Bool("proxy-succeeded", false, "proxy retry succeeded")
	payloadForwarded := flags.Bool("payload-forwarded", false, "application payload was already forwarded")
	state := flags.String("state", defaultStatePath(), "learned-state path")
	flags.Parse(args)

	learner := router.NewLearner(2, 24*time.Hour)
	if err := learner.Load(*state); err != nil {
		fail("load state: %v", err)
	}
	entry, accepted := learner.Observe(router.Observation{
		Domain:           *domain,
		Network:          *network,
		Signal:           router.Signal(*signal),
		ProxySucceeded:   *proxySucceeded,
		PayloadForwarded: *payloadForwarded,
	})
	if accepted {
		if err := learner.Save(*state); err != nil {
			fail("save state: %v", err)
		}
	}
	writeJSON(map[string]any{"accepted": accepted, "entry": entry})
}

func exportRoute(args []string) {
	flags := flag.NewFlagSet("export", flag.ExitOnError)
	network := flags.String("network", "unknown", "network fingerprint")
	state := flags.String("state", defaultStatePath(), "learned-state path")
	policyPath := flags.String("policy", "", "policy JSON path")
	flags.Parse(args)

	data, err := loadEngine(*policyPath, *state).MarshalSingBoxRoute(*network)
	if err != nil {
		fail("export route: %v", err)
	}
	fmt.Println(string(data))
}

func loadEngine(policyPath, statePath string) *router.Engine {
	policy := router.Policy{}
	if policyPath != "" {
		data, err := os.ReadFile(policyPath)
		if err != nil {
			fail("read policy: %v", err)
		}
		if err := json.Unmarshal(data, &policy); err != nil {
			fail("parse policy: %v", err)
		}
	}
	learner := router.NewLearner(2, 24*time.Hour)
	if err := learner.Load(statePath); err != nil {
		fail("load state: %v", err)
	}
	learner.Prune()
	return router.NewEngine(policy, learner)
}

func defaultStatePath() string {
	configDir, err := os.UserConfigDir()
	if err != nil {
		return "learned-routes.json"
	}
	return filepath.Join(configDir, "adaptive-vpn", "learned-routes.json")
}

func writeJSON(value any) {
	encoder := json.NewEncoder(os.Stdout)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(value); err != nil {
		fail("encode result: %v", err)
	}
}

func fail(format string, args ...any) {
	fmt.Fprintf(os.Stderr, format+"\n", args...)
	os.Exit(1)
}
