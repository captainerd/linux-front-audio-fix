#!/bin/bash

set -e

PKG_NAME="linux-headphones"
VERSION="4"
ARCH="all"
SCRIPT_FILE="headphones-jackedin.sh"
DEB_DIR="${PKG_NAME}_${VERSION}"
BUILD_DIR="./${DEB_DIR}"
BIN_DIR="${BUILD_DIR}/usr/local/bin"
SERVICE_DIR="${BUILD_DIR}/etc/systemd/user"   # change to user systemd dir

# ... rest same ...

mkdir -p "$BIN_DIR" "$SERVICE_DIR" "${BUILD_DIR}/DEBIAN"

# Copy the script
install -m 755 "$SCRIPT_FILE" "$BIN_DIR"

# Create user service (no User= line)
cat <<EOF > "${SERVICE_DIR}/headphones-jackedin.service"
[Unit]
Description=Auto-switch to real headphones when virtual sink is selected
After=graphical.target

[Service]
Type=simple
ExecStart=/usr/local/bin/headphones-jackedin.sh
ExecStop=/usr/local/bin/headphones-jackedin.sh --stop
Restart=on-failure

[Install]
WantedBy=default.target
EOF

# Control file same except add systemd user dependency
cat <<EOF > "${BUILD_DIR}/DEBIAN/control"
Package: $PKG_NAME
Version: $VERSION
Section: base
Priority: optional
Architecture: $ARCH
Depends: pulseaudio | pipewire-pulse, systemd
Maintainer: Velecron (natsos@velecron.net)
Description: Virtual audio output to always show front "Headphones" in sound settings
 Adds a virtual audio output in Linux to always display a front "Headphones" option in sound settings. 
 Useful if front panel jack sensing (fsense) pins are missing, malfunctioning, or you're stuck with an old AC'97 layout.

EOF

# postinst: enable/start user service for current user
cat <<'EOF' > "${BUILD_DIR}/DEBIAN/postinst"
#!/bin/sh
set -e

run_user_systemctl() {
    local UID=$1
    local USERNAME
    USERNAME=$(id -nu "$UID")

    export XDG_RUNTIME_DIR="/run/user/$UID"
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$UID/bus"

    sudo -u "$USERNAME" env XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
        systemctl --user daemon-reload
    sudo -u "$USERNAME" env XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
        systemctl --user enable headphones-jackedin.service
    sudo -u "$USERNAME" env XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
        systemctl --user start headphones-jackedin.service || true
}

for dir in /run/user/*; do
    uid=$(basename "$dir")
    # Check if bus socket exists to confirm active session
    if [ -e "$dir/bus" ]; then
        run_user_systemctl "$uid"
    fi
done

exit 0

EOF

chmod 755 "${BUILD_DIR}/DEBIAN/postinst"

# prerm to stop/disable user service for current user
cat <<'EOF' > "${BUILD_DIR}/DEBIAN/prerm"
#!/bin/sh
set -e

 
run_user_systemctl() {
    UID=$1
    USERNAME=$(id -nu "$UID" 2>/dev/null || echo "")

    if [ -z "$USERNAME" ]; then
        echo "No user for UID $UID, skipping" >&2
        return
    fi

    export XDG_RUNTIME_DIR="/run/user/$UID"
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$UID/bus"

    if [ ! -S "$XDG_RUNTIME_DIR/bus" ]; then
        echo "No DBUS session bus for user $USERNAME ($UID), skipping PulseAudio unload and systemctl" >&2
        return
    fi
 

    sudo -u "$USERNAME" env XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" systemctl --user stop headphones-jackedin.service || true
    sudo -u "$USERNAME" env XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" systemctl --user disable headphones-jackedin.service || true
    sudo -u "$USERNAME" env XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" systemctl --user daemon-reload || true
}

for dir in /run/user/*; do
    uid=$(basename "$dir")
    if [ -S "/run/user/$uid/bus" ]; then
        run_user_systemctl "$uid"
    else
        echo "No bus socket for UID $uid, skipping" >&2
    fi
done

exit 0


EOF

chmod 755 "${BUILD_DIR}/DEBIAN/prerm"

# Build the .deb
dpkg-deb --build "$BUILD_DIR"

echo "Built ${DEB_DIR}.deb"
