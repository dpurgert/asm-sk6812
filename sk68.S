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

.SET LEDs=5                 ; Number of LEDs
.SET dsz=(3*LEDs)           ; 3 bytes / LED * numLeds
.DEF low=R5                 ; register for low data
.DEF hi=R6                  ; register for high data
;these set a delay "timer".  Roughly, they'll hit
; a rate of (30 us / LED + 80 us reset delay) * the 16-bit number 
; "dlth_dltl".
; This is set on every iteration of the rainbow
; testing - 2 LEDS (60 us  + 80us) *10 loops = 1400 us / 1.4 ms 
.EQU dlth=0x01              ; Delay Timer(16bit). Num cycles to not
.EQU dltl=0x00              ; change rainbow color. 0x0100 = 256


;data segment for storing to RAM
.DSEG
.ORG 0x0060

dctr: .BYTE 1               ; data counter
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
  ldi r16,dsz               ; load r16 with datasize
  sts dctr, r16             ; store dcounter with r16 value

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
  
  ;set up r4 to be a constant '8' - for use in rainbow
  ldi r16, 0x08
  mov r4, r16
 
  clr r16                   ; clear R16
  inc r1                    ; set r1 = 1 to trigger display update

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
  tst r16                   ; test r16 = 0
  brne dis                  ; if nonzero, display      
  rcall upd_rainbow         ; otherwise update rainbow
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
  ;ldi r17, dsz              ; temporarily set r17 to datasize
  ;mov r2,r17                ; copy r17 into r2 
  lds r2, dctr              ; load data counter into r2
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
  inc r8                    ; set r8 to allow red to start changing
  inc r3                    ; force rainbow to sit at red for 1 delay
  clr r7                    ; ensure green and blue aren't 
  clr r9                    ; set to change colors
  clr r11                   ; ensure red is decrementing
  inc r10                   ; green is incrementing
  inc r12                   ; blue is incrementing
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
  ;*********************************************************************
  ;   Cycle through a rainbow of colors.  
  ;
  ;   Registers used:
  ;
  ;     r2 - data counter
  ;     r3 - pause rainbow (on solid colors)
  ;     r4 - constant '8' for addition / subtraction
  ;     r7 - Green Level Enabled 
  ;     r8 - Red Level Enabled
  ;     r9 - Blue Level Enabled
  ;     r10 - Increment Green positive(1) / negative(0)
  ;     r11 - Increment Red positive(1) / negative(0)
  ;     r12 - Icrement Blue positive(1) / negative(0)
  ;     r17 - Green Level
  ;     r18 - Red Level
  ;     r19 - Blue Level
  ;     r20 - countdown timer
  ;
  ;  ctXX = clock tick something (e.g. CT00
  ;*********************************************************************
chkrain:
  tst r3                    ; allowed to change?
  breq chkgrn               ; change lock byte not set, continue.
  ret                       ; change lock byte set, so return.  
chkgrn:
  inc r3
  ldi r20, dltl             ; load delay low to r20
  ldi r21, dlth             ; delay hi to r21
  tst r7                    ; changing green?
  breq chkred               ; r7 = 0, skip to red
  rjmp raingrn              ; r7 >0, so yes (jump becaue branch limit)
chkred:
  tst r8                    ; changing red?
  breq chkblu               ; r8 =0, skip to blue
  rjmp rainred              ; r8 >0, so yes (jump becaue branch limit)
chkblu:
  tst r9
  brne rainblu              ; r9>0, process blue
  cpi r19, 0xff             ; if we got this far, and blue is 255, 
  breq restblu              ; restart blue
  cpi r18,0xff              ; if we got this far, and red is 255,
  breq restred              ; restert red
  cpi r17,0xff              ; if we got this far, and green is 255,
  breq restgrn              ; restart green
finblu:                     ; otherwise finish out
  lds r2, dctr              ; load data counter into R2
  lds XL, dptr              ; set XREG to start address of data         
  lds XH, dptr+1            ; array.  
rainupdlp:
  st X+, r17                ; store r17 (green byte), increment X
  st X+, r18                ; store r18 (red byte), increment X
  st X+, r19                ; store r19 (blue byte), increment X
  dec r2                    ; decrement counter
  brne rainupdlp            ; back to updateloop
  ret                       ; return from routine

restblu: inc r9             ;force-enable blue
rainblu:
  tst r12                   ; positive or negative
  breq decblu               ; if 0, decrement
  add r19,r4                ; nonzero, increment value by 8
  brcc blupt                ; C clear, jump to "passthru"
  ldi r19, 0xFF             ; carry set, reset value to 255
  clr r12                   ; next pass, we're decrementing
  rjmp blulk                ; jump to blue lock
decblu:
  sub r19, r4               ; decrement value by 8
  brcc blupt                ; C clear, jump to "passthru"
  ldi r19, 0x00             ; carry set, ensure r19 is 0 
  inc r12                   ; next time through blue, increment
blulk:
  clr r9                    ; clear r9, not changing blue
blupt:
  tst r12                   ; check if inc. or dec. again
  brne finblu               ; r12 nonzero, incrementing
  cpi r19, 0x7F             ; compare current value to 128
  brsh finblu               ; r19 > 128, jump to redgrn processing
  inc r7                    ; else enable green changes
  rjmp finblu               ; and get to redgrn processing
;incblu:
;  cpi r19,0x80              ; compare current value to 128
;  brlo finblu               ; r19 < 128, do nothing
;  inc r8                    ; 128<r19<136, enable red to start changing
;  rjmp finblu

restred: inc r8             ; force start red
rainred:
  tst r11                   ; positive or negative
  breq decred               ; if 0, decrement
  add r18,r4                ; nonzero, increment value by 8
  brcc redpt                ; C clear, jump to "passthru"
  ldi r18, 0xFF             ; carry set, reset value to 255
  clr r11                   ; next pass, we're decrementing
  rjmp redlk                ; jump to red lock
decred:
  sub r18, r4               ; decrement value by 8
  brcc redpt                ; C clear, jump to "passthru"
  ldi r18, 0x00             ; carry set, ensure r18 is 0 
  inc r11                   ; next time through red, increment
redlk:
  clr r8                    ; clear r8, not changing red
redpt:
  tst r11                   ; check if inc. or dec. again
  brne finred               ; r11 nonzero, incrementing
  cpi r18, 0x7F             ; compare current value to 128
  brsh finred               ; r19 > 128, jump to finred processing
  inc r9                    ; else enable blue changes 
  rjmp finred               ; and get to finred processing
;incred:
;  cpi r18,0x80              ; compare current value to 128
;  brlo finred               ; r19 < 128, do nothing
;  inc r7                    ; r19 >= 128, enable green to start 
finred:
  rjmp chkblu               ; check if we need to process blue
  

restgrn: inc r7             ; force restart green
raingrn:
  tst r10                   ;positive or negative
  breq decgrn               ; if 0, decrement
  add r17,r4                ; nonzero, increment value by 8
  brcc grnpt                ; C clear, jump to "passthru"
  ldi r17, 0xFF             ; carry set, reset value to 255
  clr r10                   ; next pass, we're decrementing
  rjmp grnlk                ; jump to green lock
decgrn:
  sub r17, r4               ; decrement value by 8
  brcc grnpt                ; C clear, jump to "passthru"
  ldi r17, 0x00             ; carry set, ensure r17 is 0 
  inc r10                   ; next time through green, increment
grnlk:
  clr r7                    ; clear r7, not changing green
grnpt:
  tst r10                   ; check if inc. or dec. again
  brne fingrn               ; r12 nonzero, incrementing
  cpi r17, 0x7F             ; compare current value to 128
  brsh fingrn               ; r19 > 128, jump to redblu processing
  inc r8                    ; else enable red changes   
  rjmp fingrn               ; and get to redblu processing
;incgrn:
;  cpi r17,0x80              ; compare current value to 128
;  brlo fingrn               ; r19 < 128, do nothing
;  inc r9                    ; r19 >= 128, enable blue to change
fingrn:
  rjmp chkred               ; check if we're to process red


reset_delay:
  ;*********************************************************************
  ;   Hold data line low for ~80us.  Datasheet indicates min. is 50
  ;
  ;   Registers used:
  ;     r3 -- enable / disable the rainbow
  ;     r20:21 -- rainbow loop counter before unlocking color change
  ;     r22 -- reset loop counter
  ;**********************************************************************

  ;this loop for rainbow handling
  tst r16                   ; check r16
  brne todelay              ; if nonzero, don't bother with rainbow
  subi r20, 1               ; subtract 1 from low byte
  brcc todelay              ; if C clr, skip todelay (r20 >=0)
  ldi r20, 0xFF             ; otherwise reset to 0xFF, and 
  subi r21, 1               ; subtract 1 from high byte
  brcc todelay              ; if C clr, skip todelay (r21 >=0)
  clr r3                    ; if C set (r21:20 == 0 before subi), clr r3
                            ; r3=0 so next loop will change a color
todelay:
  ldi r22, 140              ; loop for 140 * 3 ticks (ish)
rst_lp:                     ; or approx 88 us.
  dec r22                   ; sk6812 datasheet only implies 
  tst r22                   ; 50 us is the minimum
  brne rst_lp
  ret
