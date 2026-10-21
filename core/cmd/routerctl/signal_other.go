//go:build !unix

package main

import "context"

func signalContext() (context.Context, context.CancelFunc) {
	return context.WithCancel(context.Background())
}
