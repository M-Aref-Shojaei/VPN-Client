package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"sync"
	"time"

	"adaptivevpn.local/core/controlsocket"
	"adaptivevpn.local/core/failurewatch"
)

func forwardToService(command string, args []string) bool {
	if os.Getenv("ADAPTIVE_VPN_DAEMON_LOCAL") == "1" || command == "serve" {
		return false
	}
	switch command {
	case "capability", "start", "stop", "status", "probe":
	default:
		return false
	}
	socketPath := os.Getenv("ADAPTIVE_VPN_CONTROL_SOCKET")
	if socketPath == "" {
		socketPath = defaultControlEndpoint()
	}
	var payload json.RawMessage
	if command == "start" {
		data, err := io.ReadAll(io.LimitReader(os.Stdin, controlsocket.MaximumMessageBytes))
		if err != nil {
			fail("read control payload: %v", err)
		}
		payload = data
	}
	ctx, cancel := context.WithTimeout(context.Background(), 35*time.Second)
	defer cancel()
	response, err := controlsocket.Send(ctx, socketPath, controlsocket.Request{
		Command: command,
		Args:    args,
		Payload: payload,
	})
	if err != nil {
		// A start request has already consumed its credential-bearing stdin. It
		// cannot be replayed safely through the local command path after a failed
		// service connection. Development callers that intentionally want the
		// local path must set ADAPTIVE_VPN_DAEMON_LOCAL before invoking routerctl.
		if command == "start" || os.Getenv("ADAPTIVE_VPN_REQUIRE_SERVICE") == "1" {
			fail("privileged tunnel service is unavailable: %v", err)
		}
		return false
	}
	if response.Stdout != "" {
		fmt.Fprint(os.Stdout, response.Stdout)
	}
	if response.ExitCode != 0 {
		fail("%s", response.Stderr)
	}
	return true
}

func serveTunnel(args []string) {
	flags := flag.NewFlagSet("serve", flag.ExitOnError)
	core := flags.String("core", "", "fixed sing-box executable path")
	checksum := flags.String("core-sha256", "", "expected sing-box SHA-256")
	runtimeDirectory := flags.String("runtime-dir", "", "fixed private state directory")
	socket := flags.String("socket", defaultControlEndpoint(), "control endpoint path")
	pipeSDDL := flags.String("pipe-sddl", "", "Windows named-pipe security descriptor")
	flags.Parse(args)
	if *core == "" || *checksum == "" || *runtimeDirectory == "" {
		fail("core, core-sha256, and runtime-dir are required")
	}
	ctx, stop := signalContext()
	defer stop()
	if err := runTunnelServer(ctx, *socket, *pipeSDDL, *core, *checksum, *runtimeDirectory); err != nil {
		fail("serve tunnel control endpoint: %v", err)
	}
}

func runTunnelServer(
	ctx context.Context,
	endpoint, securityDescriptor, core, checksum, runtimeDirectory string,
) error {
	executable, err := os.Executable()
	if err != nil {
		return fmt.Errorf("resolve service executable: %w", err)
	}
	handler := &serviceHandler{
		ctx:        ctx,
		executable: executable,
		core:       core,
		checksum:   checksum,
		runtimeDir: runtimeDirectory,
	}
	handler.startFailureWatcher()
	defer handler.stopFailureWatcher()
	return (controlsocket.Server{
		SocketPath:         endpoint,
		SecurityDescriptor: securityDescriptor,
		Handler:            handler,
	}).Serve(ctx)
}

type serviceHandler struct {
	ctx         context.Context
	executable  string
	core        string
	checksum    string
	runtimeDir  string
	lifecycleMu sync.Mutex
	watchMu     sync.Mutex
	watchStop   context.CancelFunc
}

