title: MyWay
subtitle: Installation and User Guide
version: 1.0.2 (with the October 2026 fixes)
platforms: Linux (GNOME on Wayland)
## About MyWay

MyWay is a screen recorder for the Linux desktop, built for GNOME on Wayland. It records your whole screen or a single window, with sound from the audio input you choose, and saves an MP4 video on your computer.

**What MyWay does**

- Records the full screen or one window, using the standard Wayland screen-sharing permission dialog.
- Records audio from an input you pick, with a live level meter.
- Encodes video as H.264, H.265 or AV1 at the bitrate you choose, at your screen's own resolution or scaled down to 720p, 1080p or 2160p.
- Saves to `~/Videos` or any folder you choose.
- Keeps a library of your recordings, where you can play, rename and find them.
- Keeps everything local: no telemetry, no uploads.

MyWay is free, open-source software under the GNU Affero General Public License v3 (AGPL-3.0). Source: github.com/TaliskerMan/MyWay.

## System requirements

| | |
|---|---|
| Operating system | 64-bit (amd64) Ubuntu, Debian, Pop!_OS or a derivative |
| Session | **GNOME on Wayland** recommended (uses the desktop's screen-sharing portal) |
| Media | GStreamer 1.22+ with the good, bad and ugly plug-in sets, PipeWire and `xdg-desktop-portal` (installed with the package) |
| AV1 recording | Also needs the GStreamer SVT-AV1 encoder (`svtav1enc`), included in `gstreamer1.0-plugins-bad` on recent Ubuntu releases |
| Disk space | Depends on length and bitrate: about 150 MB per minute at the default 20 Mbps |

On an X11 session, MyWay falls back to recording through X11 and lets you click a window to record.

## Installing MyWay

Each release includes `myway_<version>_amd64.deb`, a SHA-512 checksum and a detached GPG signature.

```
sha512sum -c myway_<version>_amd64.deb.sha512
gpg --import chuck_pubkey.asc
gpg --verify myway_<version>_amd64.deb.asc myway_<version>_amd64.deb
sudo apt install ./myway_<version>_amd64.deb
```

`apt` installs the GStreamer, PipeWire and portal packages MyWay needs. Open **MyWay** from your applications menu.

**Uninstall:** `sudo apt remove myway`. Your recordings in `~/Videos` aren't touched.

## Quick start

1. Open MyWay and choose **Audio** in the side rail. Pick your microphone (or other input) from the list and speak: the meter should move.
2. Choose **Record**. Under **Select Recording Type**, pick **Full Screen** or **Window**.
3. Click **Record**. GNOME asks which screen or window MyWay may record; choose it and click **Share**.
4. Do what you want to record.
5. Click **Stop**. The video is saved to your output folder (`~/Videos` unless you change it) as `myway_rec_<timestamp>.mp4` and appears in **Library**. GNOME's screen-sharing indicator turns off.

## Using MyWay

MyWay's side rail has six sections.

### Audio

Lists the audio inputs on your system. Choose one and watch the level meter to check it's picking up sound. If none is found, MyWay shows **No Mic Detected**; check your system sound settings.

### Record

| Control | What it does |
|---|---|
| Full Screen | Records a whole screen. On Wayland, GNOME's dialog lets you pick which one. |
| Window | Records a single window. On Wayland, pick it in GNOME's dialog. On X11, click **Select Window to Record**, then click the window. |
| Record | Starts recording (after you approve the sharing dialog on Wayland) |
| Stop | Stops and saves the recording |

> **Note:** The sharing dialog is part of Wayland's security: no app can see your screen until you allow it. You'll see it each time you start a recording.

### Settings

| Setting | What it does |
|---|---|
| Video Codec | **H.264 (AVC)** plays almost everywhere (default). **H.265 (HEVC)** makes smaller files but some players can't open them. **AV1 (SVT-AV1)** is the most efficient but needs the SVT-AV1 GStreamer encoder. |
| Video Bitrate | 2 to 80 Mbps (default 20). Higher means better quality and bigger files. |
| Recording Quality | **Source (no scaling)** records at your screen's or window's own resolution (default). **Up to 720p / 1080p / 2160p** scales larger sources down to that height, keeping the shape. MyWay never scales up, so a 1080p screen stays 1080p under "Up to 2160p". |
| Output Folder | Where recordings are saved. Click the folder button to choose another folder in your desktop's folder chooser; the reset button returns it to `~/Videos`. |

Video is encoded in software on the CPU (x264, x265 or SVT-AV1); MyWay doesn't use hardware (GPU) encoding. Audio is AAC, in an MP4 file. Frame sizes are rounded to even numbers (for example a 1001 × 803 window records at 1000 × 802), which the encoders need.

### Library

Lists the recordings in your output folder. For each one you can:

- **Play Recording** in your default video player,
- **Rename** it,
- **Open Directory** to show it in your file manager.

To delete a recording, delete the file in your file manager.

### Support

Diagnostic logging for when something goes wrong:

1. Turn on **Enable Debug Logging**.
2. Reproduce the problem.
3. Click **Export Logs & Contact Support**. MyWay saves `MyWay_Logs.tar.gz` to `~/Downloads` and opens an email to support@nordheim.online in your mail app. Attach the archive before sending.

**Refresh Logs** shows the latest log lines in the window.

### About

Version, license and credits.

## Privacy and security

- MyWay has no telemetry and makes no network connections. Recordings and logs stay on your computer.
- On Wayland, screen access goes through GNOME's screen-sharing portal, which always asks you first.
- The screen-capture handle is passed between MyWay's components through a private socket in your user runtime folder, readable by you only.
- Logs are only written when you turn on debug logging, and only sent if you choose to email them.

## Limitations

- **Area recording** (a custom rectangle) isn't available from the interface in this version.
- **Software encoding** uses the CPU. At high bitrates or on slower computers, choose H.264 and a lower bitrate if recordings stutter.
- **AV1** needs the SVT-AV1 GStreamer encoder, which may not be installed by default.
- **H.265 files** don't play in every player or browser; use H.264 for sharing.

## Troubleshooting

**The sharing dialog never appears / recording fails at once.** Make sure you're on a Wayland session with `xdg-desktop-portal` and `xdg-desktop-portal-gnome` installed. On X11 or other compositors, full-screen portal capture may be unavailable; MyWay tells you so.

**No sound in the recording.** Check the input in **Audio** (the meter should move) and that it isn't muted in system settings.

**AV1 recording won't start.** MyWay says it couldn't start the AV1 encoder. Install the SVT-AV1 GStreamer plug-in, or switch to H.264.

**"Recording stopped unexpectedly".** The recording hit an error partway through, for example the disk filled up or the output folder was removed. What was recorded may be incomplete. Turn on debug logging in **Support** and try again to see the cause.

**The folder chooser doesn't open.** Choosing a folder needs `xdg-desktop-portal` 1.12 or newer with a desktop backend such as `xdg-desktop-portal-gnome`.

**The video won't play on another device.** Switch the codec to H.264.

**I need help.** Use **Support → Export Logs & Contact Support**.

## Support and license

MyWay is free, open-source software. Report problems on GitHub (github.com/TaliskerMan/MyWay) or email **support@nordheim.online**.

| | |
|---|---|
| Website | nordheim.online |
| Source code | github.com/TaliskerMan/MyWay |
| License | GNU AGPL v3 (no warranty) |
| Copyright | © 2026 Chuck Talk, Nordheim Online, LLC |
