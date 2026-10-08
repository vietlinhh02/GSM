package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"gsmvoiceebackend/internal/api"
	"gsmvoiceebackend/internal/auth"
	"gsmvoiceebackend/internal/config"
	"gsmvoiceebackend/internal/store"
)

func getEnv(key, defaultVal string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultVal
}

func initUserStore() (*store.PostgresStore, string, error) {
	cfg, err := config.LoadDBConfig()
	if err != nil {
		return nil, "", err
	}

	pgStore, err := store.OpenPostgres(cfg.ConnURL)
	if err != nil {
		safeErr := config.SanitizeError(err, cfg.Password)
		return nil, "", fmt.Errorf("connect to PostgreSQL (%s): %w\n"+
			"Suggestion: ensure PostgreSQL is healthy (run 'make dev' or 'make db-up')",
			cfg.DisplayTarget, safeErr)
	}

	legacyFile := filepath.Join("data", "users.json")
	if err := pgStore.ImportLegacyUsersJSON(legacyFile); err != nil {
		_ = pgStore.Close()
		return nil, "", fmt.Errorf("import legacy users from %s: %w", legacyFile, err)
	}

	return pgStore, cfg.DisplayTarget, nil
}

func main() {
	if err := config.LoadEnv(); err != nil {
		log.Fatalf("configuration error: %v", err)
	}

	addr := getEnv("APP_ADDR", "127.0.0.1:8080")
	userStore, storeDesc, err := initUserStore()
	if err != nil {
		log.Fatalf("failed to initialize user store: %v", err)
	}
	defer userStore.Close()

	sessionManager := auth.NewSessionManager()
	serverHandler := api.NewServer(userStore, sessionManager)

	httpServer := &http.Server{
		Addr:         addr,
		Handler:      serverHandler,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	shutdown := make(chan os.Signal, 1)
	signal.Notify(shutdown, os.Interrupt, syscall.SIGTERM)

	go func() {
		log.Printf("Starting auth service on %s (database: postgres %s)", addr, storeDesc)
		if err := httpServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("HTTP server error: %v", err)
		}
	}()

	<-shutdown
	log.Println("Shutting down auth service...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := httpServer.Shutdown(ctx); err != nil {
		log.Printf("Server forced shutdown error: %v", err)
	}
	log.Println("Auth service stopped gracefully.")
}
