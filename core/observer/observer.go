package observer

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"syscall"
	"time"

	"adaptivevpn.local/core/router"
)

type Target struct {
	Domain  string
	Port    int
	Network string
	TLS     bool
}

type Result struct {
	DirectSucceeded bool                `json:"direct_succeeded"`
	ProxyAttempted  bool                `json:"proxy_attempted"`
	ProxySucceeded  bool                `json:"proxy_succeeded"`
	Learned         bool                `json:"learned"`
	Signal          router.Signal       `json:"signal,omitempty"`
	Entry           router.LearnedEntry `json:"entry,omitempty"`
	Message         string              `json:"message"`
}

type PathProber interface {
	Direct(context.Context, Target) error
	Proxy(context.Context, Target) error
}

type Observer struct {
	prober    PathProber
	learner   *router.Learner
	statePath string
}

func New(prober PathProber, learner *router.Learner, statePath string) (*Observer, error) {
	if prober == nil || learner == nil {
		return nil, errors.New("prober and learner are required")
	}
	if statePath == "" {
		return nil, errors.New("learned-state path is required")
	}
	return &Observer{prober: prober, learner: learner, statePath: statePath}, nil
}

func (o *Observer) Check(ctx context.Context, target Target) (Result, error) {
	domain := router.NormalizeDomain(target.Domain)
	if domain == "" {
		return Result{}, errors.New("probe domain is required")
	}
	if target.Port < 1 || target.Port > 65535 {
		return Result{}, errors.New("probe port must be between 1 and 65535")
	}
	target.Domain = domain

	directErr := o.prober.Direct(ctx, target)
	if directErr == nil {
		return Result{
			DirectSucceeded: true,
			Message:         "Direct path succeeded; no proxy retry or learning was needed.",
		}, nil
	}
	signal, strong := Classify(directErr)
	if !strong {
		return Result{
			Message: "Direct path failed without a safe learning signal.",
		}, nil
	}

	result := Result{ProxyAttempted: true, Signal: signal}
	if err := o.prober.Proxy(ctx, target); err != nil {
		result.Message = "Both direct and proxy probes failed; the route was not learned."
		return result, nil
	}
	result.ProxySucceeded = true
	entry, accepted := o.learner.Observe(router.Observation{
		Domain:           domain,
		Network:          target.Network,
		Signal:           signal,
		ProxySucceeded:   true,
		PayloadForwarded: false,
	})
	result.Entry = entry
	result.Learned = !entry.BlockedUntil.IsZero() && entry.BlockedUntil.After(time.Now())
	if accepted {
		if err := o.learner.Save(o.statePath); err != nil {
			return Result{}, fmt.Errorf("save learned observation: %w", err)
		}
		if result.Learned {
			result.Message = "The domain was promoted to the network-specific proxy route."
		} else {
			result.Message = "Verified failure evidence was recorded; another observation is required."
		}
	} else {
		result.Message = "The learner rejected the observation."
	}
	return result, nil
}

func Classify(err error) (router.Signal, bool) {
	if err == nil {
		return "", false
	}
	if errors.Is(err, context.DeadlineExceeded) || os.IsTimeout(err) {
		return router.SignalTimeout, true
	}
	var dnsError *net.DNSError
	if errors.As(err, &dnsError) && (dnsError.IsNotFound || dnsError.IsTimeout) {
		if dnsError.IsTimeout {
			return router.SignalTimeout, true
		}
		return router.SignalDNSPoisoning, true
	}
	if errors.Is(err, syscall.ECONNRESET) {
		return router.SignalTCPReset, true
	}
	var certificateError *tls.CertificateVerificationError
	if errors.As(err, &certificateError) {
		return "", false
	}
	var unknownAuthority x509.UnknownAuthorityError
	if errors.As(err, &unknownAuthority) {
		return "", false
	}
	var recordHeaderError tls.RecordHeaderError
	if errors.As(err, &recordHeaderError) {
		return router.SignalTLSFailure, true
	}
	if errors.Is(err, io.ErrUnexpectedEOF) {
		return router.SignalTLSFailure, true
	}
	return "", false
}

