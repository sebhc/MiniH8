;	H8 Demo version for the Mini H8
;
;	recreated from demonstration program originally published
;	in the H8 Operations manual
;
;	G. Roberts	August 2026

FPLEDS	EQU	200BH		; LED refresh area
MFLAG	EQU	2008H
DLY	EQU	0053H		; relocated from PAM/8 location

;HORN	EQU	0		; TBD (not yet implemented)

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
	
	MVI	A,50		; 100 ms beep
;	CALL	HORN

	MVI	A,50		; 100 ms delay
	CALL	DLY
	
	MVI	A,50		; 100 ms beep
;	CALL	HORN
	
	JMP	START		; Loop forever ...
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
	DB	01000010B	; r
	DB	01000101B	; u
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
