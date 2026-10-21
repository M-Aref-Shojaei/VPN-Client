package failurewatch

import (
	"bufio"
	"context"
	"errors"
	"io"
	"net"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"

	"adaptivevpn.local/core/router"
)

var directFailurePattern = regexp.MustCompile(
	`connection: open connection to (.+):([0-9]+) using outbound/direct\[direct\]:`,
)

type Target struct {
	Domain string
	Port   int
}

type Watcher struct {
	Path     string
	Interval time.Duration
	Cooldown time.Duration
	OnTarget func(context.Context, Target)
}

func ParseDirectFailure(line string) (Target, bool) {
	matches := directFailurePattern.FindStringSubmatch(line)
	if len(matches) != 3 {
		return Target{}, false
	}
	domain := router.NormalizeDomain(matches[1])
	if domain == "" || net.ParseIP(domain) != nil ||
		strings.ContainsAny(domain, " /\\\t\r\n") || !validDomainName(domain) {
		return Target{}, false
	}
	port, err := strconv.Atoi(matches[2])
	if err != nil || port < 1 || port > 65535 {
		return Target{}, false
	}
	return Target{Domain: domain, Port: port}, true
}

func validDomainName(domain string) bool {
	if len(domain) > 253 {
		return false
	}
	for _, label := range strings.Split(domain, ".") {
		if len(label) < 1 || len(label) > 63 || label[0] == '-' || label[len(label)-1] == '-' {
			return false
		}
		for _, character := range label {
			if (character < 'a' || character > 'z') &&
				(character < '0' || character > '9') && character != '-' {
				return false
			}
		}
	}
	return true
}

func (w Watcher) Run(ctx context.Context) error {
	if w.Path == "" || w.OnTarget == nil {
		return errors.New("watch path and callback are required")
	}
	if w.Interval <= 0 {
		w.Interval = 500 * time.Millisecond
	}
	if w.Cooldown <= 0 {
		w.Cooldown = 10 * time.Second
	}
	offset := int64(-1)
	lastTriggered := make(map[string]time.Time)
	ticker := time.NewTicker(w.Interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return nil
		case <-ticker.C:
			newOffset, err := w.readNew(ctx, offset, lastTriggered)
			if err == nil {
				offset = newOffset
			}
		}
	}
}

func (w Watcher) readNew(
	ctx context.Context,
	offset int64,
	lastTriggered map[string]time.Time,
) (int64, error) {
	file, err := os.Open(w.Path)
	if err != nil {
		return offset, err
	}
	defer file.Close()
	info, err := file.Stat()
	if err != nil {
		return offset, err
	}
	if offset < 0 {
		return info.Size(), nil
	}
	if info.Size() < offset {
		offset = 0
	}
	if _, err := file.Seek(offset, io.SeekStart); err != nil {
		return offset, err
	}
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 4096), 64*1024)
	for scanner.Scan() {
		target, ok := ParseDirectFailure(scanner.Text())
		if !ok {
			continue
		}
		key := net.JoinHostPort(target.Domain, strconv.Itoa(target.Port))
		now := time.Now()
		if previous := lastTriggered[key]; !previous.IsZero() && now.Sub(previous) < w.Cooldown {
			continue
		}
		lastTriggered[key] = now
		w.OnTarget(ctx, target)
	}
	position, seekErr := file.Seek(0, io.SeekCurrent)
	if seekErr != nil {
		return offset, seekErr
	}
	if err := scanner.Err(); err != nil {
		return position, err
	}
	return position, nil
}
