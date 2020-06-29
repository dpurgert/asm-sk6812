;***********************************************************************
;                              File: sk68.S   
;                     Copyright (c): 2020, Dan Purgert
;                                  : dan@djph.net
;                   
;                           License: GNU GPL v2 only
;                       Description: Driver control for SK6812 LEDs.
;                       
;                     Prerequisites: 
;                                  : avra >= ??? (w/ m88PA support)
;                                  : avrdude >= 6.3-2 (Debian)
;                                  : make
;                                  : tn85def.inc (from Microchip -- 
;                                  : can be obtained in the MPLABX tool)
;***********************************************************************

.include "tn85def.inc" 

.SET LEDs=2                 ; Number of LEDs
.SET dsz=(3*LEDs)           ; 3 bytes / LED * numLeds
.DEF low=R5                 ; register for low data
.DEF hi=R6                  ; register for high data

;data segment for storing to RAM
.DSEG
.ORG 0x0060

dptr: .BYTE 2               ; pointer for XREG later
lddt: .BYTE dsz             ; Data Array. 3 bytes / LED 

;reset and interrupt vectors - ATTiny25/45/85
.CSEG
.ORG 0
rjmp setup                  ; Reset vector, jump to 'setup'
rjmp INT0_ISR               ; INT0
reti                        ; PCINT0
reti                        ; TIM1_CMPA
reti                        ; TIM1_OVF
reti                        ; TIM0_OVF
reti                        ; EE_RDY
reti                        ; ANA_COMP
reti                        ; TIM1_CMPB
reti                        ; TIM0_CMPA
reti                        ; TIM0_CMPB
reti                        ; WDT
reti                        ; USI_START
reti                        ; USI_OVF

INT0_ISR:
  ;*********************************************************************
  ;   External Pin Interrupt.
  ;
  ;   Registers used:
  ;     r1 -- flag for changing memory map on next run
  ;
  ;*********************************************************************
  
  ;inc r1                    ; flag 
  reti                      ; return from interrupt
 
setup:                      
  ;*********************************************************************
  ;   Initialization routine.
  ;
  ;   Registers used:
  ;     r16 -- general purpose for setting data
  ;
  ;*********************************************************************

  ; Stack Pointer setup
  ldi r16, low(RAMEND)      ; Set stack pointer to start at
  out SPL, r16              ; RAMEND.  
  ldi r16, high(RAMEND)     ; Don't forget SP counts backwards 
  out SPH, r16              ; ($FF -> $FE -> $FD, etc.)

  ; XREG / Data setup
  ldi XL, low(lddt)         ; Set XREG to start location of DATA
  ldi XH, high(lddt)        ; Array.
  sts dptr, XL              ; Set a pointer to the beginning, for use   
  sts dptr+1, XH            ; later on                            

  ; Input and output pins - PORTB
  sbi DDRB, DDB0            ; PB0 to output
  sbi PORTB,PB2             ; PB2 to inbput_pullup
  sbi PORTB,PB1             ; PB1 pulse to trigger logic
  cbi PORTB,PB1             ; And back down        
  
  ; Set up external interrupts
  ldi r16,0x03              ; 0x03 = INT0 trg on fall (TBL 9.2)
  out MCUCR, r16            ; set MCU Control Register
  ldi r16,0x40              ; 0x40 = INT0 enable
  out GIMSK, r16            ; set Int Mask Register

  ; Set up "hi" and "low" port variable
  ldi r16,0x04              ; PORTB low value 
  mov low, r16              ; move to 'low' variable
  inc r16                   ; increment r16
  mov hi, r16               ; copy to 'hi' variable
  
  clr r16                   ; clear R16
  inc r1                    ; set r1 = 1 ... should give us white light

  ;hardcode some output data
  ;ldi r17, dsz              ; temporarily set r17 to datasize
  ;mov r2,r17                ; copy r17 into r2 
  ;ldi r17, 0xAA             ; green = 255
  ;ldi r18, 0x00             ; red = 255
  ;ldi r19, 0xFF             ; blue = 255
;updlp:
  ;st X+, r17                ; store r17 (green byte), increment X
  ;st X+, r18                ; store r18 (red byte), increment X
  ;st X+, r19                ; store r19 (blue byte), increment X
  ;dec r2                    ; decrement counter
  ;brne updlp                ; if nonzero, keep inserting

  sei                       ; enable interrupts

loop:
  ;*********************************************************************
  ;   Main program loop 
  ;
  ;   Registers used:
  ;     r1 -- display change flag
  ;
  ;*********************************************************************
  tst r1                     ; test r1 = 0
  brne udis                 ; if not, goto update display
  ;tst r16                   ; test r16 = 0
  ;brne dis                  ; if nonzero, just display
  ;rcall upd_rainbow         ; else update the rainbow first
