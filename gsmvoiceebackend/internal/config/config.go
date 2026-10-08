package config

import (
	"errors"
	"fmt"
	"net"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/joho/godotenv"
)

var (
	userInfoRegex = regexp.MustCompile(`:[^@/:]+@`)
	connPassRegex = regexp.MustCompile(`(?i)password=[^\s&]+`)
)

// DBConfig holds parsed database connection parameters and display target.
type DBConfig struct {
	ConnURL       string
	DisplayTarget string
	Password      string
}

func getEnv(key, defaultVal string) string {
	if val := strings.TrimSpace(os.Getenv(key)); val != "" {
		return val
	}
	return defaultVal
}

// FindBackendEnv searches for the backend .env file starting from the current working directory,
// bounded to the gsmvoiceebackend project root (identified by go.mod with module gsmvoiceebackend).
// It honors an explicit ENV_FILE environment variable override if provided.
// It stops at the backend project root to ensure an unrelated parent workspace .env is never loaded.
func FindBackendEnv() string {
	if explicit := strings.TrimSpace(os.Getenv("ENV_FILE")); explicit != "" {
		if _, err := os.Stat(explicit); err == nil {
			return explicit
		}
	}

	dir, err := os.Getwd()
	if err != nil {
		return ""
	}

	for i := 0; i < 5; i++ {
		goModPath := filepath.Join(dir, "go.mod")
		if data, err := os.ReadFile(goModPath); err == nil {
			if strings.Contains(string(data), "module gsmvoiceebackend") {
				envPath := filepath.Join(dir, ".env")
				if _, err := os.Stat(envPath); err == nil {
					return envPath
				}
				return ""
			}
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	return ""
}

// LoadEnv loads the backend .env file using bounded project discovery or explicit ENV_FILE.
// Missing files are tolerated safely. Read and parse errors fail fast.
func LoadEnv() error {
	envPath := FindBackendEnv()
	if envPath == "" {
		return nil
	}
	if err := godotenv.Load(envPath); err != nil {
		return fmt.Errorf("load .env file %s: %w", envPath, err)
	}
	return nil
}

// LoadDBConfig loads environment variables and constructs database connection parameters.
// It uses POSTGRES_* variables by default, or DATABASE_URL if explicitly set.
// It guarantees that errors never reveal passwords or sensitive credentials.
func LoadDBConfig() (*DBConfig, error) {
	if err := LoadEnv(); err != nil {
		return nil, err
	}

	if rawURL := strings.TrimSpace(os.Getenv("DATABASE_URL")); rawURL != "" {
		return parseRawDatabaseURL(rawURL)
	}

	host := getEnv("POSTGRES_HOST", "127.0.0.1")
	port := getEnv("POSTGRES_PORT", "5433")
	user := getEnv("POSTGRES_USER", "gsmvoicee")
	pass := getEnv("POSTGRES_PASSWORD", "gsmvoicee_dev_secret")
	dbName := getEnv("POSTGRES_DB", "gsmvoicee")
	ssl := getEnv("POSTGRES_SSLMODE", "disable")

	u := &url.URL{
		Scheme: "postgres",
		User:   url.UserPassword(user, pass),
		Host:   net.JoinHostPort(host, port),
		Path:   "/" + dbName,
	}
	q := u.Query()
	if ssl != "" {
		q.Set("sslmode", ssl)
	}
	u.RawQuery = q.Encode()

	display := fmt.Sprintf("%s:%s/%s", host, port, dbName)
	return &DBConfig{
		ConnURL:       u.String(),
		DisplayTarget: display,
		Password:      pass,
	}, nil
}

func parseRawDatabaseURL(rawURL string) (*DBConfig, error) {
	parsed, err := url.Parse(rawURL)
	if err != nil {
		var urlErr *url.Error
		if errors.As(err, &urlErr) {
			return nil, fmt.Errorf("invalid DATABASE_URL syntax: %s", urlErr.Err)
		}
		return nil, errors.New("invalid DATABASE_URL syntax")
	}

	var pass string
	if parsed.User != nil {
		pass, _ = parsed.User.Password()
	}

	display := parsed.Host + parsed.Path
	return &DBConfig{
		ConnURL:       rawURL,
		DisplayTarget: display,
		Password:      pass,
	}, nil
}

// SanitizeError strips sensitive credentials and passwords from an error message.
func SanitizeError(err error, secret string) error {
	if err == nil {
		return nil
	}

	msg := err.Error()
	if secret != "" {
		msg = strings.ReplaceAll(msg, secret, "[REDACTED]")
	}
	msg = userInfoRegex.ReplaceAllString(msg, ":[REDACTED]@")
	msg = connPassRegex.ReplaceAllString(msg, "password=[REDACTED]")

	return errors.New(msg)
}
