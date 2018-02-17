  .cdecls C,LIST,"msp430.h"	; Device header file
;;; Symbolic constants ---------------------------------------------------------
VALUE:	.equ R4		; R4 holds numeric value entered by users
BCD_VALS:	.equ R5	; R5 holds BCD numbers entered by user
DIV16:	.equ R6		; R6 is a flag set when users enter freq < 16Hz

  .def GET_KEY

  .ref OUTPUT_BITS

  .text

GET_KEY:
  push R13 ; Make space
  call #SCAN ; Get input into R12

BUTTON_INPUT_LOOP:
  mov R12,R13 ; Store into R13
  bis #MC__UP+TACLR,&TA1CTL ; Start delay timer
  nop
  bis #LPM3+GIE,SR ; Enter low power mode
  nop
  call #SCAN ; Get new input into R12
  cmp #0x0FFF,R12 ; Exit loop if no buttons are being pressed
  jnz BUTTON_INPUT_LOOP ; Loop if one button is being pressed
  mov R13,R12 ; Take last non-zero input
  pop R13 ; Restore R13
  call #DECODE_INPUT ; R12 now contains proper ASCII character
  ret

;;; Get input
SCAN:
  bic.b #BIT7,&P2OUT
  bis.b #BIT4+BIT5,&P2OUT ; 3/6/9/# column is lo
  mov.b &P2IN,R12 ; Prepare to rotate column
  and.b #0xF,R12 ; Clear upper 4 bits
  rpt #8 ; Offset by 4 bits
  rla R12 ; Rotate left
  push R12 ; Save column to stack
  bic.b #BIT5,&P2OUT
  bis.b #BIT4+BIT7,&P2OUT ; 2/5/8/0 column is lo
  mov.b &P2IN,R12 ; Prepare to rotate column
  and.b #0xF,R12 ; Clear upper 4 bits
  rpt #4 ; Offset by 4 bits
  rla R12 ; Rotate left
  push R12
  bic.b #BIT4,&P2OUT
  bis.b #BIT5+BIT7,&P2OUT ; 1/4/7/astrk column is lo
  mov.b &P2IN,R12
  and.b #0xF,R12 ; Clear upper 4 bits
  add @SP+,R12
  add @SP+,R12 ; R12 now contains #9630852A741 in that order, bits 11 dt 0
  ret

;;; Precondition: R12 is in the form XXXXXXXX------------ where X is don't care
;;;               and exactly one - is high
;;; Postcondition: R12 contains the numeric value of the key returned
DECODE_INPUT:
  ;;; First check which third we are in
  inv R12
  and #0x0FFF,R12		; Mask off high-order bits

  bit #0x00F,R12
  jnz L_THIRD
  bit #0x0F0,R12
  jnz M_THIRD
  ;;; Now do a small binary search on reamaining 4 bits
H_THIRD:
  bit #0x300,R12
  jnz L_H_THIRD
H_H_THIRD:
  bit #0x400,R12
  jnz L_H_H_THIRD
H_H_H_THIRD:
  mov #-2,R12 ; # was pressed, return -2
  ret
L_H_H_THIRD:
  mov #9,R12 ; 9 was pressed
  ret
L_H_THIRD:
  bit #0x100,R12
  jnz L_L_H_THIRD
H_L_H_THIRD:
  mov #6,R12 ; 6 was pressed
  ret
L_L_H_THIRD:
  mov #3,R12 ; 3 was pressed
  ret
M_THIRD:
  bit #0x030,R12
  jnz L_M_THIRD
H_M_THIRD:
  bit #0x040,R12
  jnz L_H_M_THIRD
H_H_M_THIRD:
  clr R12 ; 0 was pressed
  ret
L_H_M_THIRD:
  mov #8,R12 ; 8 was pressed
  ret
L_M_THIRD:
  bit #0x010,R12
  jnz L_L_M_THIRD
H_L_M_THIRD:
  mov #5,R12 ; 5 was pressed
  ret
L_L_M_THIRD:
  mov #2,R12 ; 2 was pressed
  ret
L_THIRD:
  bit #0x003,R12
  jnz L_L_THIRD
H_L_THIRD:
  bit #0x004,R12
  jnz L_H_L_THIRD
H_H_L_THIRD:
  mov #-1,R12 ; Asterisk was pressed, return -1
  ret
L_H_L_THIRD:
  mov #7,R12 ; 7 was pressed
  ret
L_L_THIRD:
  bit #0x001,R12
  jnz L_L_L_THIRD
H_L_L_THIRD:
  mov #4,R12 ; 4 was pressed
  ret
L_L_L_THIRD:
  mov #1,R12 ; 1 was pressed
  ret

;;; TA1 ISR
DELAY_TIMER_ISR:
  bic #MC__UP,&TA1CTL ; Turn off timer
  bic #LPM3,0(SP) ; Exit low power mode
  reti

  .sect  TIMER1_A0_VECTOR
  .short DELAY_TIMER_ISR
