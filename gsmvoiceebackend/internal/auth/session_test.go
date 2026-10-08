package auth_test

import (
	"testing"
	"time"

	"gsmvoiceebackend/internal/auth"
)

func TestSessionManager(t *testing.T) {
	sm := auth.NewSessionManager()

	// Create session
	token, err := sm.CreateSession("user-123")
	if err != nil {
		t.Fatalf("CreateSession failed: %v", err)
	}
	if len(token) != auth.TokenBytes*2 {
		t.Fatalf("expected token length %d, got %d", auth.TokenBytes*2, len(token))
	}

	// Lookup valid session
	uid, ok := sm.GetSession(token)
	if !ok || uid != "user-123" {
		t.Fatalf("GetSession failed: got uid=%s, ok=%v", uid, ok)
	}

	// Lookup non-existent session
	_, ok = sm.GetSession("non-existent-token")
	if ok {
		t.Fatal("expected ok=false for unknown token")
	}

	// Lookup empty token
	_, ok = sm.GetSession("")
	if ok {
		t.Fatal("expected ok=false for empty token")
	}

	// Delete session (logout)
	sm.DeleteSession(token)
	_, ok = sm.GetSession(token)
	if ok {
		t.Fatal("expected ok=false after DeleteSession")
	}

	// Expired session
	expiredToken, err := sm.CreateSessionWithTTL("user-expired", -1*time.Minute)
	if err != nil {
		t.Fatalf("CreateSessionWithTTL failed: %v", err)
	}
	_, ok = sm.GetSession(expiredToken)
	if ok {
		t.Fatal("expected ok=false for expired session")
	}
}
