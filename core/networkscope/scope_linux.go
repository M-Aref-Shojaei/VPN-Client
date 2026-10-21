//go:build linux

package networkscope

import (
	"bufio"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"net"
	"os"
	"strconv"
	"strings"
)

func currentPlatform() (string, error) {
	file, err := os.Open("/proc/net/route")
	if err != nil {
		return "", err
	}
	defer file.Close()

	var selected []string
	selectedMetric := int(^uint(0) >> 1)
	scanner := bufio.NewScanner(file)
	if scanner.Scan() { // header
		for scanner.Scan() {
			fields := strings.Fields(scanner.Text())
			if len(fields) < 8 || fields[1] != "00000000" {
				continue
			}
			flags, flagErr := strconv.ParseUint(fields[3], 16, 32)
			metric, metricErr := strconv.Atoi(fields[6])
			if flagErr != nil || metricErr != nil || flags&1 == 0 || metric >= selectedMetric {
				continue
			}
			selected = fields
			selectedMetric = metric
		}
	}
	if err := scanner.Err(); err != nil {
		return "", err
	}
	if len(selected) == 0 {
		return "", errors.New("default route is unavailable")
	}

	device, err := net.InterfaceByName(selected[0])
	if err != nil {
		return "", err
	}
	material := strings.Join([]string{
		selected[0],
		selected[2], // gateway encoded by the kernel route table
		device.HardwareAddr.String(),
	}, "\x00")
	digest := sha256.Sum256([]byte(material))
	return "linux-" + hex.EncodeToString(digest[:8]), nil
}
