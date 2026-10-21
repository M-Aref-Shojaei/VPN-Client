package controlsocket

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"time"
)

const MaximumMessageBytes = 2 * 1024 * 1024

type Request struct {
	Command string          `json:"command"`
	Args    []string        `json:"args,omitempty"`
	Payload json.RawMessage `json:"payload,omitempty"`
}

type Response struct {
	ExitCode int    `json:"exit_code"`
	Stdout   string `json:"stdout,omitempty"`
	Stderr   string `json:"stderr,omitempty"`
}

type Handler interface {
	Handle(context.Context, Request) Response
}

type Server struct {
	SocketPath         string
	SecurityDescriptor string
	Handler            Handler
}

func (s Server) Serve(ctx context.Context) error {
	if s.SocketPath == "" || s.Handler == nil {
		return errors.New("socket path and handler are required")
	}
	listener, err := listenControl(s.SocketPath, s.SecurityDescriptor)
	if err != nil {
		return fmt.Errorf("listen on control endpoint: %w", err)
	}
	defer listener.Close()
	defer cleanupControl(s.SocketPath)

	go func() {
		<-ctx.Done()
		_ = listener.Close()
	}()
	for {
		connection, acceptErr := listener.Accept()
		if acceptErr != nil {
			if ctx.Err() != nil {
				return nil
			}
			return fmt.Errorf("accept control connection: %w", acceptErr)
		}
		go s.handleConnection(ctx, connection)
	}
}

func (s Server) handleConnection(ctx context.Context, connection net.Conn) {
	defer connection.Close()
	_ = connection.SetDeadline(time.Now().Add(30 * time.Second))
	decoder := json.NewDecoder(io.LimitReader(connection, MaximumMessageBytes))
	decoder.DisallowUnknownFields()
	var request Request
	if err := decoder.Decode(&request); err != nil {
		_ = json.NewEncoder(connection).Encode(Response{
			ExitCode: 2,
			Stderr:   "invalid control request",
		})
		return
	}
	response := s.Handler.Handle(ctx, request)
	_ = json.NewEncoder(connection).Encode(response)
}

func Send(ctx context.Context, socketPath string, request Request) (Response, error) {
	connection, err := dialControl(ctx, socketPath)
	if err != nil {
		return Response{}, fmt.Errorf("connect to privileged tunnel service: %w", err)
	}
	defer connection.Close()
	if deadline, ok := ctx.Deadline(); ok {
		_ = connection.SetDeadline(deadline)
	} else {
		_ = connection.SetDeadline(time.Now().Add(30 * time.Second))
	}
	if err := json.NewEncoder(connection).Encode(request); err != nil {
		return Response{}, fmt.Errorf("send control request: %w", err)
	}
	var response Response
	decoder := json.NewDecoder(
		bufio.NewReader(io.LimitReader(connection, MaximumMessageBytes)),
	)
	if err := decoder.Decode(&response); err != nil {
		return Response{}, fmt.Errorf("read control response: %w", err)
	}
	return response, nil
}
