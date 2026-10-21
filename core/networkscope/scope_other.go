//go:build !linux && !windows

package networkscope

import "errors"

func currentPlatform() (string, error) {
	return "", errors.New("automatic network scope is not implemented on this platform")
}
