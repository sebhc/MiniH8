;	MUSIC.ASM - a program to play music on the H8 Mini
;
;	Assumes 8255 PIA has been set up by monitor ROM
;
;	bugs: need to add rests
;
;	Glenn Roberts		6 September, 2026
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
;	First we disable all interrupts. Alternatively could pick just
;	the clock one to turn off but for now disable all.
;
START:	DI			; interrupts off
;
;	Now let's blank any front panel LEDs that were left lit when
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
;
;	Now play some notes
;
TUNE:	LXI	H,SCORE		; point to the score (list of notes)
;
;	set speaker to "high" state
;
	IN	PPI+IO.A	; Read Port A settings
	ANI	00111111B	; Clear top two bits (PA6-7
	ORI	10000000B	; PA7 on; PA6 off
	OUT	PPI+IO.A	; set speaker bit
;
;	Loop over notes. First test for a period of zero,
;	which indicates the end of the notes.
;
NOTES:	MOV	A,M		; (A) = half period
	ORA	A		; set flags
	JZ	0000H		; zero = end - cold boot the system

	MOV	B,A		; (B) = 1/2 period delay
	INX	H		; duration is next
	MOV	C,M		; (C) = duration
;
;	Now play a note. set speaker high, wait 1/2 period, then
;	set speaker low. repeat for note duration.
;
;	This loop uses the pitch value in B to determine how
;	long to wait between high and low (half period), toggling
;	the speaker through a number of cycles determined by the
;	note duration in (C).
;	
TONE:	MOV	D,B		; wait 1/2 cycle
	CALL	DELAY		; "high" state duration
;
;	Now toggle the speaker
;
	IN	PPI+IO.A	; Read Port A settings
	XRI	11000000B	; toggle PA6, PA7
	OUT	PPI+IO.A	; set speaker to "low"

	MOV	D,B		; wait second 1/2 cycle
	CALL	DELAY		; "low" state duration

	DCR	C		; Decrement duration counter
	JNZ	TONE		; Repeat square wave cycle if duration is not finished
;
;	End of note
;
	INX	H		; Point to the next note
	JMP	NOTES		; Play next note
;
;	DELAY - Called each time the output signal is to be
;	toggled, i.e. 1/2 the period. Each pass through the routine
;	takes 4+4+10=18 cycles. At 2mhz clock speed (.5us/cycle) that
;	amounts to 9uS per iteration. Table below gives the number of
;	iterations for each half cycle (between toggling the output)
;	needed to produce the desired tone frequency.
;
; Note	 F(Hz)	P(ms)  P/2(ms)	Iterations
; ====  ======  ====    ====    ==========
;  C	261.63	3.82	1.91	   212
;  C#	277.18	3.61	1.80	   200
;  D	293.66	3.41	1.70	   189
;  D#	311.13	3.21	1.61	   179
;  E	329.63	3.03	1.52	   169
;  F	349.23	2.86	1.43	   159
;  F#	369.99	2.70	1.35	   150
;  G	392.00	2.55	1.28	   142
;  G#	415.30	2.41	1.20	   134
;  A	440.00	2.27	1.14	   126
;  A#	466.16	2.15	1.07	   119
;  B	493.88	2.02	1.01	   112
;
;	(see spreadsheet for continuation)
;

;
;	DELAY just kills 9 uS of time
;
DELAY:	NOP			; 4 cycles
	DCR	D		; 4 cycles
	JNZ	DELAY		; 10 cycles
	RET

;
;	Musical scale, 2 octaves (50ms per note)
;
SCORE:	DB	212,13
	DB	200,14
	DB	189,15
	DB	179,16
	DB	169,16
	DB	159,17
	DB	150,18
	DB	142,20
	DB	134,21
	DB	126,22
	DB	119,23
	DB	112,25

	DB	106,26
	DB	100,28
	DB	95,29
	DB	89,31
	DB	84,33
	DB	80,35
	DB	75,37
	DB	71,39
	DB	67,42
	DB	63,44
	DB	60,47
	DB	56,49

	DB	53,52
	DB	50,55
	DB	47,59
	DB	45,62
	DB	42,66
	DB	40,70
	DB	38,74
	DB	35,78
	DB	33,83
	DB	32,88
	DB	30,93
	DB	28,99

	DB	27,105
	DB	25,111
	DB	24,117
	DB	22,124
	DB	21,132
	DB	20,140
	DB	19,148
	DB	18,157
	DB	17,166
	DB	16,176
	DB	15,186
	DB	14,198

	DB	0

	END	START

