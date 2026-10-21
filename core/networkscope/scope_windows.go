//go:build windows

package networkscope

import (
	"crypto/sha256"
	"encoding/hex"
	"net"
	"sort"
	"strings"

	"golang.org/x/sys/windows"
)

func currentPlatform() (string, error) {
	var interfaceIndex uint32
	err := windows.GetBestInterfaceEx(
		&windows.SockaddrInet4{Addr: [4]byte{1, 1, 1, 1}},
		&interfaceIndex,
	)
	if err != nil {
		return "", err
	}
	device, err := net.InterfaceByIndex(int(interfaceIndex))
	if err != nil {
		return "", err
	}
	addresses, err := device.Addrs()
	if err != nil {
		return "", err
	}
	prefixes := make([]string, 0, len(addresses))
	for _, address := range addresses {
		if network, ok := address.(*net.IPNet); ok {
			prefixes = append(prefixes, (&net.IPNet{
				IP:   network.IP.Mask(network.Mask),
				Mask: network.Mask,
			}).String())
		}
	}
	sort.Strings(prefixes)
	material := strings.Join([]string{
		device.Name,
		device.HardwareAddr.String(),
		strings.Join(prefixes, ","),
	}, "\x00")
	digest := sha256.Sum256([]byte(material))
	return "windows-" + hex.EncodeToString(digest[:8]), nil
}
