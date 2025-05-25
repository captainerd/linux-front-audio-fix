#!/bin/bash

set -e

PKG_NAME="linux-headphones"
VERSION="1"
ARCH="all"
SCRIPT_FILE="headphones-jackedin.sh"
DEB_DIR="${PKG_NAME}_${VERSION}"
BUILD_DIR="./${DEB_DIR}"
BIN_DIR="${BUILD_DIR}/usr/local/bin"
SERVICE_DIR="${BUILD_DIR}/etc/systemd/system"

# Check if script exists
if [[ ! -f "$SCRIPT_FILE" ]]; then
  echo "❌ Script file '$SCRIPT_FILE' not found!"
  exit 1
fi

# Clean any previous build
rm -rf "$BUILD_DIR" "${DEB_DIR}.deb"

# Create directory structure
mkdir -p "$BIN_DIR" "$SERVICE_DIR" "${BUILD_DIR}/DEBIAN"

# Copy the script
install -m 755 "$SCRIPT_FILE" "$BIN_DIR"

# Create systemd service
cat <<EOF > "${SERVICE_DIR}/headphones-jackedin.service"
[Unit]
Description=Auto-switch to real headphones when virtual sink is selected
After=default.target

[Service]
Type=simple
User=natsos
ExecStart=/usr/local/bin/headphones-jackedin.sh
Restart=on-failure
Environment=DISPLAY=:0
Environment=XDG_RUNTIME_DIR=/run/user/1000

[Install]
WantedBy=default.target

EOF

# Create control file
cat <<EOF > "${BUILD_DIR}/DEBIAN/control"
Package: $PKG_NAME
Version: $VERSION
Section: base
Priority: optional
Architecture: $ARCH
Depends: pulseaudio
Maintainer: Velecron (natsos@velecron.net)
Description: Virtual audio output to always show front "Headphones" in sound settings
 Adds a virtual audio output in Linux to always display a front "Headphones" option in sound settings. 
 Useful if front panel jack sensing (fsense) pins are missing, malfunctioning, or you're stuck with an old AC'97 layout.

EOF


# Create postinst script to enable and start service
cat <<'EOF' > "${BUILD_DIR}/DEBIAN/postinst"
#!/bin/sh
set -e

systemctl daemon-reload
systemctl enable headphones-jackedin.service
systemctl start headphones-jackedin.service || true

exit 0
EOF

chmod 755 "${BUILD_DIR}/DEBIAN/postinst"

# Create prerm script to stop and disable service on removal
cat <<'EOF' > "${BUILD_DIR}/DEBIAN/prerm"
#!/bin/sh
set -e

systemctl stop headphones-jackedin.service || true
systemctl disable headphones-jackedin.service || true
rm -f /etc/systemd/system/headphones-jackedin.service || true

systemctl daemon-reload

exit 0
EOF

chmod 755 "${BUILD_DIR}/DEBIAN/prerm"

# Build the .deb
dpkg-deb --build "$BUILD_DIR"

echo "✅ Built ${DEB_DIR}.deb"

