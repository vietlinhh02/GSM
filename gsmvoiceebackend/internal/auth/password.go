package auth

import (
	"crypto/pbkdf2"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"errors"
	"fmt"
)

const (
	// Iterations specifies the PBKDF2 iteration count (OWASP recommendation: >= 600,000).
	Iterations = 600000
	// SaltLength specifies the salt length in bytes.
	SaltLength = 16
	// KeyLength specifies the derived key length in bytes.
	KeyLength = 32
)

var (
	ErrInvalidSalt = errors.New("invalid salt encoding")
	ErrInvalidHash = errors.New("invalid hash encoding")
)

// HashPassword hashes a plaintext password using PBKDF2-HMAC-SHA256 with 600,000 iterations.
func HashPassword(password string) (hashHex string, saltHex string, err error) {
	salt := make([]byte, SaltLength)
	if _, err := rand.Read(salt); err != nil {
		return "", "", fmt.Errorf("generate salt: %w", err)
	}

	dk, err := pbkdf2.Key(sha256.New, password, salt, Iterations, KeyLength)
	if err != nil {
		return "", "", fmt.Errorf("derive key: %w", err)
	}

	return hex.EncodeToString(dk), hex.EncodeToString(salt), nil
}

// VerifyPassword verifies a plaintext password against stored salt and hash
// using constant-time comparison.
func VerifyPassword(password, saltHex, hashHex string) (bool, error) {
	salt, err := hex.DecodeString(saltHex)
	if err != nil {
		return false, ErrInvalidSalt
	}

	expectedKey, err := hex.DecodeString(hashHex)
	if err != nil {
		return false, ErrInvalidHash
	}

	derivedKey, err := pbkdf2.Key(sha256.New, password, salt, Iterations, KeyLength)
	if err != nil {
		return false, fmt.Errorf("derive key: %w", err)
	}

	if subtle.ConstantTimeCompare(derivedKey, expectedKey) == 1 {
		return true, nil
	}
	return false, nil
}
