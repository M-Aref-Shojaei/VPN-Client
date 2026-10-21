package main

import (
	"testing"
	"time"
)

func TestCanonicalServiceArgsRejectsPrivilegeOverrides(t *testing.T) {
	for _, test := range []struct {
		command string
		args    []string
	}{
		{"start", []string{"-core", "/tmp/untrusted"}},
		{"stop", []string{"-runtime-dir", "/tmp/untrusted"}},
		{"probe", []string{"-domain", "example.com", "-proxy", "attacker:1080"}},
		{"probe", []string{"-domain", "example.com", "-timeout", "1h"}},
	} {
		if _, err := canonicalServiceArgs(test.command, test.args); err == nil {
			t.Fatalf("expected %s %v to be rejected", test.command, test.args)
		}
	}
}

func TestCanonicalServiceArgsAllowsBoundedProbe(t *testing.T) {
	args, err := canonicalServiceArgs("probe", []string{
		"-domain", "example.com",
		"-port", "8443",
		"-tls=false",
		"-network", "home",
		"-timeout", "5s",
		"-threshold", "3",
	})
	if err != nil {
		t.Fatal(err)
	}
	if len(args) == 0 {
		t.Fatal("expected canonical probe arguments")
	}
	if _, err := time.ParseDuration(args[8]); err != nil {
		t.Fatalf("canonical timeout is invalid: %v", err)
	}
}

func TestLifecycleCommandsAreSerialized(t *testing.T) {
	for _, command := range []string{"capability", "start", "stop", "status"} {
		if !isLifecycleCommand(command) {
			t.Fatalf("expected %q to be a lifecycle command", command)
		}
	}
	if isLifecycleCommand("probe") {
		t.Fatal("probe must remain independent from lifecycle serialization")
	}
}
