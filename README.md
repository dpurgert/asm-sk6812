# sk6812

ATTiny driver for SK6812 LEDs (similar to WS2812, etc.).  

Project grew out of a need to accommodate an extremely small physical
footprint, necessitating DIP-8 (or smaller) MCU package.  Existing
libraries all needed a lot of (flash) space.

## Requirements
 * ATTiny x5 series (25,45,85)
 * CKDIV disabled (i.e. run at 8 MHz)

## Pinout 
|PIN  | Desc      |Desc      |PIN  |
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
v 0.3 - Fixed the timer interrupt to ensure INT0 doesn't fire again.
v 0.2 - Add interrupt vector to allow changing program.
v 0.1 - Added "rainbow" color transitions.  Actual increments are +/-8
in the code, resulting in a rough progression as follows:
|Grn|Red|Blue|
|---|---|---|
|0|255|0|
|0|127|8|
|0|0|255|
|8|0|127|
|255|0|0|
|127|8|0|

More work needs to go into the transitions, as well as the timing.


