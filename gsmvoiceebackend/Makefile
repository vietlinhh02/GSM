.PHONY: help dev db-up db-down db-status db-logs test test-integration lint

SHELL := /bin/bash
CONTAINER_NAME := gsmvoicee-postgres
COMPOSE_FILE := docker-compose.yml

# Default target
help:
	@echo "GSM Voice Backend Development Commands:"
	@echo "  make dev              - Ensure healthy PostgreSQL and start backend dev server"
	@echo "  make db-up            - Start PostgreSQL container and wait until healthy"
	@echo "  make db-down          - Stop PostgreSQL container (preserves data volume)"
	@echo "  make db-status        - View database container status"
	@echo "  make db-logs          - Follow database container logs"
	@echo "  make test             - Ensure DB is healthy and run all tests with -count=1"
	@echo "  make test-integration - Run integration tests against PostgreSQL with -count=1"
	@echo "  make lint             - Run formatting and static analysis (vet)"

# Verify required host tools
check-tools:
	@command -v docker >/dev/null 2>&1 || { echo >&2 "Error: docker is required but not installed."; exit 1; }
	@docker compose version >/dev/null 2>&1 || { echo >&2 "Error: docker compose is required but not installed."; exit 1; }
	@command -v go >/dev/null 2>&1 || { echo >&2 "Error: go is required but not installed."; exit 1; }

# Initialize .env from .env.example if missing
init-env:
	@if [ ! -f .env ]; then \
		echo "Creating .env from .env.example..."; \
		cp .env.example .env; \
	fi

# Start PostgreSQL and wait for healthcheck
db-up: check-tools init-env
	@echo "Starting PostgreSQL container via Docker Compose..."
	@docker compose -f $(COMPOSE_FILE) up -d postgres
	@echo "Waiting for PostgreSQL to be healthy..."
	@for i in {1..30}; do \
		status=$$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' $(CONTAINER_NAME) 2>/dev/null || true); \
		if [ "$$status" = "healthy" ]; then \
			echo "PostgreSQL is healthy and ready!"; \
			exit 0; \
		fi; \
		if [ "$$status" = "unhealthy" ]; then \
			echo "Error: PostgreSQL container reported unhealthy status."; \
			docker compose -f $(COMPOSE_FILE) logs --tail=25 postgres; \
			exit 1; \
		fi; \
		sleep 1; \
	done; \
	echo "Error: Timed out waiting for PostgreSQL container to become healthy."; \
	docker compose -f $(COMPOSE_FILE) logs --tail=25 postgres; \
	exit 1

# Gracefully stop PostgreSQL container (data volume is preserved)
db-down: check-tools
	@echo "Stopping PostgreSQL container..."
	@docker compose -f $(COMPOSE_FILE) stop postgres
	@echo "PostgreSQL stopped. Data volume preserved."

# Show PostgreSQL container status
db-status: check-tools
	@docker compose -f $(COMPOSE_FILE) ps

# Tail PostgreSQL container logs
db-logs: check-tools
	@docker compose -f $(COMPOSE_FILE) logs -f postgres

# Run backend development server with PostgreSQL ready
dev: check-tools init-env db-up
	@echo "Starting backend development server..."
	@go run ./cmd/api

# Run formatting and vet checks
lint: check-tools
	@echo "Checking formatting..."
	@test -z "$$(gofmt -l .)" || { echo "Unformatted files found. Run 'gofmt -w .'"; exit 1; }
	@echo "Running go vet..."
	@go vet ./...
	@echo "Lint checks passed."

# Run all tests with live database ensuring non-cached execution
test: check-tools init-env db-up
	@echo "Running backend test suite with -count=1..."
	@RUN_INTEGRATION_TESTS=1 go test -race -v -count=1 ./...

# Dedicated integration test target
test-integration: test
