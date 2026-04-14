#!/bin/bash
# dev.sh — Development helper for Inventory Intelligence
# Usage:
#   ./dev.sh setup    — First-time setup (install deps, create DB, migrate, seed)
#   ./dev.sh start    — Start Rails server + Sidekiq
#   ./dev.sh test     — Run full test suite
#   ./dev.sh lint     — Run RuboCop
#   ./dev.sh security — Run bundler-audit + brakeman
#   ./dev.sh health   — Check /health endpoint

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
    step "Installing Ruby dependencies..."
    bundle install

    step "Creating and migrating database..."
    bundle exec rails db:prepare

    step "Seeding development data..."
    bundle exec rails db:seed

    pass "Setup complete! Run './dev.sh start' to launch the app."
    ;;

  start)
    step "Starting Rails server (port 3000)..."
    echo "  Sidekiq: run './dev.sh sidekiq' in a separate terminal"
    bundle exec rails server
    ;;

  sidekiq)
    step "Starting Sidekiq..."
    bundle exec sidekiq -C config/sidekiq.yml
    ;;

  test)
    step "Running RSpec..."
    if bundle exec rspec; then
      pass "All tests passed!"
    else
      fail "Test failures detected"
      exit 1
    fi
    ;;

  lint)
    step "Running RuboCop..."
    bundle exec rubocop
    pass "Lint complete."
    ;;

  security)
    step "Running bundler-audit..."
    bundle exec bundler-audit check --update || true

    step "Running brakeman..."
    bundle exec brakeman --no-pager -q || true

    pass "Security checks complete."
    ;;

  health)
    step "Checking /health endpoint..."
    curl -s http://localhost:3000/health | python3 -m json.tool 2>/dev/null || curl -s http://localhost:3000/health
    echo ""
    ;;

  console)
    step "Starting Rails console..."
    bundle exec rails console
    ;;

  *)
    echo "Usage: ./dev.sh <command>"
    echo ""
    echo "Commands:"
    echo "  setup      Install deps, create DB, migrate, seed"
    echo "  start      Start Rails server"
    echo "  sidekiq    Start Sidekiq worker"
    echo "  test       Run RSpec test suite"
    echo "  lint       Run RuboCop linter"
    echo "  security   Run bundler-audit + brakeman"
    echo "  health     Check /health endpoint"
    echo "  console    Start Rails console"
    ;;

esac
