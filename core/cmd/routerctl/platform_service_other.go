//go:build !windows

package main

func platformService([]string) {
	fail("platform service management is currently available only on Windows")
}
