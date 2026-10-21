package observer

import (
	"context"
	"crypto/tls"
	"errors"
	"net"
	"os"
	"path/filepath"
	"syscall"
	"testing"
	"time"

	"adaptivevpn.local/core/router"
)

type fakeProber struct {
	directErr error
	proxyErr  error
	direct    int
	proxy     int
}

func (p *fakeProber) Direct(context.Context, Target) error {
	p.direct++
	return p.directErr
}

func (p *fakeProber) Proxy(context.Context, Target) error {
	p.proxy++
	return p.proxyErr
}

func TestObserverLearnsOnlyAfterStrongFailureAndProxySuccess(t *testing.T) {
	statePath := filepath.Join(t.TempDir(), "learned.json")
	prober := &fakeProber{directErr: syscall.ECONNRESET}
	learner := router.NewLearner(1, time.Hour)
	observer, err := New(prober, learner, statePath)
	if err != nil {
		t.Fatal(err)
	}

	result, err := observer.Check(context.Background(), Target{
		Domain:  "Blocked.Example",
		Port:    443,
		TLS:     true,
		Network: "home",
	})
	if err != nil {
		t.Fatal(err)
	}
	if !result.ProxyAttempted || !result.ProxySucceeded || !result.Learned {
		t.Fatalf("unexpected result: %#v", result)
	}
	if result.Signal != router.SignalTCPReset ||
		!learner.IsBlocked("home", "blocked.example") {
		t.Fatalf("observation was not learned: %#v", result)
	}
	if _, err := os.Stat(statePath); err != nil {
		t.Fatalf("learned state was not saved: %v", err)
	}
}

func TestObserverRejectsAmbiguousAndUnverifiedFailures(t *testing.T) {
	tests := []struct {
		name      string
		directErr error
		proxyErr  error
		wantProxy int
	}{
		{
			name:      "connection refused",
			directErr: syscall.ECONNREFUSED,
		},
		{
			name:      "certificate trust",
			directErr: &tls.CertificateVerificationError{},
		},
		{
			name:      "proxy also failed",
			directErr: context.DeadlineExceeded,
			proxyErr:  errors.New("proxy unavailable"),
			wantProxy: 1,
		},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			prober := &fakeProber{
				directErr: test.directErr,
				proxyErr:  test.proxyErr,
			}
			learner := router.NewLearner(1, time.Hour)
			observer, err := New(
				prober,
				learner,
				filepath.Join(t.TempDir(), "state.json"),
			)
			if err != nil {
				t.Fatal(err)
			}
			result, err := observer.Check(context.Background(), Target{
				Domain: "example.com",
				Port:   443,
				TLS:    true,
			})
			if err != nil {
				t.Fatal(err)
			}
			if result.Learned || prober.proxy != test.wantProxy {
				t.Fatalf("unsafe observation result: %#v", result)
			}
		})
	}
}

func TestClassifySignals(t *testing.T) {
	tests := []struct {
		err    error
		signal router.Signal
		ok     bool
	}{
		{context.DeadlineExceeded, router.SignalTimeout, true},
		{&net.DNSError{IsNotFound: true}, router.SignalDNSPoisoning, true},
		{syscall.ECONNRESET, router.SignalTCPReset, true},
		{errors.New("ambiguous"), "", false},
	}
	for _, test := range tests {
		signal, ok := Classify(test.err)
		if signal != test.signal || ok != test.ok {
			t.Fatalf("Classify(%v) = %q, %v", test.err, signal, ok)
		}
	}
}
