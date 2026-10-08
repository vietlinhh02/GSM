package store_test

import (
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"gsmvoiceebackend/internal/config"
	"gsmvoiceebackend/internal/store"
	"gsmvoiceebackend/internal/testutil"
)

func TestPostgresStore_NilDB(t *testing.T) {
	_, err := store.NewPostgresStore(nil)
	if err == nil {
		t.Fatal("expected error when passing nil db to NewPostgresStore, got nil")
	}
}

func TestPostgresStore_UnavailableConnection(t *testing.T) {
	// Attempt connecting to a closed local port
	badConnStr := "postgres://user:pass@127.0.0.1:54321/db?connect_timeout=1&sslmode=disable"
	_, err := store.OpenPostgres(badConnStr)
	if err == nil {
		t.Fatal("expected connection error for unreachable database port, got nil")
	}
}

func TestPostgresStore_UnavailableConnectionNoSecretLeak(t *testing.T) {
	sentinel := "TEST_SENTINEL_SECRET_TOKEN_XYZ123"
	badConnStr := "postgres://user:" + sentinel + "@127.0.0.1:54321/db?connect_timeout=1&sslmode=disable"
	_, err := store.OpenPostgres(badConnStr)
	if err == nil {
		t.Fatal("expected connection error for unreachable database port, got nil")
	}

	safeErr := config.SanitizeError(err, sentinel)
	if strings.Contains(safeErr.Error(), sentinel) {
		t.Fatalf("sanitized error leaked sentinel: %v", safeErr)
	}
}

func TestPostgresStore_Validation(t *testing.T) {
	pgStore := testutil.GetTestPostgresStore(t)
	if pgStore == nil {
		return
	}

	validSalt := hex.EncodeToString(make([]byte, 16))
	validHash := hex.EncodeToString(make([]byte, 32))

	tests := []struct {
		name string
		salt string
		hash string
	}{
		{"invalid_salt_length", "abcd", validHash},
		{"invalid_salt_hex", "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz", validHash},
		{"invalid_hash_length", validSalt, "1234"},
		{"invalid_hash_hex", validSalt, "gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := pgStore.CreateUser("Test User", "test@example.com", tt.hash, tt.salt)
			if err == nil {
				t.Fatalf("expected error for %s, got nil", tt.name)
			}
		})
	}
}

func TestPostgresStore_CRUDAndConstraints(t *testing.T) {
	pgStore := testutil.GetTestPostgresStore(t)
	if pgStore == nil {
		return
	}

	salt := hex.EncodeToString([]byte("0123456789abcdef"))
	hash := hex.EncodeToString([]byte("0123456789abcdef0123456789abcdef"))

	uniqueEmail := fmt.Sprintf("pgtest_%d@example.com", time.Now().UnixNano())

	// 1. Create user
	created, err := pgStore.CreateUser("Postgres Tester", uniqueEmail, hash, salt)
	if err != nil {
		t.Fatalf("failed to create user: %v", err)
	}
	if created.ID == "" {
		t.Fatal("expected non-empty user ID")
	}
	if created.Email != uniqueEmail {
		t.Fatalf("expected email %s, got %s", uniqueEmail, created.Email)
	}

	// 2. Duplicate email rejection (exact match)
	_, err = pgStore.CreateUser("Duplicate User", uniqueEmail, hash, salt)
	if err == nil || err != store.ErrDuplicateEmail {
		t.Fatalf("expected ErrDuplicateEmail, got: %v", err)
	}

	// 3. Duplicate email rejection (case-insensitive)
	upperEmail := "PGTEST_" + uniqueEmail[7:]
	_, err = pgStore.CreateUser("Duplicate Upper", upperEmail, hash, salt)
	if err == nil || err != store.ErrDuplicateEmail {
		t.Fatalf("expected ErrDuplicateEmail for uppercase email, got: %v", err)
	}

	// 4. GetByEmail (case-insensitive lookup)
	byEmail, err := pgStore.GetByEmail(upperEmail)
	if err != nil {
		t.Fatalf("failed to get user by uppercase email: %v", err)
	}
	if byEmail.ID != created.ID {
		t.Fatalf("expected ID %s, got %s", created.ID, byEmail.ID)
	}

	// 5. GetByID
	byID, err := pgStore.GetByID(created.ID)
	if err != nil {
		t.Fatalf("failed to get user by ID: %v", err)
	}
	if byID.Email != uniqueEmail {
		t.Fatalf("expected email %s, got %s", uniqueEmail, byID.Email)
	}

	// 6. User not found errors
	_, err = pgStore.GetByEmail("nonexistent_user_xyz@example.com")
	if err != store.ErrUserNotFound {
		t.Fatalf("expected ErrUserNotFound, got %v", err)
	}

	_, err = pgStore.GetByID("nonexistent-id-0000000000000000")
	if err != store.ErrUserNotFound {
		t.Fatalf("expected ErrUserNotFound, got %v", err)
	}
}

