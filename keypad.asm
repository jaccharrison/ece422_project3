  .cdecls C,LIST,"msp430.h"	; Device header file
;;; Symbolic constants ---------------------------------------------------------
VALUE:	.equ R4		; R4 holds numeric value entered by users
BCD_VALS:	.equ R5	; R5 holds BCD numbers entered by user
DIV16:	.equ R6		; R6 is a flag set when users enter freq < 16Hz

  .def GET_KEY

  .ref OUTPUT_BITS

  .text

GET_KEY:
	;; Take initial scan
	push R13      ; Push contents of R13 to create a free register
	call #SCAN    ; Get input into R12

BUTTON_INPUT_LOOP:
	mov R12,R13		; Create working copy of input in R13
	bis #MC__UP+TACLR,&TA1CTL ; Start delay timer
	nop
	bis #LPM3+GIE,SR	; Enter low power mode
	nop
	;; Take another scan for comparison against the first one
	call #SCAN		; Get new input into R12
	cmp #0x0FFF,R12	; If all are high, not buttons are pressed
	jnz BUTTON_INPUT_LOOP	; If not zero, check our input again
	mov R13,R12		; Take last non-zero input
	pop R13		; Restore R13
	call #DECODE_INPUT      ; Decodes 12 input bits into a numeric value
	ret

;;; Get input
SCAN:
	;; Set 3, 6, 9, # column lo
	bic.b #BIT7,&P2OUT
	bis.b #BIT4+BIT5,&P2OUT
	;; Store row inputs when 369# column is low
	mov.b &P2IN,R12	; Create working copy of P2IN in R12
	and.b #0xF,R12		; We only care about P2.0-P2.3
	rpt #8			; Move inputs into bits 8-11 of R12
	rla R12
	push R12		; Save inputs from 369# column on stack

	;; Set 2, 5, 8, 0 column lo
	bic.b #BIT5,&P2OUT
	bis.b #BIT4+BIT7,&P2OUT
	;; Store row inputs when 2580 column is low
	mov.b &P2IN,R12	; Create working copy of P2IN in R12
	and.b #0xF,R12		; Clear all but low four bits
	rpt #4			; Move inputs into bits 4-7 of R12
	rla R12
	push R12		; Push inputs from 2580 column on stack

	;; Set 1, 4, 7, * column lo
	bic.b #BIT4,&P2OUT
	bis.b #BIT5+BIT7,&P2OUT ; 1/4/7/astrk column is lo
	;; Store row inputs when 147* column is low
	mov.b &P2IN,R12	; Create working copy of P2IN in R12
	and.b #0xF,R12		; Clear all but low four bits

	;; Load results of polling all three columns into R12
	add @SP+,R12		; Bits 4-7 of R12 are now from 2580 column
	add @SP+,R12		; Bits 8-11 of R12 are now from 369# column

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
