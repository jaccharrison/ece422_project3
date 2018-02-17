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

	.def RESET	; Make program entry point known to linker
	.def OUTPUT_BITS

  .ref CLR_LCD	; Clears the LCD by writing spaces
	.ref initClocks ; Configures LFXT
	.ref myLCD_init	; Prepare LCD to receive commands
	.ref myLCD_showChar	; C function that prints a char on the LCD
	.ref myLCD_showSymbol ; C function used to put a decimal point on LCD
	.ref GET_KEY ; Returns the struck key
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
	call #initClocks	; Initializes LFXT
	;call #myLCD_init	; Prepare LCD to receive commands
;;; Begin the main loop --------------------------------------------------------
	;; Display instructions?

  ;; Take in numbers until * is hit
  nop
  bis #LPM3+GIE,SR ; Enter low power mode 3 until a key is struck
  nop
  call #GET_KEY ; Pressed key will be in R12 ; R12 gets clobbered
  bic.b #OUTPUT_BITS,&P2OUT
  mov.b #INPUT_BITS,&P2IE ; Re-enable interrupts for 3 input pins

DEBUG_LOOP:
  jmp DEBUG_LOOP

;;; THIS CODE IS FOR REFERENCE ONLY!  NEEDS TO BE DELETED LATER!!!
*DEBOUNCE:
*	bic.b #INPUT_BITS,&P2IE	   ; Disable button interrupts
*	bis #TASSEL_1+MC_1,&TA3CTL	   ; Start TA3
*	bis.b #CCIE,&TA3CCTL0		   ; Enable interrupt
*	ret
*DEBOUNCE_ISR:
*	mov #MC_0,&TA3CTL
*	cmp #2,STATE
*	jz NO_SUBMIT_IE
*	bis.b #INPUT_BITS,&P2IE	; Re-enable all interrupts
*NO_SUBMIT_IE:
*	bis.b #BIT1+BIT3,&P2IE		; En. up/dwn, but not submit
*
*	clr &P2IV
*	clr &P2IFG
*	reti

;;;-----------------------------------------------------------------------------
;;; Interrupt Service Routines
;;;-----------------------------------------------------------------------------
KEY_PRESS_ISR:
  clr.b &P2IE ; Disable interrupts until key is recorded
  clr.b &P2IV ; Clear further pending interrupts
  clr.b &P2IFG
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
