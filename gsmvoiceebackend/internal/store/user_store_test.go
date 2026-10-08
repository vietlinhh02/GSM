package store_test

import (
	"encoding/hex"
	"testing"
	"time"

	"gsmvoiceebackend/internal/store"
)

func TestValidateUserRecord_Table(t *testing.T) {
	validSalt := hex.EncodeToString(make([]byte, 16))
	validHash := hex.EncodeToString(make([]byte, 32))

	tests := []struct {
		name      string
		user      *store.User
		wantError bool
	}{
		{
			name: "valid_record",
			user: &store.User{
				ID:           "valid_user_id_123",
				Email:        "user@example.com",
				Name:         "Valid User",
				PasswordHash: validHash,
				Salt:         validSalt,
				CreatedAt:    time.Now().UTC(),
			},
			wantError: false,
		},
		{
			name:      "nil_user",
			user:      nil,
			wantError: true,
		},
		{
			name: "empty_id",
			user: &store.User{
				ID:           "   ",
				Email:        "user@example.com",
				Name:         "User",
				PasswordHash: validHash,
				Salt:         validSalt,
			},
			wantError: true,
		},
		{
			name: "empty_email",
			user: &store.User{
				ID:           "id123",
				Email:        "   ",
				Name:         "User",
				PasswordHash: validHash,
				Salt:         validSalt,
			},
			wantError: true,
		},
		{
			name: "empty_name",
			user: &store.User{
				ID:           "id123",
				Email:        "user@example.com",
				Name:         "   ",
				PasswordHash: validHash,
				Salt:         validSalt,
			},
			wantError: true,
		},
		{
			name: "invalid_salt_length",
			user: &store.User{
				ID:           "id123",
				Email:        "user@example.com",
				Name:         "User",
				PasswordHash: validHash,
				Salt:         "shortsalt",
			},
			wantError: true,
		},
		{
			name: "invalid_salt_hex",
			user: &store.User{
				ID:           "id123",
				Email:        "user@example.com",
				Name:         "User",
				PasswordHash: validHash,
				Salt:         "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz",
			},
			wantError: true,
		},
		{
			name: "invalid_hash_length",
			user: &store.User{
				ID:           "id123",
				Email:        "user@example.com",
				Name:         "User",
				PasswordHash: "shorthash",
				Salt:         validSalt,
			},
			wantError: true,
		},
		{
			name: "invalid_hash_hex",
			user: &store.User{
				ID:           "id123",
				Email:        "user@example.com",
				Name:         "User",
				PasswordHash: "gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg",
				Salt:         validSalt,
			},
			wantError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := store.ValidateUserRecord(tt.user)
			if (err != nil) != tt.wantError {
				t.Fatalf("ValidateUserRecord() error = %v, wantError = %v", err, tt.wantError)
			}
		})
	}
}
