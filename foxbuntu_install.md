
## Foxbuntu Installation Guide
### Requirements for installing Foxbuntu
To install Foxbuntu, you'll need the following:
1. microSD card. You can select one from [supported hardware](supported_hardware.md), but any card over 8gb and supporting UHS-I *should* work
 2. microSD card reader for your computer
 3. A method to configure the Fox:
	* With any model, a USB OTG adapter (USB-C to USB-A) and a USB flash drive, OR
	* With a Femtofox Pro, a USB-C cable to connect the Fox to your computer, OR
	* With any model, a USB UART serial adapter to connect to UART2 (serial debug pins), OR
	* With any model with an ethernet port, an ethernet cable
4. A Femtofox (duh!)

### Installation instructions
1. Download the latest stable [Foxbuntu release](https://github.com/noon92/femtofox/releases). At the bottom of the release, click the <u>.7z</u> file to download.
2. Flash the image your MicroSD card using [Balena Etcher](https://etcher.balena.io/) or your favorite flashing program. You will likely get a warning that the image appears to be invalid or has no partition table. This is normal.
3. Insert the microSD card into the Luckfox Pico Mini. The microSD slot is on the back of the board.
4. Configure the Femtofox using one of the following methods:
	* For USB config, following the instructions on the [USB Configuration Tool](usb_config.md) page, prepare your USB flash drive with your desired settings. Using a USB OTG adapter, plug the USB flash drive into the *data* USB port (the port on the Luckfox.
	* On Femtofox Pro, connect the *Power USB-C port* to your PC with a cable, and open a serial console application such as PuTTY for windows. Select your the Femtofox's COM port (find the correct COM port in Windows hitting <kbd>WIN</kbd>+<kbd>R</kbd> and entering `cmd /k wmic path Win32_SerialPort get DeviceID, Description && pause`. The port should be named 
	* Use a USB UART serial adapter to connect to UART2 (serial debug pins).
	* Use an ethernet cable and SSH in. Femtofox's default hostname is femtofox.local.
5. Connect the Femtofox to power, either via the *power USB-C port* (Pro model only, on the same side as the ethernet port) or via the power-in JST power plug.
6. The Femtofox will perform its first boot. This can take up to 5 minutes (subsequent boots ~40 seconds). When boot is complete, the USR LED will blink 5 times, 1/2 a second each. At this point, Meshtastic should be running and if you plug in a wifi adapter it should work.
7. To connect to your Femtofox via SSH, open [PuTTY](https://www.putty.org/) or your favorite SSH client and connect to your Femtofox via `femtofox.local` or its IP (check your router).
	* Username: `femto`
	* Password: `fox`
<!--stackedit_data:
eyJoaXN0b3J5IjpbMTMwMjgxOTI4Ml19
-->