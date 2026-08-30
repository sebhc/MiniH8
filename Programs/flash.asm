; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;
;	Sample program to flash "MON" LED on
;	Mini H8
;
;	32K of RAM
;	first 8K of memory is ROM
;
;	GFR	8/13/2026
;

;	8255 PPI at 0F0-0F3

PPI	EQU	0F0h
IOA	EQU	0
CTRL	EQU	3

	ORG	2040h
;
;	set up 8255 PPI
;
START:	MVI	A,10001000b	; all bits OUT except PC4..PC7
	OUT	PPI+CTRL
;
;	Loop turning MON (PA5) on and then off
;
FLASH:	MVI	A,00100000b	; PA5 ON
	OUT	PPI+IOA
	
	CALL	DELAY
	

	MVI	A,0		; all OFF
	OUT	PPI+IOA
	
	CALL	DELAY
	JMP	FLASH
;
;	simple delay (double-nested counter loop)
;
DELAY:	MVI	A,0FFh
	MOV	B,A
PT1:	DCR	A
PT2:	DCR	B
	JNZ	PT2
	CPI	0
	JNZ	PT1
	RET
	
	END	START
