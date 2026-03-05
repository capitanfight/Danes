#!/bin/bash

info()    { echo -e "\e[32m[update]\e[0m $*"; }
warn()    { echo -e "\e[33m[update]\e[0m WARNING: $*"; }
error()   { echo -e "\e[31m[update]\e[0m ERROR: $*" >&2; exit 1; }
require() { command -v "$1" &>/dev/null || error "$1 is required but not found. Please install it first."; }

info "Checking requirements..."
require git
require javac
info "All requirements met."

$DANES_DIR="$HOME/.config/danes"
$REPO_DIR="$DANES_DIR/repo"
$SETUP="$REPO_DIR/setup.sh"
$EXEC_DANES="$HOME/.local/bin/danes"

info "Checking for updates in git repo..."
if [[ ! -d "$REPO_DIR/.git" ]]; then
    error "Repo dir not found"
fi

cd "$REPO_DIR"

# Fetch without merging; suppress non-fatal errors (e.g. no network)
git fetch origin 2>/dev/null || true

LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse @{u} 2>/dev/null || echo "$LOCAL")

if [[ "$LOCAL" != "$REMOTE" ]]; then
    log "Update found — pulling latest changes..."
    git pull --ff-only origin 2>/dev/null || {
        log "WARNING: git pull failed, running with existing version."
    }
    RESETUP=true
else
    log "Already up to date."
    RESETUP=false
fi

info "Setting up Danes..."
if [[ "$RESETUP" == true ]]; then
    if [[ ! -f "$SETUP" ]]; then
        error "Set up file was not found at $SETUP"
    fi
    chmod +x "$SETUP"
    exec "$SETUP"
    info "Setup completed"

    info "Executing Danes..."
    chmod +x "$EXEC_DANES"
    exec "$EXEC_DANES"
fi

