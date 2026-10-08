package auth_test

import (
	"encoding/hex"
	"testing"

	"gsmvoiceebackend/internal/auth"
)

func TestPasswordHashingProduction(t *testing.T) {
	password := "correct-horse-battery-staple"

	hashHex, saltHex, err := auth.HashPassword(password)
	if err != nil {
		t.Fatalf("HashPassword failed: %v", err)
	}

	saltBytes, err := hex.DecodeString(saltHex)
	if err != nil {
		t.Fatalf("salt is not valid hex: %v", err)
	}
	if len(saltBytes) != auth.SaltLength {
		t.Errorf("expected salt length %d, got %d", auth.SaltLength, len(saltBytes))
	}

	hashBytes, err := hex.DecodeString(hashHex)
	if err != nil {
		t.Fatalf("hash is not valid hex: %v", err)
	}
	if len(hashBytes) != auth.KeyLength {
		t.Errorf("expected hash length %d, got %d", auth.KeyLength, len(hashBytes))
	}

	match, err := auth.VerifyPassword(password, saltHex, hashHex)
	if err != nil {
		t.Fatalf("VerifyPassword failed: %v", err)
	}
	if !match {
		t.Fatal("expected correct password to match")
	}

	wrongMatch, err := auth.VerifyPassword("wrong-password", saltHex, hashHex)
	if err != nil {
		t.Fatalf("VerifyPassword with wrong password failed: %v", err)
	}
	if wrongMatch {
		t.Fatal("expected wrong password to not match")
	}

	_, err = auth.VerifyPassword(password, "invalid-hex", hashHex)
	if err == nil {
		t.Fatal("expected error on invalid salt hex")
	}

	_, err = auth.VerifyPassword(password, saltHex, "invalid-hex")
	if err == nil {
		t.Fatal("expected error on invalid hash hex")
	}
}
