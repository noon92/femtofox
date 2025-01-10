## Supported Hardware
| Hardware | Confirmed working | Expected to work | Notes |
|-|-|-|--|
|LoRa radios (working with Meshtasticd)|<li>[Waveshare RPi LoRa hat without GNSS](https://www.waveshare.com/sx1262-lorawan-hat.htm?sku=22002)*<li>[Seeed Wio SX1262](https://www.seeedstudio.com/Wio-SX1262-Wireless-Module-p-5981.html)<li>[Ebyte E220900M30S](https://aliexpress.com/item/4000543921245.html)<li>AI Thinker RA-01SH<li>[Heltec HT-RA62](https://www.aliexpress.com/item/1005005445349105.html)|<li>Ebyte E22-900mm22s<li>[Ebyte E22-900m22s](https://www.aliexpress.com/item/1005001808069127.html)<li>Any SPI LoRa radio that's Meshtastic compatible|*Waveshare RPi hat is not recommended as it has issues with sending longer messages.|
|MicroSD cards|<li>[Kingston Endurance 32gb](https://www.kingston.com/en/memory-cards/high-endurance-microsd-card)<li>[Sandisk Ultra UHS-I 32gb](https://shop.sandisk.com/products/memory-cards/microsd-cards/sandisk-ultra-uhs-i-microsd?sku=SDSQUA4-032G-GN6MA)|Any reasonably fast (UHS-I or better) card with 8gb or more|Stick with reputable manufacturers (Kingston, PNY Samsung, Sandisk, Transcend...)<br>The faster the better! Consider sticking with "endurance" cards, especially for remotely deployed nodes.|
|RTC (real time clock)|<li>[DS3231M](https://vi.aliexpress.com/item/1005007143842437.html)<li>[DS1307](https://vi.aliexpress.com/item/1005007143542894.html)|DS1337, DS1338, DS1340, other DS3231 variants                                                                                                          |Some DS3231 modules are listed as having a supercapacitor - these are usually actually lithium coin cells.|
|Meshtastic nodes|USB+UART: [RAK4631 with RAK19007 or RAK19003 base board](https://store.rakwireless.com/products/wisblock-meshtastic-starter-kit)|                                                                                                                                                       |RAK4630 and 4631 are the same.|
|USB wifi adapter chipsets|||See below|  |
|Misc. hardware|<li>USB hubs (powered or not)<li>Thumb drives<li>SD card readers||If power draw exceeds supply, the device will reboot, bootloop or hard crash. Unpowered USB hubs seem to be notorious for causing reboots.<br>Some users have reported that USB-C flash drives do not work. This requires more study.|

### Wifi chipsets
The following wifi chipsets/devices have their drivers included in the OS images. Most of these have not been tested. Note that power consumption metrics are for a specific version of a chipset and may not apply to all implementations.

|Chipset:               |Tested?|Recommended?|Power usage |Notes|
|-----------------------|-------|------------|------------|-----|
|**<u>Realtek:**        |       |            |            |     |
|rtl8187                |       |            |            |     |
|rtl8187b               |       |            |            |     |
|rtl8188[cr]u           |       |            |            |     |
|rtl8188cu              |       |            |            |     |
|rtl8188ee              |       |            |            |     |
|rtl8188eu<br>rtl8188eus<br>rtl8188cus|✔️|✔️|Idle: 0.25w<br>TXing: 0.4w<br>Off: 0.026w|Model tested:<br>[TP-LINK TL-WN725N **V2**](https://techinfodepot.shoutwiki.com/wiki/TP-LINK_TL-WN725N_v2): working<br>[TP-Link TL-WR722N **V4**](https://techinfodepot.shoutwiki.com/wiki/TP-LINK_TL-WN722N_v1.x): working (v2, v3 *should* be identical)|
|rtl8188ru              |       |            |            |     |
|rtl819[12]cu           |       |            |            |     |
|rtl8191cu              |       |            |            |     |
|rtl8192ce              |       |            |            |     |
|rtl8192cu              |✔️     |❔          |            |Tested:<br>[Edimax EW-7811Un](https://techinfodepot.shoutwiki.com/wiki/Edimax_EW-7811Un): working|
|rtl8192de              |       |            |            |     |
|rtl8192e               |       |            |            |     |
|rtl8192ee              |       |            |            |     |
|rtl8192eu              |✔️     |❌          |            |Buggy|
|rtl8192se              |       |            |            |     |
|rtl8273,8188,8191,8192 |       |            |            |     |
|rtl8712u               |       |            |            |     |
|rtl8723ae              |       |            |            |     |
|rtl8723au              |       |            |            |     |
|rtl8723be              |       |            |            |     |
|rtl8812bu				|✔️     |❌          |            |Tested:<br>[TP-LINK Archer T3U](https://techinfodepot.shoutwiki.com/wiki/TP-LINK_Archer_T3U): **NOT** working|
|rtl8821ae              |       |            |            |     |
|rtl8821au              |✔️     |❌          |            |Tested:<br>[TP-Link Archer T2U Plus](https://www.tp-link.com/us/home-networking/usb-adapter/archer-t2u-plus/): **NOT** working|
|rtl8xxx other          |       |            |            |     |
|                       |       |            |            |     |
|**<u>Mediatek:**       |       |            |            |     |
|mt7601u                |✔️     |✔️          |Idle: 0.739w|Tested:<br>[Genbasic RF 2A4M1](https://www.amazon.com/dp/B0BNFKJPXS): working|
|mt76x0u                |       |            |            |     |
|mt76x2u                |       |            |            |     |
|mt7663s                |       |            |            |     |
|mt7663u                |       |            |            |     |
|                       |       |            |            |     |
|**<u>Atheros:**        |       |            |            |     |
|ar5008                 |       |            |            |     |
|ar5523                 |       |            |            |     |
|ar6003                 |       |            |            |     |
|ar6004                 |       |            |            |     |
|ar9001                 |       |            |            |     |
|ar9002                 |       |            |            |     |
|ar9170                 |       |            |            |     |
|ar9271                 |✔️     |❔          |            |Tested:<br>[TP-Link TL-WR722N **V1**](https://techinfodepot.shoutwiki.com/wiki/TP-LINK_TL-WN722N_v1.x): working<br>[Penguin Wireless TPE-N150USB](https://www.thinkpenguin.com/gnu-linux/penguin-wireless-n-usb-adapter-gnu-linux-tpe-n150usb): buggy<br>[Generic AR9271 w/SMA antenna](https://www.aliexpress.com/item/1005007556237899.html): buggy<br>Work in progress|
|ar9k                   |       |            |            |     |
|ath11k                 |       |            |            |     |
|ar10k                  |       |            |            |     |
|wcn3660                |       |            |            |     |
|wcn3680                |       |            |            |     |
|                       |       |            |            |     |
|**<u>Ralink:**         |       |            |            |     |
|rt2501/rt73            |       |            |            |     |
|rt2571                 |       |            |            |     |
|rt2571w                |       |            |            |     |
|rt2572                 |       |            |            |     |
|rt2573                 |       |            |            |     |
|rt25xx                 |       |            |            |     |
|rt2671                 |       |            |            |     |
|rt27xx                 |       |            |            |     |
|rt28xx                 |       |            |            |     |
|rt28xx unknown         |       |            |            |     |
|rt30xx                 |       |            |            |     |
|rt3070                 |✔️     |❔          |            |Tested:<br>[Alfa AWUS036NEH](https://techinfodepot.shoutwiki.com/wiki/ALFA_Network_AWUS036NEH): buggy|
|rt33xx                 |       |            |            |     |
|rt3573                 |       |            |            |     |
|rt35xx                 |       |            |            |     |
|rt53xx                 |       |            |            |     |
|rt55xx                 |       |            |            |     |
|                       |       |            |            |     |
|**<u>Atmel:**          |       |            |            |     |
|at76c503               |       |            |            |     |
|at76c505               |       |            |            |     |
|at76c505a              |       |            |            |     |
|                       |       |            |            |     |
|**<u>Microchip Atmel:**|       |            |            |     |
|wilc1000               |       |            |            |     |
|                       |       |            |            |     |
|**<u>Zydas:**          |       |            |            |     |
|zd1201                 |       |            |            |     |
|zd1211                 |       |            |            |     |
|zd1211b                |       |            |            |     |
|                       |       |            |            |     |
|**<u>RNDIS USB:**      |       |            |            |     |
|Asus WL169gE           |       |            |            |     |
|Belkin F5D7051         |       |            |            |     |
|BT Voyager 1055        |       |            |            |     |
|Buffalo WLI-U2-KG125S  |       |            |            |     |
|BUFFALO WLI-USB-G54    |       |            |            |     |
|Eminent EM4045         |       |            |            |     |
|Linksys WUSB54GSC      |       |            |            |     |
|Linksys WUSB54GSv1     |       |            |            |     |
|Linksys WUSB54GSv2     |       |            |            |     |
|U.S. Robotics USR5420  |       |            |            |     |
|U.S. Robotics USR5421  |       |            |            |     |
