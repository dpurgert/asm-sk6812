#build and upload to the micro
sk: sk68.S
	avra -fM sk68.S    
	avrdude -e -pattiny85  -carduino -P/dev/ttyUSB0 -b19200 \
		-Uflash:w:sk68.S.hex:i

#build and upload to the micro
compileonly: sk68.S
	avra -fM sk68.S    

#read current fuse settings
read_fuses:
	avrdude -e -pattiny85  -carduino -P/dev/ttyUSB0 -b19200 \
		-Ulfuse:r:-:i -Uhfuse:r:-:i -Uefuse:r:-:i

#set 8 MHz internal oscillator \
 lfuse - 8MHz internal oscillator \
         CKSEL 0010 / SUT 10 = PWRDN/RST 6ck/14ck + 64ms\
 hfuse - SPI programming enable
8m_fuse:
	avrdude -e -pattiny85  -carduino -P/dev/ttyUSB0 -b19200 \
		-Ulfuse:w:0xe2:m -Uhfuse:w:0xdf:m -Uefuse:w:0xff:m

#default fuses \
 lfuse - 8MHz internal oscillator, CKDIV8 = 1 MHz\
         CKSEL 0010 / SUT 10 = PWRDN/RST 6ck/14ck + 64ms\
 hfuse - SPI programming enable
def_fuse:
	avrdude -e -pattiny85  -carduino -P/dev/ttyUSB0 -b19200 \
		-Ulfuse:w:0x62:m -Uhfuse:w:0xdf:m -Uefuse:w:0xff:m

#clean build dir
clean:
	rm *hex *obj
