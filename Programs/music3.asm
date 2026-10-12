; MUSIC3 - Program to play music on the H8 Mini
;
; Based on the approach by James Grogan and Robert Monteith.
;
; This approach was first discussed in Monteith's contribution to HUG 885-1008
; (Heath User Group's first software volume). By lifting pin 9 on IC112
; on the H8 front panel the speaker output can be converted to direct control
; by the CPU (otherwise the CPU simply toggles the 1Khz square wave input
; to the speaker.) The approach was further refined by Grogan and published
; in HUG 885-1031 volumes A and B. The approach taken was to develop a Benton Harbor
; BASIC program to create/edit music. The output of the BASIC program was an
; HDOS executable (.ABS file) consisting of a short assembly program and
; the musical SCORE. This program is based on a disassembly of the .ABS file
; (the ASM source for that was never published).
;
; The advantage of this approach is that there are multiple music files
; that have already been created that can be adapted to the Mini H8.
;
; G. Roberts	October 2026
;

;
;	H8 Mini equates
;
;	8255 PPI at 0F0-0F3
;
PPI	EQU	0F0H
IO.A	EQU	0
IO.B	EQU	1

	ORG	2040H		; ORG at 040.100A
;
;	Plays the score then does a cold reboot on H8 Mini
;
START:	DI			; interrupts off
;
;	Blank any front panel LEDs that were left lit when
;	we killed the update.
;
BLANK:	IN	PPI+IO.A	; read port A settings
	ANI	11110000B	; clear LED selects (PA0..PA3)
	MOV	B,A		; save it
	MVI	C,9		; 9 LEDs
BLOOP:	ADD	C		; address an LED
	OUT	PPI+IO.A	; select it
	XRA	A		; zero = all segments off
	OUT	PPI+IO.B	; turn off all segments
	MOV	A,B		; get back mask
	DCR	C		; count down
	JNZ	BLOOP		; and loop through all 9

	CALL	PLAY		; play the tune
	
	EI			; interrupts on
	JMP	0H		; reboot
	
;
;	Play SCORE
;
PLAY:	LXI	H,SCORE		; point to score
	PUSH	H		; keep our place
;
;	Note loop
;
NLOOP:	POP	H		; our place in the score
	MOV	E,M
	INX	H
	MOV	D,M		; (DE) = note duration
	INX	H
	MOV	A,D		; test for zero
	ORA	E
	JZ	PEXIT		; tune over
	MOV	C,M
	INX	H
	MOV	B,M		; (BC) = period counter
	INX	H
	PUSH	H		; save our place in the score
	
	MOV	A,B
	ORA	C
	JNZ	PNOTE		; BC == 0 ? rest (DE) units, else note
;
;	Rest - duration = (DE)
;	
REST:	MVI	B,50		; 7 states
;
;	loop count: 7 + 50*15 + 5 + 5 + 4 + 10 = 781 = 390 uS
;
ILOOP:	DCR	B		; 5 states (on 8080); 4 cycles (8085)
	JNZ	ILOOP		; 10 states
	
	DCX	D		; 5 states (8080); 6 states (8085)
	MOV	A,D		; 5 states (8085); 4 states (8085)
	ORA	E		; 4 states
	JNZ	REST		; 10 states
	
	JMP	NLOOP
;
;	Play note - duration = (DE)
;
PNOTE:	MOV	H,B
	MOV	L,C		; (HL) = half period count
;
;	set speaker to "high" state
;
	IN	PPI+IO.A	; Read Port A settings
	ANI	00111111B	; Clear top two bits (PA6-7
	ORI	10000000B	; PA7 on; PA6 off
	OUT	PPI+IO.A	; set speaker bit

	CALL	NOTE		; play the note
	
	JMP	NLOOP		; go to next note

PEXIT:	RET			; tune is done

;
;	NOTE - Play a note
;
;	ENTRY:	A = speaker mask
;		DE = duration
;		HL = half period
;
;	USES:	BC
;
NOTE	EQU	*
;
;	count half the period (HL)
;
;	12 uS per loop
;
	MOV	B,H
	MOV	C,L		; (BC) = half period count
NOTE1:	DCX 	B		; 5 cycles (8080), 6 cycles (8085)
	MOV	A,B		; 5 cycles (8080), 4 cycles (8085)
	ORA	C		; 4 cycles (8080 & 8085)
	JNZ	NOTE1		; 10 cycles
;
;	Toggle speaker bits
;
	IN	PPI+IO.A	; Read Port A settings
	XRI	11000000B	; toggle PA6, PA7
	OUT	PPI+IO.A	; toggle speaker
;
;	count down the time 'til done
;	
	DCX	D
	MOV	A,D
	ORA	E		; (DE) == 0?
	JNZ	NOTE		; and keep toggling
	
	RET
	

SCORE	EQU	*
;
;	Each note is a word pair. The first word is the note
;	duration and the second word is one half the note period
;	A zero duration ends the tune. a zero half period is a rest.
;
	INCL	"MOZART.TXT"
	
	END	START
