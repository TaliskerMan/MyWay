#!/usr/bin/env bash
# MyWay Release Builder for Linux
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "${SCRIPT_DIR}"

NO_BUMP=false
for arg in "$@"; do
    if [[ "$arg" == "--no-bump" ]]; then
        NO_BUMP=true
    fi
done

if [[ "$NO_BUMP" = false ]]; then
    echo "==> Incrementing build version..."
    bash "${SCRIPT_DIR}/scripts/increment_build.sh"
else
    echo "==> Re-using current version without bumping (--no-bump specified)"
fi

if [[ -f pubspec.yaml ]]; then
    CURRENT_VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}' | tr -d '\r')
    VERSION="${CURRENT_VERSION%+*}"
    BUILD_SUFFIX="${CURRENT_VERSION#*+}"
else
    echo "pubspec.yaml not found!"
    exit 1
fi
PKG_NAME="myway"

# Single source of truth: regenerate assets/version.json from pubspec so the
# About screen can never show a stale version.
echo "==> Writing assets/version.json from pubspec (${VERSION}, build ${BUILD_SUFFIX})..."
cat > "${SCRIPT_DIR}/assets/version.json" <<JSON
{
  "app_name": "myway",
  "version": "${VERSION}",
  "build_number": "${BUILD_SUFFIX}",
  "package_name": "myway"
}
JSON
FLUTTER="flutter"
ARTIFACTS="${SCRIPT_DIR}/packaging/linux_build/artifacts"

# Fix clang++ linker issue on some arm64/Linux environments
if [[ -d "/usr/lib/gcc/aarch64-linux-gnu/13" ]]; then
    export LIBRARY_PATH="/usr/lib/gcc/aarch64-linux-gnu/13:${LIBRARY_PATH:-}"
fi
if [[ -d "/usr/include/c++/13" ]]; then
    export CPLUS_INCLUDE_PATH="/usr/include/c++/13:/usr/include/aarch64-linux-gnu/c++/13:${CPLUS_INCLUDE_PATH:-}"
fi

UNAME_M=$(uname -m)
if [[ "$UNAME_M" = "x86_64" ]]; then
    FLUTTER_ARCH="x64"
elif [[ "$UNAME_M" = "aarch64" ]]; then
    FLUTTER_ARCH="arm64"
else
    FLUTTER_ARCH="$UNAME_M"
fi

ARCH=$(dpkg --print-architecture)
BUILD_DIR="${SCRIPT_DIR}/build/linux/${FLUTTER_ARCH}/release/bundle"
DEB_ROOT="${SCRIPT_DIR}/packaging/linux_build/deb_pkg"

echo "==> MyWay Linux Release Builder v${VERSION}+${BUILD_SUFFIX}"
rm -rf "${ARTIFACTS}"
mkdir -p "${ARTIFACTS}"

echo "==> Building Flutter Linux release..."
cd "${SCRIPT_DIR}"
"${FLUTTER}" build linux --release

echo "==> Generating SBOM via Syft..."
SYFT_BIN="syft"
if ! command -v syft &> /dev/null; then
    if [[ -f "${HOME}/.local/bin/syft" ]]; then
        SYFT_BIN="${HOME}/.local/bin/syft"
    elif [[ -f "./syft" ]]; then
        SYFT_BIN="./syft"
    fi
fi
if command -v "${SYFT_BIN}" &> /dev/null; then
    mkdir -p "${SCRIPT_DIR}/Audit"
    "${SYFT_BIN}" dir:. \
        --exclude ./venv \
        --exclude ./android \
        --exclude ./ios \
        --exclude ./macos \
        --exclude ./build \
        --exclude ./packaging_output \
        --exclude ./dist \
        --exclude ./plan \
        --exclude ./.dart_tool \
        --exclude ./.agents \
        --exclude ./.gemini \
        -o cyclonedx-json > "${SCRIPT_DIR}/Audit/SBOM-Linux.json"
    cp "${SCRIPT_DIR}/Audit/SBOM-Linux.json" "${SCRIPT_DIR}/Audit/SBOM-Linux"
    cp "${SCRIPT_DIR}/Audit/SBOM-Linux.json" "${SCRIPT_DIR}/Audit/sbom.json"
fi

echo "==> Preparing DEB package structure..."
rm -rf "${DEB_ROOT}"
mkdir -p "${DEB_ROOT}/DEBIAN"
mkdir -p "${DEB_ROOT}/usr/bin"
mkdir -p "${DEB_ROOT}/usr/lib/myway"
mkdir -p "${DEB_ROOT}/usr/share/applications"
mkdir -p "${DEB_ROOT}/usr/share/icons/hicolor"
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

# Also install com.example.myway.desktop for Wayland / GNOME Shell matching
cp "${DEB_ROOT}/usr/share/applications/myway.desktop" "${DEB_ROOT}/usr/share/applications/com.example.myway.desktop"

# Copy full 9-tier hicolor icon suite (16x16 to 512x512)
echo "==> Copying high-resolution hicolor icon suite..."
cp -r "${SCRIPT_DIR}/share/icons/hicolor/." "${DEB_ROOT}/usr/share/icons/hicolor/"

# Copy package control scripts
if [[ -f "${SCRIPT_DIR}/debian/postinst" ]]; then
    cp "${SCRIPT_DIR}/debian/postinst" "${DEB_ROOT}/DEBIAN/postinst"
    chmod 755 "${DEB_ROOT}/DEBIAN/postinst"
fi
if [[ -f "${SCRIPT_DIR}/debian/postrm" ]]; then
    cp "${SCRIPT_DIR}/debian/postrm" "${DEB_ROOT}/DEBIAN/postrm"
    chmod 755 "${DEB_ROOT}/DEBIAN/postrm"
fi

