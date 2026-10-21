package router

import "time"

type Route string

const (
	RouteDirect Route = "direct"
	RouteProxy  Route = "proxy"
)

type Reason string

const (
	ReasonManualDirect Reason = "manual_direct"
	ReasonManualProxy  Reason = "manual_proxy"
	ReasonPrivate      Reason = "private_destination"
	ReasonKnownBlocked Reason = "known_blocked"
	ReasonLearned      Reason = "learned_blocked"
	ReasonDefault      Reason = "default_direct"
)

type Signal string

const (
	SignalDNSPoisoning Signal = "dns_poisoning"
	SignalTCPReset     Signal = "tcp_reset"
	SignalTimeout      Signal = "connect_timeout"
	SignalTLSFailure   Signal = "tls_interference"
)

type Destination struct {
	Domain string `json:"domain,omitempty"`
	IP     string `json:"ip,omitempty"`
}

type Decision struct {
	Route  Route  `json:"route"`
	Reason Reason `json:"reason"`
	Match  string `json:"match,omitempty"`
}

type Observation struct {
	Domain           string    `json:"domain"`
	Network          string    `json:"network"`
	Signal           Signal    `json:"signal"`
	ProxySucceeded   bool      `json:"proxy_succeeded"`
	OccurredAt       time.Time `json:"occurred_at"`
	PayloadForwarded bool      `json:"payload_forwarded"`
}

type LearnedEntry struct {
	Domain         string    `json:"domain"`
	Network        string    `json:"network"`
	FailureCount   int       `json:"failure_count"`
	LastSignal     Signal    `json:"last_signal"`
	LastObservedAt time.Time `json:"last_observed_at"`
	BlockedUntil   time.Time `json:"blocked_until,omitempty"`
}
