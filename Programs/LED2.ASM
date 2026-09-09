; Recreation of LED2 demo from early HUG
;
; Assembled with A85 for H8 Mini
;
; G. Roberts	September 2026
;

.ALEDS	EQU	200BH		; ABUSS LEDs
.MFLAG	EQU	2008H		; User Option Byte
UO.DDU	EQU	00000010B	; Disable Display Update
.TICCNT EQU	201BH		; Clock Tick Counter

	ORG	2040H
;
; Here's the classic LED2 demo code ...
;
LED2	MVI	C,1		; C stores pattern byte for LEDs
	LXI	H,.TICCNT	; Low byte of tick counter
;
;
LOOP1	MOV	A,M
	ANI	32H
	CPI	32H
	JNZ	LOOP1
;
;	Now prepare to display the patterns. Disable normal
;	LED updates but leave LEDs lit
;
	LXI	H,.MFLAG
	MVI	M,UO.DDU	; Disable ROM LED updates
;
;	Memory pointer (HL) points to LED locations. Update
;	all 9 of them.
;
	LXI	H,.ALEDS
	DCR	C		; Go to next pattern mask
;
;	Store the pattern in all 9 LED locations
;
	MVI	B,9
LOOP2	MOV	M,C		; C into the LED patterns
	INX	H
	DCR	B
	JNZ	LOOP2
;

;	
	LXI	H,.TICCNT	; Low byte of tick counter
LOOP3	MOV	A,M
	ANI	32H
	CPI	32H
	JZ	LOOP3

	JMP	LOOP1

	END	LED2
