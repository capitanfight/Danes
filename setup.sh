#!/bin/bash

info()    { echo -e "\e[32m[setup]\e[0m $*"; }
warn()    { echo -e "\e[33m[setup]\e[0m WARNING: $*"; }
error()   { echo -e "\e[31m[setup]\e[0m ERROR: $*" >&2; exit 1; }
require() { command -v "$1" &>/dev/null || error "$1 is required but not found. Please install it first."; }

info "Checking requirements..."

require java
require javac
require git

JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d. -f1)
[[ "$JAVA_VERSION" -ge 11 ]] 2>/dev/null || warn "Java 11+ recommended (found version ${JAVA_VERSION:-unknown})."

info "All requirements met."

$REPO_URL=""
DANES_DIR="$HOME/.config/danes"
RAID_DIR="$DANES_DIR/raids"
BIN_DIR="$DANES_DIR/bin"
EXEC_DEST="$HOME/.local/bin/danes"
CONFIG_DIR="$DANES_DIR/config"
REPO_DIR="$DANES_DIR/repo"
LOGS_DIR="$DANES_DIR/logs"
AUTOSTART_DIR="$HOME/.config/autostart"
SYSTEMD_DIR="$HOME/.config/systemd/user"

for dir in $DANES_DIR $RAID_DIR $BIN_DIR $CONFIG_DIR $REPO_DIR $LOGS_DIR "$HOME/.local/bin" $AUTOSTART_DIR $SYSTEMD_DIR; do
    if [[ ! -d "$dir" ]]; then
        info "Creating dir at: $dir"
        mkdir -p "$dir"
    fi
done

info "Setting up bin..."
mv "./update.sh" "$BIN_DIR"
chmod +x "$BIN_DIR/update.sh"

mv "./src/Danes.java" "$BIN_DIR"
info "Compiling Danes.java..."
javac -d "$BIN_DIR" "$REPO_DIR/src/Danes.java" || error "Compilation failed."
info "Compilation successful."
rm "$BIN_DIR/Danes.java"

mv "./exec.sh" "$EXEC_DEST"
chmod +x "$EXEC_DEST"
info "Bin setup completed"

info "Setting up repo..."
info "Cloning repository from $REPO_URL ..."
if [[ -d "$REPO_DIR/.git" ]]; then
    info "Repo already cloned — pulling latest..."
    git -C "$REPO_DIR" pull --ff-only
else
    git clone "$REPO_URL" "$REPO_DIR"
fi
info "Repo setup completed"

add_to_path() {
    local RC="$1"
    if [[ -f "$RC" ]] && grep -q 'local/bin' "$RC"; then
        return  # already there
    fi
    {
        echo ''
        echo '# Added by Danes installer'
        echo 'export PATH="$HOME/.local/bin:$PATH"'
    } >> "$RC"
    info "Added ~/.local/bin to PATH in $RC"
}

add_to_path "$HOME/.bashrc"
[[ -f "$HOME/.zshrc" ]] && add_to_path "$HOME/.zshrc"

info "Creating systemd user service..."

cat > "$SYSTEMD_DIR/danes.service" <<EOF
[Unit]
Description=Danes — The most trusted installer by vikings
After=network.target

[Service]
Type=forking
ExecStart=$EXEC_DEST
PIDFile=$DANES_DIR/danes.pid
Restart=on-failure
RestartSec=5
StandardOutput=append:$LOGS_DIR/danes.log
StandardError=append:$LOGS_DIR/danes.log

[Install]
WantedBy=default.target
EOF

# Enable the service (starts at user login; no sudo needed for user units)
if systemctl --user daemon-reload 2>/dev/null && systemctl --user enable danes.service 2>/dev/null; then
    info "systemd user service enabled — Danes will start at login."
else
    warn "systemctl --user not available. Falling back to XDG autostart only."
fi

# ---------- XDG autostart (fallback for non-systemd DEs) --------------------

info "Creating XDG autostart entry..."

cat > "$AUTOSTART_DIR/danes.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Danes
Comment=The most trusted installer by vikings
Exec=$EXEC_DEST
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

info "XDG autostart entry created at $AUTOSTART_DIR/danes.desktop"





