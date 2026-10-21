package networkscope

import "testing"

func TestResolvePreservesExplicitNormalizedScope(t *testing.T) {
	if got := Resolve("  Test-Network  "); got != "test-network" {
		t.Fatalf("Resolve() = %q", got)
	}
}

func TestResolveAutomaticScopeNeverReturnsEmpty(t *testing.T) {
	if got := Resolve("unknown"); got == "" {
		t.Fatal("automatic network scope must never be empty")
	}
}
