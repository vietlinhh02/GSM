package config_test

import (
	"errors"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"gsmvoiceebackend/internal/config"
)

func TestLoadDBConfig_ReservedPasswordCharacters(t *testing.T) {
	os.Setenv("POSTGRES_USER", "user@special")
	os.Setenv("POSTGRES_PASSWORD", "p@ss:w#rd%123")
	os.Setenv("POSTGRES_HOST", "127.0.0.1")
	os.Setenv("POSTGRES_PORT", "5433")
	os.Setenv("POSTGRES_DB", "gsmvoicee")
	os.Unsetenv("DATABASE_URL")
	defer func() {
		os.Unsetenv("POSTGRES_USER")
		os.Unsetenv("POSTGRES_PASSWORD")
	}()

	cfg, err := config.LoadDBConfig()
	if err != nil {
		t.Fatalf("LoadDBConfig failed: %v", err)
	}

	parsed, err := url.Parse(cfg.ConnURL)
	if err != nil {
		t.Fatalf("failed to parse generated URL: %v", err)
	}

	pass, _ := parsed.User.Password()
	if pass != "p@ss:w#rd%123" {
		t.Fatalf("expected unescaped password 'p@ss:w#rd%%123', got '%s'", pass)
	}

	if !strings.Contains(cfg.ConnURL, "p%40ss%3Aw%23rd%25123") {
		t.Fatalf("expected encoded password in raw URL, got %s", cfg.ConnURL)
	}
}

func TestLoadDBConfig_MalformedURLNoSecretLeak(t *testing.T) {
	sentinel := "SENTINEL_SECRET_TEST_TOKEN_XYZ999"
	malformedURL := "postgres://user:" + sentinel + "@[invalid-ipv6-bracket/dbname"

	os.Setenv("DATABASE_URL", malformedURL)
	defer os.Unsetenv("DATABASE_URL")

	_, err := config.LoadDBConfig()
	if err == nil {
		t.Fatal("expected error for malformed DATABASE_URL, got nil")
	}

	if strings.Contains(err.Error(), sentinel) {
		t.Fatalf("FATAL SECRET LEAK: error message contains sentinel password: %v", err)
	}
}

func TestSanitizeError_SentinelRedacted(t *testing.T) {
	sentinel := "SUPER_SECRET_SENTINEL_TOKEN_12345"

	tests := []struct {
		name     string
		inputErr error
		secret   string
	}{
		{
			name:     "contains_raw_secret",
			inputErr: errors.New("connection failed with secret: " + sentinel),
			secret:   sentinel,
		},
		{
			name:     "contains_url_userinfo",
			inputErr: errors.New("dial failed for postgres://admin:" + sentinel + "@127.0.0.1:5433/db"),
			secret:   sentinel,
		},
		{
			name:     "contains_dsn_password_param",
			inputErr: errors.New("driver error host=127.0.0.1 password=" + sentinel + " dbname=test"),
			secret:   sentinel,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			sanitized := config.SanitizeError(tt.inputErr, tt.secret)
			if sanitized == nil {
				t.Fatal("expected non-nil sanitized error")
			}
			if strings.Contains(sanitized.Error(), sentinel) {
				t.Fatalf("sanitized error leaked sentinel: %s", sanitized.Error())
			}
			if !strings.Contains(sanitized.Error(), "[REDACTED]") {
				t.Fatalf("expected [REDACTED] in error message: %s", sanitized.Error())
			}
		})
	}
}

