;;; ----------------------------------------------------------------------------
;;; ECE 422 Project 3
;;; Jacob Harrison, Benjamin Levandowski
;;; 2018/02/22
;;; ----------------------------------------------------------------------------
;;; main.asm:
;;; ----------------------------------------------------------------------------
	.cdecls C,LIST,"msp430.h","myLCD.h" ; Include device header file
;;; Symbolic constants ---------------------------------------------------------
SCROLL_PAUSE: .equ 1024  ; Clock cycles to pause when scrolling text
INPUT_BITS:  .equ BIT0+BIT1+BIT2+BIT3
OUTPUT_BITS: .equ BIT4+BIT5+BIT7
BCD_VALS:    .equ R5
STATE:       .equ R7       ; Tracks whether we are currently testing

	.def RESET	; Make program entry point known to linker
	.def OUTPUT_BITS

  .ref CLR_LCD	; Clears the LCD by writing spaces
	.ref initClocks ; Configures LFXT
	.ref myLCD_init	; Prepare LCD to receive commands
	.ref myLCD_showChar	; C function that prints a char on the LCD
	.ref myLCD_showSymbol ; C function used to put a decimal point on LCD
	.ref GET_KEY ; Returns the struck key
  .ref PRINT
  .ref DIV_WORDS
  .ref DIV_DWORDS
  .ref SCROLL_TXT
;;; ----------------------------------------------------------------------------
	.data
inst: .cstring "ENTER FREQ LESS THAN 999HZ"
;;; ----------------------------------------------------------------------------
;;; .bss
;;; ----------------------------------------------------------------------------
	.text	      ; Assemble into program memory.
	.retain	      ; Override ELF conditional linking
	.retainrefs   ; Retain sections that reference current section
;;; ----------------------------------------------------------------------------
RESET:
	mov #__STACK_END,SP	; Initialize stackpointer
	mov #WDTPW|WDTHOLD,&WDTCTL	; Stop watchdog timer
;;; Reset global variables------------------------------------------------------
  clr STATE
;;; Configure I/O --------------------------------------------------------------
	bic #LOCKLPM5,&PM5CTL0	; Unlock GPIO pins
	mov.b #OUTPUT_BITS,&P2DIR ; 2.0-2.3 are inputs, 2.4,2.5,2.7 are outputs
	mov.b #INPUT_BITS,&P2OUT ; Outputs are lo, resistors are pull up
	mov.b #INPUT_BITS,&P2REN; inputs use pull down resistors

	;; Set button interrupt mode
	mov.b #INPUT_BITS,&P2IES ; Trigger interrupt on ? transition
	mov.b #INPUT_BITS,&P2IE ; Enable interrupts for 3 input pins
	clr &P2IFG ; Clear pending port 2 interrupts

	;; Configure 1.0 for TA0's output unit QW
	bis.b #BIT0,&P1DIR
	bis.b #BIT0,&P1SEL0
;;; Configure Timers -----------------------------------------------------------
	;; Timer A0 - used to blink Red LED on P1.0
	mov #TASSEL__SMCLK+MC__UP,&TA0CTL
	;; Timer A1 - used for button polling delay
	mov #TASSEL__ACLK,&TA1CTL ; Use ACLK
	mov #4095,&TA1CCR0 ; Fires every 1/8 sec ish
	mov #CCIE,&TA1CCTL0 ; Enable timer interrupts
	;; Timer A2 - controls rate of scrolling messages
  mov #SCROLL_PAUSE,&TA2CCR0 ; Count to SCROLL_PAUSE before scrolling txt
  mov #TASSEL_1+MC_1+ID_3,&TA2CTL ; Source ACLK, up mode, divide clk by 8
;;; Prepare the LCD to receive commands ----------------------------------------
  call #myLCD_init  ; Prepare LCD to receive commands
	;; Begin custom LCD changes
	bic #LCDON,&LCDCCTL0 ; Turn off LCD
	bic #LCDS40+LCDS42+LCDS43,LCDCPCTL2 ; Undo pin muxing for P2.4/5/7
  bis #LCDON,&LCDCCTL0 ; Turn on LCD
;;; Print instructions - exits if a button is pressed while printing -----------
  mov #inst,R12   ; Move instruction into function argument
  call #SCROLL_TXT  ; Scroll instruction across LCD
  call #CLR_LCD
;;; Begin main loop
LED_OFF:
  bic #OUTMOD_7,&TA0CCTL1
GET_FREQ:
  clr BCD_VALS
  push #-1 ; Need to know when done
