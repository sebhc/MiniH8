; Recreation of LED3 demo from early HUG
;
; Assembled with A85 for the H8 Mini
;
; G. Roberts September 2026
;

.ALEDS	EQU	200BH		; ABUSS LEDs
.MFLAG	EQU	2008H		; User Option Byte
UO.DDU	EQU	00000010B	; Disable Display Update
.TICCNT	EQU	201BH		; Clock Tick Counter

	ORG	2040H
;
; Here's the classic LED3 demo code ...
;
LED3:	MVI	C,1		; C stores pattern byte for LEDs
WAIT4:	LXI	H,.TICCNT+1	; High byte of tick counter
;
;	Watch the clock and wait for it to be a multiple of 4
;	(bit 3 of the high byte on). As long as it is set
;	just continue to loop here. During this time the 
;	LED patterns will not be updated.
;
LOOP:	MOV	A,M
	ANI	4
	CPI	4
	JNZ	LOOP
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
	MVI	B,9
DISP:	DCR	C		; Move successive values of
	MOV	M,C		; C into the LED patterns
	INX	H
	DCR	B
	JNZ	DISP
;
;	Watch the clock and wait for it to be a multiple of 2
;	(bit 2 of the high byte on). As long as it is set
;	just continue to loop here. During this time the 
;	LED patterns will not be updated.
;	
WAIT2:	LXI	H,.TICCNT+1	; High byte of tick counter
LOOP2:	MOV	A,M
	ANI	2
	CPI	2
	JZ	LOOP2
;
;	Note: when neither bits 2 nor 3 are set in the high byte
;	of the tick counter the program will cycle through this
;	outer loop, updating the 9 LEDs on each loop.  The user
;	will see a jumble of activity on the LEDs during this
;	time. The effect will be to freeze the LED display for
;	3 seconds and see the rapid updates for 1 second.
;
	JMP	LOOP
	
	END	LED3
