//go:build windows

package tunnel

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	"golang.org/x/sys/windows"
)

const (
	defaultStopTimeout  = 5 * time.Second
	defaultCheckTimeout = 15 * time.Second
	windowsPrivateSDDL  = "D:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)"
)

type Options struct {
	BinaryPath  string
	ConfigPath  string
	StatePath   string
	LogPath     string
	PrefixArgs  []string
	StopTimeout time.Duration
}

type State struct {
	PID          int       `json:"pid"`
	BinaryPath   string    `json:"binary_path"`
	ConfigPath   string    `json:"config_path"`
	ProcessStart string    `json:"process_start"`
	StartedAt    time.Time `json:"started_at"`
}

type Status struct {
	Running bool   `json:"running"`
	PID     int    `json:"pid,omitempty"`
	Message string `json:"message"`
}

type Manager struct {
	options Options
}

func NewManager(options Options) (*Manager, error) {
	if options.BinaryPath == "" || options.ConfigPath == "" ||
		options.StatePath == "" || options.LogPath == "" {
		return nil, errors.New("binary, config, state, and log paths are required")
	}
	binary, err := filepath.Abs(options.BinaryPath)
	if err != nil {
		return nil, fmt.Errorf("resolve core path: %w", err)
	}
	info, err := os.Stat(binary)
	if err != nil {
		return nil, fmt.Errorf("inspect core binary: %w", err)
	}
	if !info.Mode().IsRegular() {
		return nil, errors.New("core path is not a regular file")
	}
	options.BinaryPath = binary
	if options.StopTimeout <= 0 {
		options.StopTimeout = defaultStopTimeout
	}
	return &Manager{options: options}, nil
}

func WritePrivateFile(path string, data []byte) error {
	directory := filepath.Dir(path)
	if err := os.MkdirAll(directory, 0o700); err != nil {
		return fmt.Errorf("create runtime directory: %w", err)
	}
	if err := protectWindowsPath(directory); err != nil {
		return fmt.Errorf("protect runtime directory: %w", err)
	}
	temp, err := os.CreateTemp(directory, ".adaptive-vpn-*")
	if err != nil {
		return fmt.Errorf("create temporary runtime file: %w", err)
	}
	tempPath := temp.Name()
	defer os.Remove(tempPath)
	if _, err := temp.Write(data); err != nil {
		temp.Close()
		return fmt.Errorf("write temporary runtime file: %w", err)
	}
	if err := temp.Sync(); err != nil {
		temp.Close()
		return fmt.Errorf("sync temporary runtime file: %w", err)
	}
	if err := temp.Close(); err != nil {
		return fmt.Errorf("close temporary runtime file: %w", err)
	}
	from, err := windows.UTF16PtrFromString(tempPath)
	if err != nil {
		return err
	}
	to, err := windows.UTF16PtrFromString(path)
	if err != nil {
		return err
	}
	if err := windows.MoveFileEx(
		from,
		to,
		windows.MOVEFILE_REPLACE_EXISTING|windows.MOVEFILE_WRITE_THROUGH,
	); err != nil {
		return fmt.Errorf("replace runtime file: %w", err)
	}
	return nil
}

func protectWindowsPath(path string) error {
	descriptor, err := windows.SecurityDescriptorFromString(windowsPrivateSDDL)
	if err != nil {
		return err
	}
	dacl, _, err := descriptor.DACL()
	if err != nil {
		return err
	}
	return windows.SetNamedSecurityInfo(
		path,
		windows.SE_FILE_OBJECT,
		windows.DACL_SECURITY_INFORMATION|windows.PROTECTED_DACL_SECURITY_INFORMATION,
		nil,
		nil,
		dacl,
		nil,
	)
}

func (m *Manager) Validate(ctx context.Context) error {
	checkContext, cancel := context.WithTimeout(ctx, defaultCheckTimeout)
	defer cancel()
	args := append(append([]string{}, m.options.PrefixArgs...), "check", "-c", m.options.ConfigPath)
	command := exec.CommandContext(checkContext, m.options.BinaryPath, args...)
	command.SysProcAttr = hiddenProcessAttributes()
	output, err := command.CombinedOutput()
	if errors.Is(checkContext.Err(), context.DeadlineExceeded) {
		return errors.New("core configuration validation timed out")
	}
	if err != nil {
		return fmt.Errorf("core rejected configuration: %s", cleanWindowsOutput(output, err))
	}
	return nil
}