type NetworkProber struct {
	ProxyAddress string
	Timeout      time.Duration
}

func (p NetworkProber) Direct(ctx context.Context, target Target) error {
	timeout := p.timeout()
	dialer := &net.Dialer{Timeout: timeout}
	connection, err := dialer.DialContext(
		ctx,
		"tcp",
		net.JoinHostPort(target.Domain, fmt.Sprint(target.Port)),
	)
	if err != nil {
		return err
	}
	defer connection.Close()
	return probeHandshake(ctx, connection, target, timeout)
}

func (p NetworkProber) Proxy(ctx context.Context, target Target) error {
	if p.ProxyAddress == "" {
		return errors.New("SOCKS proxy address is required")
	}
	timeout := p.timeout()
	dialer := &net.Dialer{Timeout: timeout}
	connection, err := dialer.DialContext(ctx, "tcp", p.ProxyAddress)
	if err != nil {
		return err
	}
	defer connection.Close()
	if deadline, ok := ctx.Deadline(); ok {
		_ = connection.SetDeadline(deadline)
	} else {
		_ = connection.SetDeadline(time.Now().Add(timeout))
	}
	if err := socksConnect(connection, target.Domain, target.Port); err != nil {
		return err
	}
	return probeHandshake(ctx, connection, target, timeout)
}

func (p NetworkProber) timeout() time.Duration {
	if p.Timeout <= 0 {
		return 8 * time.Second
	}
	return p.Timeout
}

func probeHandshake(
	ctx context.Context,
	connection net.Conn,
	target Target,
	timeout time.Duration,
) error {
	if !target.TLS {
		return nil
	}
	tlsConnection := tls.Client(connection, &tls.Config{
		MinVersion: tls.VersionTLS12,
		ServerName: target.Domain,
	})
	handshakeContext, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	return tlsConnection.HandshakeContext(handshakeContext)
}

func socksConnect(connection net.Conn, domain string, port int) error {
	if len(domain) > 255 {
		return errors.New("SOCKS target domain is too long")
	}
	if _, err := connection.Write([]byte{0x05, 0x01, 0x00}); err != nil {
		return fmt.Errorf("write SOCKS greeting: %w", err)
	}
	greeting := make([]byte, 2)
	if _, err := io.ReadFull(connection, greeting); err != nil {
		return fmt.Errorf("read SOCKS greeting: %w", err)
	}
	if greeting[0] != 0x05 || greeting[1] != 0x00 {
		return errors.New("SOCKS proxy rejected unauthenticated access")
	}
	request := []byte{0x05, 0x01, 0x00, 0x03, byte(len(domain))}
	request = append(request, domain...)
	request = append(request, byte(port>>8), byte(port))
	if _, err := connection.Write(request); err != nil {
		return fmt.Errorf("write SOCKS connect request: %w", err)
	}
	header := make([]byte, 4)
	if _, err := io.ReadFull(connection, header); err != nil {
		return fmt.Errorf("read SOCKS response: %w", err)
	}
	if header[0] != 0x05 || header[1] != 0x00 {
		return fmt.Errorf("SOCKS connect failed with code %d", header[1])
	}
	var addressLength int
	switch header[3] {
	case 0x01:
		addressLength = net.IPv4len
	case 0x03:
		length := make([]byte, 1)
		if _, err := io.ReadFull(connection, length); err != nil {
			return fmt.Errorf("read SOCKS domain length: %w", err)
		}
		addressLength = int(length[0])
	case 0x04:
		addressLength = net.IPv6len
	default:
		return errors.New("SOCKS response used an unknown address type")
	}
	discard := make([]byte, addressLength+2)
	if _, err := io.ReadFull(connection, discard); err != nil {
		return fmt.Errorf("read SOCKS response address: %w", err)
	}
	return nil
}
