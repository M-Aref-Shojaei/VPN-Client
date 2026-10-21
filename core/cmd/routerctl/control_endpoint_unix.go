//go:build !windows

package main

func defaultControlEndpoint() string {
	return "/run/adaptive-vpn/control.sock"
}
