//go:build windows

package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
	"time"

	"adaptivevpn.local/core/controlsocket"

	"golang.org/x/sys/windows"
	"golang.org/x/sys/windows/svc"
	"golang.org/x/sys/windows/svc/mgr"
)

const windowsServiceName = "AdaptiveVPNService"

type windowsServiceOptions struct {
	core       string
	checksum   string
	runtimeDir string
	endpoint   string
	pipeSDDL   string
}

func platformService(args []string) {
	if len(args) == 0 {
		fail("usage: routerctl service <install|uninstall|start|stop|run> [options]")
	}
	switch args[0] {
	case "install":
		installWindowsService(args[1:])
	case "uninstall":
		uninstallWindowsService()
	case "start":
		controlWindowsService(true)
	case "stop":
		controlWindowsService(false)
	case "run":
		runWindowsService(args[1:])
	default:
		fail("unknown Windows service command %q", args[0])
	}
}

func parseWindowsServiceOptions(name string, args []string) windowsServiceOptions {
	programData := os.Getenv("ProgramData")
	if programData == "" {
		programData = `C:\ProgramData`
	}
	executable, err := os.Executable()
	if err != nil {
		fail("resolve routerctl executable: %v", err)
	}
	base := filepath.Dir(executable)
	flags := flag.NewFlagSet(name, flag.ExitOnError)
	core := flags.String("core", filepath.Join(base, "sing-box.exe"), "fixed sing-box executable")
	checksum := flags.String("core-sha256", "", "expected sing-box SHA-256")
	runtimeDir := flags.String(
		"runtime-dir",
		filepath.Join(programData, "AdaptiveVPN", "runtime"),
		"private service runtime directory",
	)
	endpoint := flags.String("pipe", defaultControlEndpoint(), "named pipe path")
	pipeSDDL := flags.String("pipe-sddl", "", "named pipe security descriptor")
	flags.Parse(args)
	if *checksum == "" {
		fail("core-sha256 is required")
	}
	absoluteCore, err := filepath.Abs(*core)
	if err != nil {
		fail("resolve absolute sing-box path: %v", err)
	}
	absoluteRuntime, err := filepath.Abs(*runtimeDir)
	if err != nil {
		fail("resolve absolute runtime path: %v", err)
	}
	return windowsServiceOptions{
		core:       absoluteCore,
		checksum:   *checksum,
		runtimeDir: absoluteRuntime,
		endpoint:   *endpoint,
		pipeSDDL:   *pipeSDDL,
	}
}

func installWindowsService(args []string) {
	options := parseWindowsServiceOptions("service install", args)
	if options.pipeSDDL == "" {
		var err error
		options.pipeSDDL, err = currentUserPipeSDDL()
		if err != nil {
			fail("build current-user pipe ACL: %v", err)
		}
	}
	if _, err := windows.SecurityDescriptorFromString(options.pipeSDDL); err != nil {
		fail("validate named-pipe security descriptor: %v", err)
	}
	if err := verifyCore(options.core, options.checksum); err != nil {
		fail("verify sing-box before service install: %v", err)
	}
	executable, err := os.Executable()
	if err != nil {
		fail("resolve routerctl executable: %v", err)
	}
	executable, err = filepath.Abs(executable)
	if err != nil {
		fail("resolve absolute routerctl path: %v", err)
	}
	manager, err := mgr.Connect()
	if err != nil {
		fail("connect to Windows Service Control Manager: %v", err)
	}
	defer manager.Disconnect()
	if existing, openErr := manager.OpenService(windowsServiceName); openErr == nil {
		existing.Close()
		fail("Windows service is already installed")
	}
	service, err := manager.CreateService(
		windowsServiceName,
		executable,
		mgr.Config{
			StartType:        mgr.StartAutomatic,
			ErrorControl:     mgr.ErrorNormal,
			ServiceStartName: "LocalSystem",
			DisplayName:      "Adaptive VPN Tunnel Service",
			Description:      "Privileged Smart TUN lifecycle service for Adaptive VPN.",
			Dependencies:     []string{"Tcpip"},
			SidType:          windows.SERVICE_SID_TYPE_UNRESTRICTED,
		},
		"service", "run",
		"-core", options.core,
		"-core-sha256", options.checksum,
		"-runtime-dir", options.runtimeDir,
		"-pipe", options.endpoint,
		"-pipe-sddl", options.pipeSDDL,
	)
	if err != nil {
		fail("install Windows service: %v", err)
	}
	defer service.Close()
	if err := service.SetRecoveryActions([]mgr.RecoveryAction{
		{Type: mgr.ServiceRestart, Delay: 2 * time.Second},
		{Type: mgr.ServiceRestart, Delay: 5 * time.Second},
		{Type: mgr.NoAction},
	}, 86400); err != nil {
		_ = service.Delete()
		fail("configure Windows service recovery: %v", err)
	}
	if err := service.Start(); err != nil {
		_ = service.Delete()
		fail("start Windows service: %v", err)
	}
	if err := waitWindowsServiceState(service, svc.Running, 30*time.Second); err != nil {
		fail("wait for Windows service start: %v", err)
	}
	writeJSON(map[string]any{"installed": true, "running": true})
}

