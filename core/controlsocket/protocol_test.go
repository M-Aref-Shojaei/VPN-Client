package controlsocket

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"
)

type echoHandler struct{}

func (echoHandler) Handle(_ context.Context, request Request) Response {
	return Response{
		Stdout: string(request.Payload),
	}
}

func TestServerClientRoundTrip(t *testing.T) {
	socketPath := filepath.Join(t.TempDir(), "control.sock")
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	serverDone := make(chan error, 1)
	go func() {
		serverDone <- (Server{
			SocketPath: socketPath,
			Handler:    echoHandler{},
		}).Serve(ctx)
	}()
	deadline := time.Now().Add(time.Second)
	for {
		response, err := Send(ctx, socketPath, Request{
			Command: "start",
			Payload: json.RawMessage(`{"profile":{"type":"test"}}`),
		})
		if err == nil {
			if response.Stdout != `{"profile":{"type":"test"}}` {
				t.Fatalf("unexpected response: %#v", response)
			}
			break
		}
		if time.Now().After(deadline) {
			t.Fatal(err)
		}
		time.Sleep(10 * time.Millisecond)
	}
	cancel()
	if err := <-serverDone; err != nil {
		t.Fatal(err)
	}
}

func TestServerRefusesNonSocketPath(t *testing.T) {
	path := filepath.Join(t.TempDir(), "control.sock")
	if err := os.WriteFile(path, []byte("not a socket"), 0o600); err != nil {
		t.Fatal(err)
	}
	err := (Server{SocketPath: path, Handler: echoHandler{}}).Serve(
		context.Background(),
	)
	if err == nil {
		t.Fatal("expected non-socket path to be rejected")
	}
}
