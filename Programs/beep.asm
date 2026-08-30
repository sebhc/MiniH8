; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;
;	Sample program to make a sound on the MiniH8 speaker
;
;	GFR	8/29/2026
;

;	8255 PPI at 0F0-0F3

PPI	EQU	0F0h
IOA	EQU	0
CTRL	EQU	3

DLY	EQU	53H		; delay program in ROM

	ORG	2040H
;
;	Assumes PPI control port is already set up by ROM Monitor
;
BEEP:	IN	PPI+IOA		; Read Port A settings
	ANI	00111111B	; Clear top two bits (PA6-7)
	ORI	10000000B	; PA7 on; PA6 off

LOOP:	OUT	PPI+IOA		; send to speaker
	MVI	A,1		; wait a small amount
	CALL	DLY
	
	IN	PPI+IOA		; read it again
	XRI	11000000B	; alternate top 2 bits
	JMP	LOOP		; and loop
	
	END	BEEP
	
