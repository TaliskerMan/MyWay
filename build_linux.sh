#!/usr/bin/env bash
# MyWay Release Builder for Linux
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "${SCRIPT_DIR}"

echo "==> Incrementing build version..."
bash "${SCRIPT_DIR}/scripts/increment_build.sh"

if [ -f pubspec.yaml ]; then
    CURRENT_VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}' | tr -d '\r')
    VERSION="${CURRENT_VERSION%+*}"
    BUILD_SUFFIX="${CURRENT_VERSION#*+}"
else
    echo "pubspec.yaml not found!"
    exit 1
fi
PKG_NAME="myway"
FLUTTER="flutter"
ARTIFACTS="${SCRIPT_DIR}/packaging/linux_build/artifacts"
BUILD_DIR="${SCRIPT_DIR}/build/linux/x64/release/bundle"
DEB_ROOT="${SCRIPT_DIR}/packaging/linux_build/deb_pkg"

echo "==> MyWay Linux Release Builder v${VERSION}+${BUILD_SUFFIX}"
mkdir -p "${ARTIFACTS}"

echo "==> Building Flutter Linux release..."
cd "${SCRIPT_DIR}"
"${FLUTTER}" build linux --release

echo "==> Preparing DEB package structure..."
rm -rf "${DEB_ROOT}"
mkdir -p "${DEB_ROOT}/DEBIAN"
mkdir -p "${DEB_ROOT}/usr/bin"
mkdir -p "${DEB_ROOT}/usr/lib/myway"
mkdir -p "${DEB_ROOT}/usr/share/applications"
mkdir -p "${DEB_ROOT}/usr/share/icons/hicolor/256x256/apps"
mkdir -p "${DEB_ROOT}/usr/share/doc/myway"

echo "==> Copying build artifacts..."
cp "${BUILD_DIR}/myway" "${DEB_ROOT}/usr/lib/myway/myway"
cp -r "${BUILD_DIR}/lib/." "${DEB_ROOT}/usr/lib/myway/lib/"
cp -r "${BUILD_DIR}/data/." "${DEB_ROOT}/usr/lib/myway/data/"

cat > "${DEB_ROOT}/usr/bin/myway" << 'WRAPPER'
#!/bin/bash
export LD_LIBRARY_PATH="/usr/lib/myway/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec /usr/lib/myway/myway "$@"
WRAPPER
chmod +x "${DEB_ROOT}/usr/bin/myway"

cat > "${DEB_ROOT}/usr/share/applications/myway.desktop" << 'DESKTOP'
[Desktop Entry]
Name=MyWay
Comment=Screen and Audio Capture utility
Exec=/usr/bin/myway
Icon=myway
Terminal=false
Type=Application
Categories=Utility;Video;AudioVideo;
StartupWMClass=com.example.myway
DESKTOP

# Fallback icon
touch "${DEB_ROOT}/usr/share/icons/hicolor/256x256/apps/myway.png"

if [ -f "${SCRIPT_DIR}/LICENSE" ]; then
    cp "${SCRIPT_DIR}/LICENSE" "${DEB_ROOT}/usr/share/doc/myway/copyright"
fi

echo "==> Generating DEBIAN/control file..."
INSTALLED_SIZE=$(du -sk "${DEB_ROOT}" | awk '{print $1}')
cat > "${DEB_ROOT}/DEBIAN/control" << CONTROL
Package: myway
Version: ${VERSION}-${BUILD_SUFFIX}
Architecture: amd64
Maintainer: Chuck Talk <chuck@nordheim.online>
Priority: optional
Depends: libgstreamer1.0-0, gstreamer1.0-plugins-base, gstreamer1.0-plugins-good, gstreamer1.0-plugins-bad, gstreamer1.0-plugins-ugly, gstreamer1.0-pipewire, pipewire, xdg-desktop-portal
Installed-Size: ${INSTALLED_SIZE}
Description: Screen and Audio Capture utility for Linux
 MyWay allows users to record their screen and audio seamlessly
 using modern Wayland and PipeWire technologies.
CONTROL

echo "==> Building .deb package..."
DEB_FILE="${ARTIFACTS}/${PKG_NAME}_${VERSION}-${BUILD_SUFFIX}_amd64.deb"
dpkg-deb --build --root-owner-group "${DEB_ROOT}" "${DEB_FILE}"

echo "==> Generating SHA512 hash..."
sha512sum "${DEB_FILE}" | awk '{print $1}' > "${DEB_FILE}.sha512"

echo "==> Signing .deb with GPG..."
if command -v gpg > /dev/null 2>&1; then
    gpg --local-user chuck@nordheim.online --detach-sign --yes --armor "${DEB_FILE}"
    echo "    Signed: ${DEB_FILE}.asc"
    gpg --export -a chuck@nordheim.online > "${ARTIFACTS}/chuck_pubkey.asc"
    echo "    Pubkey: ${ARTIFACTS}/chuck_pubkey.asc"
else
    echo "    WARNING: gpg not found - package NOT signed!"
fi

echo "==> Copying to NOBuilds directory..."
NOBUILDS_DIR="${HOME}/NOBuilds/MyWay/v${VERSION}+${BUILD_SUFFIX}"
mkdir -p "${NOBUILDS_DIR}"
cp "${ARTIFACTS}/"* "${NOBUILDS_DIR}/"

echo ""
echo "==================================="
echo "  Build complete!"
echo "  Package : ${DEB_FILE}"
echo "  SHA512  : ${DEB_FILE}.sha512"
echo "  GPG sig : ${DEB_FILE}.asc"
echo "  Local   : ${NOBUILDS_DIR}"
echo "==================================="
