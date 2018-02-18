;;; ----------------------------------------------------------------------------
;;; custom_lcd.asm:
;;; Custom assembly functions for the MSP430
;;; ----------------------------------------------------------------------------
	.cdecls C,LIST,"msp430.h","myLCD.h"
;;; Symbolic constant ----------------------------------------------------------
STATE:	.equ R7		; Tracks whether we are currently testing

	;; Make routine names defined in file known to linker
	.def SCROLL_TXT
	.def CLR_LCD
	.def PRINT

	.ref myLCD_showChar ; C function that displays a character on LCD
	.ref myLCD_showSymbol	; C function that displays a symbol on LCD
;;; ----------------------------------------------------------------------------
	.data
	;; Spaces to pad beginning and end of the screen for scrolling text
beg_spc: .cstring "     "	; Five spaces
end_spc: .cstring "      "	; Six spaces
;;; ----------------------------------------------------------------------------
	.bss str_w_spc, 76 ; Uninitialized memory for string with spaces
;;; ----------------------------------------------------------------------------
	.text			; Assemble into program memory
;;; ----------------------------------------------------------------------------

;;; SCROLL_TXT:
;;;
;;; Scrolls a text string located at the memory location specified by R12
;;; across the MSP430 Launchpad LCD. The rate at which the letters scroll is
;;; controlled by the value in TA2CCR0; the letters scroll in interrupts.
;;;
;;; The string whose address is stored in R12 will be copied into a new array
;;; that is padded at the front by 5 leading spaces, and at the end by 6 spaces
;;; and a null character. The spaces are used to create the 'scrolling' effect.
;;; Once the string has been copied into the new padded array, the TA3CCR0
;;; interrupt is enabled and the microcontroller is put into LPM3 (which leaves
;;; ACLK enabled) to wait for the timer interrupt to fire and cause the text to
;;; scroll across the LCD.
;;;
;;; When the ISR fires, the six letters from the address stored in R14 will be
;;; printed on the display in quick succession, and the microcontroller will be
;;; released from LPM3 to check the status of a global variable that would cause
;;; an early exit from the function. If the variable is set, the microcontroller
;;; will exit instead of printing the remainder of the text string.
;;;
;;; - The string in R12 should be 64 or fewer character in length.
;;; - The string in R12 should be null terminated (c-style)
;;;
;;; This routing uses registers R12-R15

SCROLL_TXT:
	mov.w #str_w_spc,R14	; Load address of str_w_space into R14

	mov.w R12,R13       ; Create working copy of str. addr. in R13
FIND_LEN:
	mov.b #0xFF,R15	; Move mask for finding null into R13 for speed
	bit.b @R13+,R15	; Char at R13 == '\0'?
	jnz FIND_LEN		; Char at R15 not null, test next char

	;; Test to ensure length of string <= 64
	sub.w R12,R13		; Find difference between addresses
	cmp.w #0x40,R13	; Difference >= 64?
	jn CP_FRONT_SPC	; If negative, len(string) <= 64
	ret			; Else, string is too long, return.

;;; Load address of beg_spc into R13 and pad front of new memory w/ spaces
CP_FRONT_SPC:
	mov.w #beg_spc,R13	; Load address of beg_spc into R13
	xor.w R15,R15		; Clear R13, which will be used in jump table
	jmp CP

;;; Load address of supplied string into R13 and copy string into new memory
CP_STR:
	mov.w R12,R13		; Copy address of user supplied string to R13
	jmp CP

;;; Load address of end_spc into R13 and pad end of new memory w/ spaces
CP_END_SPC:
	mov.w #end_spc,R13	; Load address of end_spc into R13

;;; Copy the null-terminated string beginning at R13 into memory at R14
CP:
	mov.b @R13+,0(R14)	; Copy char into str_w_spc
	add #0x01,R14		; Prepare str_w_spc to receive next copied char
	tst.b 0(R13)		; Character at R13 null? (End of str?)
	jnz CP			; Not null, copy next space

	add.b #0x02,R15	; Set next jmp point
	add.w R15,PC		; Add jmp offset to PC
	nop
	jmp CP_STR
	jmp CP_END_SPC
	mov.b #0,0(R14)	; Copy null char to end of completed string
	mov #str_w_spc,R14	; Set R14 to point to beginnign of str_w_spc
	bis #CCIE,&TA2CCTL0	; Enable TA2CCR0 interrupt to advance scrolling

SCROLL:
	nop
	bis #GIE+LPM3,SR ; Enter LPM3 - wait for interrupt
	nop
	mov.b STATE,R15   ; Move early exit flag to a register for testing
	tst.b R15		; Check whether user has 'skipped' instructions
	jnz RET_SCROLL		; If early_exit set, return

	add.w #0x01,R14	; Set R14 to point to next char
	tst.b 5(R14)            ; Check for end of printable string
	jnz SCROLL		; If 5(R14) was not null, repeat

	;; Null character reached - scrolling complete, return to caller
