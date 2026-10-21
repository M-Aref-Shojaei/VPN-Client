//go:build linux

package tunnel

import (
	"os"
	"os/signal"
	"syscall"
)

func signalNotifyPlatform(channel chan<- os.Signal) {
	signal.Notify(channel, syscall.SIGTERM, syscall.SIGINT)
}
