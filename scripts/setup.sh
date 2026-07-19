#!/usr/bin/env bash
# ============================================================================
# owlnighter — bootstrap wrapper (macOS / Linux / Git Bash on Windows)
#
# Handles the "nothing installed" case: makes sure Node ≥20 and pnpm exist
# (installing Node via the OS package manager if it's missing), enables pnpm
# through corepack, then hands off to scripts/setup.mjs which does the real work.
#
# It deliberately does NOT try to auto-install the heavy tools (Docker Desktop,
# Flutter/Android SDK) — those installs are fragile to script. setup.mjs detects
# them and prints the official installer links instead.
#
# Usage:
#   ./scripts/setup.sh                 # interactive
#   ./scripts/setup.sh --non-interactive
# Safe to re-run.
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

info() { printf '\033[36m%s\033[0m\n' "$*"; }
warn() { printf '\033[33m%s\033[0m\n' "$*"; }
err()  { printf '\033[31m%s\033[0m\n' "$*" >&2; }

have() { command -v "$1" >/dev/null 2>&1; }

os_name() {
  case "$(uname -s)" in
    Darwin) echo macos ;;
    Linux)  echo linux ;;
    MINGW*|MSYS*|CYGWIN*) echo windows ;;
    *) echo unknown ;;
  esac
}

node_major() {
  node -v 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/'
}

install_node() {
  local os; os="$(os_name)"
  info "Node ≥20 not found — attempting to install..."
  case "$os" in
    macos)
      if have brew; then
        brew install node
      else
        err "Homebrew not found. Install Node ≥20 from https://nodejs.org/en/download and re-run."
        exit 1
      fi
      ;;
    linux)
      if have apt-get; then
        # NodeSource sets up a current LTS. Needs sudo.
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y nodejs
      elif have dnf; then
        sudo dnf install -y nodejs
      elif have pacman; then
        sudo pacman -S --noconfirm nodejs npm
      else
        err "No supported package manager (apt/dnf/pacman). Install Node ≥20 from https://nodejs.org and re-run."
        exit 1
      fi
      ;;
    *)
      err "Please install Node ≥20 from https://nodejs.org/en/download and re-run."
      exit 1
      ;;
  esac
}

# --- 1. Node -----------------------------------------------------------------
if ! have node || [ "$(node_major)" -lt 20 ] 2>/dev/null; then
  install_node
fi

if ! have node; then
  err "Node still not on PATH after install. Open a new shell and re-run."
  exit 1
fi
info "Using Node $(node -v)"

# --- 2. pnpm via corepack ----------------------------------------------------
if ! have pnpm; then
  if have corepack; then
    info "Enabling pnpm via corepack..."
    corepack enable || warn "corepack enable failed (may need sudo); continuing — setup.mjs will retry."
  else
    warn "corepack not found; setup.mjs will fall back to detecting pnpm."
  fi
fi

# --- 3. Hand off to the orchestrator -----------------------------------------
info "Launching setup..."
cd "$REPO_ROOT"
exec node scripts/setup.mjs "$@"
