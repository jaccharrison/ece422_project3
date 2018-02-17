;;; ----------------------------------------------------------------------------
;;; ECE 422 Project 3
;;; Jacob Harrison, Benjamin Levandowski
;;; 2018/02/22
;;; ----------------------------------------------------------------------------
;;; main.asm:
;;; ----------------------------------------------------------------------------
	.cdecls C,LIST,"msp430.h","myLCD.h" ; Include device header file
;;; Symbolic constants ---------------------------------------------------------
INPUT_BITS:  .equ BIT0+BIT1+BIT2+BIT3
OUTPUT_BITS: .equ BIT4+BIT5+BIT7
BCD_VALS:    .equ R5

	.def RESET	; Make program entry point known to linker
	.def OUTPUT_BITS

  .ref CLR_LCD	; Clears the LCD by writing spaces
	.ref initClocks ; Configures LFXT
	.ref myLCD_init	; Prepare LCD to receive commands
	.ref myLCD_showChar	; C function that prints a char on the LCD
	.ref myLCD_showSymbol ; C function used to put a decimal point on LCD
	.ref GET_KEY ; Returns the struck key
    .ref PRINT
;;; ----------------------------------------------------------------------------
	.data
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
  clr BCD_VALS ; TODO: ADD OTHER REGISTERS
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
	;; TODO

	;; Sets port J to LFXT mode
	bic #BIT4+BIT5,&PJDIR
	bis #BIT4+BIT5,&PJSEL0
;;; Configure Timers -----------------------------------------------------------
	;; Timer A0 - used to blink Red LED on P1.0
	;; Timer A1 - used for button polling delay
	mov #TASSEL__ACLK,&TA1CTL ; Use ACLK
	mov #4095,&TA1CCR0 ; Fires every 1/8 sec
	mov #CCIE,&TA1CCTL0 ; Enable timer interrupts
;;; Prepare the LCD to receive commands & configure LFXT -----------------------
	;call #initClocks	; Initializes LFXT
	;call #myLCD_init	; Prepare LCD to receive commands
;;; Begin the main loop --------------------------------------------------------
	;; Display instructions?

  GET_FREQ:
  push #-1 ; Need to know when done
NEXT_DIGIT:
  ;; Take in numbers until * is hit
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
  call #PRINT
  bic.b #OUTPUT_BITS,&P2OUT
  clr.b &P2IFG
  mov.b #INPUT_BITS,&P2IE ; Re-enable interrupts for 3 input pins
  jmp NEXT_DIGIT ; Read in another digit

CALC_FREQ:
  ;; First test if we're asked to do 0
  tst BCD_VALS
  jz NEXT_DIGIT ; Don't accept input; ask for another digit

  pop R12 ; Get last digit pressed
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

DEBUG_LOOP:
  jmp DEBUG_LOOP

;;;-----------------------------------------------------------------------------
;;; Interrupt Service Routines
;;;-----------------------------------------------------------------------------
KEY_PRESS_ISR:
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
