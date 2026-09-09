; TESTLEDS
;
; Simple program to light up all the LED segments. press
; any keypad key to exit
;
; Assembled with A85 for H8 Mini
;
; G. Roberts	September 2026
;

FPLEDS	EQU	200BH		; LED pattern storage location
MFLAG	EQU	2008H		; Front panel update flags

	ORG	2040H


TEST:	MVI	A,00000010B	; LED refresh only (no data update)
	STA	MFLAG

	MVI	A,377Q		; all segments lit
;
;	copy pattern into all 9 locations
;
	LXI	H,FPLEDS	; Point to LED refresh RAM
	MVI	C,9		; 9 LEDs to refresh
LOOP:	MOV	M,A		; Store in LED position
	INX	H		; Point to next LED position
	DCR	C		; Count down
	JNZ	LOOP
;
;	loop forever (RST/0 to restart)
;
WAIT:	JMP	WAIT

	END	TEST
