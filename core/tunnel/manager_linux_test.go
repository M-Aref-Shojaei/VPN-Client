//go:build linux

package tunnel

import (
	"context"
	"os"
	"path/filepath"
	"syscall"
	"testing"
	"time"
)

func TestHelperProcess(t *testing.T) {
	if os.Getenv("ADAPTIVE_VPN_HELPER_PROCESS") != "1" {
		return
	}
	args := os.Args
	separator := -1
	for index, argument := range args {
		if argument == "--" {
			separator = index
			break
		}
	}
	if separator < 0 || len(args) <= separator+1 {
		os.Exit(2)
	}
	switch args[separator+1] {
	case "check":
		os.Exit(0)
	case "run":
		signals := make(chan os.Signal, 1)
		signalNotify(signals)
		<-signals
		os.Exit(0)
	default:
		os.Exit(2)
	}
}

func TestManagerLifecycleAndPrivateFiles(t *testing.T) {
	t.Setenv("ADAPTIVE_VPN_HELPER_PROCESS", "1")
	executable, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	directory := t.TempDir()
	options := Options{
		BinaryPath:  executable,
		ConfigPath:  filepath.Join(directory, "config.json"),
		StatePath:   filepath.Join(directory, "core-state.json"),
		LogPath:     filepath.Join(directory, "core.log"),
		PrefixArgs:  []string{"-test.run=TestHelperProcess", "--"},
		StopTimeout: time.Second,
	}
	if err := WritePrivateFile(options.ConfigPath, []byte("{}\n")); err != nil {
		t.Fatal(err)
	}
	info, err := os.Stat(options.ConfigPath)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("runtime config mode = %o, want 600", info.Mode().Perm())
	}
	manager, err := NewManager(options)
	if err != nil {
		t.Fatal(err)
	}
	if err := manager.Validate(context.Background()); err != nil {
		t.Fatal(err)
	}
	state, err := manager.Start(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		if process, findErr := os.FindProcess(state.PID); findErr == nil {
			_ = process.Signal(syscall.SIGKILL)
		}
	})
	status, err := manager.Status()
	if err != nil {
		t.Fatal(err)
	}
	if !status.Running || status.PID != state.PID {
		t.Fatalf("unexpected running status: %#v", status)
	}
	if err := manager.Stop(); err != nil {
		t.Fatal(err)
	}
	status, err = manager.Status()
	if err != nil {
		t.Fatal(err)
	}
	if status.Running {
		t.Fatalf("expected stopped status: %#v", status)
	}
}

func TestStatusRejectsReusedOrUnrelatedPID(t *testing.T) {
	executable, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	directory := t.TempDir()
	manager, err := NewManager(Options{
		BinaryPath: executable,
		ConfigPath: filepath.Join(directory, "config.json"),
		StatePath:  filepath.Join(directory, "state.json"),
		LogPath:    filepath.Join(directory, "log"),
	})
	if err != nil {
		t.Fatal(err)
	}
	data := []byte(`{"pid":1,"binary_path":"` + executable +
		`","config_path":"x","process_start":"definitely-not-real"}`)
	if err := WritePrivateFile(manager.options.StatePath, data); err != nil {
		t.Fatal(err)
	}
	status, err := manager.Status()
	if err != nil {
		t.Fatal(err)
	}
	if status.Running {
		t.Fatal("unrelated PID must not be treated as the tunnel")
	}
}

func TestCleanOutputRemovesTerminalEscapes(t *testing.T) {
	got := cleanOutput([]byte("\x1b[31mFATAL\x1b[0m operation not permitted"), nil)
	if got != "FATAL operation not permitted" {
		t.Fatalf("clean output = %q", got)
	}
}

func signalNotify(channel chan<- os.Signal) {
	// Kept behind a helper so the test clearly documents the only accepted
	// termination signals for the detached core process.
	signalNotifyPlatform(channel)
}
