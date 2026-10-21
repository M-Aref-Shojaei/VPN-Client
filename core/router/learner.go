package router

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sort"
	"sync"
	"time"
)

const defaultNetwork = "unknown"

type Learner struct {
	mu        sync.RWMutex
	entries   map[string]LearnedEntry
	threshold int
	ttl       time.Duration
	now       func() time.Time
}

func NewLearner(threshold int, ttl time.Duration) *Learner {
	if threshold < 1 {
		threshold = 2
	}
	if ttl <= 0 {
		ttl = 24 * time.Hour
	}
	return &Learner{
		entries:   make(map[string]LearnedEntry),
		threshold: threshold,
		ttl:       ttl,
		now:       time.Now,
	}
}

func learningKey(network, domain string) string {
	network = NormalizeDomain(network)
	if network == "" {
		network = defaultNetwork
	}
	return network + "\x00" + NormalizeDomain(domain)
}

func (l *Learner) Observe(observation Observation) (LearnedEntry, bool) {
	domain := NormalizeDomain(observation.Domain)
	if domain == "" || !observation.ProxySucceeded || observation.PayloadForwarded {
		return LearnedEntry{}, false
	}
	if !validSignal(observation.Signal) {
		return LearnedEntry{}, false
	}

	network := NormalizeDomain(observation.Network)
	if network == "" {
		network = defaultNetwork
	}
	observedAt := observation.OccurredAt
	if observedAt.IsZero() {
		observedAt = l.now()
	}

	l.mu.Lock()
	defer l.mu.Unlock()

	key := learningKey(network, domain)
	entry := l.entries[key]
	entry.Domain = domain
	entry.Network = network
	entry.FailureCount++
	entry.LastSignal = observation.Signal
	entry.LastObservedAt = observedAt
	if entry.FailureCount >= l.threshold {
		entry.BlockedUntil = observedAt.Add(l.ttl)
	}
	l.entries[key] = entry
	return entry, true
}

func validSignal(signal Signal) bool {
	switch signal {
	case SignalDNSPoisoning, SignalTCPReset, SignalTimeout, SignalTLSFailure:
		return true
	default:
		return false
	}
}

func (l *Learner) IsBlocked(network, domain string) bool {
	l.mu.RLock()
	entry, ok := l.entries[learningKey(network, domain)]
	l.mu.RUnlock()
	return ok && entry.BlockedUntil.After(l.now())
}

func (l *Learner) Entries() []LearnedEntry {
	l.mu.RLock()
	defer l.mu.RUnlock()

	entries := make([]LearnedEntry, 0, len(l.entries))
	for _, entry := range l.entries {
		entries = append(entries, entry)
	}
	sort.Slice(entries, func(i, j int) bool {
		if entries[i].Network == entries[j].Network {
			return entries[i].Domain < entries[j].Domain
		}
		return entries[i].Network < entries[j].Network
	})
	return entries
}

func (l *Learner) Prune() int {
	now := l.now()
	l.mu.Lock()
	defer l.mu.Unlock()

	removed := 0
	for key, entry := range l.entries {
		if entry.BlockedUntil.IsZero() {
			if now.Sub(entry.LastObservedAt) > l.ttl {
				delete(l.entries, key)
				removed++
			}
			continue
		}
		if !entry.BlockedUntil.After(now) {
			delete(l.entries, key)
			removed++
		}
	}
	return removed
}

func (l *Learner) Load(path string) error {
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}

	var entries []LearnedEntry
	if err := json.Unmarshal(data, &entries); err != nil {
		return err
	}

	l.mu.Lock()
	defer l.mu.Unlock()
	l.entries = make(map[string]LearnedEntry, len(entries))
	for _, entry := range entries {
		domain := NormalizeDomain(entry.Domain)
		if domain == "" {
			continue
		}
		entry.Domain = domain
		l.entries[learningKey(entry.Network, domain)] = entry
	}
	return nil
}

func (l *Learner) Save(path string) error {
	data, err := json.MarshalIndent(l.Entries(), "", "  ")
	if err != nil {
		return err
	}
	data = append(data, '\n')

	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	temp, err := os.CreateTemp(filepath.Dir(path), ".learned-*.json")
	if err != nil {
		return err
	}
	tempPath := temp.Name()
	defer os.Remove(tempPath)

	if err := temp.Chmod(0o600); err != nil {
		temp.Close()
		return err
	}
	if _, err := temp.Write(data); err != nil {
		temp.Close()
		return err
	}
	if err := temp.Sync(); err != nil {
		temp.Close()
		return err
	}
	if err := temp.Close(); err != nil {
		return err
	}
	return os.Rename(tempPath, path)
}
