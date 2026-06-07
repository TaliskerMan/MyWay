# MyWay Security & Vulnerability Report

## Overview
This document represents an automated AI security audit of the MyWay Screen Recorder application (Flutter + C FFI) executed prior to the build release. The audit specifically focuses on ensuring adherence to the "ShadowAgent" principles ("first, do no harm") and strict user-space execution parameters.

## Codebase Audit (Flutter Layer)
- **Dependencies**: The `pubspec.yaml` relies only on established first-party or highly trusted community packages (`url_launcher`, `shared_preferences`, `ffi`, `path_provider`, `dbus`).
- **File System Access**: Access is restricted to user-defined directories requested via the UI for storing `.mkv`/`.mp4` recordings. No arbitrary system file traversal is present.
- **Network Access**: Network access is restricted entirely. The application does not contain telemetric beacons, remote update checks, or background daemon processes. It operates strictly locally.
- **ShadowAgent Compliance**: The application does not execute any hidden routines, risk automated data exfiltration, or modify system states without explicit, undeniable user interaction.

## Native Layer Audit (C / GStreamer / PipeWire)
- **Memory Safety**: The native build utilizes `calloc`/`free` appropriately. In development builds, AddressSanitizer (ASan) and UndefinedBehaviorSanitizer (UBSan) are configured to catch memory leaks, out-of-bounds access, and undefined behavior.
- **Privilege Separation**: The C plugin (`libmyway_capture.so`) executes entirely within the unprivileged user-space sandbox. 
- **Audio/Video Enumeration**: Hardware access bypasses raw ALSA interfaces and strictly interfaces with XDG Desktop Portals and PipeWire. PipeWire guarantees that device enumeration and stream capture only occur after explicit Wayland compositor authorization. The application does not require and must not be run with `sudo` or `root` privileges.

## Vulnerability Scans
As part of the CI/CD release script, this software undergoes:
1. **Snyk Code Test (SAST)**: Scanning the Dart and C codebase for insecure logic patterns.
2. **Snyk Test**: Scanning the dependency tree for known CVEs.
3. **Syft + Grype**: Generating a CycloneDX JSON Software Bill of Materials (SBOM) and auditing it against the Anchore vulnerability database.

**Conclusion**: The application meets the required security standards for deployment. No immediate vulnerabilities were detected in the source code logic.
