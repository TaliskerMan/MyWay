# MyWay Security & Vulnerability Report — v1.0.2+4

## Overview
This document represents an automated AI security audit of the MyWay Screen Recorder application (Flutter + C FFI) executed prior to the build release. The audit specifically focuses on ensuring adherence to the "ShadowAgent" principles ("first, do no harm") and strict user-space execution parameters.

## Scope & Verification
This release underwent comprehensive local security, supply chain analysis, and static application security testing (SAST):

- **Semgrep OSS (SAST)**: 0 findings across 58 files and 486 security rules.
- **OSV-Scanner (SCA)**: 0 vulnerabilities found across 81 package dependencies.
- **Dart & Flutter Unit Tests**: All 12 unit tests passing (100% pass rate).
- **Desktop & Icon Integration**: Complete 9-tier hicolor icon suite (16x16 to 512x512) generated with high-quality Lanczos resampling and packaged into `/usr/share/icons/hicolor/`.
- **GTK Runner Enhancement**: Configured window icon name and direct high-resolution fallback pixbuf in `linux/runner/my_application.cc`.
- **Cryptographic Packaging**: 64-bit Linux DEB package signed with Chuck Talk's GPG maintainer key (`chuck@nordheim.online`), producing detached `.asc` and `.sig` signatures alongside SHA-512 and SHA-256 manifests.

## Codebase Audit (Flutter Layer)
- **Dependencies**: The `pubspec.yaml` relies only on established first-party or highly trusted community packages (`url_launcher`, `shared_preferences`, `ffi`, `path_provider`, `dbus`, `package_info_plus`).
- **File System Access**: Access is restricted to user-defined directories requested via the UI for storing `.mp4` recordings. No arbitrary system file traversal is present.
- **Network Access**: Network access is restricted entirely. The application does not contain telemetric beacons, remote update checks, or background daemon processes. It operates strictly locally.
- **ShadowAgent Compliance**: The application does not execute any hidden routines, risk automated data exfiltration, or modify system states without explicit user interaction.

## Native Layer Audit (C / GStreamer / PipeWire)
- **Memory Safety**: The native build utilizes `calloc`/`free` appropriately. Bounded `snprintf` is strictly enforced for string and path handling.
- **Privilege Separation**: The C plugin (`libmyway_capture.so`) executes entirely within the unprivileged user-space sandbox.
- **Audio/Video Enumeration**: Hardware access bypasses raw ALSA interfaces and strictly interfaces with XDG Desktop Portals and PipeWire. PipeWire guarantees that device enumeration and stream capture only occur after explicit Wayland compositor authorization. The application does not require and must not be run with `sudo` or `root` privileges.

## Vulnerability Scans Summary
1. **Dart & Flutter Analysis**: All 12 unit tests passed.
2. **Semgrep OSS**: Clean pass (0 findings).
3. **OSV-Scanner**: Clean pass (0 vulnerabilities across 81 dependencies).
4. **Syft SBOM**: CycloneDX SBOM generated and verified in `Audit/SBOM-Linux.json` and `Audit/sbom.json`.

**Conclusion**: All static analysis, dependency scanning, and quality checks passed cleanly. Release v1.0.2+4 meets all security criteria for official deployment.
