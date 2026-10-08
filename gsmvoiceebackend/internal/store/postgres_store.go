package store

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgconn"
	_ "github.com/jackc/pgx/v5/stdlib"
)

const usersTableSchema = `
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(64) PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    password_hash VARCHAR(64) NOT NULL,
    salt VARCHAR(32) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_users_email_lower ON users (LOWER(email));
`

// PostgresStore implements UserStore backed by PostgreSQL.
type PostgresStore struct {
	db *sql.DB
}

// NewPostgresStore creates a PostgresStore using an existing sql.DB.
// It verifies connectivity and executes table creation if not already present.
func NewPostgresStore(db *sql.DB) (*PostgresStore, error) {
	if db == nil {
		return nil, errors.New("database connection cannot be nil")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := db.PingContext(ctx); err != nil {
		return nil, fmt.Errorf("ping postgres database: %w", err)
	}

	if _, err := db.ExecContext(ctx, usersTableSchema); err != nil {
		return nil, fmt.Errorf("execute schema migration: %w", err)
	}

	return &PostgresStore{db: db}, nil
}

// OpenPostgres initializes a connection pool and returns a ready PostgresStore.
func OpenPostgres(connStr string) (*PostgresStore, error) {
	db, err := sql.Open("pgx", connStr)
	if err != nil {
		return nil, fmt.Errorf("open postgres database: %w", err)
	}

	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(5 * time.Minute)

	store, err := NewPostgresStore(db)
	if err != nil {
		_ = db.Close()
		return nil, err
	}

	return store, nil
}

// CreateUser persists a new user into PostgreSQL.
func (s *PostgresStore) CreateUser(name, email, passwordHash, salt string) (*User, error) {
	normEmail := strings.ToLower(strings.TrimSpace(email))

	saltBytes, err := hex.DecodeString(salt)
	if err != nil || len(saltBytes) != 16 {
		return nil, errors.New("invalid salt encoding")
	}

	hashBytes, err := hex.DecodeString(passwordHash)
	if err != nil || len(hashBytes) != 32 {
		return nil, errors.New("invalid password hash encoding")
	}

	idBytes := make([]byte, 16)
	if _, err := rand.Read(idBytes); err != nil {
		return nil, fmt.Errorf("generate user id: %w", err)
	}

	user := &User{
		ID:           hex.EncodeToString(idBytes),
		Email:        normEmail,
		Name:         strings.TrimSpace(name),
		PasswordHash: passwordHash,
		Salt:         salt,
		CreatedAt:    time.Now().UTC(),
	}

	query := `
INSERT INTO users (id, email, name, password_hash, salt, created_at)
VALUES ($1, $2, $3, $4, $5, $6)`

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, err = s.db.ExecContext(ctx, query,
		user.ID,
		user.Email,
		user.Name,
		user.PasswordHash,
		user.Salt,
		user.CreatedAt,
	)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return nil, ErrDuplicateEmail
		}
		if strings.Contains(strings.ToLower(err.Error()), "unique") {
			return nil, ErrDuplicateEmail
		}
		return nil, fmt.Errorf("insert user record: %w", err)
	}

	return user, nil
}

// GetByEmail retrieves a user by email address (case-insensitive).
func (s *PostgresStore) GetByEmail(email string) (*User, error) {
	normEmail := strings.ToLower(strings.TrimSpace(email))

	query := `
SELECT id, email, name, password_hash, salt, created_at
FROM users
WHERE LOWER(email) = LOWER($1)
LIMIT 1`

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	row := s.db.QueryRowContext(ctx, query, normEmail)

	var u User
	if err := row.Scan(&u.ID, &u.Email, &u.Name, &u.PasswordHash, &u.Salt, &u.CreatedAt); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrUserNotFound
		}
		return nil, fmt.Errorf("query user by email: %w", err)
	}

	return &u, nil
}

// GetByID retrieves a user by unique identifier.
func (s *PostgresStore) GetByID(id string) (*User, error) {
	query := `
SELECT id, email, name, password_hash, salt, created_at
FROM users
WHERE id = $1
LIMIT 1`

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	row := s.db.QueryRowContext(ctx, query, strings.TrimSpace(id))

	var u User
	if err := row.Scan(&u.ID, &u.Email, &u.Name, &u.PasswordHash, &u.Salt, &u.CreatedAt); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrUserNotFound
		}
		return nil, fmt.Errorf("query user by id: %w", err)
	}

	return &u, nil
}

// Close closes the underlying database pool.
func (s *PostgresStore) Close() error {
	return s.db.Close()
}

// Ping verifies database connectivity.
func (s *PostgresStore) Ping(ctx context.Context) error {
	return s.db.PingContext(ctx)
}

// ImportLegacyUsersJSON imports users from a legacy JSON file into PostgreSQL transactionally.
// It tolerates an absent file (returns nil if os.IsNotExist).
// It strictly validates all records and fails without partial import on invalid data.
// Repeated imports safely preserve existing records without duplicates.
func (s *PostgresStore) ImportLegacyUsersJSON(filePath string) error {
	data, err := os.ReadFile(filePath)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("read legacy users file %s: %w", filePath, err)
	}

	content := strings.TrimSpace(string(data))
	if len(content) == 0 {
		return fmt.Errorf("legacy users file %s is empty or corrupted", filePath)
	}

	var users []*User
	if err := json.Unmarshal(data, &users); err != nil {
		return fmt.Errorf("malformed legacy users json %s: %w", filePath, err)
	}

	if users == nil {
		return fmt.Errorf("legacy users list in %s is null", filePath)
	}

	for i, u := range users {
		if err := ValidateUserRecord(u); err != nil {
			return fmt.Errorf("invalid user record at index %d in %s: %w", i, filePath, err)
		}
	}

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin transaction for legacy import: %w", err)
	}
	defer tx.Rollback()

	query := `
INSERT INTO users (id, email, name, password_hash, salt, created_at)
VALUES ($1, $2, $3, $4, $5, $6)
ON CONFLICT DO NOTHING`

	for _, u := range users {
		normEmail := strings.ToLower(strings.TrimSpace(u.Email))
		_, err := tx.ExecContext(ctx, query,
			strings.TrimSpace(u.ID),
			normEmail,
			strings.TrimSpace(u.Name),
			u.PasswordHash,
			u.Salt,
			u.CreatedAt,
		)
		if err != nil {
			return fmt.Errorf("import user %s: %w", u.Email, err)
		}
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit legacy users import: %w", err)
	}

	return nil
}
