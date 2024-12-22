## Foxbuntu Installation Guide
### Requirements for installing Foxbuntu
To install Foxbuntu, you'll need the following:
1. microSD card. You can select one from [Supported Hardware](supported_hardware.md), but any card over 8gb and supporting UHS-I *should* work.
2. microSD card reader for your PC.
3. USB OTG adapter.
4. USB flash drive.
5. A Femtofox.

### Installation instructions
1. Download the latest [stable Foxbuntu release.](https://github.com/noon92/femtofox/releases). At the bottom of the release, click the <u>.7z</u> file to download.
2. Flash the image your MicroSD card using [Balena Etcher](https://etcher.balena.io/) or your favorite flashing program. You will likely get a warning that the image appears to be invalid or has no partition table. This is normal.
3. Insert the microSD card into the Luckfox Pico Mini.
	* Optional: attach a USB to serial adapter to the Femtofox via the TX2 and RX2 pins for debug console. Remember bridge grounds!
4. Following the instructions on the [USB Configuration Tool](usb_config.md) page, prepare your USB flash drive with your desired settings.
5. Using your USB OTG adapter, plug  the USB flash drive into the Luckfox Pico Mini's USB port.
6. Give power to the Femtofox.
7. The Femtofox will perform its first boot. This can take up to 5 minutes. When boot is complete, the USR LED will blink 5 times, 1/2 a second each. At this point, Meshtastic should be running and if you plug in a wifi adapter you should have network.
	* Optional: plug an RJ45 cable in to the ethernet port, if you have one installed.
8. To connect to your Femtofox via SSH, open [PuTTY](https://www.putty.org/) or your favorite SSH client and connect to your Femtofox via `femtofox.local` or its IP (check your router).
	* Username: `femto`
	* Password: `fox`
