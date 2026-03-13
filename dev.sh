#!/bin/bash
# dev.sh — One command to rule them all
# Usage:
#   ./dev.sh test     — Run all tests (backend + frontend)
#   ./dev.sh start    — Start the full app
#   ./dev.sh setup    — First-time setup (build, create DB, migrate)
#   ./dev.sh lint     — Run all linters
#   ./dev.sh stop     — Stop all services

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

step() { echo -e "\n${YELLOW}▸ $1${NC}"; }
pass() { echo -e "${GREEN}✓ $1${NC}"; }
fail() { echo -e "${RED}✗ $1${NC}"; }

case "${1:-help}" in

  setup)
    step "Building Docker images..."
    docker-compose build

    step "Starting DB and Redis..."
    docker-compose up -d db redis
    sleep 3

    step "Creating and migrating database..."
    docker-compose run --rm web bin/rails db:create db:migrate

    step "Setting up test database..."
    docker-compose run --rm -e RAILS_ENV=test web bin/rails db:create db:migrate

    pass "Setup complete! Run './dev.sh start' to launch the app."
    ;;

  start)
    step "Starting all services (Rails + Sidekiq + Postgres + Redis)..."
    docker-compose up
    ;;

  stop)
    step "Stopping all services..."
    docker-compose down
    pass "All services stopped."
    ;;

  test)
    step "TypeScript type check..."
    if npx tsc --noEmit; then
      pass "TypeScript OK"
    else
      fail "TypeScript errors found"
      exit 1
    fi

    step "Starting DB and Redis for backend tests..."
    docker-compose up -d db redis
    sleep 3

    step "Running RSpec (backend tests)..."
    if docker-compose run --rm -e RAILS_ENV=test web bundle exec rspec; then
      pass "RSpec OK"
    else
      fail "RSpec failures"
      exit 1
    fi

    echo ""
    pass "All tests passed!"
    ;;

  lint)
    step "ESLint (frontend)..."
    npx eslint frontend/ || true

    step "RuboCop (backend)..."
    docker-compose run --rm web bundle exec rubocop || true

    pass "Lint complete."
    ;;

  health)
    step "Checking /health endpoint..."
    curl -s http://localhost:3000/health | python3 -m json.tool 2>/dev/null || curl -s http://localhost:3000/health
    echo ""
    ;;

  *)
    echo "Usage: ./dev.sh <command>"
    echo ""
    echo "Commands:"
    echo "  setup    First-time setup (build images, create DB, migrate)"
    echo "  start    Start the full app (Rails + Sidekiq + Postgres + Redis)"
    echo "  stop     Stop all services"
    echo "  test     Run all tests (TypeScript + RSpec)"
    echo "  lint     Run linters (ESLint + RuboCop)"
    echo "  health   Check the /health endpoint"
    ;;

esac