RET_SCROLL:
	bic #CCIE,&TA2CCTL0	; Disable TA2CCR0 interrupt
	ret			; Return control to caller

;;; TA2 Interrupt that scrolls the message across the screen
ADV_SCROLL:
	mov.b #5,R13		; Address offset from R14 of 1st char to print
PRINT_CHAR:
	tst.b R13		; If R13 is zero, we've printed 6 chars - exit
	jn ADV_SCROLL_EXIT

	;; Get char to display into R12
	mov.w R14,R12		; Move address of string to print into R12
	add.w R13,R12		; Factor in address offset from R13
	mov.b 0(R12),R12	; Load character pointed to by R12 into R12
	add.b #0x01,R13	; Convert R13 from addr. offset to LCD posn.

	;; Push current offset and char addr. to stack so they don't get lost
	;; during C function call
	push.w R14              ; Current character address
	push.b R13              ; Current offset

	;; Char to display is in now in R12, LCD position is in R13.
	;; Call C function 'myLCD_showChar(R12,R13)'
	call #myLCD_showChar

	;; Pop offset and char address back off of stack
	pop.b R13               ; Recover current offset
	pop R14                 ; Recover character address

	sub.b #0x02,R13	; (LCD offset)-2 to get next addr. offset
	jmp PRINT_CHAR		; Print next character

ADV_SCROLL_EXIT:
	nop
	bic #LPM3,0(SP) ; Leave LPM3
	nop
	reti

;;; CLR_LCD:
;;;
;;; Clears the six main positions on the LCD by writing a ' ' to each.
CLR_LCD:
	mov #0x20,R12		; Move a space char into 1st funct arg
	mov #0x06,R13		; Move LCD posn into 2nd funct arg
CLR_LOOP:
	tst R13		; LCD posn  == 0?
	jz CLR_EXIT		; If zero, we're done - exit routine
	pushm #2,R13
	call #myLCD_showChar	; Display char ' ' at location in R13
	popm #2,R13
	dec R13
	jmp CLR_LOOP		; Write ' ' to LCD until cleared
CLR_EXIT:
	ret

;;; PRINT:
;;;
;;; Displays the binary coded decimals in the 12 LSB of R5 in LCD positions
;;; 4, 5, and 6. The 4 digits in bits 11 downto 8, 7 downto 4, and 3 downto 0
;;; correspond to the numbers displayed in LCD position 4, 5, and 6 respectively
;;;
;;; If one of the BCD is zero, the LCD will display a space character instead so
;;; that it prints '  1' instead of '001'
PRINT:
	;; Print 'F:' at the beginning of the LCD
	mov #0x46,R12		; Move 'F' into 1st function arg
	mov #0x02,R13		; Print 'F' in LCD posn 2
	call #myLCD_showChar
	mov #LCD_UPDATE,R12	; Move memory op for LCD into function arg 1
	mov #LCD_A2COL,R13	; Move posn 2 colon into function arg 2
	clr R14		; Specify main memory register as funct arg 3
	call #myLCD_showSymbol	; Print colon at position 2

	;; Print BCD numbers in posns 4, 5, and 6
	mov R5,R12		; Create working copy of R5 in R12
	and #0x000F,R12	; Mask off all but lowest 4 bits of R12
	add #0x30,R12		; Convert to char representation of number
	mov #0x06,R13		; Specify LCD posn 6
	call #myLCD_showChar

	mov R5,R12		; Create working copy of R5 in R12
	and #0x00F0,R12	; Mask off all but bits 4-7 of R12
	rpt #0x04		; Repeat next instruction 4 times
	rra R12		; Shift into lowest nibble
	add #0x30,R12		; Convert to char representation of number
	mov #0x05,R13		; Specify LCD posn 5
	call #myLCD_showChar

	mov R5,R14		; Create working copy of R5 in R14
	and #0x0F00,R14	; Mask off all but bits 8-11 of R14
	mov #0x20,R12		; Pre-emptively move space into R12
	tst R14		; R14 == 0?
	jz PRINT_N2		; If zero, print space in hundreds digit
	mov R14,R12		; Not zero, need to print digit, move to R12
	rpt #0x08		; Repeat next instruction 8 times
	rra R12		; Shift into lowest nibble
	add #0x30,R12		; Convert to char representation of number
PRINT_N2:
...	mov #0x04,R13		; Specify LCD posn 4
	call #myLCD_showChar

	ret

;;; Interrupt vector definitions
	.sect TIMER2_A0_VECTOR
	.short ADV_SCROLL
