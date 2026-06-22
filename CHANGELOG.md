# Changelog — MyWay

All notable changes to the MyWay project are documented in this file. This project adheres to Semantic Versioning.

---

## [Unreleased]

### Security
- **FD hand-off socket moved off `/tmp`:** the UNIX socket that transfers the
  screen-capture file descriptor is now created in the per-user
  `XDG_RUNTIME_DIR` with an unpredictable random name, and the native binder sets
  it to mode `0600` (and tightens umask across `bind()`). Previously it lived in
  world-writable `/tmp` under a guessable timestamp name.

### Fixed
- **Non-ASCII output paths no longer corrupt:** native string buffers (output
  path, codec, mode) are now encoded as **UTF-8** with the copy bounded to
  `maxLength - 1` and a guaranteed NUL terminator (was UTF-16 code units with no
  guaranteed terminator). Multi-byte sequences are not split at the boundary.
- **Version is single-sourced:** `assets/version.json` is regenerated from
  `pubspec.yaml` at build time so the About screen can't show a stale version;
  the README install example and changelog are aligned.
- **Removed fake metrics:** the always-zero bitrate / dropped-frame fields were
  dropped from `CaptureStatus` (they were never measured and never displayed).

### Changed
- Documented the FFI ownership contract at the `start_capture` boundary
  (params are consumed synchronously, so the immediate `free` is safe), and the
  native library load now raises a clear error on a packaging/`rpath` failure.
- Non-portal / X11 sessions now get a clear message when full-screen portal
  capture is unavailable (`isScreenCastPortalAvailable`).
- Re-scoped `security_report.md` honestly (SAST/SCA ≠ a clean bill of health) and
  noted the two manually-found issues fixed here; set a real `debian/control`
  maintainer (`Chuck Talk <support@nordheim.online>`).
- Repo hygiene: gitignored the `scratch/` spikes and stray test binaries/images.

### Added
- Unit tests for the UTF-8 native-buffer path encoder.

---

## [1.0.1] - 2026-06-10

### Fixed
- **Codebase Lint Cleanups:** Removed unused imports (such as `recent_recordings.dart` and `audio_service.dart`) and cleaned unused class fields in the settings and audio setup interfaces.
- **D-Bus GC Warning:** Suppressed false-positive unused field lints on the D-Bus file descriptor reference.
- **Analysis Config:** Configured analysis exclusions to bypass temporary test files under the `scratch/` folder.

---

## [1.0.0] - 2026-05-18

### Added
- **Wayland Screen Recording:** Integrated GStreamer capture and PipeWire socket file descriptor extraction.
- **Audio Integrations:** Added dynamic volume VU meters and input selection dropdowns.
- **Local Diagnostics:** Added support logs exporter (`MyWay_Logs.tar.gz`) to package and debug capture issues locally.
- **Automated Packaging:** Built release builder scripts (`build_linux.sh`) supporting version increments, GPG detached signatures, SHA512 checks, and local staging directory deployment copies.