func (m *Manager) Start(ctx context.Context) (State, error) {
	status, err := m.Status()
	if err != nil {
		return State{}, err
	}
	if status.Running {
		return State{}, fmt.Errorf("tunnel is already running with PID %d", status.PID)
	}
	if err := m.Validate(ctx); err != nil {
		return State{}, err
	}
	if err := os.MkdirAll(filepath.Dir(m.options.LogPath), 0o700); err != nil {
		return State{}, fmt.Errorf("create log directory: %w", err)
	}
	if err := protectWindowsPath(filepath.Dir(m.options.LogPath)); err != nil {
		return State{}, fmt.Errorf("protect log directory: %w", err)
	}
	logFile, err := os.OpenFile(m.options.LogPath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o600)
	if err != nil {
		return State{}, fmt.Errorf("open core log: %w", err)
	}
	defer logFile.Close()

	args := append(append([]string{}, m.options.PrefixArgs...), "run", "-c", m.options.ConfigPath)
	command := exec.Command(m.options.BinaryPath, args...)
	command.Stdin = nil
	command.Stdout = logFile
	command.Stderr = logFile
	command.SysProcAttr = hiddenProcessAttributes()
	if err := command.Start(); err != nil {
		return State{}, fmt.Errorf("start core: %w", err)
	}

	processStart, _, err := windowsProcessIdentity(command.Process.Pid)
	if err != nil {
		_ = command.Process.Kill()
		_, _ = command.Process.Wait()
		return State{}, fmt.Errorf("read started process identity: %w", err)
	}
	waitResult := make(chan error, 1)
	go func() { waitResult <- command.Wait() }()
	select {
	case waitErr := <-waitResult:
		_ = logFile.Sync()
		output, _ := os.ReadFile(m.options.LogPath)
		_ = os.Remove(m.options.StatePath)
		return State{}, fmt.Errorf("core exited during startup: %s", cleanWindowsOutput(output, waitErr))
	case <-time.After(250 * time.Millisecond):
	}
	state := State{
		PID:          command.Process.Pid,
		BinaryPath:   m.options.BinaryPath,
		ConfigPath:   m.options.ConfigPath,
		ProcessStart: processStart,
		StartedAt:    time.Now().UTC(),
	}
	stateData, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		_ = command.Process.Kill()
		return State{}, fmt.Errorf("encode process state: %w", err)
	}
	if err := WritePrivateFile(m.options.StatePath, append(stateData, '\n')); err != nil {
		_ = command.Process.Kill()
		return State{}, err
	}
	return state, nil
}

func hiddenProcessAttributes() *syscall.SysProcAttr {
	return &syscall.SysProcAttr{
		CreationFlags: windows.CREATE_NEW_PROCESS_GROUP | windows.CREATE_NO_WINDOW,
		HideWindow:    true,
	}
}

func (m *Manager) Stop() error {
	state, err := m.readState()
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	running, err := m.matches(state)
	if err != nil {
		return err
	}
	if !running {
		_ = os.Remove(m.options.StatePath)
		return nil
	}
	handle, err := windows.OpenProcess(
		windows.PROCESS_TERMINATE|windows.SYNCHRONIZE|windows.PROCESS_QUERY_LIMITED_INFORMATION,
		false,
		uint32(state.PID),
	)
	if err != nil {
		return fmt.Errorf("open core process: %w", err)
	}
	defer windows.CloseHandle(handle)
	if err := windows.TerminateProcess(handle, 0); err != nil {
		return fmt.Errorf("stop core process: %w", err)
	}
	timeout := uint32(m.options.StopTimeout / time.Millisecond)
	result, err := windows.WaitForSingleObject(handle, timeout)
	if err != nil {
		return fmt.Errorf("wait for core process: %w", err)
	}
	if result == uint32(windows.WAIT_TIMEOUT) {
		return errors.New("core process did not stop within the timeout")
	}
	_ = os.Remove(m.options.StatePath)
	return nil
}

func (m *Manager) Status() (Status, error) {
	state, err := m.readState()
	if errors.Is(err, os.ErrNotExist) {
		return Status{Message: "Tunnel is stopped."}, nil
	}
	if err != nil {
		return Status{}, err
	}
	running, err := m.matches(state)
	if err != nil {
		return Status{}, err
	}
	if !running {
		_ = os.Remove(m.options.StatePath)
		return Status{Message: "Removed stale tunnel state."}, nil
	}
	return Status{Running: true, PID: state.PID, Message: "Tunnel is running."}, nil
}

func (m *Manager) readState() (State, error) {
	data, err := os.ReadFile(m.options.StatePath)
	if err != nil {
		return State{}, err
	}
	var state State
	if err := json.Unmarshal(data, &state); err != nil {
		return State{}, fmt.Errorf("parse process state: %w", err)
	}
	if state.PID < 1 || state.BinaryPath == "" || state.ProcessStart == "" {
		return State{}, errors.New("process state is incomplete")
	}
	return state, nil
}

func (m *Manager) matches(state State) (bool, error) {
	creation, executable, err := windowsProcessIdentity(state.PID)
	if errors.Is(err, windows.ERROR_INVALID_PARAMETER) || errors.Is(err, windows.ERROR_ACCESS_DENIED) {
		if errors.Is(err, windows.ERROR_INVALID_PARAMETER) {
			return false, nil
		}
		return false, err
	}
	if err != nil {
		return false, err
	}
	expected, err := filepath.Abs(state.BinaryPath)
	if err != nil {
		return false, err
	}
	return creation == state.ProcessStart && strings.EqualFold(filepath.Clean(executable), filepath.Clean(expected)), nil
}

func windowsProcessIdentity(pid int) (string, string, error) {
	handle, err := windows.OpenProcess(windows.PROCESS_QUERY_LIMITED_INFORMATION, false, uint32(pid))
	if err != nil {
		return "", "", err
	}
	defer windows.CloseHandle(handle)
	var creation, exit, kernel, user windows.Filetime
	if err := windows.GetProcessTimes(handle, &creation, &exit, &kernel, &user); err != nil {
		return "", "", err
	}
	buffer := make([]uint16, 32768)
	size := uint32(len(buffer))
	if err := windows.QueryFullProcessImageName(handle, 0, &buffer[0], &size); err != nil {
		return "", "", err
	}
	return strconv.FormatInt(creation.Nanoseconds(), 10), windows.UTF16ToString(buffer[:size]), nil
}

func cleanWindowsOutput(output []byte, fallback error) string {
	message := strings.TrimSpace(string(output))
	if message == "" && fallback != nil {
		message = fallback.Error()
	}
	if len(message) > 2048 {
		message = message[:2048] + "…"
	}
	return message
}