func TestRegression_InternalDirEnvDiscovery(t *testing.T) {
	tempProject := t.TempDir()
	goModContent := "module gsmvoiceebackend\n\ngo 1.27.1\n"
	if err := os.WriteFile(filepath.Join(tempProject, "go.mod"), []byte(goModContent), 0600); err != nil {
		t.Fatalf("failed to write dummy go.mod: %v", err)
	}

	envContent := "POSTGRES_HOST=10.0.0.99\nPOSTGRES_PORT=15433\nPOSTGRES_USER=special_user\nPOSTGRES_PASSWORD=p@ss:w#rd%999\n"
	if err := os.WriteFile(filepath.Join(tempProject, ".env"), []byte(envContent), 0600); err != nil {
		t.Fatalf("failed to write dummy .env: %v", err)
	}

	for _, sub := range []string{"internal/store", "internal/api"} {
		t.Run(sub, func(t *testing.T) {
			subDir := filepath.Join(tempProject, filepath.FromSlash(sub))
			if err := os.MkdirAll(subDir, 0700); err != nil {
				t.Fatalf("failed to create subDir: %v", err)
			}

			// Change working directory to simulated internal/{store,api}
			t.Chdir(subDir)

			// Clean process environment so only .env is read
			os.Unsetenv("POSTGRES_HOST")
			os.Unsetenv("POSTGRES_PORT")
			os.Unsetenv("POSTGRES_USER")
			os.Unsetenv("POSTGRES_PASSWORD")
			os.Unsetenv("DATABASE_URL")
			os.Unsetenv("ENV_FILE")

			cfg, err := config.LoadDBConfig()
			if err != nil {
				t.Fatalf("LoadDBConfig failed from internal subdirectory: %v", err)
			}

			if !strings.Contains(cfg.DisplayTarget, "10.0.0.99:15433") {
				t.Fatalf("expected non-default host and port 10.0.0.99:15433 discovered from root .env, got display: %s", cfg.DisplayTarget)
			}
			if !strings.Contains(cfg.ConnURL, "special_user:") {
				t.Fatalf("expected non-default user special_user discovered in ConnURL")
			}
			if cfg.Password != "p@ss:w#rd%999" {
				t.Fatalf("expected non-default password discovered from root .env (password mismatch)")
			}
			if !strings.Contains(cfg.ConnURL, "p%40ss%3Aw%23rd%25999") {
				t.Fatalf("expected URL-encoded reserved password in ConnURL")
			}
		})
	}
}

func TestFindBackendEnv_ActualInternalDirs(t *testing.T) {
	for _, sub := range []string{"store", "api"} {
		targetDir := filepath.Join("..", sub)
		if stat, err := os.Stat(targetDir); err == nil && stat.IsDir() {
			t.Run("actual_internal_"+sub, func(t *testing.T) {
				t.Chdir(targetDir)
				found := config.FindBackendEnv()
				if found == "" {
					t.Fatalf("failed to discover root .env from actual %s directory", targetDir)
				}
				if !strings.HasSuffix(found, filepath.Join("gsmvoiceebackend", ".env")) {
					t.Fatalf("expected backend .env path ending in gsmvoiceebackend/.env, got %s", found)
				}
			})
		}
	}
}

func TestFindBackendEnv_BoundedDiscoveryStopsAtProjectRoot(t *testing.T) {
	parentDir := t.TempDir()
	// Create an unrelated parent workspace .env
	parentEnv := filepath.Join(parentDir, ".env")
	if err := os.WriteFile(parentEnv, []byte("POSTGRES_PORT=9999\n"), 0600); err != nil {
		t.Fatalf("failed to write parent .env: %v", err)
	}

	backendDir := filepath.Join(parentDir, "gsmvoiceebackend")
	subDir := filepath.Join(backendDir, "internal", "store")
	if err := os.MkdirAll(subDir, 0700); err != nil {
		t.Fatalf("failed to create dirs: %v", err)
	}
	if err := os.WriteFile(filepath.Join(backendDir, "go.mod"), []byte("module gsmvoiceebackend\n\ngo 1.27.1\n"), 0600); err != nil {
		t.Fatalf("failed to write go.mod: %v", err)
	}

	t.Chdir(subDir)
	found := config.FindBackendEnv()
	if found != "" {
		t.Fatalf("expected bounded discovery to NOT load parent workspace .env, got: %s", found)
	}
}
