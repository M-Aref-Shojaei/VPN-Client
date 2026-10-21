//go:build unix

package main

import (
	"context"
	"os/signal"
	"syscall"
)

func signalContext() (context.Context, context.CancelFunc) {
	return signal.NotifyContext(context.Background(), syscall.SIGTERM, syscall.SIGINT)
}