NEXT_DIGIT:
  ;; Take in numbers until * is hit
  clr.b &P2IFG
  bic.b #OUTPUT_BITS,&P2OUT
  mov.b #INPUT_BITS,&P2IE ; Re-enable interrupts for 3 input pins
  nop
  bis #LPM3+GIE,SR ; Enter low power mode 3 until a key is struck
  nop
  call #GET_KEY ; Pressed key will be in R12 ; R12 gets clobbered
  tst R12 ; Did we hit either enter key?
  jn CALC_FREQ ; Process new freqency
  push R12 ; Save keystroke
  rpt #4
  rla BCD_VALS ; Make room for new digit
  add R12,BCD_VALS ; Add in new digit
  and #0xFFF,BCD_VALS ; Store only 3 digits
  push R12
  call #PRINT
  pop R12
  bic.b #OUTPUT_BITS,&P2OUT
  jmp NEXT_DIGIT ; Read in another digit

CALC_FREQ:
  ;; First test if we're asked to do 0
  ;tst BCD_VALS
  ;jz NEXT_DIGIT ; Don't accept input; ask for another digit

  pop R12 ; Get last digit pressed
  tst R12
  jn GET_FREQ
;;; Don't need to scale one's digit
FREQ_ONES:
  pop R13 ; Check for another digit
  tst R13 ; Exit if read -1
  jn SET_FREQ
;;; Scale by 10x, then add to R12
FREQ_TENS:
  mov R13,&MPY ; Load first opperand
  mov #10,&OP2 ; Load second opperand
  nop ; Wait for result to process
  nop
  nop
  add &RESLO,R12 ; Add result to R12
  pop R13 ; Check for another digit
  tst R13 ; Exit if read -1
  jn SET_FREQ
FREQ_HUNDS:
  mov R13,&MPY ; Load first opperand
  mov #100,&OP2 ; Load second opperand
  nop ; Wait for result to process
  nop
  nop
  add &RESLO,R12 ; Add result to R12
CLR_STK:
  pop R13 ; Check for another digit
  tst R13 ; Exit if read -1
  jge CLR_STK
SET_FREQ:
  tst R12 ; Check selcted frequency
  jz LED_OFF ; Turn off LED if 0 is selected
  bis #OUTMOD_7,&TA0CCTL1 ; Use output unit if freq = 0
  cmp #16,R12 ; Low frequency?
  jn LOW_FREQ ; Need to divide clock by 16 if this is the case
HIGH_FREQ:
  bic #ID__8,&TA0CTL ; Need not divide by anything
  bic #TAIDEX_1,&TA0EX0 ; So change (back) to /1
  bis #TACLR,&TA0CTL ; Reset timer count
  mov R12,R15 ; Prepare for division
  clr R14
  mov #0x4240,R13 ; Take 1 000 000 / selected frequency
  mov #0xF,R12
  call #DIV_DWORDS
  mov R13,&TA0CCR0  ; Set frequency by storing result in TA0CCR0
  clrc
  rrc R13
  mov R13,&TA0CCR1 ; 50% Duty
  jmp GET_FREQ
LOW_FREQ:
  bis #ID__8,&TA0CTL ; Need to divide by 16
  bis #TAIDEX_1,&TA0EX0 ; To handle lowest frequencies
  bis #TACLR,&TA0CTL ; Reset timer count
  mov R12,R15 ; Prepare for division
  clr R14
  mov #0xF424,R13 ; Take 1 000 000 / selected frequency
  clr R12
  call #DIV_DWORDS
  mov R13,&TA0CCR0  ; Set frequency by storing result in TA0CCR0
  clrc
  rrc R13
  mov R13,&TA0CCR1 ; 50% Duty
  jmp GET_FREQ

DEBUG_LOOP:
  jmp DEBUG_LOOP

;;;-----------------------------------------------------------------------------
;;; Interrupt Service Routines
;;;-----------------------------------------------------------------------------
KEY_PRESS_ISR:
  mov #1,STATE
  clr.b &P2IE ; Disable interrupts until key is recorded
  clr.b &P2IFG ; Clear further pending interrupts
  bic #LPM3,0(SP) ; Exit low power mode
  reti

  .global __STACK_END
  .sect   .stack
;;;-----------------------------------------------------------------------------
;;; Interrupt Vectors
;;;-----------------------------------------------------------------------------
  .sect  PORT2_VECTOR
  .short KEY_PRESS_ISR
	.sect  RESET_VECTOR
	.short RESET