func uninstallWindowsService() {
	manager, err := mgr.Connect()
	if err != nil {
		fail("connect to Windows Service Control Manager: %v", err)
	}
	defer manager.Disconnect()
	service, err := manager.OpenService(windowsServiceName)
	if err != nil {
		if errors.Is(err, windows.ERROR_SERVICE_DOES_NOT_EXIST) {
			writeJSON(map[string]any{"installed": false, "running": false})
			return
		}
		fail("open Windows service: %v", err)
	}
	defer service.Close()
	status, _ := service.Query()
	if status.State != svc.Stopped {
		_, _ = service.Control(svc.Stop)
		if err := waitWindowsServiceState(service, svc.Stopped, 30*time.Second); err != nil {
			fail("stop Windows service before uninstall: %v", err)
		}
	}
	if err := service.Delete(); err != nil {
		fail("delete Windows service: %v", err)
	}
	writeJSON(map[string]any{"installed": false, "running": false})
}

func controlWindowsService(start bool) {
	manager, err := mgr.Connect()
	if err != nil {
		fail("connect to Windows Service Control Manager: %v", err)
	}
	defer manager.Disconnect()
	service, err := manager.OpenService(windowsServiceName)
	if err != nil {
		fail("open Windows service: %v", err)
	}
	defer service.Close()
	if start {
		if err := service.Start(); err != nil && !errors.Is(err, windows.ERROR_SERVICE_ALREADY_RUNNING) {
			fail("start Windows service: %v", err)
		}
		if err := waitWindowsServiceState(service, svc.Running, 30*time.Second); err != nil {
			fail("wait for Windows service start: %v", err)
		}
		writeJSON(map[string]any{"running": true})
		return
	}
	status, err := service.Control(svc.Stop)
	if err != nil && status.State != svc.Stopped {
		fail("stop Windows service: %v", err)
	}
	if err := waitWindowsServiceState(service, svc.Stopped, 30*time.Second); err != nil {
		fail("wait for Windows service stop: %v", err)
	}
	writeJSON(map[string]any{"running": false})
}

func waitWindowsServiceState(service *mgr.Service, expected svc.State, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		status, err := service.Query()
		if err != nil {
			return err
		}
		if status.State == expected {
			return nil
		}
		time.Sleep(250 * time.Millisecond)
	}
	return fmt.Errorf("service did not reach state %d", expected)
}

func runWindowsService(args []string) {
	options := parseWindowsServiceOptions("service run", args)
	if options.pipeSDDL == "" {
		fail("pipe-sddl is required for the installed Windows service")
	}
	if _, err := windows.SecurityDescriptorFromString(options.pipeSDDL); err != nil {
		fail("validate service named-pipe security descriptor: %v", err)
	}
	if err := verifyCore(options.core, options.checksum); err != nil {
		fail("verify service core: %v", err)
	}
	if err := svc.Run(windowsServiceName, windowsTunnelService{options: options}); err != nil {
		fail("run Windows service: %v", err)
	}
}

type windowsTunnelService struct {
	options windowsServiceOptions
}

func (service windowsTunnelService) Execute(
	_ []string,
	requests <-chan svc.ChangeRequest,
	changes chan<- svc.Status,
) (bool, uint32) {
	changes <- svc.Status{State: svc.StartPending}
	ctx, cancel := context.WithCancel(context.Background())
	serverResult := make(chan error, 1)
	go func() {
		serverResult <- runTunnelServer(
			ctx,
			service.options.endpoint,
			service.options.pipeSDDL,
			service.options.core,
			service.options.checksum,
			service.options.runtimeDir,
		)
	}()
	readyDeadline := time.Now().Add(10 * time.Second)
	for {
		select {
		case err := <-serverResult:
			cancel()
			if err != nil {
				return true, 1
			}
			return true, 3
		default:
		}
		probeContext, probeCancel := context.WithTimeout(ctx, 750*time.Millisecond)
		response, err := controlsocket.Send(
			probeContext,
			service.options.endpoint,
			controlsocket.Request{Command: "capability"},
		)
		probeCancel()
		if err == nil && response.ExitCode == 0 {
			break
		}
		if time.Now().After(readyDeadline) {
			cancel()
			return true, 3
		}
		time.Sleep(100 * time.Millisecond)
	}
	changes <- svc.Status{State: svc.Running, Accepts: svc.AcceptStop | svc.AcceptShutdown}
	for {
		select {
		case err := <-serverResult:
			cancel()
			if err != nil {
				return true, 1
			}
			return false, 0
		case request := <-requests:
			switch request.Cmd {
			case svc.Interrogate:
				changes <- request.CurrentStatus
			case svc.Stop, svc.Shutdown:
				changes <- svc.Status{State: svc.StopPending}
				service.stopDataPlane()
				cancel()
				select {
				case <-serverResult:
				case <-time.After(10 * time.Second):
					return true, 2
				}
				changes <- svc.Status{State: svc.Stopped}
				return false, 0
			}
		}
	}
}

func currentUserPipeSDDL() (string, error) {
	user, err := windows.GetCurrentProcessToken().GetTokenUser()
	if err != nil {
		return "", err
	}
	return fmt.Sprintf(
		"D:P(A;;GA;;;SY)(A;;GA;;;BA)(A;;GRGW;;;%s)",
		user.User.Sid.String(),
	), nil
}

func (service windowsTunnelService) stopDataPlane() {
	executable, err := os.Executable()
	if err != nil {
		return
	}
	command := exec.Command(
		executable,
		"stop",
		"-core", service.options.core,
		"-core-sha256", service.options.checksum,
		"-runtime-dir", service.options.runtimeDir,
	)
	command.Env = append(os.Environ(), "ADAPTIVE_VPN_DAEMON_LOCAL=1")
	command.SysProcAttr = windowsHiddenProcessAttributes()
	_ = command.Run()
}

func windowsHiddenProcessAttributes() *syscall.SysProcAttr {
	return &syscall.SysProcAttr{
		CreationFlags: windows.CREATE_NEW_PROCESS_GROUP | windows.CREATE_NO_WINDOW,
		HideWindow:    true,
	}
}
