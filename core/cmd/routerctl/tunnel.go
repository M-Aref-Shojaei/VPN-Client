package main

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"time"

	"adaptivevpn.local/core/configbuilder"
	"adaptivevpn.local/core/networkscope"
	"adaptivevpn.local/core/router"
	"adaptivevpn.local/core/tunnel"
)

const maxControlRequestBytes = 1024 * 1024
const defaultLearningTTL = 24 * time.Hour

type controlRequest struct {
	Profile json.RawMessage `json:"profile"`
	Policy  router.Policy   `json:"policy"`
	Network string          `json:"network"`
	TUN     *bool           `json:"tun,omitempty"`
}

type tunnelPaths struct {
	core         string
	checksum     string
	config       string
	state        string
	log          string
	learned      string
	learnedRules string
	runtimeDir   string
}

func tunnelCapability(args []string) {
	_, paths := tunnelFlags("capability", args)
	if runtime.GOOS != "linux" && runtime.GOOS != "windows" {
		writeJSON(map[string]any{
			"available": false,
			"message":   "The desktop process adapter is currently implemented only on Linux and Windows.",
		})
		return
	}
	if err := verifyCore(paths.core, paths.checksum); err != nil {
		writeJSON(map[string]any{"available": false, "message": err.Error()})
		return
	}
	manager, err := newTunnelManager(paths)
	if err != nil {
		writeJSON(map[string]any{"available": false, "message": err.Error()})
		return
	}
	status, err := manager.Status()
	if err != nil {
		writeJSON(map[string]any{"available": false, "message": err.Error()})
		return
	}
	writeJSON(map[string]any{
		"available": true,
		"message":   "Verified sing-box core and privileged desktop lifecycle adapter are ready.",
		"running":   status.Running,
	})
}

func startTunnel(args []string) {
	_, paths := tunnelFlags("start", args)
	if err := verifyCore(paths.core, paths.checksum); err != nil {
		fail("%v", err)
	}
	request := readControlRequest()
	if len(request.Profile) == 0 {
		fail("profile is required")
	}
	request.Network = networkscope.Resolve(request.Network)
	enableTUN := true
	if request.TUN != nil {
		enableTUN = *request.TUN
	}
	options := configbuilder.DefaultOptions()
	options.EnableTUN = enableTUN
	options.EnableMixed = true
	options.LearnedRuleSetPath = paths.learnedRules

	learner := router.NewLearner(2, defaultLearningTTL)
	if err := learner.Load(paths.learned); err != nil {
		fail("load learned routes: %v", err)
	}
	learner.Prune()
	engine := router.NewEngine(request.Policy, learner)
	if err := writeLearnedRuleSet(paths.learnedRules, engine, request.Network); err != nil {
		fail("write learned route rules: %v", err)
	}
	profile := configbuilder.Profile{
		ID:       "active",
		Name:     "Active profile",
		Outbound: request.Profile,
	}
	config, err := configbuilder.Build(profile, engine.SingBoxRoute(request.Network), options)
	if err != nil {
		fail("build runtime configuration: %v", err)
	}
	if err := tunnel.WritePrivateFile(paths.config, append(config, '\n')); err != nil {
		fail("%v", err)
	}
	manager, err := newTunnelManager(paths)
	if err != nil {
		fail("%v", err)
	}
	state, err := manager.Start(context.Background())
	if err != nil {
		fail("%v", err)
	}
	writeJSON(map[string]any{
		"running": true,
		"pid":     state.PID,
		"message": "Tunnel started.",
	})
}

func stopTunnel(args []string) {
	_, paths := tunnelFlags("stop", args)
	manager, err := newTunnelManager(paths)
	if err != nil {
		fail("%v", err)
	}
	if err := manager.Stop(); err != nil {
		fail("%v", err)
	}
	writeJSON(map[string]any{"running": false, "message": "Tunnel stopped."})
}

func tunnelStatus(args []string) {
	_, paths := tunnelFlags("status", args)
	manager, err := newTunnelManager(paths)
	if err != nil {
		fail("%v", err)
	}
	status, err := manager.Status()
	if err != nil {
		fail("%v", err)
	}
	writeJSON(status)
}

