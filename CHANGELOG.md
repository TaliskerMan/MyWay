# Changelog — MyWay

All notable changes to the MyWay project are documented in this file. This project adheres to Semantic Versioning.

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
