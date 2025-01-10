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

Select the number of PCBs and the assembly options you require. Minimum PCB quantities are usually 5 boards, although assembly can be as few as 2 boards.

If required, upload the BOM and Pick&Place files, and check that the suggested parts are available. JLC regularly changes their stocked items, so make sure that, at a minimum, the following are correct for each item:

 - Components are the correct footprint (Resistors and Capacitors are 0603 or 1206, MOSFETS are SOT23)
 - Components are the correct rating (see BOM for details)
 - Components are in the `basic` series where possible, especially capacitors, resistors and MOSFETs

Ensure that the components are placed correctly on the PCB, and that the correct radio module is selected, then check and place the order.

Assemble the PCBs according to the BOM and Pick&Place files, or the photographs below.

Solder the Luckfox Pico Mini to the headers as low down as possible, to ensure easy access to the SD card.

#### 2. Buying a Femtofox
Although the Femtofox CE is only licensed for personal use and not for sale, a Femtofox Pro is available through licensed sellers as follows:

 1. Open Source Country
 2. NomDeTom
 3. Noon
 4. TBC
 5. TBC

The Femtofox Pro has all the same features as the CE, plus a few features that only make sense when ordered at scale [Insert link]. If you require a large quantity of Femtofox 

<!--stackedit_data:
eyJoaXN0b3J5IjpbLTEwMjAxOTkyOTRdfQ==
-->