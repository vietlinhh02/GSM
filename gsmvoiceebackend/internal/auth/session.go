package auth

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"sync"
	"time"
)

const (
	// TokenBytes defines the entropy size for bearer tokens (32 bytes = 256 bits).
	TokenBytes = 32
	// SessionDuration defines the session lifetime (1 hour).
	SessionDuration = 1 * time.Hour
)

// Session represents an active authenticated session in memory.
type Session struct {
	UserID    string
	ExpiresAt time.Time
}

// SessionManager manages in-memory sessions with concurrency safety.
type SessionManager struct {
	mu       sync.RWMutex
	sessions map[string]Session
}

// NewSessionManager creates a new SessionManager.
func NewSessionManager() *SessionManager {
	return &SessionManager{
		sessions: make(map[string]Session),
	}
}

// CreateSession generates a secure opaque token with default 1-hour duration.
func (sm *SessionManager) CreateSession(userID string) (string, error) {
	return sm.CreateSessionWithTTL(userID, SessionDuration)
}

// CreateSessionWithTTL generates a session with custom duration.
func (sm *SessionManager) CreateSessionWithTTL(userID string, ttl time.Duration) (string, error) {
	b := make([]byte, TokenBytes)
	if _, err := rand.Read(b); err != nil {
		return "", fmt.Errorf("generate session token: %w", err)
	}
	token := hex.EncodeToString(b)

	sm.mu.Lock()
	defer sm.mu.Unlock()

	sm.sessions[token] = Session{
		UserID:    userID,
		ExpiresAt: time.Now().Add(ttl),
	}
	return token, nil
}

// GetSession retrieves the user ID for a valid, non-expired token.
func (sm *SessionManager) GetSession(token string) (string, bool) {
	if token == "" {
		return "", false
	}

	sm.mu.RLock()
	session, exists := sm.sessions[token]
	sm.mu.RUnlock()

	if !exists {
		return "", false
	}

	if time.Now().After(session.ExpiresAt) {
		// Clean up expired session
		sm.mu.Lock()
		delete(sm.sessions, token)
		sm.mu.Unlock()
		return "", false
	}

	return session.UserID, true
}

// DeleteSession invalidates and removes the session for the given token.
func (sm *SessionManager) DeleteSession(token string) {
	if token == "" {
		return
	}
	sm.mu.Lock()
	delete(sm.sessions, token)
	sm.mu.Unlock()
}
