;
;	Classic LED1 demo, adapted for H8 Mini
;
;	Uses A85 Assembler
;
;	Glenn Roberts	8 September 2026
;

FPLEDS	EQU	200BH
MFLAG	EQU	2008H

DLY	EQU	0053H

CTLPORT	EQU	360Q

;
;	Org at 40K but we will store in ROM at 2000H
;
	ORG	02040H
;
; Here's the classic LED demo code ...
;
DEMO:	MVI	A,00000010B	; Disable LED updates
	STA	MFLAG

BEGIN:	MVI	B,0		; Initial pattern

MLOOP:	LXI	H,FPLEDS	; Point to LED refresh RAM
	MVI	C,9		; 9 LEDs to refresh

	MOV	A,B		; Grab current pattern
;
;	copy the same pattern to all 9 LED positions
;
LLOOP:	MOV	M,A		; Store in LED position
	INX	H		; Point to next LED position
	DCR	C		; Count down
	JNZ	LLOOP
;
;	Delay a bit...
;
	MVI	C,1		; Call .DLY once
DLOOP:	MVI	A,50
	CALL	DLY		; delay...
	DCR	C		; Count down
	JNZ	DLOOP

	DCR	B		; Change the pattern
	JNZ	MLOOP		; Loop through all patterns
;
;	Have cycled through all 255 patterns, now repeat
;
	JMP	BEGIN		; Now start over!

	END	DEMO
