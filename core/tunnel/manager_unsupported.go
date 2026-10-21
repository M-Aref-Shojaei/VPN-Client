//go:build !linux && !windows

package tunnel

import (
	"context"
	"errors"
	"time"
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
type Manager struct{}

func NewManager(Options) (*Manager, error) {
	return nil, errors.New("the local process tunnel manager is currently available only on Linux")
}
func WritePrivateFile(string, []byte) error {
	return errors.New("private runtime file support is currently available only on Linux")
}
func (m *Manager) Validate(context.Context) error { return errors.New("unsupported platform") }
func (m *Manager) Start(context.Context) (State, error) {
	return State{}, errors.New("unsupported platform")
}
func (m *Manager) Stop() error { return errors.New("unsupported platform") }
func (m *Manager) Status() (Status, error) {
	return Status{}, errors.New("unsupported platform")
}
