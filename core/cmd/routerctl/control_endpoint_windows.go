//go:build windows

package main

func defaultControlEndpoint() string {
	return `\\.\pipe\adaptive-vpn-control`
}
