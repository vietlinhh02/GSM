package testutil

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/stdlib"

	"gsmvoiceebackend/internal/config"
	"gsmvoiceebackend/internal/store"
)

// GetTestPostgresStore returns an isolated PostgresStore in a dedicated temporary schema.
// Real rows in public.users are never modified. The temporary schema is dropped on cleanup.
func GetTestPostgresStore(t *testing.T) *store.PostgresStore {
	t.Helper()

	cfg, err := config.LoadDBConfig()
	if err != nil {
		t.Fatalf("failed to load database configuration for test: %v", err)
	}

	// Explicit override via TEST_DATABASE_URL if present
	if explicitURL := os.Getenv("TEST_DATABASE_URL"); explicitURL != "" {
		cfg.ConnURL = explicitURL
		cfg.DisplayTarget = "custom TEST_DATABASE_URL"
	}

	masterDB, err := sql.Open("pgx", cfg.ConnURL)
	if err != nil {
		if os.Getenv("RUN_INTEGRATION_TESTS") != "" || os.Getenv("TEST_DATABASE_URL") != "" {
			t.Fatalf("failed to open test database (%s): %v",
				cfg.DisplayTarget, config.SanitizeError(err, cfg.Password))
		}
		t.Skip("PostgreSQL database not available; run 'make db-up' or set RUN_INTEGRATION_TESTS=1")
		return nil
	}

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	if err := masterDB.PingContext(ctx); err != nil {
		_ = masterDB.Close()
		if os.Getenv("RUN_INTEGRATION_TESTS") != "" || os.Getenv("TEST_DATABASE_URL") != "" {
			t.Fatalf("failed to ping test database (%s): %v",
				cfg.DisplayTarget, config.SanitizeError(err, cfg.Password))
		}
		t.Skip("PostgreSQL database not available; run 'make db-up' or set RUN_INTEGRATION_TESTS=1")
		return nil
	}

	randBytes := make([]byte, 8)
	if _, err := rand.Read(randBytes); err != nil {
		_ = masterDB.Close()
		t.Fatalf("failed to generate random schema identifier: %v", err)
	}
	schemaName := fmt.Sprintf("test_%d_%s", time.Now().UnixNano(), hex.EncodeToString(randBytes))

	if _, err := masterDB.Exec(fmt.Sprintf(`CREATE SCHEMA "%s"`, schemaName)); err != nil {
		_ = masterDB.Close()
		t.Fatalf("failed to create test schema %s: %v",
			schemaName, config.SanitizeError(err, cfg.Password))
	}

	t.Cleanup(func() {
		cleanupCtx, cleanupCancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cleanupCancel()

		if _, err := masterDB.ExecContext(cleanupCtx, fmt.Sprintf(`DROP SCHEMA "%s" CASCADE`, schemaName)); err != nil {
			t.Errorf("cleanup failed: unable to drop test schema %s: %v", schemaName, err)
		}
		_ = masterDB.Close()
	})

	connConfig, err := pgx.ParseConfig(cfg.ConnURL)
	if err != nil {
		t.Fatalf("failed to parse connection config: %v", config.SanitizeError(err, cfg.Password))
	}
	if connConfig.RuntimeParams == nil {
		connConfig.RuntimeParams = make(map[string]string)
	}
	connConfig.RuntimeParams["search_path"] = schemaName

	testDB := stdlib.OpenDB(*connConfig)
	t.Cleanup(func() {
		_ = testDB.Close()
	})

	pgStore, err := store.NewPostgresStore(testDB)
	if err != nil {
		t.Fatalf("failed to initialize test PostgresStore: %v", config.SanitizeError(err, cfg.Password))
	}

	return pgStore
}
