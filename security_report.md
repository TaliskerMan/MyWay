# MyWay Security & Vulnerability Report

## Overview
This document represents an automated AI security audit of the MyWay Screen Recorder application (Flutter + C FFI) executed prior to the build release. The audit specifically focuses on ensuring adherence to the "ShadowAgent" principles ("first, do no harm") and strict user-space execution parameters.

## Scope & limitations
This report covers **dependency CVEs (SCA)** and **generic code-pattern scanning (SAST)** plus manual review notes. A clean automated scan means "no known-vulnerable dependencies and no obvious unsafe patterns" — it is **not** a proof that the privileged data paths are secure. In particular, automated scanning did **not** flag two issues that manual review found and that are fixed in this release:

- The screen-capture file descriptor was handed off over a **predictable, world-writable `/tmp` UNIX socket** (now moved to a per-user `XDG_RUNTIME_DIR` socket with mode `0600`).
- Native string buffers (output path, codec, mode) were filled with **UTF-16 code units with no guaranteed NUL terminator**, corrupting non-ASCII paths (now UTF-8 with bounded, NUL-terminated copies).

Treat the scan results below accordingly, and re-run the scans after these fixes.

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

**Conclusion**: The dependency and SAST scans surfaced no known-vulnerable packages or obvious unsafe patterns. This is a clean *automated* result, not a guarantee about the privileged FD-transfer path — see *Scope & limitations*. The two manually-identified issues above were fixed in this release; the scans should be re-run to confirm.
