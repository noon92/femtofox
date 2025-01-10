## Femtofox - Getting Started
This guide assumes a certain level of familiarity with [Meshtastic](meshtastic.org), and [Meshtastic nodes](https://meshtastic.org/docs/getting-started/).

The Femtofox is similar to, and can functionally replace, a [Raspberry Pi Linux Native Meshtastic node](https://meshtastic.org/docs/hardware/devices/linux-native-hardware/). However, the Foxbuntu OS takes away most of the heavy lifting of a typical install, leaving you free to build your mesh application without the initial hurdles.

### Hardware
To get started, you will need a Femtofox. You can either build or buy one.

#### 1. Building a Femtofox
Femtofox Community Edition (CE) is provided as standard PCB Gerber files and suitable Bills of Materials (BOM) and Pick and Place files for the components.
Download the Gerber files from [here](TBC), selecting the set of files for your application:

 - Bare PCB - you have all of the necessary components on hand
 - SMD populated PCB - you have a Luckfox Pico Mini and suitable radio module on hand, plus any other headers or connectors desired.
 - Radio and header populated PCB - only a Luckfox Pico Mini is required to complete the build. Two sets of files are provided for this, based on the radio module required:
	 - 22db (E22-900M22S)
	 - 30db (E22-900M30S)

Upload the Gerber .zip file to a PCB maker of your choice, e.g.:
 - JLCPCB
 - PCBWay
 - OSHPark

Prototypes were made using JLCPCB. We recommend selecting a board thickness of 1.6mm, and a lead-free HASL surface finish. It is also suggested to select "Remove mark" for order serial numbers, as the Gerbers do not contain a specific location for this marking.

If required, upload the BOM and Pick&Place files, and check that the suggested parts are available. JLC regularly changes their stocked items

### 
<!--stackedit_data:
eyJoaXN0b3J5IjpbLTYzNjI5ODQyOV19
-->