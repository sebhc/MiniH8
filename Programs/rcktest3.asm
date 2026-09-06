; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;
;	This program demonstrates a replacement for
;	the PAM-8 Read Console Keypad (RCK) routine.
;	This version is designed to work with the
;	H8 Mini. The RCK routine will replace
;	the PAM-8 one in the new ROM.
;
;
;	GFR	9/1/2026
;

;	8255 PPI at 0F0-0F3

PPI	EQU	0F0h
IO.A	EQU	0
;
;	Debounce and auto-repeat delays (ms)
;
DBDLY	EQU	20
ARDLY	EQU	400

;
;	Monitor entry points and key values
;
DLY	EQU	0053H		; 2ms delay routine

PRTHEX	EQU	04B3H		; print byte in A in hex
PRTSPC	EQU	04C7H		; print a space
PRTCLS	EQU	04D6H		; print CR/LF then string
PRTSTR	EQU	04D9H		; print string
KEYVAL	EQU	2034H		; temp storage for key value
RCKA	EQU	2016H		; key passing byte

	ORG	2040h		; ORG at 040.100
;
;	Assumes PPI has been initialized by the ROM
;
;
;	Loop calling RCK and printing result
;
LOOP:	CALL	RCK		; read console keypad (blocking read)

;
;	debounce
;
	CALL	PRTHEX		; print the value
	CALL	PRTSPC		; and a separator
	
	JMP	LOOP		; and loop forever...

;
;       RCK - Read Console Keypad
;
;
RCK:	PUSH	H
	PUSH	B
	
	MVI	C,ARDLY/DBDLY
	LXI	H,RCKA		; point to keypad byte
;
;	First wait for some keyboard action
;
RCK1:	LDA	KEYVAL		; get most recent key hit
	MOV	B,A		; save it
	MVI	A,DBDLY/2	; delay to debounce
	CALL	DLY
	MOV	A,B		; get back candidate
	
	CMP	M		; compare to RCKA
	JNZ	RCK2		; have a change
	DCR	C		; wait N cycles (auto repeat)
	JNZ	RCK1		; changed, start over

RCK2:	MOV	M,A
	ORA	A		; set flag bits
	JM	RCK1		; bit 7 set... no key pressed
;
;	have a key (make a sound here)
;	
;
;	Make noise here...
;
	ANI	17Q		; make sure it's 4 bits
	
	POP	B
	POP	H
	RET
;
;	simple version (for testing. no debounce)
;
RK:	LXI	H,RCKA
RK1:	MOV	A,M		; fetch possible key value
	ORA	A		; set flags
	JM	RK1		; loop 'til not negative
	RET

	END	LOOP
