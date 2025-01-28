## Femtofox - Getting Started
This guide assumes a certain level of familiarity with [Meshtastic](meshtastic.org), and [Meshtastic nodes](https://meshtastic.org/docs/getting-started/).

The Femtofox is similar to, and can functionally replace, a [Raspberry Pi Linux Native Meshtastic node](https://meshtastic.org/docs/hardware/devices/linux-native-hardware/). However, the Foxbuntu OS takes away most of the heavy lifting of a typical install, leaving you free to build your mesh application without the initial hurdles.

### Hardware
To get started, you will need a Femtofox. You can either build or buy one.
<B> 1. Building a Femtofox </B>

Femtofox Community Edition (CE) is provided as a standard PCB Gerber files and suitable Bill of Materials (BOM) and Pick and Place files for the components.

Download the Gerber files from [here](TBC).

Upload the Gerber .zip file to a PCB maker of your choice, e.g.:
 - JLCPCB
 - PCBWay
 - OSHPark

Prototypes were made using JLCPCB. It is recommend to select a board thickness of 1.6mm, and a lead-free HASL surface finish. It is also suggested to select "Remove mark" for order serial numbers, as the Gerbers do not contain a specific location for this marking.

Select the number of PCBs and the assembly options you require. Minimum PCB quantities are usually 5 boards, although assembly can be as few as 2 boards.

If required, upload the BOM and Pick&Place files, and check that the suggested parts are available. JLC regularly changes their stocked items, so make sure that, at a minimum, the following are correct for each item:

 - Components are the correct footprint (Resistors and Capacitors are 0603 or 1206, MOSFETS are SOT23)
 - Components are the correct rating (see BOM for details)
 - Components are in the `basic` series where possible, especially capacitors, resistors and MOSFETs

Ensure that the components are placed correctly on the PCB, and that the correct radio module is selected, then check and place the order.

Assemble the PCBs according to the BOM and Pick&Place files, or the photographs below.

Solder the Luckfox Pico Mini to the headers as low down as possible, to ensure easy access to the SD card.
</details>

<details>
<summary> <B> 2. Buying a Femtofox </B> </summary>

The Femtofox Pro is available for purchase, and has several added features:
* Arrives fully assembled
* 4-Layer PCB allows for extra complexity
* USB-C for power and built in serial debug, which allows for direct access to the Femtofox without network or additional hardware
* Extra pins are mapped to the headers, allowing for easier expansion
* An added "Kill Switch" breakout, allowing for the addition of an optional thermal fuse for added safety on solar builds
* Additional decoupling capacitors
The Femtofox Pro is available through the following licensed sellers:
 1. Open Source Country (USA)
 2. NomDeTom (UK)
 3. Noon (Central Korea)
 4. TBC
 5. TBC

If you require a large quantity of Femtofox boards, please get in touch.
</details>

### Operating System

 1. Download the latest image of Foxbuntu from the releases [link] and extract from the 7z file with [7z program].
 2. Use an image flashing tool such as [Balena Etcher] to flash the image to a suitable SD card (see [supported hardware]).
 Note that the image will not appear bootable to Etcher, but will be functional in use.
 3. Insert the SD card into the reader of the Femtofox

### Initial Configuration - Suggested Workflow
Foxbuntu is ready to operate almost from the first boot. The settings can be configured using one of the following methods:

<details>
<summary> <B>  Command Line </B> </summary>

 1. Serial console - Connect a USB-C cable to the power/serial port (Femtofox Pro) or connect a serial-USB adaptor to TX/RX/Gnd of UART2 (Femtofox CE).
 2. SSH via Ethernet - connect a network cable either through the RJ45 port or by soldering directly to the Ethernet headers of the Luckfox (possible but not recommended) and connect it to your network. Identify the IP address via your DHCP server (e.g. your router) and connect using an SSH client of your choice.

After first login, run `sudo femto-config` from the command prompt, and launch the setup wizard.

[ 3. Web tool via Wifi AP mode - if a wifi adaptor is identified at first boot, and no configuration is provided for it, then the Femtofox will automatically generate a wifi hotspot to allow configuration. Connect to the wifi hotspot and access the web config tool using `192.168.4.1` in a browser.]: #
[ 4. SSH via Wifi AP mode - ... ]: #

</details>

<details>
<summary> <B>   USB Config </B> </summary>

See [this page](./usb_config.md) for details on how to configure via a USB drive.
</details>

### Mesh Applications
Femtofox is supplied with pre-installed copies of many popular applications, such as:

 1. [Meshing Around](https://github.com/SpudGunMan/meshing-around) - a popular auto-responder/query handler/BBS/everything else.
 2. [TheCommsChannel BBS](https://github.com/TheCommsChannel/TC2-BBS-mesh) - a popular BBS application
 3. [Curses Client for Meshtastic](https://github.com/pdxlocations/curses-client-for-meshtastic) - the simplest, most retro client possible

Additional applications may be added to the default image in future.

### Updating
Foxbuntu, Meshtasticd and the mesh applications can be updated as using the `Femto-Config` tool.


<!--stackedit_data:
eyJoaXN0b3J5IjpbMjA5NjI5MjA1M119
-->