func (h *serviceHandler) Handle(ctx context.Context, request controlsocket.Request) controlsocket.Response {
	args, err := canonicalServiceArgs(request.Command, request.Args)
	if err != nil {
		return controlsocket.Response{ExitCode: 2, Stderr: err.Error()}
	}
	if isLifecycleCommand(request.Command) {
		h.lifecycleMu.Lock()
		defer h.lifecycleMu.Unlock()
	}
	switch request.Command {
	case "capability", "start", "stop", "status":
		args = append(args,
			"-core", h.core,
			"-core-sha256", h.checksum,
			"-runtime-dir", h.runtimeDir,
		)
	case "probe":
		args = append(args,
			"-state", filepath.Join(filepath.Dir(h.runtimeDir), "learned-routes.json"),
			"-rules", filepath.Join(h.runtimeDir, "learned-routes.rules.json"),
			"-proxy", "127.0.0.1:2080",
		)
	default:
		return controlsocket.Response{ExitCode: 2, Stderr: "unsupported service command"}
	}
	command := exec.CommandContext(ctx, h.executable, append([]string{request.Command}, args...)...)
	command.Env = append(os.Environ(), "ADAPTIVE_VPN_DAEMON_LOCAL=1")
	if len(request.Payload) > 0 {
		command.Stdin = bytes.NewReader(request.Payload)
	}
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	command.Stdout = &stdout
	command.Stderr = &stderr
	runErr := command.Run()
	exitCode := 0
	if runErr != nil {
		var exitError *exec.ExitError
		if errors.As(runErr, &exitError) {
			exitCode = exitError.ExitCode()
		} else {
			exitCode = 1
			if stderr.Len() == 0 {
				stderr.WriteString(runErr.Error())
			}
		}
	}
	response := controlsocket.Response{
		ExitCode: exitCode,
		Stdout:   stdout.String(),
		Stderr:   stderr.String(),
	}
	if response.ExitCode == 0 {
		switch request.Command {
		case "start":
			h.startFailureWatcher()
		case "stop":
			h.stopFailureWatcher()
		}
	}
	return response
}

func isLifecycleCommand(command string) bool {
	switch command {
	case "capability", "start", "stop", "status":
		return true
	default:
		return false
	}
}

func (h *serviceHandler) startFailureWatcher() {
	h.watchMu.Lock()
	defer h.watchMu.Unlock()
	if h.watchStop != nil {
		h.watchStop()
	}
	ctx, cancel := context.WithCancel(h.ctx)
	h.watchStop = cancel
	watcher := failurewatch.Watcher{
		Path:     filepath.Join(h.runtimeDir, "sing-box.log"),
		Interval: 500 * time.Millisecond,
		Cooldown: 10 * time.Second,
		OnTarget: func(probeContext context.Context, target failurewatch.Target) {
			_ = h.Handle(probeContext, controlsocket.Request{
				Command: "probe",
				Args: []string{
					"-domain", target.Domain,
					"-port", strconv.Itoa(target.Port),
					"-tls=true",
					"-network", "auto",
				},
			})
		},
	}
	go func() { _ = watcher.Run(ctx) }()
}

func (h *serviceHandler) stopFailureWatcher() {
	h.watchMu.Lock()
	defer h.watchMu.Unlock()
	if h.watchStop != nil {
		h.watchStop()
		h.watchStop = nil
	}
}

func canonicalServiceArgs(command string, input []string) ([]string, error) {
	if command != "probe" {
		if len(input) != 0 {
			return nil, errors.New("this service command does not accept client options")
		}
		return nil, nil
	}
	flags := flag.NewFlagSet("probe", flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	domain := flags.String("domain", "", "")
	port := flags.Int("port", 443, "")
	useTLS := flags.Bool("tls", true, "")
	network := flags.String("network", "unknown", "")
	timeout := flags.Duration("timeout", 8*time.Second, "")
	threshold := flags.Int("threshold", 2, "")
	if err := flags.Parse(input); err != nil {
		return nil, errors.New("invalid probe options")
	}
	if flags.NArg() != 0 || *domain == "" ||
		*port < 1 || *port > 65535 ||
		*timeout <= 0 || *timeout > 30*time.Second ||
		*threshold < 1 || *threshold > 10 {
		return nil, errors.New("probe options are outside the allowed range")
	}
	return []string{
		"-domain", *domain,
		"-port", strconv.Itoa(*port),
		"-tls=" + strconv.FormatBool(*useTLS),
		"-network", *network,
		"-timeout", timeout.String(),
		"-threshold", strconv.Itoa(*threshold),
	}, nil
}
