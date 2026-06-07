# MyWay Screen Recorder

![MyWay Logo](assets/myway.png)

MyWay is a premium, secure, native Linux Screen Recorder specifically designed for GNOME and Wayland. Built with Flutter and a native C/GStreamer backend, MyWay offers an intuitive, hardware-accelerated screen capturing experience while adhering strictly to the **ShadowAgent** principles of "first, do no harm".

MyWay emphasizes user privacy and localized control. We guarantee zero automatic telemetry and provide an offline-first architecture that strictly utilizes standard XDG Desktop Portals to securely interface with PipeWire.

## Features
- **Wayland Native**: Designed specifically for modern GNOME on Wayland environments.
- **Hardware Acceleration**: Utilizes GStreamer and PipeWire for high-performance capturing.
- **Dynamic Capture Modes**: Record your full screen, specific windows, or custom rectangular areas.
- **Audio Integration**: Visual VU meter and dropdown audio device selection.
- **High Quality Export**: Configurable resolutions (720p, 1080p, 2160p) using modern h264/h265 codecs.
- **Zero Telemetry**: All logs and recordings stay on your machine. You control your data.

## Installation

MyWay is distributed as a cryptographically signed Debian (`.deb`) package for seamless integration with Ubuntu and Debian-based Linux distributions. 

1. Download the latest `.deb` release from the [GitHub Releases](https://github.com/TaliskerMan/MyWay/releases) page.
2. Install the package using `apt` to resolve any system dependencies automatically:
   ```bash
   sudo apt install ./MyWay_v1.0.0+5.deb
   ```
3. MyWay will now be available in your application launcher!

*Note: MyWay requires `libgstreamer1.0-0`, `gstreamer1.0-plugins-good`, and `libpipewire-0.3-0`.*

## Usage

1. **Launch the Application**: Open MyWay from your GNOME app drawer.
2. **Select Recording Mode**: On the main screen, choose to record your Full Screen, a specific Window, or a selected Area.
3. **Configure Audio**: Select your preferred audio input source from the dropdown below the volume meter.
4. **Record**: Press the prominent **Record** button. The Wayland screen-sharing portal will prompt you to grant MyWay permission to view your screen (a security feature of Wayland).
5. **Stop**: Once finished, press **Stop**. The video will automatically be saved to your configured output folder.

## Saving Videos & Hosting

By default, MyWay saves all `.mkv` recordings directly into your `~/Videos` directory. You can easily change this target directory by navigating to the **Settings** tab.

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
- **App fails to capture screen**: Ensure you are running on a Wayland session. X11 sessions may require a different capturing backend.
- **No Audio**: Check your system settings to ensure your microphone is not muted at the OS level. Verify the correct device is selected in the MyWay dropdown.

## License

This project is licensed under the MIT License - see the `LICENSE` file for details.
