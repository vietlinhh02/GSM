package api

import (
	"errors"
	"net/mail"
	"regexp"
	"strings"
	"unicode/utf8"
)

var (
	emailRegex = regexp.MustCompile(
		`^[a-zA-Z0-9.!#$%&'*+/=?^_` + "`" +
			`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?` +
			`(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$`,
	)

	ErrNameEmpty        = errors.New("name cannot be empty")
	ErrNameTooLong      = errors.New("name cannot exceed 100 characters")
	ErrEmailInvalid     = errors.New("invalid email address format")
	ErrPasswordTooShort = errors.New("password must be at least 8 characters")
	ErrPasswordTooLong  = errors.New("password cannot exceed 128 characters")
)

// ValidateName checks trimmed name length within [1, 100] runes.
func ValidateName(raw string) (string, error) {
	name := strings.TrimSpace(raw)
	runes := utf8.RuneCountInString(name)
	if runes == 0 {
		return "", ErrNameEmpty
	}
	if runes > 100 {
		return "", ErrNameTooLong
	}
	return name, nil
}

// ValidateEmail performs strict email address validation rejecting display-name forms.
func ValidateEmail(raw string) (string, error) {
	trimmed := strings.TrimSpace(raw)
	if len(trimmed) == 0 || len(trimmed) > 254 {
		return "", ErrEmailInvalid
	}

	// Must not contain display name markers or whitespace
	if strings.ContainsAny(trimmed, "<>\"\r\n\t ") {
		return "", ErrEmailInvalid
	}

	if !emailRegex.MatchString(trimmed) {
		return "", ErrEmailInvalid
	}

	addr, err := mail.ParseAddress(trimmed)
	if err != nil || addr.Name != "" || addr.Address != trimmed {
		return "", ErrEmailInvalid
	}

	return strings.ToLower(trimmed), nil
}

// ValidatePassword validates password rune length within [8, 128].
func ValidatePassword(password string) error {
	runes := utf8.RuneCountInString(password)
	if runes < 8 {
		return ErrPasswordTooShort
	}
	if runes > 128 {
		return ErrPasswordTooLong
	}
	return nil
}
