# MyWay v1.0.2+6 Official Linux Release

**MyWay** is an unprivileged, Wayland-native Linux screen and audio recorder for GNOME, Pop!_OS, Ubuntu, and Debian — built with Flutter, GStreamer 1.22+, and PipeWire to record your full screen or a single window with audio to MP4 (`H.264`, `H.265`, or `AV1`) strictly locally on your computer.

## What's Changed Since v1.0.2+4 (`v1.0.2+5` – `v1.0.2+6`)
- **SonarQube Cloud & Snyk Full Clean-Code & Security Hardening (`TaliskerMan_MyWay`):** Remediated all 48 SonarQube Cloud findings across `native/libmyway_capture.c` (cognitive complexity & nesting reduction, descriptor-scoped `fchmod`/`chmod` replacing process-wide `umask`, literal `snprintf` format strings), `linux/runner/my_application.cc`, `docs/guide/build_guide.js` (`REPO_ROOT` path containment & linear-time $O(n)$ parsers), and shell build scripts — achieving **Quality Gate `OK` (`0` Bugs, `0` Vulnerabilities, `0` Code Smells, `0` Security Hotspots)** and **`0` Snyk Code & Open Source issues**.
- **Owner-Only Rotated Diagnostic Logging (`CP-Logging`):** Hardened `lib/services/log_service.dart` with CR/LF log-injection sanitization (`LogService.sanitize`), `0600` owner-only permissions on `myway_debug.log`, and 5 MiB automatic rotation.
- **Refreshed Documentation & CycloneDX SBOM (`v1.0.2+6`):** Updated `README.md`, `MyWay_User_Guide.md`, and the branded `MyWay_User_Guide.pdf` (`v1.0.2+6`), and generated path-sanitized CycloneDX SBOMs (`0` Grype/OSV/Trivy findings).

## Package Integrity & Verification

| Asset | Description |
|---|---|
| `myway_1.0.2-6_amd64.deb` | Debian/Ubuntu 64-bit (`amd64`) desktop package |
| `myway_1.0.2-6_amd64.deb.asc` | GPG ASCII-armored detached signature |
| `myway_1.0.2-6_amd64.deb.sig` | GPG binary detached signature |
| `myway_1.0.2-6_amd64.deb.sha512` | SHA-512 package checksum |
| `myway_1.0.2-6_amd64.deb.sha512.asc` | GPG detached signature on SHA-512 checksum |
| `myway_1.0.2-6_amd64.deb.sha256` | SHA-256 package checksum |
| `pubkey.asc` / `chuck_pubkey.asc` | Maintainer GPG public key (`Chuck Talk <chuck@nordheim.online>`) |
| `myway_source.tar.gz` | Corresponding AGPL-3.0 source archive |
| `SBOM-Linux.json` / `sbom.json` | CycloneDX Software Bill of Materials (SBOM) |
| `security_report.md` | Multi-scanner security and quality audit report |
| `MyWay_User_Guide.pdf` | Official User Guide & manual (`v1.0.2+6`) |
| `SHA512SUMS` / `SHA256SUMS` | Combined release asset checksum manifests |

### Verification Instructions

```bash
# Verify SHA-512 checksum
sha512sum -c myway_1.0.2-6_amd64.deb.sha512

# Import Chuck Talk's release signing key and verify GPG detached signature
gpg --import chuck_pubkey.asc
gpg --verify myway_1.0.2-6_amd64.deb.asc myway_1.0.2-6_amd64.deb
```

### Installation

```bash
sudo apt install ./myway_1.0.2-6_amd64.deb
```