func TestPostgresStore_LegacyImport_SuccessAndIdempotent(t *testing.T) {
	pgStore := testutil.GetTestPostgresStore(t)
	if pgStore == nil {
		return
	}

	tmpDir := t.TempDir()
	seedPath := filepath.Join(tmpDir, "seed_test.json")

	email1 := fmt.Sprintf("seed1_%d@example.com", time.Now().UnixNano())
	email2 := fmt.Sprintf("seed2_%d@example.com", time.Now().UnixNano())
	salt := hex.EncodeToString([]byte("0123456789abcdef"))
	hash := hex.EncodeToString([]byte("0123456789abcdef0123456789abcdef"))

	content := fmt.Sprintf(`[
		{
			"id": "seedid_1_%d",
			"email": "%s",
			"name": "Seed User One",
			"passwordHash": "%s",
			"salt": "%s",
			"createdAt": "2026-10-08T00:00:00Z"
		},
		{
			"id": "seedid_2_%d",
			"email": "%s",
			"name": "Seed User Two",
			"passwordHash": "%s",
			"salt": "%s",
			"createdAt": "2026-10-08T00:00:00Z"
		}
	]`, time.Now().UnixNano(), email1, hash, salt, time.Now().UnixNano(), email2, hash, salt)

	if err := os.WriteFile(seedPath, []byte(content), 0600); err != nil {
		t.Fatalf("failed to write test seed file: %v", err)
	}

	// First import
	if err := pgStore.ImportLegacyUsersJSON(seedPath); err != nil {
		t.Fatalf("ImportLegacyUsersJSON returned error: %v", err)
	}

	u1, err := pgStore.GetByEmail(email1)
	if err != nil || u1.Name != "Seed User One" {
		t.Fatalf("failed to retrieve seeded user 1: %v", err)
	}

	// Repeated import must be idempotent and safely succeed
	if err := pgStore.ImportLegacyUsersJSON(seedPath); err != nil {
		t.Fatalf("repeated ImportLegacyUsersJSON failed: %v", err)
	}
}

func TestPostgresStore_LegacyImport_TolerateAbsentFile(t *testing.T) {
	pgStore := testutil.GetTestPostgresStore(t)
	if pgStore == nil {
		return
	}

	absentPath := filepath.Join(t.TempDir(), "nonexistent_users.json")
	if err := pgStore.ImportLegacyUsersJSON(absentPath); err != nil {
		t.Fatalf("expected nil error for absent file, got: %v", err)
	}
}

func TestPostgresStore_LegacyImport_CorruptedStateRejection(t *testing.T) {
	pgStore := testutil.GetTestPostgresStore(t)
	if pgStore == nil {
		return
	}

	validSalt := hex.EncodeToString(make([]byte, 16))
	validHash := hex.EncodeToString(make([]byte, 32))

	tests := []struct {
		name    string
		content string
	}{
		{"zero_byte_file", ""},
		{"whitespace_only", "   \n\t  "},
		{"null_json", "null"},
		{"invalid_json_syntax", "{not json}"},
		{"invalid_salt_length", fmt.Sprintf(`[{"id":"1","email":"a@b.c","name":"A","passwordHash":"%s","salt":"bad"}]`, validHash)},
		{"invalid_hash_length", fmt.Sprintf(`[{"id":"1","email":"a@b.c","name":"A","passwordHash":"bad","salt":"%s"}]`, validSalt)},
		{"missing_id", fmt.Sprintf(`[{"id":"","email":"a@b.c","name":"A","passwordHash":"%s","salt":"%s"}]`, validHash, validSalt)},
		{"missing_email", fmt.Sprintf(`[{"id":"1","email":"","name":"A","passwordHash":"%s","salt":"%s"}]`, validHash, validSalt)},
		{"missing_name", fmt.Sprintf(`[{"id":"1","email":"a@b.c","name":"","passwordHash":"%s","salt":"%s"}]`, validHash, validSalt)},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			path := filepath.Join(t.TempDir(), "test.json")
			if err := os.WriteFile(path, []byte(tt.content), 0600); err != nil {
				t.Fatalf("write temp file failed: %v", err)
			}
			err := pgStore.ImportLegacyUsersJSON(path)
			if err == nil {
				t.Fatalf("expected error for corrupted case %s, got nil", tt.name)
			}
		})
	}
}

func TestPostgresStore_LegacyImport_AtomicRollback(t *testing.T) {
	pgStore := testutil.GetTestPostgresStore(t)
	if pgStore == nil {
		return
	}

	validSalt := hex.EncodeToString(make([]byte, 16))
	validHash := hex.EncodeToString(make([]byte, 32))
	email1 := fmt.Sprintf("valid1_%d@example.com", time.Now().UnixNano())

	// Batch has 2 users: first is valid, second has corrupt salt
	content := fmt.Sprintf(`[
		{
			"id": "user1",
			"email": "%s",
			"name": "User One",
			"passwordHash": "%s",
			"salt": "%s",
			"createdAt": "2026-10-08T00:00:00Z"
		},
		{
			"id": "user2",
			"email": "user2@example.com",
			"name": "User Two",
			"passwordHash": "%s",
			"salt": "invalid-salt",
			"createdAt": "2026-10-08T00:00:00Z"
		}
	]`, email1, validHash, validSalt, validHash)

	path := filepath.Join(t.TempDir(), "atomic_test.json")
	if err := os.WriteFile(path, []byte(content), 0600); err != nil {
		t.Fatalf("write file failed: %v", err)
	}

	err := pgStore.ImportLegacyUsersJSON(path)
	if err == nil {
		t.Fatal("expected import error due to user2 invalid salt, got nil")
	}

	// Verify user1 was NOT imported (atomic rollback)
	_, err = pgStore.GetByEmail(email1)
	if err != store.ErrUserNotFound {
		t.Fatalf("expected user1 to not exist due to rollback, got err: %v", err)
	}
}
