# MyWay v1.0.2+4 Official Linux Release

MyWay is an unprivileged Wayland-native screen and audio recorder for Linux (GNOME, Cosmic, Plasma) leveraging GStreamer and PipeWire for capturing full screens or individual application windows with software-encoded MP4 (H.264, H.265, AV1) output.

## What's Changed in v1.0.2+4
- **High-Resolution Hicolor Icon Suite**: Generated and packaged the complete 9-tier hicolor icon suite (`16x16`, `24x24`, `32x32`, `48x48`, `64x64`, `96x96`, `128x128`, `256x256`, and `512x512`) from the master 512×512 image using Lanczos resampling. Both `myway.png` and `com.example.myway.png` are distributed to `/usr/share/icons/hicolor/<size>/apps/` for crystal-clear, sharp rendering on Desktop, AppGrid, and top panel.
- **GTK Runner Icon Integration**: Updated `linux/runner/my_application.cc` to explicitly register window icon name `myway` and load the high-resolution master asset as a direct fallback pixbuf for panel, dock, and Alt-Tab window switcher.
- **Desktop & Launcher Matching**: Installed dual desktop definitions (`myway.desktop` and `com.example.myway.desktop`) with `StartupWMClass=com.example.myway` to ensure seamless launcher matching under Wayland compositors.
- **Debian Control Scripts**: Added package `postinst` and `postrm` scripts to automatically refresh the system GTK icon cache and desktop database upon install and removal.
- **Cryptographic Packaging & Checksums**: Full dual GPG detached signatures (ASCII `.asc` and binary `.sig`) signed with Chuck Talk's maintainer key (`chuck@nordheim.online`), alongside SHA-512 and SHA-256 manifests.

## Package Integrity & Verification

| Asset | Description |
|---|---|
| `myway_1.0.2-4_amd64.deb` | Debian/Ubuntu 64-bit release package |
| `myway_1.0.2-4_amd64.deb.asc` | GPG ASCII-armored detached signature |
| `myway_1.0.2-4_amd64.deb.sig` | GPG binary detached signature |
| `myway_1.0.2-4_amd64.deb.sha512` | SHA-512 checksum |
| `myway_1.0.2-4_amd64.deb.sha256` | SHA-256 checksum |
| `pubkey.asc` / `chuck_pubkey.asc` | Maintainer GPG public key (`chuck@nordheim.online`) |
| `SBOM-Linux.json` / `sbom.json` | CycloneDX Software Bill of Materials (SBOM) |
| `security_report.md` | Security and SAST vulnerability audit |
| `MyWay_User_Guide.pdf` | Official User Guide & manual |

### Verification Instructions

Import the release signing key and verify the Debian package:
```bash
# Import Chuck Talk's release signing key
gpg --import chuck_pubkey.asc

# Verify the GPG detached signature
gpg --verify myway_1.0.2-4_amd64.deb.asc myway_1.0.2-4_amd64.deb

# Verify SHA-512 checksum
sha512sum -c myway_1.0.2-4_amd64.deb.sha512
```

### Installation
```bash
sudo apt install ./myway_1.0.2-4_amd64.deb
```
