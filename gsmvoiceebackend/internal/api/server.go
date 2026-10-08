package api

import (
	"net/http"

	"gsmvoiceebackend/internal/auth"
	"gsmvoiceebackend/internal/store"
)

// Server coordinates HTTP routing, storage, and session authentication.
type Server struct {
	userStore      store.UserStore
	sessionManager *auth.SessionManager
	mux            *http.ServeMux
}

// NewServer builds and configures a new Server instance.
func NewServer(userStore store.UserStore, sessionManager *auth.SessionManager) *Server {
	s := &Server{
		userStore:      userStore,
		sessionManager: sessionManager,
		mux:            http.NewServeMux(),
	}

	s.routes()
	return s
}

func (s *Server) routes() {
	s.mux.HandleFunc("POST /auth/register", s.handleRegister)
	s.mux.HandleFunc("POST /auth/login", s.handleLogin)
	s.mux.HandleFunc("GET /auth/me", s.handleMe)
	s.mux.HandleFunc("POST /auth/logout", s.handleLogout)
	s.mux.HandleFunc("GET /health", s.handleHealth)
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	s.mux.ServeHTTP(w, r)
}
