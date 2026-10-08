package api

import (
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/http"
	"strings"
	"time"

	"gsmvoiceebackend/internal/auth"
	"gsmvoiceebackend/internal/store"
)

const maxRequestBodyBytes = 16384 // 16 KB

// PublicUser represents public user profile data.
type PublicUser struct {
	ID        string    `json:"id"`
	Email     string    `json:"email"`
	Name      string    `json:"name"`
	CreatedAt time.Time `json:"createdAt"`
}

// RegisterRequest holds registration payload.
type RegisterRequest struct {
	Name     string `json:"name"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

// LoginRequest holds login payload.
type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

// AuthResponse represents authentication success response.
type AuthResponse struct {
	Token string     `json:"token"`
	User  PublicUser `json:"user"`
}

// UserResponse represents /auth/me response.
type UserResponse struct {
	User PublicUser `json:"user"`
}

// ErrorResponse represents structured error payload.
type ErrorResponse struct {
	Error string `json:"error"`
}

// MessageResponse represents simple message payload.
type MessageResponse struct {
	Message string `json:"message"`
}

func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) error {
	r.Body = http.MaxBytesReader(w, r.Body, maxRequestBodyBytes)
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()

	if err := dec.Decode(dst); err != nil {
		return err
	}

	var extra any
	if err := dec.Decode(&extra); !errors.Is(err, io.EOF) {
		return errors.New("unexpected trailing JSON data")
	}

	return nil
}

func writeJSON(w http.ResponseWriter, status int, data any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(data); err != nil {
		log.Printf("write json error: %v", err)
	}
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, ErrorResponse{Error: msg})
}

func extractBearerToken(r *http.Request) (string, bool) {
	authHeader := r.Header.Get("Authorization")
	if authHeader == "" {
		return "", false
	}
	parts := strings.SplitN(authHeader, " ", 2)
	if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
		return "", false
	}
	token := strings.TrimSpace(parts[1])
	if token == "" {
		return "", false
	}
	return token, true
}

func toPublicUser(u *store.User) PublicUser {
	return PublicUser{
		ID:        u.ID,
		Email:     u.Email,
		Name:      u.Name,
		CreatedAt: u.CreatedAt,
	}
}

func (s *Server) handleRegister(w http.ResponseWriter, r *http.Request) {
	var req RegisterRequest
	if err := decodeJSON(w, r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "Invalid request payload: "+err.Error())
		return
	}

	name, err := ValidateName(req.Name)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	email, err := ValidateEmail(req.Email)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	if err := ValidatePassword(req.Password); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	hash, salt, err := auth.HashPassword(req.Password)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to hash password")
		return
	}

	user, err := s.userStore.CreateUser(name, email, hash, salt)
	if err != nil {
		if errors.Is(err, store.ErrDuplicateEmail) {
			writeError(w, http.StatusConflict, "Email is already registered")
			return
		}
		writeError(w, http.StatusInternalServerError, "Failed to create user")
		return
	}

	token, err := s.sessionManager.CreateSession(user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to generate session")
		return
	}

	writeJSON(w, http.StatusCreated, AuthResponse{
		Token: token,
		User:  toPublicUser(user),
	})
}

func (s *Server) handleLogin(w http.ResponseWriter, r *http.Request) {
	var req LoginRequest
	if err := decodeJSON(w, r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "Invalid request payload: "+err.Error())
		return
	}

	email, err := ValidateEmail(req.Email)
	if err != nil {
		// Generic invalid credentials response for security
		writeError(w, http.StatusUnauthorized, "Invalid email or password")
		return
	}

	user, err := s.userStore.GetByEmail(email)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "Invalid email or password")
		return
	}

	match, err := auth.VerifyPassword(req.Password, user.Salt, user.PasswordHash)
	if err != nil || !match {
		writeError(w, http.StatusUnauthorized, "Invalid email or password")
		return
	}

	token, err := s.sessionManager.CreateSession(user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to generate session")
		return
	}

	writeJSON(w, http.StatusOK, AuthResponse{
		Token: token,
		User:  toPublicUser(user),
	})
}

func (s *Server) handleMe(w http.ResponseWriter, r *http.Request) {
	token, ok := extractBearerToken(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	userID, ok := s.sessionManager.GetSession(token)
	if !ok {
		writeError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	user, err := s.userStore.GetByID(userID)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	writeJSON(w, http.StatusOK, UserResponse{
		User: toPublicUser(user),
	})
}

func (s *Server) handleLogout(w http.ResponseWriter, r *http.Request) {
	token, ok := extractBearerToken(r)
	if ok {
		s.sessionManager.DeleteSession(token)
	}
	writeJSON(w, http.StatusOK, MessageResponse{
		Message: "Logged out successfully",
	})
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}
