; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;
;	Test the new RCK function in minipam8
;
;
;	GFR	9/14/2026
;


;
;	Monitor entry points and key values
;
DLY	EQU	0053H		; 2ms delay routine

PRTHEX	EQU	04C5H		; print byte in A in hex
PRTSPC	EQU	04D9H		; print a space
PRTCLS	EQU	04E8H		; print CR/LF then string
PRTSTR	EQU	04EBH		; print string
CRLF	EQU	04DEH		; print CR/LF

RCK	EQU	0644H		; RCK (in minipam8)
HORN	EQU	0276H		; HORN (in minipam8)

	ORG	2040h		; ORG at 040.100
	
START:	CALL	CRLF		; start on a new line
;
;	Assumes PPI has been initialized by the ROM
;
;
;	Loop calling RCK and printing result
;
LOOP:	CALL	RCK		; read console keypad (blocking read)

	PUSH	PSW
	MVI	A,20		; 20 ms beep
	CALL	HORN
	POP	PSW
	
	CALL	PRTHEX		; print the value
	CALL	CRLF		; new line
	
	JMP	LOOP		; and loop forever...


	END	START
