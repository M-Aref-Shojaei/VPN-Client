package failurewatch

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestParseDirectFailureAcceptsOnlyDomainDirectFailures(t *testing.T) {
	line := "ERROR connection: open connection to Blocked.Example:443 using outbound/direct[direct]: reset"
	target, ok := ParseDirectFailure(line)
	if !ok || target.Domain != "blocked.example" || target.Port != 443 {
		t.Fatalf("unexpected target: %#v, %v", target, ok)
	}
	for _, invalid := range []string{
		"connection: open connection to blocked.example:443 using outbound/vless[proxy]: reset",
		"connection: open connection to 192.0.2.1:443 using outbound/direct[direct]: reset",
		"connection: open connection to bad domain:443 using outbound/direct[direct]: reset",
		"connection: open connection to bad_domain:443 using outbound/direct[direct]: reset",
	} {
		if _, ok := ParseDirectFailure(invalid); ok {
			t.Fatalf("accepted unsafe or irrelevant line: %q", invalid)
		}
	}
}

func TestWatcherReadsOnlyAppendedFailuresAndDebounces(t *testing.T) {
	path := filepath.Join(t.TempDir(), "sing-box.log")
	old := "connection: open connection to old.example:443 using outbound/direct[direct]: timeout\n"
	if err := os.WriteFile(path, []byte(old), 0o600); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	targets := make(chan Target, 2)
	watcher := Watcher{
		Path: path, Interval: 5 * time.Millisecond, Cooldown: time.Hour,
		OnTarget: func(_ context.Context, target Target) { targets <- target },
	}
	go func() { _ = watcher.Run(ctx) }()
	time.Sleep(20 * time.Millisecond)
	file, err := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0o600)
	if err != nil {
		t.Fatal(err)
	}
	line := "connection: open connection to new.example:443 using outbound/direct[direct]: timeout\n"
	if _, err := fmt.Fprint(file, line, line); err != nil {
		file.Close()
		t.Fatal(err)
	}
	if err := file.Close(); err != nil {
		t.Fatal(err)
	}
	select {
	case target := <-targets:
		if target.Domain != "new.example" {
			t.Fatalf("unexpected target: %#v", target)
		}
	case <-time.After(time.Second):
		t.Fatal("watcher did not deliver appended failure")
	}
	select {
	case target := <-targets:
		t.Fatalf("duplicate was not debounced: %#v", target)
	case <-time.After(30 * time.Millisecond):
	}
}
