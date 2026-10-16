# MyWay Screen Recorder

![MyWay Logo](assets/myway.png)

MyWay is a native Linux screen recorder designed for GNOME on Wayland. Built with Flutter and a native C/GStreamer backend, it records your full screen or a single window, with audio, to an MP4 file on your computer, following Nordheim Online's principle of "first, do no harm".

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

1. Download the latest `.deb` release from the [GitHub Releases](https://github.com/TaliskerMan/MyWay/releases) page.
2. Install the package using `apt` to resolve any system dependencies automatically:
   ```bash
   sudo apt install ./myway_*_amd64.deb
   ```
3. MyWay will now be available in your application launcher!

`apt` installs what MyWay needs: GStreamer 1.22+ with the base, good, bad and ugly plug-in sets, PipeWire, and `xdg-desktop-portal` (plus `xdg-desktop-portal-gnome`, recommended).

To verify a download first:
```bash
sha512sum -c myway_<version>_amd64.deb.sha512
gpg --import chuck_pubkey.asc
gpg --verify myway_<version>_amd64.deb.asc myway_<version>_amd64.deb
```

## Usage

1. **Launch the Application**: Open MyWay from your GNOME app drawer.
2. **Configure Audio**: In the **Audio** section, pick your audio input; the level meter shows it is picking up sound.
3. **Select Recording Mode**: In the **Record** section, choose **Full Screen** or **Window**.
4. **Record**: Press the prominent **Record** button. The Wayland screen-sharing portal will prompt you to grant MyWay permission to view your screen (a security feature of Wayland).
5. **Stop**: Once finished, press **Stop**. The video will automatically be saved to your configured output folder.

## Saving Videos & Hosting

By default, MyWay saves recordings as MP4 files named `myway_rec_<timestamp>.mp4` in your `~/Videos` folder. To use a different folder, open **Settings** and click the folder button next to **Output Folder**; your desktop's folder chooser opens. The reset button returns it to `~/Videos`.

**Online Hosting**: Once your videos are created and saved locally, they can be uploaded and hosted online at no charge using platforms such as YouTube, Vimeo, or natively shared on social media, making it incredibly simple to build demo videos and tutorials.

## Troubleshooting & Support

If you run into issues while capturing or saving videos, MyWay includes a built-in diagnostic suite:

1. Open MyWay and navigate to the **Support** tab in the sidebar.
2. Toggle **Enable Debug Logging** to ON.
3. Attempt to reproduce your issue (e.g., start and stop a recording).
4. Return to the Support tab and click **Export Logs & Contact Support**. 
5. The application will automatically generate a compressed archive (`MyWay_Logs.tar.gz`) in your `~/Downloads` folder.
6. Your default email client will open. Simply attach the generated `.tar.gz` file and send the email to `support@nordheim.online`.

### Common Issues
- **App fails to capture screen**: On Wayland, make sure `xdg-desktop-portal` and `xdg-desktop-portal-gnome` are installed. On X11, MyWay records directly through X11 instead, and you click the window you want to record.
- **AV1 recording won't start**: Install the GStreamer SVT-AV1 plug-in, or choose H.264 in Settings.
- **"Recording stopped unexpectedly"**: The recording pipeline hit an error (for example, the disk filled up). Turn on debug logging in **Support** and try again to see why.
- **No Audio**: Check your system settings to ensure your microphone is not muted at the OS level. Verify the correct device is selected in the MyWay dropdown.

## License

This project is licensed under the GNU Affero General Public License v3.0 (AGPL-3.0) - see the `LICENSE` file for details.
