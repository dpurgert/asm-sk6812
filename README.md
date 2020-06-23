# sk6812

ATTiny driver for SK6812 LEDs (similar to WS2812, etc.).  

Project grew out of a need to accommodate an extremely small physical
footprint, necessitating DIP-8 (or smaller) MCU package.  Existing
libraries all needed a lot of space.

## Pinout 
|:---:|:----------|---------:|:---:|
|1    |RST (NC)   |VCC       |    8|
|2    |PB4 (NC)   |INT0 (col)|    7|
|3    |PB3 (NC)   |PB1 (NC)  |    6|
|4    |GND        |PB0       |    5|

Connected Pins / purpose:
* 4 - System Ground
* 5 - Data Out
* 7 - Color Change
* 8 - VCC

##Changelog

