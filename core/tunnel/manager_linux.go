//go:build linux

package tunnel

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"syscall"
	"time"
)

const (
	defaultStopTimeout  = 5 * time.Second
	defaultCheckTimeout = 15 * time.Second
)

var ansiEscapePattern = regexp.MustCompile(`\x1b\[[0-?]*[ -/]*[@-~]`)

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
	if !info.Mode().IsRegular() || info.Mode().Perm()&0o111 == 0 {
		return nil, errors.New("core path is not an executable regular file")
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
	if err := os.Chmod(directory, 0o700); err != nil {
		return fmt.Errorf("protect runtime directory: %w", err)
	}
	temp, err := os.CreateTemp(directory, ".adaptive-vpn-*")
	if err != nil {
		return fmt.Errorf("create temporary runtime file: %w", err)
	}
	tempPath := temp.Name()
	defer os.Remove(tempPath)
	if err := temp.Chmod(0o600); err != nil {
		temp.Close()
		return fmt.Errorf("protect temporary runtime file: %w", err)
	}
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
	if err := os.Rename(tempPath, path); err != nil {
		return fmt.Errorf("replace runtime file: %w", err)
	}
	return nil
}

func (m *Manager) Validate(ctx context.Context) error {
	checkContext, cancel := context.WithTimeout(ctx, defaultCheckTimeout)
	defer cancel()
	args := append(append([]string{}, m.options.PrefixArgs...), "check", "-c", m.options.ConfigPath)
	output, err := exec.CommandContext(checkContext, m.options.BinaryPath, args...).CombinedOutput()
	if errors.Is(checkContext.Err(), context.DeadlineExceeded) {
		return errors.New("core configuration validation timed out")
	}
	if err != nil {
		return fmt.Errorf("core rejected configuration: %s", cleanOutput(output, err))
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
	logFile, err := os.OpenFile(m.options.LogPath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o600)
	if err != nil {
		return State{}, fmt.Errorf("open core log: %w", err)
	}
	defer logFile.Close()
	if err := logFile.Chmod(0o600); err != nil {
		return State{}, fmt.Errorf("protect core log: %w", err)
	}

	args := append(append([]string{}, m.options.PrefixArgs...), "run", "-c", m.options.ConfigPath)
	command := exec.Command(m.options.BinaryPath, args...)
	command.Stdin = nil
	command.Stdout = logFile
	command.Stderr = logFile
	command.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	if err := command.Start(); err != nil {
		return State{}, fmt.Errorf("start core: %w", err)
	}

	processStart, err := readProcessStart(command.Process.Pid)
	if err != nil {
		_ = command.Process.Kill()
		_, _ = command.Process.Wait()
		return State{}, fmt.Errorf("read started process identity: %w", err)
	}
	waitResult := make(chan error, 1)
	go func() {
		waitResult <- command.Wait()
	}()
	select {
	case waitErr := <-waitResult:
		_ = logFile.Sync()
		output, _ := os.ReadFile(m.options.LogPath)
		_ = os.Remove(m.options.StatePath)
		return State{}, fmt.Errorf("core exited during startup: %s", cleanOutput(output, waitErr))
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
		_, _ = command.Process.Wait()
		return State{}, fmt.Errorf("encode process state: %w", err)
	}
	if err := WritePrivateFile(m.options.StatePath, append(stateData, '\n')); err != nil {
		_ = command.Process.Kill()
		return State{}, err
	}
	return state, nil
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
	process, err := os.FindProcess(state.PID)
	if err != nil {
		return fmt.Errorf("find core process: %w", err)
	}
	if err := process.Signal(syscall.SIGTERM); err != nil && !errors.Is(err, os.ErrProcessDone) {
		return fmt.Errorf("stop core process: %w", err)
	}
	deadline := time.Now().Add(m.options.StopTimeout)
	for time.Now().Before(deadline) {
		running, matchErr := m.matches(state)
		if matchErr == nil && !running {
			_ = os.Remove(m.options.StatePath)
			return nil
		}
		time.Sleep(50 * time.Millisecond)
	}
	if err := process.Signal(syscall.SIGKILL); err != nil && !errors.Is(err, os.ErrProcessDone) {
		return fmt.Errorf("kill unresponsive core process: %w", err)
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
	processStart, err := readProcessStart(state.PID)
	if errors.Is(err, os.ErrNotExist) {
		return false, nil
	}
	if err != nil {
		return false, fmt.Errorf("read process identity: %w", err)
	}
	if processStart != state.ProcessStart {
		return false, nil
	}
	executable, err := os.Readlink(filepath.Join("/proc", strconv.Itoa(state.PID), "exe"))
	if errors.Is(err, os.ErrNotExist) {
		return false, nil
	}
	if err != nil {
		return false, fmt.Errorf("read process executable: %w", err)
	}
	expected, err := filepath.EvalSymlinks(state.BinaryPath)
	if err != nil {
		return false, fmt.Errorf("resolve expected executable: %w", err)
	}
	actual, err := filepath.EvalSymlinks(executable)
	if err != nil {
		return false, fmt.Errorf("resolve running executable: %w", err)
	}
	return actual == expected, nil
}

func readProcessStart(pid int) (string, error) {
	file, err := os.Open(filepath.Join("/proc", strconv.Itoa(pid), "stat"))
	if err != nil {
		return "", err
	}
	defer file.Close()
	line, err := bufio.NewReader(file).ReadString('\n')
	if err != nil && !errors.Is(err, os.ErrClosed) {
		// procfs files commonly end without a newline.
		if len(line) == 0 {
			return "", err
		}
	}
	closing := strings.LastIndex(line, ")")
	if closing < 0 {
		return "", errors.New("unexpected process stat format")
	}
	fields := strings.Fields(line[closing+1:])
	if len(fields) <= 19 {
		return "", errors.New("process stat is missing start time")
	}
	return fields[19], nil
}

func cleanOutput(output []byte, fallback error) string {
	message := stripANSI(strings.TrimSpace(string(output)))
	if message == "" {
		message = fallback.Error()
	}
	if len(message) > 2048 {
		message = message[:2048] + "…"
	}
	return message
}

func stripANSI(value string) string {
	return ansiEscapePattern.ReplaceAllString(value, "")
}
