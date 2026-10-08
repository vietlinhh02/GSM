package store

import (
	"encoding/hex"
	"errors"
	"strings"
	"time"
)

var (
	// ErrDuplicateEmail indicates an email is already registered.
	ErrDuplicateEmail = errors.New("email is already registered")
	// ErrUserNotFound indicates no user was found matching criteria.
	ErrUserNotFound = errors.New("user not found")
)

// User represents a stored user record.
type User struct {
	ID           string    `json:"id"`
	Email        string    `json:"email"`
	Name         string    `json:"name"`
	PasswordHash string    `json:"passwordHash"`
	Salt         string    `json:"salt"`
	CreatedAt    time.Time `json:"createdAt"`
}

// UserStore defines the repository interface for user authentication persistence.
type UserStore interface {
	CreateUser(name, email, passwordHash, salt string) (*User, error)
	GetByEmail(email string) (*User, error)
	GetByID(id string) (*User, error)
	Close() error
}

// ValidateUserRecord strictly validates user record fields, salt, and password hash.
func ValidateUserRecord(u *User) error {
	if u == nil {
		return errors.New("user record is nil")
	}
	if strings.TrimSpace(u.ID) == "" {
		return errors.New("user ID cannot be empty")
	}
	if strings.TrimSpace(u.Email) == "" {
		return errors.New("user email cannot be empty")
	}
	if strings.TrimSpace(u.Name) == "" {
		return errors.New("user name cannot be empty")
	}
	saltBytes, err := hex.DecodeString(u.Salt)
	if err != nil || len(saltBytes) != 16 {
		return errors.New("invalid salt encoding: must be 16-byte hex (32 characters)")
	}
	hashBytes, err := hex.DecodeString(u.PasswordHash)
	if err != nil || len(hashBytes) != 32 {
		return errors.New("invalid password hash encoding: must be 32-byte hex (64 characters)")
	}
	return nil
}
