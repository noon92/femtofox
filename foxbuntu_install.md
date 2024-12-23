## Foxbuntu Installation Guide
### Requirements for installing Foxbuntu
To install Foxbuntu, you'll need the following:
1. microSD card. You can select one from [supported hardware](supported_hardware.md), but any card over 8gb and supporting UHS-I *should* work.
2. microSD card reader for your PC.
3. USB OTG adapter (USB-C to USB-A).
4. USB flash drive.
5. A Femtofox.

### Installation instructions
1. Download the latest stable [Foxbuntu release](https://github.com/noon92/femtofox/releases). At the bottom of the release, click the <u>.7z</u> file to download.
2. Flash the image your MicroSD card using [Balena Etcher](https://etcher.balena.io/) or your favorite flashing program. You will likely get a warning that the image appears to be invalid or has no partition table. This is normal.
3. Insert the microSD card into the Luckfox Pico Mini. The microSD slot is on the back of the board.
4. Following the instructions on the [USB Configuration Tool](usb_config.md) page, prepare your USB flash drive with your desired settings.
5. Using a USB OTG adapter, plug the USB flash drive into the *data* USB port.
> [!TIP]
> Optional: attach a USB to serial adapter to the Femtofox via the TX2 and RX2 pins for debug console. Remember to bridge the grounds!
> Optional: plug an RJ45 cable in to the ethernet port, if you have one installed.
7. Connect the Femtofox to power, either via the *power* USB-C port (on the same side as the ethernet port) or via the 3.3v or the 5v JST power plugs.
8. The Femtofox will perform its first boot. This can take up to 5 minutes (subsequent boots ~40 seconds). When boot is complete, the USR LED will blink 5 times, 1/2 a second each. At this point, Meshtastic should be running and if you plug in a wifi adapter it should work.
9. To connect to your Femtofox via SSH, open [PuTTY](https://www.putty.org/) or your favorite SSH client and connect to your Femtofox via `femtofox.local` or its IP (check your router).
	* Username: `femto`
	* Password: `fox`