func tunnelFlags(name string, args []string) (*flag.FlagSet, tunnelPaths) {
	defaults := defaultTunnelPaths()
	flags := flag.NewFlagSet(name, flag.ExitOnError)
	core := flags.String("core", defaults.core, "sing-box executable path")
	checksum := flags.String("core-sha256", defaults.checksum, "expected sing-box SHA-256")
	runtimeDir := flags.String("runtime-dir", defaults.runtimeDir, "private runtime directory")
	flags.Parse(args)
	paths := tunnelPaths{
		core:       *core,
		checksum:   strings.ToLower(strings.TrimSpace(*checksum)),
		runtimeDir: *runtimeDir,
	}
	paths.config = filepath.Join(paths.runtimeDir, "sing-box.json")
	paths.state = filepath.Join(paths.runtimeDir, "core-state.json")
	paths.log = filepath.Join(paths.runtimeDir, "sing-box.log")
	paths.learned = filepath.Join(filepath.Dir(paths.runtimeDir), "learned-routes.json")
	paths.learnedRules = filepath.Join(paths.runtimeDir, "learned-routes.rules.json")
	return flags, paths
}

func writeLearnedRuleSet(path string, engine *router.Engine, network string) error {
	data, err := engine.MarshalLearnedRuleSet(network)
	if err != nil {
		return err
	}
	return tunnel.WritePrivateFile(path, append(data, '\n'))
}

func defaultTunnelPaths() tunnelPaths {
	configDirectory, err := os.UserConfigDir()
	if err != nil {
		configDirectory = "."
	}
	runtimeDirectory := filepath.Join(configDirectory, "adaptive-vpn", "runtime")
	corePath := strings.TrimSpace(os.Getenv("ADAPTIVE_VPN_CORE"))
	checksum := strings.TrimSpace(os.Getenv("ADAPTIVE_VPN_CORE_SHA256"))
	if corePath == "" {
		corePath = discoverDevelopmentCore()
	}
	if checksum == "" {
		checksum = discoverDevelopmentChecksum()
	}
	return tunnelPaths{core: corePath, checksum: checksum, runtimeDir: runtimeDirectory}
}

func discoverDevelopmentCore() string {
	executable, err := os.Executable()
	if err == nil {
		candidate := filepath.Clean(filepath.Join(filepath.Dir(executable), "..", "bin", "sing_box", "sing-box"))
		if isRegularFile(candidate) {
			return candidate
		}
	}
	workingDirectory, err := os.Getwd()
	if err == nil {
		for _, candidate := range []string{
			filepath.Join(workingDirectory, "bin", "sing_box", "sing-box"),
			filepath.Join(workingDirectory, "..", "bin", "sing_box", "sing-box"),
		} {
			if isRegularFile(candidate) {
				return candidate
			}
		}
	}
	return "sing-box"
}

func discoverDevelopmentChecksum() string {
	for _, base := range developmentRoots() {
		data, err := os.ReadFile(filepath.Join(base, "packaging", "sing-box-linux-amd64.sha256"))
		if err == nil {
			fields := strings.Fields(string(data))
			if len(fields) > 0 {
				return fields[0]
			}
		}
	}
	return ""
}

func developmentRoots() []string {
	roots := make([]string, 0, 3)
	if executable, err := os.Executable(); err == nil {
		roots = append(roots, filepath.Clean(filepath.Join(filepath.Dir(executable), "..")))
	}
	if workingDirectory, err := os.Getwd(); err == nil {
		roots = append(roots, workingDirectory, filepath.Clean(filepath.Join(workingDirectory, "..")))
	}
	return roots
}

func verifyCore(path, expected string) error {
	if expected == "" {
		return errors.New("sing-box checksum is not configured")
	}
	if len(expected) != sha256.Size*2 {
		return errors.New("sing-box checksum must be a 64-character SHA-256 value")
	}
	file, err := os.Open(path)
	if err != nil {
		return fmt.Errorf("open sing-box core: %w", err)
	}
	defer file.Close()
	hash := sha256.New()
	if _, err := io.Copy(hash, file); err != nil {
		return fmt.Errorf("hash sing-box core: %w", err)
	}
	actual := hex.EncodeToString(hash.Sum(nil))
	if actual != expected {
		return errors.New("sing-box checksum verification failed")
	}
	return nil
}

func newTunnelManager(paths tunnelPaths) (*tunnel.Manager, error) {
	return tunnel.NewManager(tunnel.Options{
		BinaryPath: paths.core,
		ConfigPath: paths.config,
		StatePath:  paths.state,
		LogPath:    paths.log,
	})
}

func readControlRequest() controlRequest {
	decoder := json.NewDecoder(io.LimitReader(os.Stdin, maxControlRequestBytes))
	decoder.DisallowUnknownFields()
	var request controlRequest
	if err := decoder.Decode(&request); err != nil {
		fail("decode control request: %v", err)
	}
	return request
}

func isRegularFile(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.Mode().IsRegular()
}
