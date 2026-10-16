# Changelog — MyWay

All notable changes to the MyWay project are documented in this file. This project adheres to Semantic Versioning.

---

## [1.0.2+3] - 2026-10-16

### Security & Hardening
- **Safe bounded string copies**: Replaced `strncpy` with `snprintf` across `native/libmyway_capture.c` to guarantee bounded length, explicit NUL-termination, and clear Semgrep security audit gate.
- **Developer contact & license compliance**: Added `chuck@nordheim.online` interactive contact link to the About screen per CP-AboutPage.

### Fixed — claims now match the code (2026-10-15 review)
- **AV1 recording works.** The pipeline set a `bitrate` property that the
  GStreamer 1.22+ `svtav1enc` doesn't have, so every AV1 recording failed. It
  now uses `target-bitrate` (kbps).
- **Odd-sized windows record in AV1.** SVT-AV1 refuses odd frame sizes; the
  output size is now always rounded to even numbers.
- **Recording Quality works.** It was shown but never saved or used. It now
  scales the video down to at most 720p, 1080p or 2160p (never up), with a new
  default of "Source (no scaling)".
- **Output Folder can be changed.** The folder button did nothing; it now opens
  the desktop's folder chooser (xdg-desktop-portal FileChooser), with a reset
  to `~/Videos`.
- **Start failures are reported.** The native start result was ignored, so a
  missing encoder looked like a successful start. The app now says what went
  wrong.
- **Mid-recording failures are reported.** If the pipeline stops by itself
  (for example the disk fills up), the app now says so instead of carrying on
  and later reporting "Recording saved". Empty files are removed, and the
  native pipeline is released.
- **Screen sharing ends when recording stops.** The portal session was left
  open until MyWay quit, keeping GNOME's screen-sharing indicator on.
- **Checksum file works with `sha512sum -c`.** The `.sha512` file held only the
  bare hash; it is now in the standard `<hash>  <filename>` format.
- The codec shown in Settings now matches the codec actually used (the screen
  showed H.265 while recordings used H.264). The output folder no longer falls
  back to a hard-coded home directory.
- The output path is now set as a filesink property rather than interpolated
  into the pipeline description, so folder names with quotes can't alter it.

### Removed
- **Area recording**, which had no way to be selected in the interface
  (unused `area_selector.dart` removed; the native crop code removed).
- **Hardware-acceleration claim.** Encoding is, and always was, in software.
  The unused `gstreamer1.0-vaapi` and `libva2` dependencies were dropped.
- The README's `.mkv` claim (recordings are MP4).

### Changed
- Package dependencies now include `gstreamer1.0-plugins-base`, `libgtk-3-0`
  and `x11-utils` (for X11 window selection); `xdg-desktop-portal-gnome` is
  recommended.

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
