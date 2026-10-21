package networkscope

import "strings"

const Unknown = "unknown"

// Resolve returns an explicit scope when supplied, otherwise a privacy-preserving
// fingerprint of the current platform network. Raw interface identifiers are
// never returned or persisted.
func Resolve(requested string) string {
	requested = strings.ToLower(strings.TrimSpace(requested))
	if requested != "" && requested != Unknown && requested != "auto" {
		return requested
	}
	if current, err := currentPlatform(); err == nil && current != "" {
		return current
	}
	return Unknown
}
