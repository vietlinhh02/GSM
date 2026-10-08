.PHONY: help dev dev-backend db-up db-down db-status db-logs test test-integration lint

help:
	@echo "GSM Workspace Commands:"
	@echo "  make dev              - Run backend dev server with Docker PostgreSQL (alias: make dev-backend)"
	@echo "  make db-up            - Start PostgreSQL database container and wait until healthy"
	@echo "  make db-down          - Stop PostgreSQL database container (preserves volume)"
	@echo "  make db-status        - View database container status"
	@echo "  make db-logs          - Follow database container logs"
	@echo "  make test             - Run backend tests with live DB and -count=1"
	@echo "  make test-integration - Run PostgreSQL integration tests with -count=1"
	@echo "  make lint             - Run formatting and vet checks"

dev: dev-backend

dev-backend:
	@$(MAKE) -C gsmvoiceebackend dev

db-up:
	@$(MAKE) -C gsmvoiceebackend db-up

db-down:
	@$(MAKE) -C gsmvoiceebackend db-down

db-status:
	@$(MAKE) -C gsmvoiceebackend db-status

db-logs:
	@$(MAKE) -C gsmvoiceebackend db-logs

test:
	@$(MAKE) -C gsmvoiceebackend test

test-integration:
	@$(MAKE) -C gsmvoiceebackend test-integration

lint:
	@$(MAKE) -C gsmvoiceebackend lint
