	.cdecls C,LIST,"msp430fr6989.h"       ; Device header file

  .def DIV_WORDS
	.def DIV_DWORDS

	.text

;;; Used http://www.tofla.iconbar.com/tofla/arm/arm02/index.htm as reference
;;; Precondition: Dividend in R12 and Divisor in R13
;;; Postcondition: Quotient in R12, remainder in R13
DIV_WORDS:
  pushm #2,R15      ; Make space
  mov R13,R14     ; Move operands
  mov R12,R13
  clr R12
  mov #1,R15
SBSETUP:
  rla R15     ; Increase divisor
  rla R14
  cmp R13,R14   ; Repeant until dvsr > dvdnd
  jnc SBSETUP
SRTSB:
  cmp R14,R13   ; Add bit to quo if can subtract
  jnc NOSB
DIVSB:
  sub R14,R13   ; Subtract from dividend
  add R15,R12    ; Add bit to quotient
NOSB:
  rra R14
  rra R15
  jnc SRTSB
  popm #2,R15   ; Restore registers
  ret


;;; Used http://www.tofla.iconbar.com/tofla/arm/arm02/index.htm as reference
;;; Precondition: Dividend in R12/R13 and Divisor in R14/R15 (big-endian, sorry)
;;; Postcondition: Quotient in R12/13, remainder in R14/15 (both big-endian)
DIV_DWORDS:
	pushm #4,R11			; Make space
	mov R12,R10			; Move operands
	mov R13,R11
	mov R14,R12
	mov R15,R13
	clr R8				; Clear where quotient goes
	clr R9
	clr R14
	mov #1,R15
SUBSETUP:
	rla R15			; Increase divisor
	rlc		R14
	rla		R13
	rlc		R12
	cmp R10,R12		; Repeant until dvsr > dvdnd
	jnc SUBSETUP
	jnz SRTSUB
	cmp R11,R13
	jnc SUBSETUP
SRTSUB:
	cmp R12,R10		; Add bit to quo if can subtract
	jnc NOSUB
	jnz DIVSUB
	cmp R13,R11
	jnc NOSUB
DIVSUB:
	sub R13,R11		; Subtract from dividend
	subc R12,R10
	add R15,R9		; Add bit to quotient
	addc R14,R8
NOSUB:
	rra R12		; Down shift dividend
	rrc R13
	rra R14		; Down shift placeholder bit
	rrc R15
	jnc SRTSUB
	mov R8,R12		; Move results
	mov R9,R13
	mov R10,R14
	mov R11,R15
	popm #4,R11		; Restore registers
	ret
