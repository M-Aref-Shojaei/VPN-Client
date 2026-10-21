//go:build windows

package tunnel

import (
	"context"
	"os"
	"path/filepath"
	"slices"
	"testing"
	"time"

	"golang.org/x/sys/windows"
)

func TestWindowsHelperProcess(t *testing.T) {
	separator := slices.Index(os.Args, "--")
	if separator < 0 || separator+1 >= len(os.Args) {
		return
	}
	switch os.Args[separator+1] {
	case "check":
		return
	case "run":
		time.Sleep(30 * time.Second)
	}
}

func TestWindowsManagerLifecycle(t *testing.T) {
	if !windows.GetCurrentProcessToken().IsElevated() {
		t.Skip("Windows lifecycle test requires an elevated token for the protected runtime ACL")
	}
	directory := t.TempDir()
	configPath := filepath.Join(directory, "config.json")
	if err := os.WriteFile(configPath, []byte("{}\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	manager, err := NewManager(Options{
		BinaryPath:  os.Args[0],
		ConfigPath:  configPath,
		StatePath:   filepath.Join(directory, "state.json"),
		LogPath:     filepath.Join(directory, "core.log"),
		PrefixArgs:  []string{"-test.run=^TestWindowsHelperProcess$", "--"},
		StopTimeout: 2 * time.Second,
	})
	if err != nil {
		t.Fatal(err)
	}
	state, err := manager.Start(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if state.PID < 1 {
		t.Fatalf("invalid child state: %#v", state)
	}
	status, err := manager.Status()
	if err != nil || !status.Running {
		t.Fatalf("unexpected running status: %#v, %v", status, err)
	}
	if err := manager.Stop(); err != nil {
		t.Fatal(err)
	}
	status, err = manager.Status()
	if err != nil || status.Running {
		t.Fatalf("unexpected stopped status: %#v, %v", status, err)
	}
}
