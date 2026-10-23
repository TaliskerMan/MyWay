# Plan for MyWay

Done (v1.0.2+4 Release - 2026-10-23):
- [x] Generate full 9-tier hicolor icon suite (`16x16` to `512x512`) from master 512x512 PNG using Lanczos resampling.
- [x] Configure GTK runner (`my_application.cc`) with `gtk_window_set_icon_name` and fallback high-res pixbuf.
- [x] Update Debian packaging to distribute full hicolor suite, postinst/postrm icon cache refresh, and dual desktop entries.
- [x] Auto-increment version to `1.0.2+4` across `pubspec.yaml`, `assets/version.json`, `debian/control`, `CHANGELOG.md`.
- [x] Run security scans (Semgrep 0 findings, OSV-Scanner 0 vulnerabilities) and run Flutter test suite (12 passed).
- [x] Execute `build_linux.sh --no-bump` to compile Flutter release, build DEB, GPG detached sign (.asc, .sig), generate SHA512/SHA256 manifests, and stage to NOBuilds.
- [x] Commit changes, tag `v1.0.2+4`, push to GitHub, and publish official release with all assets.

Done (v1.0.2+3 Release - 2026-10-16):
- [x] Untrack sonar-project.properties from GitHub and add to .gitignore
- [x] Execute Shift-Left Quality Gate (`code-gate.sh`): Dart, SonarQube, C/C++, Shell, Semgrep OSS, osv-scanner, Syft SBOM, and Grype CVE scan all PASSED
- [x] Ensure compliance with CP-AboutPage (contact email `chuck@nordheim.online`, AGPL-3.0 license display)
- [x] Resolve Semgrep string-copy warnings via bounded `snprintf` in `libmyway_capture.c`
- [x] Auto-increment build version to `1.0.2+3` and compile 64-bit Linux DEB package
- [x] Perform GPG detached signing with `chuck@nordheim.online` and generate standard SHA512 checksums
- [x] Stage release artifacts in `/home/freecode/NOBuilds/MyWay-10-16-2026-1.0.2/`
- [x] Publish official release to GitHub repository (`v1.0.2+3`)

