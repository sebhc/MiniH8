; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;
;	This program demonstrates a replacement for
;	the PAM-8 Read Console Keypad (RCK) routine.
;	This version is designed to work with the
;	Mini H8. The RCK routine will replace
;	the PAM-8 one in the new ROM.
;
;	GFR	8/17/2026
;

;	8255 PPI at 0F0-0F3

PPI	EQU	0F0h
IOA	EQU	0
IOB	EQU	1
IOC	EQU	2
CTRL	EQU	3

KNUM	EQU	00010000b	; PC4
KMATH	EQU	00100000b	; PC5
KR	EQU	01000000b	; PC6
K0	EQU	10000000b	; PC7

;
;	Monitor entry points
;
PRTHEX	EQU	01CAh		; print byte in A in hex
PRTSPC	EQU	01DEh		; print a space
PRTCLS	EQU	01EDh		; print CR/LF then string
PRTSTR	EQU	01F0h		; print string

	ORG	2040h		; ORG at 040.100
;
;	set up 8255 PPI
;
START:	MVI	A,10001000b	; all bits OUT except PC4..PC7
	OUT	PPI+CTRL
;
;	Loop calling RCK and printing result
;
LOOP:	CALL	RCK		; read console keypad (blocking read)
;	CALL	PRTHEX		; print the value
;	CALL	PRTSPC		; and a separator
;	CALL	DELAY		; delay (debounce)
	CALL	FLASH		; flash the MON LED
	JMP	LOOP		; and loop forever...

;
;	Flash the MON LED(PA5) on and then off
;
FLASH:	IN	PPI+IOA		; read port A status byte
	ORI	00100000b	; PA5 ON
	OUT	PPI+IOA
	CALL	DELAY		; wait a bit
	ANI	11011111b	; PA5 OFF
	OUT	PPI+IOA
	RET
	
;
;	simple delay (double-nested counter loop)
;
DELAY:	PUSH	PSW
	PUSH	B
	
	MVI	A,010h
	MOV	B,A
PT1:	DCR	A
PT2:	DCR	B
	JNZ	PT2
	CPI	0
	JNZ	PT1
	
	POP	B
	POP	PSW
	RET
;
;       RCK - Read Console Keypad
;
;       RCK is called to read a keystroke from the console keypad.
;       Whenever a key is accepted.
;
;       bugs: add debouncing, auto-repeat, and a *bip* sound
;       when a value is accepted.
;
;       Entry:	None
;       Exit:	to caller when a key is hit:
;
;               (A) = 0 - '0'
;                     1 - '1'
;                     2 - '2'
;                     3 - '3'
;                     4 - '4'
;                     5 - '5'
;                     6 - '6'
;                     7 - '7'
;                     8 - '8'
;                     9 - '9'
;                    10 - '+'
;                    11 - '-'
;                    12 - '*'
;                    13 - '/'
;                    14 - '#'
;                    15 - '.'
;
RCK:	IN	PPI+IOC		; read PC inputs on PPI
	MOV	B,A		; save it
	ANI	KR		; check for '/' key
	MVI	A,13		; prepare for yes
	JNZ	RCKX		; "high" = key pressed
	
	MOV	A,B		; restore input value
	ANI	K0		; check for '0' key
	MVI	A,0		; prepare for yes
	JNZ	RCKX		; "high" = key pressed
;
;	Now poll the "math" keys
;
	IN	PPI+IOA		; read port A status byte
	ANI	11110000b	; clear PA0..PA3 bits
	MOV	B,A		; save it
	
	MVI	C,5		; loop 5 times
RCK1:	ORA	C		; set PA bits
	OUT	PPI+IOA		; select PA bits
	IN	PPI+IOC		; read keys ("low" = key pressed)
	CMA			; now "high" = key pressed
	ANI	KMATH		; test bit
	JNZ	RCKL		; found a key!
	MOV	A,B		; get back value
	DCR	C		; count down
	JNZ	RCK1		; and loop ...
;
;	Now poll the "numeric" keys (should be a subroutine!)
;
	MVI	C,9		; 9 digits ('0' done already)
RCK2:	ORA	C		; set PA bits
	OUT	PPI+IOA		; select PA bits
	IN	PPI+IOC		; read keys ("low" = key pressed)
	CMA			; now "high" = key pressed
	ANI	KNUM		; test bit
	JNZ	RCKM		; found a key!
	MOV	A,B		; get back value
	DCR	C		; count down
	JNZ	RCK2
;
;	Have now tested all cases. if execution falls through
;	there was no key pressed... keep scanning...
;
	JMP	RCK
	
;
;	Come here if found "math" key match
;
RCKL:	DCR	C		; make zero-based
	MVI	B,0		; (BC) = offset
	LXI	H,RCKTBL	; (HL) = lookup table
	DAD	B		; look up value
	MOV	A,M		; grab it
	JMP	RCKX		; and done!
;
;	Lookup for KMATH scan
;	
RCKTBL:	DB	15		; 1 = '.'
	DB	12		; 2 = '*'
	DB	11		; 3 = '-'
	DB	10		; 4 = '+'
	DB	14		; 5 = '#'
;
;	Come here if found "num" key match
;
RCKM:	MOV	A,C		; simply return the iteration number
;
;	Come here with A containing the value that was read.
;
RCKX:	RET

	
	END	START
