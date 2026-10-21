//go:build !windows

package controlsocket

import (
	"context"
	"errors"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"time"
)

func listenControl(path, _ string) (net.Listener, error) {
	if err := prepareSocket(path); err != nil {
		return nil, err
	}
	listener, err := net.Listen("unix", path)
	if err != nil {
		return nil, err
	}
	if err := os.Chmod(path, 0o660); err != nil {
		listener.Close()
		return nil, fmt.Errorf("protect control socket: %w", err)
	}
	return listener, nil
}

func dialControl(ctx context.Context, path string) (net.Conn, error) {
	dialer := net.Dialer{Timeout: 5 * time.Second}
	return dialer.DialContext(ctx, "unix", path)
}

func cleanupControl(path string) {
	_ = os.Remove(path)
}

func prepareSocket(path string) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o750); err != nil {
		return fmt.Errorf("create socket directory: %w", err)
	}
	info, err := os.Lstat(path)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("inspect existing socket: %w", err)
	}
	if info.Mode()&os.ModeSocket == 0 {
		return errors.New("refusing to replace a non-socket control path")
	}
	if err := os.Remove(path); err != nil {
		return fmt.Errorf("remove stale control socket: %w", err)
	}
	return nil
}
