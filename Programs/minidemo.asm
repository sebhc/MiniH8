;	H8 Demo version for the Mini H8
;
;	recreated from demonstration program originally published
;	in the H8 Operations manual
;
;	G. Roberts	August 2026

FPLEDS	EQU	200BH		; LED refresh area
MFLAG	EQU	2008H
DLY	EQU	0053H		; relocated from PAM/8 location
;
;	H8 Mini equates
;
;	8255 PPI at 0F0-0F3
;
PPI	EQU	0F0H
IO.A	EQU	0
IO.B	EQU	1

	ORG	2040H
;
;	Classic "Your H8 is uP and running" code ...
;
DEMO	MVI	A,00000010B	; Disable LED updates
	STA	MFLAG
	
START	MVI	B,4		; Four sets of patterns
	LXI	H,LEDPAT	; LED patterns to display
DEMO0	LXI	D,FPLEDS	; LED pattern fields
	
	MVI	C,9		; 9 LEDs
DEMO1	MOV	A,M		; Get an LED pattern
	STAX	D		; store it in a field
	INX	H		; next pattern
	INX	D		; next field
	DCR	C		; count down
	JNZ	DEMO1		; loop 'til done
;
;	Delay for about a second and a half
;
	MVI	C,3		; three times
DEMO2	MVI	A,255		; about 1/2 second
	CALL	DLY
	DCR	C
	JNZ	DEMO2

	DCR	B		; next pattern
	JNZ	DEMO0
;
;	Now beep three times. best done with interrupts off
;
	DI			; interrupts off
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
;	set speaker to "high" state
;
	IN	PPI+IO.A	; Read Port A settings
	ANI	00111111B	; Clear top two bits (PA6-7)
	ORI	10000000B	; PA7 on; PA6 off
	OUT	PPI+IO.A	; set speaker bit
;
;	Play beeps.
;
	MVI	B,53		; 1046.5 Hz = C6 or "High" C)
	MVI	C,105		; 100 ms duration
	CALL	TONE

	CALL	DLY100		; pause, 100ms
	
	MVI	B,53		; 1046.5 Hz = C6 or "High" C)
	MVI	C,105		; 100 ms duration
	CALL	TONE
;
;	set speaker outputs both "low"
;
	IN	PPI+IO.A	; Read Port A settings
	ANI	00111111B	; Clear top two bits (PA6-7)
	OUT	PPI+IO.A	; set speaker bit
	
	EI			; interrupts back on
	
	JMP	START		; Loop forever ...
;
;	TONE - play a note. set speaker high, wait 1/2 period, then
;	set speaker low. repeat for note duration.
;
;	This loop uses the pitch value to determine how long to wait
;	between high and low (half period), toggling the speaker through
;	a number of cycles determined by the note duration.
;
;	ENTRY:	(B)	pitch value
;		(C)	note duration
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
;
;	DELAY just kills 9 uS of time
;
DELAY:	NOP			; 4 cycles
	DCR	D		; 4 cycles
	JNZ	DELAY		; 10 cycles
	RET
	
; =====================================================================
;
; from Google AI
;
; DLY100 - Pause execution for 100 milliseconds (at 2 MHz clock)
; For use when front 2ms clock is disabled)
;
; USES: BC
;
; =====================================================================
DLY100:	MVI	B,100		; [7 T-states] Outer loop counter: repeat 100 times
OUTER:	MVI	C,82		; [7 T-states] Inner loop counter
INNER:	DCR	C		; [5 T-states] Decrement inner counter
	JNZ	INNER		; [10 T-states if jump, 7 T-states if fallback]
	DCR	B		; [5 T-states] Decrement outer counter
	JNZ	OUTER		; [10 T-states if jump, 7 T-states if fallback]
	RET			; [10 T-states] Return to caller

;
; 	LED patterns to display (four sets of 9)
;
LEDPAT	DB	00000000B	; <blank>
	DB	01001101B	; Y
	DB	01000111B	; o
	DB	01000101B	; u
	DB	01000010B	; r
	DB	00000000B	; <blank>
	DB	01101101B	; H
	DB	01111111B	; 8
	DB	00000000B	; <blank>
	
	DB	01100000B	; i
	DB	01011011B	; s
	DB	00000000B	; <blank>
	DB	01000101B	; u
	DB	01100111B	; p
	DB	00000000B	; <blank>
	DB	01101111B	; a
	DB	00101001B	; n
	DB	00111101B	; d
	
	DB	00000000B	; <blank>
	DB	00100001B	; r
	DB	00111000B	; u
	DB	00101001B	; n
	DB	00101001B	; n
	DB	01100000B	; i
	DB	00101001B	; n
	DB	01011111B	; g
	DB	00000000B	; <blank>
	
	DB	01100001B
	DB	00000001B
	DB	00001101B
	DB	01100001B
	DB	00000001B
	DB	00001101B
	DB	01100001B
	DB	00000001B
	DB	00001101B
	
	END	DEMO
