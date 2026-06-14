#!/usr/bin/env bash
# =============================================================================
# 01 — Install Prerequisites
# =============================================================================
# Installs minikube, kubectl, helm, and docker via Homebrew.
# Safe to re-run; skips anything already installed.
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }

install_if_missing() {
    local bin=$1
    local formula=${2:-$1}
    if command -v "$bin" &>/dev/null; then
        info "$bin is already installed: $(command -v "$bin")"
    else
        info "Installing $formula via Homebrew..."
        brew install "$formula"
    fi
}

echo ""
echo "================================================"
echo "  Falco in Action — Install Prerequisites"
echo "================================================"
echo ""

# Check Homebrew
if ! command -v brew &>/dev/null; then
    echo "❌ Homebrew is required. Install it from https://brew.sh"
    exit 1
fi

install_if_missing minikube
install_if_missing kubectl
install_if_missing helm
install_if_missing docker

echo ""
info "✅ All prerequisites installed."
echo ""
echo "Next step:"
echo "  ./scripts/02-start-cluster.sh"
echo ""
