//go:build windows

package controlsocket

import (
	"context"
	"net"

	"github.com/Microsoft/go-winio"
)

const windowsPipeSecurity = "D:P(A;;GA;;;SY)(A;;GA;;;BA)(A;;GRGW;;;IU)"

func listenControl(path, securityDescriptor string) (net.Listener, error) {
	if securityDescriptor == "" {
		securityDescriptor = windowsPipeSecurity
	}
	return winio.ListenPipe(path, &winio.PipeConfig{
		SecurityDescriptor: securityDescriptor,
		MessageMode:        false,
		InputBufferSize:    MaximumMessageBytes,
		OutputBufferSize:   MaximumMessageBytes,
	})
}

func dialControl(ctx context.Context, path string) (net.Conn, error) {
	return winio.DialPipeContext(ctx, path)
}

func cleanupControl(string) {}
