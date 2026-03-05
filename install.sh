#!/bin/bash

info()    { echo -e "\e[32m[install]\e[0m $*"; }
warn()    { echo -e "\e[33m[install]\e[0m WARNING: $*"; }
error()   { echo -e "\e[31m[install]\e[0m ERROR: $*" >&2; exit 1; }
require() { command -v "$1" &>/dev/null || error "$1 is required but not found. Please install it first."; }

info "Checking requirements..."
require git
info "All requirements met."

REPO_URL="https://github.com/capitanfight/Danes.git"
REPO_DIR="$HOME/.cache/danes"
EXEC_DANES="$HOME/.local/bin/danes"
SETUP="$REPO_DIR/setup.sh"

info "Cloning repository from $REPO_URL..."
if [[ ! -d "$REPO_DIR" ]]; then
    mkdir -p "$REPO_DIR"
fi
git clone "$REPO_URL" "$REPO_DIR"
info "Repository clone completed"

info "Setting up Danes..."
if [[ ! -f "$SETUP" ]]; then
    error "Set up file was not found at $SETUP"
fi
chmod +x "$SETUP"
exec "$SETUP"
info "Setup completed"

info "Executing Danes..."
chmod +x "$EXEC_DANES"
exec "$EXEC_DANES"

info "Cleaning up..."
rm -rf "$REPO_DIR"
info "Succesfully cleaned up"