dis:
  rcall display             ; output display data
  rcall reset_delay         ; reset_delay for the LEDs
  rjmp loop                 ; and back to the loop
udis:
  rcall upd_display         ; update the display color
  rjmp dis                  ; and display
  

upd_display:
  ;*********************************************************************
  ;   Update Display Output
  ;
  ;   Registers used:
  ;     r1 -- display change flag
  ;     r16 -- display state flag (solid white, red, blue, rainbow)
  ;            use R16 because we can use immediate compares, saving
  ;            an instruction.
  ;     r17:19 -- Green, Red, Blue values for solid colors
  ;
  ;*********************************************************************
  dec r1                    ; decrement r1 back to 0
  ldi r17, dsz              ; temporarily set r17 to datasize
  mov r2,r17                ; copy r17 into r2 
  cpi r16, 0x00             ; if r16 = 0, white
  breq white                ;
  cpi r16, 0x01             ; if r16 = 1, red
  breq red                  ;
  cpi r16, 0x02             ; if r16 = 2, blue
  breq blue                 ;
                            ; else, rainbow

rainbow:
  ldi r17, 0x00             ; green = 0
  ldi r18, 0xff             ; red = 255
  ldi r19, 0x00             ; blue = 0
  clr r16                   ; r16 = 0 (for next cycle)
  rjmp upd_cmp              ; to complete teh update

white:
  ldi r17, 0xff             ; green = 0
  ldi r18, 0xff             ; red = 0  
  ldi r19, 0xff             ; blue = 255
  inc r16                   ; r16 =1 (for next cycle)
  rjmp upd_cmp              ; to complete teh update

red:
  ldi r17, 0x00             ; green = 0
  ldi r18, 0xff             ; red = 255
  ldi r19, 0x00             ; blue = 0
  inc r16                   ; r16 =1 (for next cycle)
  rjmp upd_cmp              ; to complete teh update

blue:
  ldi r17, 0x00             ; green = 0
  ldi r18, 0x00             ; red = 0  
  ldi r19, 0xff             ; blue = 255
  inc r16                   ; r16 =1 (for next cycle)

upd_cmp:
  lds XL, dptr              ; set XREG to start address of data         
  lds XH, dptr+1            ; array.  
updlp:
  st X+, r17                ; store r17 (green byte), increment X
  st X+, r18                ; store r18 (red byte), increment X
  st X+, r19                ; store r19 (blue byte), increment X
  dec r2                    ; decrement counter
  brne updlp                ; back to updateloop
  ret                       ; or return from subroutine

display:
  ;*********************************************************************
  ;   Send LED Data out to LEDs
  ;
  ;   Registers used:
  ;
  ;     r2 - Output byte register
  ;     r24 - byte counter
  ;     r23 - bit counter
  ;
  ;  ctXX = clock tick something (e.g. CT00
  ;
  ;*********************************************************************
  lds XL, dptr              ; set XREG to start address of data         
  lds XH, dptr+1            ; array.  
  ldi r24, dsz              ; r25 to data size
st:
  ldi r23, 7                ; 7 bits to send (loop 7 times)
  ld r2, X+                 ; load r2 with first byte in data
ct06: nop                   ; clocktick6, no op
ct07: nop                   ; clocktick7, no op
  out PORTB, low            ; force pb0 low (clear bit 1)
ct09: lsl r2                ; tick 9 shift bit
s00: out PORTB, hi          ; tick0 pb0 high
  brcs ct03                 ; if carry set, jump to clock3
  out PORTB, low            ; else shut off pb0 (2 ticks = logic 0)
ct03: dec r23               ; subtract a bit
  brne ct06                 ; if bits >0, jump to clock6
  lsl r2                    ; else shift last bit
  brcc bit8                 ; jump to bit8 processing if bit8=0
  ldi r23,7                 ; otherwise reset counter to 7
  out PORTB, low            ; portb down (7 ticks = logic high)
  nop
  out PORTB, hi             ; portb up
  sbiw r24, 1               ; decrement bytes
  ld r2, X+                 ; and load next byte
  brne ct07                 ; bytes >0, back to clock7
  rjmp disend               ; else finish up
bit8: out PORTB, low        ; bit8 was 0, bit7 data low
  ldi r23, 7                ; reset bit counter
  out PORTB, hi             ; data high
  nop
  out PORTB, low            ; data low (2 clocks = logical 0)
  sbiw r24,1                ; decrement bytes
  ld r2, X+                 ; and load next byte
  brne ct09                 ; if byteAvail, goto clocktick9
disend: out PORTB, low      ; else, shutdown
  ret                       ; and return

upd_rainbow:
  ;do nothing for now - just wanna compile
  ret

reset_delay:
  ldi r22, 160  
rst_lp:
  dec r22
  tst r22
  brne rst_lp
  ; for giggles, cycle through things
  inc r1
  ret