if [[ -f "${SCRIPT_DIR}/LICENSE" ]]; then
    cp "${SCRIPT_DIR}/LICENSE" "${DEB_ROOT}/usr/share/doc/myway/copyright"
fi

echo "==> Generating DEBIAN/control file..."
INSTALLED_SIZE=$(du -sk "${DEB_ROOT}" | awk '{print $1}')
cat > "${DEB_ROOT}/DEBIAN/control" << CONTROL
Package: myway
Version: ${VERSION}-${BUILD_SUFFIX}
Architecture: ${ARCH}
Maintainer: Chuck Talk <chuck@nordheim.online>
Priority: optional
Depends: libgtk-3-0, libgstreamer1.0-0 (>= 1.22), gstreamer1.0-plugins-base, gstreamer1.0-plugins-good, gstreamer1.0-plugins-bad, gstreamer1.0-plugins-ugly, gstreamer1.0-pipewire, pipewire, xdg-desktop-portal (>= 1.12), x11-utils
Recommends: xdg-desktop-portal-gnome
Installed-Size: ${INSTALLED_SIZE}
Description: Screen and Audio Capture utility for Linux
 Records the full screen or a single window, with audio, to MP4
 (H.264, H.265 or AV1) using GStreamer, PipeWire and the Wayland
 screen-sharing portal. Encoding is done in software.
CONTROL

echo "==> Building .deb package..."
DEB_FILE="${ARTIFACTS}/${PKG_NAME}_${VERSION}-${BUILD_SUFFIX}_${ARCH}.deb"
dpkg-deb --build --root-owner-group "${DEB_ROOT}" "${DEB_FILE}"

echo "==> Signing .deb with GPG..."
GPG_KEY="chuck@nordheim.online"
if command -v gpg > /dev/null 2>&1; then
    gpg --batch --yes --pinentry-mode loopback --local-user "${GPG_KEY}" --detach-sign --armor --output "${DEB_FILE}.asc" "${DEB_FILE}"
    echo "    Signed (ASCII): ${DEB_FILE}.asc"
    gpg --batch --yes --pinentry-mode loopback --local-user "${GPG_KEY}" --detach-sign --output "${DEB_FILE}.sig" "${DEB_FILE}"
    echo "    Signed (Binary): ${DEB_FILE}.sig"
    gpg --armor --export "${GPG_KEY}" > "${ARTIFACTS}/chuck_pubkey.asc"
    cp "${ARTIFACTS}/chuck_pubkey.asc" "${ARTIFACTS}/pubkey.asc"
    echo "    Pubkeys: ${ARTIFACTS}/chuck_pubkey.asc and pubkey.asc"
else
    echo "    WARNING: gpg not found - package NOT signed!"
fi

echo "==> Generating SHA512 and SHA256 checksums..."
(cd "${ARTIFACTS}" && sha512sum "$(basename "${DEB_FILE}")" > "$(basename "${DEB_FILE}").sha512")
(cd "${ARTIFACTS}" && sha256sum "$(basename "${DEB_FILE}")" > "$(basename "${DEB_FILE}").sha256")

if [[ -f "${DEB_FILE}.sha512" ]] && command -v gpg > /dev/null 2>&1; then
    gpg --batch --yes --pinentry-mode loopback --local-user "${GPG_KEY}" --detach-sign --armor --output "${DEB_FILE}.sha512.asc" "${DEB_FILE}.sha512"
fi

# Copy user guide, source tarball, and docs into artifacts
if [[ -f "${SCRIPT_DIR}/docs/MyWay_User_Guide.pdf" ]]; then
    cp "${SCRIPT_DIR}/docs/MyWay_User_Guide.pdf" "${ARTIFACTS}/MyWay_User_Guide.pdf"
fi
if [[ -f "${SCRIPT_DIR}/Audit/security_report.md" ]]; then
    cp "${SCRIPT_DIR}/Audit/security_report.md" "${ARTIFACTS}/security_report.md"
fi

tar --exclude=build --exclude=.dart_tool --exclude=.git --exclude=.agents --exclude=.gemini --exclude=packaging/linux_build -czf "${ARTIFACTS}/myway_source.tar.gz" -C "${SCRIPT_DIR}" .

# Multi-file checksums
(cd "${ARTIFACTS}" && { sha512sum -- ./* > SHA512SUMS 2>/dev/null || true; })
(cd "${ARTIFACTS}" && { sha256sum -- ./* > SHA256SUMS 2>/dev/null || true; })

echo "==> Copying to NOBuilds directory..."
DATE_STR=$(date +%m-%d-%Y)
NOBUILDS_DIR="${HOME}/NOBuilds/MyWay-${DATE_STR}-${VERSION}"
mkdir -p "${NOBUILDS_DIR}"
cp -- "${ARTIFACTS}/"* "${NOBUILDS_DIR}/"

# Copy license, readme, sbom to NOBuilds
cp "${SCRIPT_DIR}/LICENSE" "${NOBUILDS_DIR}/" || true
cp "${SCRIPT_DIR}/README.md" "${NOBUILDS_DIR}/" || true
cp "${SCRIPT_DIR}/Audit/SBOM-Linux.json" "${NOBUILDS_DIR}/" || true
cp "${SCRIPT_DIR}/Audit/SBOM-Linux" "${NOBUILDS_DIR}/" || true
cp "${SCRIPT_DIR}/Audit/sbom.json" "${NOBUILDS_DIR}/" || true

echo ""
echo "==================================="
echo "  Build complete!"
echo "  Package : ${DEB_FILE}"
echo "  SHA512  : ${DEB_FILE}.sha512"
echo "  GPG sig : ${DEB_FILE}.asc / .sig"
echo "  Local   : ${NOBUILDS_DIR}"
echo "==================================="
