#!/bin/bash
# Needed to make it easier for RPM package distros to enable it.
# Until now, it needs the user to type manually on terminal "enable-headphones-jackedin.sh"
SERVICE_NAME="headphones-jackedin.service"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
GLOBAL_SERVICE_PATH="/etc/systemd/user/$SERVICE_NAME"

log() {
    echo -e "[\e[1;32mINFO\e[0m] $1"
}
warn() {
    echo -e "[\e[1;33mWARN\e[0m] $1"
}
debug() {
    echo -e "[\e[1;34mDEBUG\e[0m] $1"
}

# Check if running as root
if [ "$(id -u)" -eq 0 ]; then
    # Prefer the installing user if run via sudo
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        log "Detected sudo install. Switching to user: $SUDO_USER"
        sudo -u "$SUDO_USER" XDG_RUNTIME_DIR="/run/user/$(id -u "$SUDO_USER")" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$SUDO_USER")/bus" "$0"
        exit $?
    else
        warn "You're root, and no installing user was found (SUDO_USER empty). Skipping."
        exit 1
    fi
fi

debug "Whoami: $(whoami), User: $USER, Home: $HOME"
 
# Ensure the user has a systemd session bus
if ! loginctl show-user "$USER" &>/dev/null; then
    warn "No active user session detected for $USER. Please login graphically first."
    exit 1
fi

# Ensure user systemd directory exists
mkdir -p "$SYSTEMD_USER_DIR"

# Copy the service file instead of symlinking
if [ ! -e "$SYSTEMD_USER_DIR/$SERVICE_NAME" ]; then
    cp "$GLOBAL_SERVICE_PATH" "$SYSTEMD_USER_DIR/$SERVICE_NAME"
    log "Copied $SERVICE_NAME to your user systemd directory."
else
    log "Service already exists in user directory."
fi

# Reload and enable the service
systemctl --user daemon-reexec
systemctl --user daemon-reload
systemctl --user enable --now "$SERVICE_NAME" && \
    log "✅ Service $SERVICE_NAME is now active." || \
    warn "❌ Failed to enable service. Check systemctl --user status $SERVICE_NAME"
systemctl --user start  "$SERVICE_NAME"
