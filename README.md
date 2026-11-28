# MyWay Screen Recorder

![MyWay Logo](assets/myway.png)

MyWay is a native Linux screen recorder designed for GNOME on Wayland. Built with Flutter and a native C/GStreamer backend, it records your full screen or a single window, with audio, to an MP4 file on your computer, following Nordheim Online's principle of "first, do no harm".

<p align="center">
  <a href="https://sonarcloud.io/summary/new_code?id=TaliskerMan_MyWay"><img src="https://sonarcloud.io/api/project_badges/measure?project=TaliskerMan_MyWay&metric=alert_status" alt="Quality Gate Status"></a>
  <a href="https://sonarcloud.io/summary/new_code?id=TaliskerMan_MyWay"><img src="https://sonarcloud.io/api/project_badges/measure?project=TaliskerMan_MyWay&metric=security_rating" alt="Security Rating"></a>
  <a href="https://sonarcloud.io/summary/new_code?id=TaliskerMan_MyWay"><img src="https://sonarcloud.io/api/project_badges/measure?project=TaliskerMan_MyWay&metric=reliability_rating" alt="Reliability Rating"></a>
  <a href="https://sonarcloud.io/summary/new_code?id=TaliskerMan_MyWay"><img src="https://sonarcloud.io/api/project_badges/measure?project=TaliskerMan_MyWay&metric=sqale_rating" alt="Maintainability Rating"></a>
</p>


MyWay has no telemetry and makes no network connections. On Wayland it uses the standard XDG Desktop Portal, so the desktop asks your permission before MyWay can see your screen.

## Features
- **Wayland Native**: Designed specifically for modern GNOME on Wayland environments.
- **Capture Modes**: Record your full screen or a single window.
- **Audio Integration**: Visual VU meter and dropdown audio device selection.
- **Codecs**: H.264 (default, plays everywhere), H.265, or AV1 (needs the GStreamer SVT-AV1 encoder, `svtav1enc`). Encoding is done in software on the CPU (x264, x265, SVT-AV1); there is no hardware (GPU) encoding.
- **Quality**: Record at your screen's own resolution, or scale down to at most 720p, 1080p or 2160p. MyWay never scales up.
- **Bitrate**: 2 to 80 Mbps (default 20).
- **Zero Telemetry**: All logs and recordings stay on your machine. You control your data.

## Installation

MyWay is distributed as a cryptographically signed Debian (`.deb`) package for seamless integration with Ubuntu and Debian-based Linux distributions. 

1. Download `myway_1.0.2-6_amd64.deb`, `myway_1.0.2-6_amd64.deb.sha512`, `myway_1.0.2-6_amd64.deb.asc`, and `chuck_pubkey.asc` from the [GitHub Releases](https://github.com/TaliskerMan/MyWay/releases) page.
2. Verify the download's SHA-512 checksum and GPG signature, then install via `apt` to resolve all system dependencies automatically:
   ```bash
   sha512sum -c myway_1.0.2-6_amd64.deb.sha512
   gpg --import chuck_pubkey.asc
   gpg --verify myway_1.0.2-6_amd64.deb.asc myway_1.0.2-6_amd64.deb
   sudo apt install ./myway_1.0.2-6_amd64.deb
   ```
3. MyWay will now be available in your application launcher!

`apt` installs what MyWay needs: GStreamer 1.22+ with the base, good, bad and ugly plug-in sets, PipeWire, `x11-utils`, and `xdg-desktop-portal` (plus `xdg-desktop-portal-gnome`, recommended).

## Usage

MyWay's left navigation rail provides six sections (**Audio**, **Settings**, **Record**, **Library**, **Support**, and **About**):

1. **Launch the Application**: Open MyWay from your GNOME app drawer.
2. **Configure Audio & Settings**: In **Audio**, pick your input device and confirm the live level meter responds. In **Settings**, choose your codec (`H.264`, `H.265`, or `AV1`), quality (`Source` or downscale to `720p`/`1080p`/`2160p`), bitrate (`2–80 Mbps`), and output folder (default `~/Videos`).
3. **Select Recording Mode**: In **Record**, choose **Full Screen** or **Window**.
4. **Record**: Press the prominent **Record** button. On Wayland, the screen-sharing portal prompts you to choose which screen or window MyWay may record.
5. **Stop & Manage**: Press **Stop**. Recordings are saved as `myway_rec_<timestamp>.mp4` and listed in **Library** (where you can play, rename, or open their folder).

## Saving Videos & Hosting

By default, MyWay saves recordings as MP4 files named `myway_rec_<timestamp>.mp4` in your `~/Videos` folder. To use a different folder, open **Settings** and click the folder button next to **Output Folder**; your desktop's folder chooser opens. The reset button returns it to `~/Videos`.

**Online Hosting**: Once your videos are created and saved locally, they can be uploaded and hosted online at no charge using platforms such as YouTube, Vimeo, or natively shared on social media, making it incredibly simple to build demo videos and tutorials.

## Troubleshooting & Support

If you run into issues while capturing or saving videos, MyWay includes a built-in diagnostic suite:

1. Open MyWay and navigate to the **Support** tab in the sidebar.
2. Toggle **Enable Debug Logging** to ON (writes sanitized local logs with `0600` permissions and 5 MiB rotation).
3. Attempt to reproduce your issue (e.g., start and stop a recording).
4. Return to the Support tab and click **Export Logs & Contact Support**. 
5. The application will automatically generate a compressed archive (`MyWay_Logs.tar.gz`) in your `~/Downloads` folder.
6. Your default email client will open. Simply attach the generated `.tar.gz` file and send the email to `support@nordheim.online`.

### Common Issues
- **App fails to capture screen**: On Wayland, make sure `xdg-desktop-portal` and `xdg-desktop-portal-gnome` are installed. On X11, MyWay records directly through X11 instead, and you click the window you want to record.
- **AV1 recording won't start**: Install the GStreamer SVT-AV1 plug-in, or choose H.264 in Settings.
- **"Recording stopped unexpectedly"**: The recording pipeline hit an error (for example, the disk filled up). Turn on debug logging in **Support** and try again to see why.
- **No Audio**: Check your system settings to ensure your microphone is not muted at the OS level. Verify the correct device is selected in the MyWay dropdown.

## Author & License

Copyright © 2026 Chuck Talk, Nordheim Online, LLC — <chuck@nordheim.online> · https://nordheim.online

This project is licensed under the GNU Affero General Public License v3.0 (AGPL-3.0) - see the `LICENSE` file for details.
