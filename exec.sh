#!/bin/bash

set -euo pipefail

DIR="$HOME/.config/danes"
REPO_DIR="$DIR/repo"
BIN_DIR="$DIR/bin"
LOG="$DIR/logs/danes.log"
PID_FILE="$DIR/danes.pid"

# ---------- helpers ----------------------------------------------------------

log() { echo "[danes] $*"; }

kill_existing() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log "Stopping existing server (PID $pid)..."
            kill "$pid" && sleep 1
        fi
        rm -f "$PID_FILE"
    fi
}

exec "$BIN_DIR/update.sh"

kill_existing

log "Starting Danes in background..."
nohup java -cp "$BIN_DIR" Danes >> "$LOG" 2>&1 &
echo $! > "$PID_FILE"
log "Danes started (PID $(cat "$PID_FILE")). Log: $LOG"


