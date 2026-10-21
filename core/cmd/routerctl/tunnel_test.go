package main

import (
	"crypto/sha256"
	"encoding/hex"
	"os"
	"path/filepath"
	"testing"
)

func TestVerifyCoreAcceptsOnlyExpectedSHA256(t *testing.T) {
	path := filepath.Join(t.TempDir(), "sing-box")
	content := []byte("reviewed core artifact")
	if err := os.WriteFile(path, content, 0o700); err != nil {
		t.Fatal(err)
	}
	sum := sha256.Sum256(content)
	expected := hex.EncodeToString(sum[:])
	if err := verifyCore(path, expected); err != nil {
		t.Fatal(err)
	}
	if err := verifyCore(path, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"); err == nil {
		t.Fatal("mismatched core checksum must be rejected")
	}
}
