#!/bin/bash
set -euo pipefail

PKG_NAME="linux-headphones"
VERSION="4.1"
RELEASE="1"
ARCH="noarch"
PACKAGES_DIR="./packages"

# Working directory (where your sources live)
SRC_DIR="$(pwd)"
RPMBUILD_DIR="$SRC_DIR/rpmbuild"
SOURCES_DIR="$RPMBUILD_DIR/SOURCES"
SPECS_DIR="$RPMBUILD_DIR/SPECS"

# Create rpmbuild tree
rm -rf "$RPMBUILD_DIR"
mkdir -p "$SOURCES_DIR" "$SPECS_DIR" "$RPMBUILD_DIR/BUILD" "$RPMBUILD_DIR/RPMS" "$RPMBUILD_DIR/SRPMS"

echo "📦 Copying source files to $SOURCES_DIR..."
cp headphones-jackedin.sh "$SOURCES_DIR/"
cp enable-headphones-jackedin.sh "$SOURCES_DIR/"
cp headphones-jackedin.service "$SOURCES_DIR/"

# Write the spec file inline
SPEC_FILE="$SPECS_DIR/${PKG_NAME}.spec"

cat > "$SPEC_FILE" <<EOF
Name:           $PKG_NAME
Version:        $VERSION
Release:        $RELEASE%{?dist}
Summary:        Virtual audio output that always displays front Headphones

License:        MIT
URL:            https://velecron.net
Source0:        headphones-jackedin.sh
Source1:        headphones-jackedin.service
Source2:        enable-headphones-jackedin.sh

Recommends: pulseaudio
Recommends: pipewire-pulseaudio

BuildArch:      $ARCH

%description
Adds a virtual audio output in Linux to always display a front "Headphones" option in sound settings. 
Useful if front panel jack sensing pins are missing, malfunctioning, or you're stuck with an old AC'97 layout.

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/usr/local/bin
mkdir -p %{buildroot}/etc/systemd/user
install -m 755 %{SOURCE0} %{buildroot}/usr/local/bin/headphones-jackedin.sh
install -m 644 %{SOURCE1} %{buildroot}/etc/systemd/user/headphones-jackedin.service
install -m 755 %{SOURCE2} %{buildroot}/usr/local/bin/enable-headphones-jackedin.sh

%post
for uid in \$(ls /run/user); do
    export XDG_RUNTIME_DIR="/run/user/\$uid"
    export DBUS_SESSION_BUS_ADDRESS="unix:path=\$XDG_RUNTIME_DIR/bus"
    if [ -S "\$XDG_RUNTIME_DIR/bus" ]; then
        sudo -u "#\$uid" systemctl --user daemon-reexec
        sudo -u "#\$uid" systemctl --user daemon-reload
        sudo -u "#\$uid" systemctl --user enable --now headphones-jackedin.service || :
    fi
done
if [ -n "\$SUDO_USER" ] && [ "\$SUDO_USER" != "root" ]; then
    sudo -u "\$SUDO_USER" /usr/local/bin/enable-headphones-jackedin.sh || :
else
    echo "⚠️  Please run /usr/local/bin/enable-headphones-jackedin.sh as your user to finish setup."
fi

%preun
for uid in \$(ls /run/user); do
    export XDG_RUNTIME_DIR="/run/user/\$uid"
    export DBUS_SESSION_BUS_ADDRESS="unix:path=\$XDG_RUNTIME_DIR/bus"
    if [ -S "\$XDG_RUNTIME_DIR/bus" ]; then
        sudo -u "#\$uid" systemctl --user stop headphones-jackedin.service || :
        sudo -u "#\$uid" systemctl --user disable headphones-jackedin.service || :
        sudo -u "#\$uid" systemctl --user daemon-reload || :
    fi
done

%files
/usr/local/bin/headphones-jackedin.sh
/etc/systemd/user/headphones-jackedin.service
/usr/local/bin/enable-headphones-jackedin.sh

%changelog
* $(date +"%a %b %d %Y") Velecron <natsos@velecron.net> - $VERSION-$RELEASE
- Automated RPM build with embedded spec file
EOF

echo "🔧 Building RPM..."
rpmbuild --define "_topdir $RPMBUILD_DIR" -ba "$SPEC_FILE"
mv "$RPMBUILD_DIR/RPMS/noarch/"*.rpm "$PACKAGES_DIR/"
ABS_PACKAGES_DIR="$(cd "$PACKAGES_DIR" && pwd -P)"

echo -e "\033[32m✅ Build complete. RPMs are located in $ABS_PACKAGES_DIR\033[0m"

# Cleanup
rm -rf "$RPMBUILD_DIR"
echo "🧹 Cleaned up build directory."

