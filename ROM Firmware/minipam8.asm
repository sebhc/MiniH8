; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;	This is a modified version of PAM/8, originally written by Gordon
;	Letwin 50 years ago! This version is designed to support Lee Hart's
;	"Mini H8", which incorporates some hardware modifications to simplify
;	the design and allow it to run on a 3" x 6" PCB. 
;
;	A modified version of Jon Chapman's Glitch Works Monitor GWMON-80
;	has been added to support a console monitor and ability to load
;	Intel Hex files.
;
;	Modified by HRJ for assembly with the A85 assembler.
;
;	by Glenn Roberts (gfr), Augutst 2026
;
;	Key changes over PAM/8:
;	- IRQ handling limited to the 3 hardware interrupts on the
;	  Mini-H8: 2ms Clock, RTM/0 and Serial start.
;	- LOAD and DUMP to use the serial I/O port to load .H8T files
;
;	edits HRJ are by Herb Johnson July 25 2026
;	- HRJ provided INCLUDES with available sources
;	- HRJ commented out macro calls (see macro.mac) with comments
;	- HRJ replaced expressions <symbol>#256 with LOW <symbol>,
;	  extracts low byte from address
;
; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

;	PAM/8 - H8 FRONT PANEL MONITOR
;
;	JGL, 05/01/76.
;
;	FOR *WINTEK* INC.
;
;	COPYRIGHT  05/1976, WINTEK CORPORATION
;	902 N. 9TH ST.
;	LAFAYETTE, IND.

;	PAM/8 - H8 FRONT PANEL MONITOR
;
;	THIS PROGRAM RESIDES (IN ROM) IN THE LOW 1024 BYTES OF THE HEATH
;	H8 COMPUTER. IT ACTUALLY CONSISTS OF TWO VIRTUALLY INDEPENDENT
;	ROUTINES: A TASK-TIME PROGRAM WHICH PROVIDES SOPHISTICATED
;	FRONT PANEL MONITOR SERVICE, AND AN INTERRUPT-TIME PROGRAM WHICH
;	PROVIDES BOTH A REAL-TIME CLOCK AND EMULATES AN EFFECTIVE
;	HARDWARE FRONT PANEL.

;	INTERRUPTS.
;
;	PAM/8 IS THE PRIMARY PROCESSOR FOR ALL INTERRUPTS.
;	THEY ARE PROCESSED AS FOLLOWS:
;
;	RST	USE
;
;	0	MASTER CLEAR. (NEVER USES FOR I/O OR RESET)
;
;	1	CLOCK INTERRUPT. NORMALLY TAKEN BY PAM/8.
;		SETTING BIT *U0.CLK* IN BYTE *MFLAG* ALLOWS
;		USER PROCESSING (VIA A JUMP THROUGH *UIVEC*).
;		UPON ENTRY OF THE USER ROUTINE, THE STACK
;		CONTAINS:
;		(STACK+0)  = RETURN ADDRESS (TO PAM/8)
;		(STACK+2)  = (STACKPTR+4)
;		(STACK+4)  = (AF)
;		(STACK+6)  = (BC)
;		(STACK+8)  = (DE)
;		(STACK+10) = (HL)
;		(STACK+12) = (PC)
;		THE USER'S ROUTINE SHOULD RETURN TO PAM/8 VIA
;		A *RET* WITHOUT ENABLING INTERRUPTS.
;
;	2	SINGLE STEP. SINGLE STEP INTERRUPTS GENERATED
;		BY PAM/8 ARE PROCESSED BY PAM/8.
;		ANY SINGLE STEP INTERRUPT RECEIVED WHEN IN
;		USER MODE CAUSES A JUMP THROUGH *UIVEC*+3.
;		STACK UPON USER ROUTINE ENTRY;
;		(STACK+0)  = (STACKPTR+12)
;		(STACK+2)  = (AF)
;		(STACK+4)  = (BC)
;		(STACK+6)  = (DE)
;		(STACK+8)  = (HL)
;		(STACK+10) = (PC)
;		THE USER'S ROUTINE SHOULD HANDLE ITS OWN RETURN
;		FROM THE INTERRUPT.
;
;
;	THE FOLLOWING INTERRUPTS ARE VECTORED DIRECTLY THROUGH *UIVEC*.
;	THE USER ROUTINE MUST HAVE SETUP A JUMP IN *UIVEC* BEFORE ANY
;	OF THESE INTERRUPTS MAY OCCUR.
;
;	3	I/O 3. CAUSES A DIRECT JUMP THROUGH *UIVEC*+6
;
;	4	I/O 4. CAUSES A DIRECT JUMP THROUGH *UIVEC*+9
;
;	5	I/O 5. CAUSES A DIRECT JUMP THROUGH *UIVEC*+12
;
;	6	I/O 6. CAUSES A DIRECT JUMP THROUGH *UIVEC*+15
;
;	7	I/O 7. CAUSES A DIRECT JUMP THROUGH *UIVEC*+18


;		ASSEMBLY CONSTANTS

;		I/O PORTS

IP.PAD	EQU	360Q		; PAD INPUT PORT
OP.CTL	EQU	360Q		; CONTROL OUTPUT PORT
OP.DIG	EQU	360Q		; DIGIT SELECT OUTPUT PORT
OP.SEG	EQU	361Q		; SEGMENT SELECT OUTPUT PORT
IP.TPC	EQU	371Q		; TAPE CONTROL IN
OP.TPC	EQU	371Q		; TAPE CONTROL OUT
IP.TPD	EQU	370Q		; TAPE DATA IN
OP.TPD	EQU	370Q		; TAPE DATA OUT

;		ASCII CHARACTERS.

A.SYN	EQU	026Q		; SYNC CHARACTER
A.STX	EQU	002Q		; STX CHARACTER

;		FRONT PANEL HARDWARE CONTROL BITS.

CB.SSI	EQU	00010000B	; SINGLE STEP INTERRUPT
CB.MTL	EQU	00100000B	; MONITOR LIGHT
CB.CLI	EQU	01000000B	; CLOCK INTERRUPT ENABLE
CB.SPK	EQU	10000000B	; SPEAKER ENABLE

;		DISPLAY MODE FLAGS (IN *DSPMOD*)

DM.MR	EQU	0		; MEMORY READ
DM.MW	EQU	1		; MEMORY WRITE
DM.RR	EQU	2		; REGISTER READ
DM.RW	EQU	3		; REGISTER WRITE

;		MACHINE INSTRUCTIONS.

MI.HLT	EQU	01110110B	; HALT
MI.RET	EQU	11001001B	; RETURN
MI.IN	EQU	11011011B	; INPUT
MI.OUT	EQU	11010011B	; OUTPUT
MI.LDA	EQU	00111010B	; LDA
MI.ANI	EQU	11100110B	; ANI
MI.LXID EQU	00010001B	; LXI D

;		USER OPTION BITS.
;
;		THESE BITS ARE SET IN CELL MFLAG.

UO.HLT	EQU	10000000B	; DISABLE HALT PROCESSING
UO.NFR	EQU	CB.CLI		; NO REFRESH OF FRONT PANEL
UO.DDU	EQU	00000010B	; DISABLE DISPLAY UPDATE
UI.CLK	EQU	00000001B	; ALLOW CLOCK INTERRUPT PROCESSING

;
;	MiniH8 equates
;
;	8255 PPI at 0F0-0F3
;
PPI	EQU	0F0H
IO.A	EQU	0
IO.B	EQU	1
IOC	EQU	2
CTRL	EQU	3

KNUM	EQU	00010000B	; PC4
KMATH	EQU	00100000B	; PC5
KR	EQU	01000000B	; PC6
K0	EQU	10000000B	; PC7

;
;	Equates used by GWMON
;
;	ASCII Equates
;
CTLC	EQU	03
BS	EQU	08
LF	EQU	10
CR	EQU	13

CANCEL	EQU	CTLC		; Escape/cancel character, CTRL+C
NEXTLOC	EQU	CR		; Keystroke for next location in E
				; defaults to CR
				
STACK	equ	8000H		; Stack at top of RAM (32K for MiniH8)
				
;
;	Bit times for bit-banged serial
;
; Using Intel Application Note AP-29 the following are computed for
; use with 4.0 MHz crystal - gfr
;
;BITTIME	EQU	010AH		;9600 BPS with 4.0 MHz crystal
;HALFBIT	EQU	0106H		;Half-bit time

BITTIME	EQU	0137H		;2400 BPS with 4.0 MHz crystal
HALFBIT	EQU	011CH		;Half-bit time


	INCL	"u8251.asm"	; DEFINE THE 8251 USART BITS

;	INTERRUPT VECTORS.
;

;	LEVEL 0 - RESET
;
;	The CPU will jump here on a cold start
;
;	THIS 'INTERRUPT' MAY NOT BE PROCESSED BY A USER PROGRAM.

	ORG	0

INIT0	LXI	D,PRSROM	; (DE) = ROM COPY OF PRS CODE
	LXI	H,PRSRAM+PRSL-1 ; (HL) = RAM DESTINATION FOR CODE
	JMP	INIT		; INITIALIZE
;	ERRPL	INIT-1000Q	; BYTE IN WORD 10A MUST BE 0

	ORG	33Q
;
;	Legacy relic from PAM/8 - needs updating for MiniH8 if used
;
GO.     MVI     A,CB.SSI+CB.CLI+CB.SPK ; OFF MONITOR MODE LIGHT
        JMP     SST1            ; RETURN TO USER PROGRAM


;	Interrupt 5.5 - caused by RTM/0 key combination
;
;	On the original H8 RTM/0 generated a level 10 
;	interrupt - basically the clock handler. The CLOCK
;	routine would test for the RTM/0 combination and
;	drop back into the monitor.
;
;	The MiniH8 has its own direct interrupt handler for the
;	RTM/0 key combo. Need to insert similar code here.
;
;	This interrupt is maskable via SIM instruction.
;
;	NOTE: In PAM-8 location 53Q is the address of DLY, a
;	general purpose delay routine. Unfortunately
;	we will have to relocate DLY because of the INT5.5
;	code.

	ORG	54Q
INT5.5	EQU	*
	EI
	RET
	
;	Interrupt 6.5 - triggered by RX serial line. Can be used
;	to detect serial start bit. Maskable via SIM instruction.

	ORG	64Q
INT6.5	EQU	*
	EI
	RET
	
;	Interrupt 7.5 - generated by 2ms clock
;
;	Currently just increment TICCNT, however will need to
;	add LED refresh here as well.

	ORG	74Q
INT7.5	PUSH	PSW
	PUSH	B
	PUSH	D
	PUSH	H

;	Update TICCNT

	LHLD	TICCNT		; clock ticker
	INX	H		; bump it
	SHLD	TICCNT		; and save
	
	MVI	D,0		; needed for proper RFP execution
	CALL	RFP		; refresh front panel display
	
	POP	H
	POP	D
	POP	B
	POP	PSW
	
	EI
	RET
	

	NOP			; forces DLY to be 053H

;	DLY - DELAY TIME INTERVAL.
;
;	This routine now lives at 053H (in PAM/8 was 053Q)
;
;	ENTRY	(A) = MILLISECONDS DELAY COUNT/2
;	EXIT	NONE
;	USES	A,F

DLY	PUSH	PSW		; SAVE COUNT
	XRA	A		; DONT SOUND HORN
	JMP	HRN0		; PROCESS AS HORN



;	INIT - initialize system
;
;	INIT is called whenever a hardware master-clear is initiated.
;
;	Setup PAM/8 control cells in RAM.
;	Decode how much memory exists, setup stackpointer, amd
;	enter the monitor loop.
;
;	ENTRY:	from master clear
;	EXIT:	into PAM/8 main loop
;
;	First, initalize key locations in RAM using initial
;	values stored in ROM (PRSROM). Values are copied in
;	reverse order.
;
INIT	LDAX	D		; copying from *PRSROM* into RAM
	MOV	M,A		; move a byte
	DCX	H		; decrement destination
	INR	E		; increment source
	JNZ	INIT		; and loop 'til done
;
;	In PAM/8 the code determines the top of RAM by probing
;	every 1K for live RAM and then set the stack pointer
;	there. For the MiniH8 we assume a 32K RAM space and
;	set SP there.
;
	LXI	SP,STACK	; Stack at top of RAM
	
;	PUSH	H		; save *PC* value on stack
;	LXI	H,ERROR		; ERROR = general bail out routine
;	PUSH	H		; set as 'return address'
;
;	For testing purposes we now initialize key values and
;	jump to GWMON console monitor

;	NOTE: PPI setup routine can only be executed from RAM.
;	first copy to RAM and then call it

	MVI	C,PPSIZE	; size of PPSRAM routine
	LXI	D,PPSROM	; (DE) = ROM version
	LXI	H,PPSRAM	; (HL) = new home in RAM
	
MOVPPS:	LDAX	D		; fetch a byte
	MOV	M,A		; store in RAM
	INX	D		; next source address
	INX	H		; next destination address
	DCR	C		; check the count
	JNZ	MOVPPS		; loop 'til done
;
;	Now call the routine (in RAM) to set up the 8255 PPI
;
	CALL	PPSRAM
;
;	Set up interrupt vectors
;
	MVI	A,00001011B	; enable RST 7.5 - clock IRQ
	SIM			; apply the mask
	EI			; globally enable interrupts
;
;	Now just go to the GWMON command loop (later we'll add the
;	front panel keypad code)
;
	JMP	GWMON


;
;	This routine must be copied to and executed in RAM as
;	it will temporarily disable the ROM while it is being
;	executed

PPSIZE	EQU	9		; length of PPISET to be copied to RAM

PPSROM:	MVI	A,10001000B	; all bits OUT except PC4..PC7
	OUT	PPI+CTRL
	MVI	A,00010000B	; make sure PA4 stays high (ROM/RAM line)
	OUT	PPI+IO.A
	RET


;
;	SAVALL - SAVE ALL REGISTERS ON STACK.
;
;	SAVALL IS CALLED WHEN AN INTERRUPT IS ACCEPTED, IN ORDER TO
;	SAVE THE CONTENTS OF THE REGISTERS ON THE STACK.
;
;	ENTRY	CALLED DIRECTLY FROM THE INTERRUPT ROUTINE.
;	EXIT	ALL REGISTERS PUSHED ON STACK.
;		IF NOT YET IN MONITOR MODE, REGPTR = ADDRESS OF REGISTERS
;		ON STACK.
;		(DE) = ADDRESS OF CTLFLG


SAVALL	XTHL			; SET H,L ON STACK TOP
	PUSH	D
	PUSH	B
	PUSH	PSW
	XCHG			; (D,E) = RETURN ADDRESS
	LXI	H,10
	DAD	SP		; (H,L) = ADDRESS OF USERS SP
	PUSH	H		; SET ON STACK AS 'REGISTER'
	PUSH	D		; SET RETURN ADDRESS
	LXI	D,CTLFLG
	LDAX	D		; (A) = CTLFLG
	CMA
	ANI	CB.MTL+CB.SSI	; SAVE REGISTER ADDR IF USER OR SINGLE-STEP
	RZ			; RETURN IF WAS INTERRUPT OR MONITOR LOOP
	LXI	H,2
	DAD	SP		; (H,L) = ADDRESS OF 'STACKPTR' ON STACK
	SHLD	REGPTR
	RET

;	RETURN TO PROGRAM FROM INTERRUPT.

INTXIT	POP	PSW		; REMOVE FAKE 'STACK REGISTER'
	POP	PSW
	POP	B
	POP	D
	POP	H
	EI
	RET

;	For test purposes the PAM/8 CLOCK routine below is not
;	used. Clock processing is handled at INT7.5 location
;			- gfr
;

;	CLOCK - PROCESS CLOCK INTERRUPT
;
;	CLOCK IS ENTERED WHENEVER A MILLISECOND CLOCK INTERRUPT IS
;	PROCESSED.
;
;	TICCNT IS INCREMENTED EVERY INTERRUPT.

CLOCK	LHLD	TICCNT
	INX	H
	SHLD	TICCNT		; INCREMENT TICCOUNT

;	For test purposes RFP is now a stand alone routine that
;	just updates the front panel LEDs. - gfr
;
;	ENTRY: 	calling program should set (D) = 0

;	REFRESH FRONT PANEL.
;
;	THIS CODE DISPLAYS THE APPROPRIATE PATTERN ON THE
;	FRONT PANEL LEDS. THE LEDS ARE PAINTED IN REVERSE ORDER,
;	ONE PER INTERRUPT. FIRST, NUMBER 9 IS LIT, THEN NUMBER 8,
;	ETC.

RFP	LXI	H,MFLAG		; ((HL)) = MFLAG
	MOV	A,M		; (A) = current MFLAG value
	MOV	B,A		; save it in (B)
	ANI	UO.NFR		; Test No Front Refresh bit
	INX	H		; code assumes CTLFLG follows MFLAG

	MOV	A,M		; (A) = CTLFLG
	MOV	C,D		; (C) = 0 in case no panel refresh
	JNZ	CLK3		; NFR bit was set - no refresh
	INX	H		; code assumes REFIND follows CTLFLG
;
;	Here (HL) points to the refresh index (REFIND). Since the front
;	panel LED pattern bytes (FPLEDS) immediately follow that location
;	they are indexed from 1 to 9. REFIND was initialized to 1 at startup.
;
	DCR	M		; decrement digit index
	JNZ	CLK2		; still positive, keep going
	MVI	M,9		; reset to 9 when it gets to zero
CLK2	MOV	E,M		; (DE) = index pointer to pattern
	DAD	D		; ((HL)) = (M) = LED pattern
;
;	Port B controls which of the segments to light
;	(M) = pattern to send to the LED
;
	XRA	A		; first zero the pattern
	OUT	PPI+IO.B	; this avoids "ghosting"
	
CLK3	IN	PPI+IO.A	; read Port A status
	ANI	11110000B	; clear lower 4 bits
	ORA	E		; set bits for digit to select
	OUT	PPI+IO.A	; select it
;
;	Now set the segments to be lit on Port B
;
	MOV	A,M		; (A) = LED pattern from table
	OUT	PPI+IO.B	; set it!
	
;	For test purposes we are done now, return - gfr

	RET
	
	

;	SEE IF TIME TO DECODE DISPLAY VALUES

	MVI	L,LOW TICCNT	; look only at low byte
	MOV	A,M
	ANI	31		; EVERY 32 INTERRUPTS
	CZ	UFD		; UPDATE FRONT PANEL DISPLAYS

;	EXIT CLOCK INTERRUPT

	LXI	B,CTLFLG
	LDAX	B		; (A) = CTLFLG
	ANI	CB.MTL
	JNZ	INTXIT		; IF IN MONITOR CODE
	DCX	B
;	ERRNZ	CTLFLG-MFLAG-1	; code assumes CTLFLG follows MFLAG
	LDAX	B		; (A) = MFLAG
;	ERRNZ	UO.HLT-200Q	; ASSUME HIGH-ORDER
	RAL
	JC	CLK4		; SKIP IT

;	NOT IN MONITOR MODE, CHECK FOR HALT

	MVI	A,10		; (A) = INDEX OF *P* REG
	CALL	LRA.		; LOCATE REGISTER ADDRESS
	MOV	E,M
	INX	H
	MOV	D,M		; (D,E) = PC CONTENTS
	DCX	D
	LDAX	D
	CPI	MI.HLT		; CHECK FOR HALT
	JZ	ERROR		; IF HALT, BE IN MONITOR MODE

;	CHECK FOR 'RETURN TO MONITOR' KEY ENTRY.
CLK4	EQU	*
;	 IN	 IP.PAD
;	 CPI	 56Q		 ; SEE IF '0' AND '#'
;	 JNZ	 CUI1		 ; IF NOT, ALLOW USER PROCESSING OF CLOCK

;	ERROR - COMMAND ERROR.
;
;	ERROR IS CALLED AS A 'BAIL-OUT' ROUTINE.
;
;	IT RESETS THE OPERATIONAL MODE, AND RESTORES THE STACKPOINTER.
;
;	ENTRY	NONE
;	EXIT	TO MTR LOOP
;		CTLFLG SET
;		MFLAG CLEARED
;	USES	ALL

ERROR
	LXI	H,MFLAG
	MOV	A,M		; (A) = MFLAG
	ANI	377Q-UO.DDU-UO.NFR ; RE-ENABLE DISPLAYS
	MOV	M,A		; REPLACE
	INX	H		; next point to CTLFLG
	MVI	M,CB.SSI+CB.MTL+CB.CLI+CB.SPK ; RESTORE *CTLFLG*
;	ERRNZ	CTLFLG-MFLAG-1	; code assumes CTLFLG follows MFLAG
	EI
	LHLD	REGPTR
	SPHL			; RESTORE STACK POINTER TO EMPTY STATE
	CALL	ALARM		; ALARM FOR 200 MS

;	MTR - MONITOR LOOP.
;
;	THIS IS THE MAIN EXECUTIVE LOOP FOR THE FRONT PANEL EMULATOR.

MTR	EI

MTR1	LXI	H,MTR1
	PUSH	H		; SET 'MTR1' AS RETURN ADDRESS
	LXI	B,DSPMOD	; (BC) = #DSPMOD
	LDAX	B
	ANI	1		; (A) = 1 IF ALTER
	CMA
	STA	DSPROT		; ROTATE LED PERIODS IF ALTER

;	READ KEY

	CALL	RCK		; READ CONSOLE KEYPAD
	LHLD	ABUSS
	CPI	10
	JNC	MTR4		; IF IN 'ALWAYS VALID' GROUP
	MOV	E,A		; SAVE VALUE
;	SET	DSPMOD
	LDAX	B		; (A) = DSPMOD
	RRC
	JC	MTR5		; IF IN ALTER MODE
	MOV	A,E		; (A) = CODE

;	HAVE A COMMAND (NOT A VALUE)

MTR4	SUI	4		; (A) = COMMAND
	JC	ERROR		; IF BAD
	MOV	E,A
	PUSH	H		; SAVE ABUSS VALUE
	LXI	H,MTRA
	MVI	D,0
	DAD	D		; (H,L) = ADDRESS OF TABLE ENTRY
	MOV	E,M
	DAD	D		; (H,L) = ADDRESS OF PROCESSOR
	XTHL			; SET ADDRESS, (H,L) = (ABUSS)
	LXI	D,REGI		; (D,E) = ADDRESS OF REG INDEX
;	SET	DSPMOD
	LDAX	B		; (A) = DSPMOD
	ANI	2		; SET 'Z' IF MEMORY
	LDAX	B		; (A) = DSPMOD
	RET			; JUMP TO PROCESSOR

MTRA				; JUMP TABLE
	DB	GO-$		; 4 - GO
	DB	IN- $		; 5 - INPUT
	DB	OUT-$		; 6 - OUTPUT
	DB	SSTEP-$		; 7 - SINGLE STEP
	DB	RMEM-$		; 8 - CASSETTE LOAD
	DB	WMEM-$		; 9 - CASSETTE DUMP
	DB	NEXT-$		; + - NEXT
	DB	LAST-$		; - - LAST
	DB	ABORT-$		; * - ABORT
	DB	RW-$		; / - DISPLAY/ALTER
	DB	MEMM-$		; # - MEMORY MODE
	DB	REGM-$		; . - REGISTER MODE

;	PROCESS MEMORY/REGISTER ALTERATIONS.
;
;	THIS CODE IS ENTERED IF
;
;	1) AM IN ALTER MODE, AND
;	2) A KEY FROM 0-7 WAS ENTERED.

MTR5	RRC
	MOV	A,E		; (A) = VALUE
	JC	MTR6		; IS REGISTER
	STC			; INDICATE 1ST DIGIT IS IN (A)
	CALL	IOB		; INPUT OCTAL BYTE
	INX	H		; DISPLAY NEXT LOCATION

;	SAE - STORE ABUSS AND EXIT.
;
;	ENTRY	(HL) = ABUSS VALUE
;	EXIT	TO (RET)
;	USES	NONE

SAE	SHLD	ABUSS
	RET

;	ALTER REGISTER

MTR6	PUSH	PSW		; SAVE CODE
	CALL	LRA		; LOCATE REGISTER ADDRESS
	ANA	A
	JZ	ERROR		; NOT ALLOWED TO ALTER STACKPOINTER
	INX	H
	POP	PSW		; RESTORE VALUE AND CARRY FLAG
	JMP	IOA		; INPUT OCTAL ADDRESS


;	REGM - ENTER REGISTER DISPLAY MODE.
;
;	ENTRY	(A) = DSPMOD
;		(BC) = #DSPMOD

REGM	MVI	A,2		; SET DISPLAY REGISTER MODE
;	SET	DSPMOD
	STAX	B		; SET DISPLAY REGISTER MODE
;	ERRNZ	DSPMOD-DSPROT-1	; code assumesDSPMOD follows DSPROT
	DCX	B		; (BC) = #DSPROT
	XRA	A
	STAX	B		; SET ALL PERIODS ON
	CALL	RCK		; READ KEY ENTRY
	DCR	A		; DISPLACE
	CPI	6
	JNC	ERROR		; NOT 1-6
	RLC
	STAX	D		; SET NEW REG IND
;	SET	REGI
	RET

;	RW - TOGGLE DISPLAY/ALTER MODE.
;
;	ENTRY	(A) = DSPMOD
;		(BC) = ADDRESS OF DSPMOD

;	SET	DSPMOD
RW	XRI	1
	STAX	B
	RET

;	NEXT - INCREMENT DISPLAY ELEMENT
;
;	ENTRY	(HL) = (ABUSS)
;		(DE) = ADDRESS OF REGIND

NEXT	INX	H
	JZ	SAE		; IF MEMORY, STORE VALUES AND EXIT

;	IS REGISTER MODE.

;	SET	REGI
	LDAX	D		; (A) = REGI
	ADI	2		; INCREMENT REGISTER INDEX
	STAX	D		; WRAP TO *SP*
	CPI	12
	RC			; IF NOT TOO LARGE, EXIT
	XRA	A		; OVERFLOW
	STAX	D
ABORT	RET

;	LAST - INCREMENT DISPLAY ELEMENT
;
;	ENTRY	(HL) = (ABUSS)
;		(DE) = ADDRESS OF REGIND
;

LAST	DCX	H
	JZ	SAE		; IF MEMORY, STORE AND EXIT

;	IS REGISTER MODE

;	SET	REGI
LST2	LDAX	D		; (A) = REGI
	SUI	2
	STAX	D
	RNC			; IF OK
	MVI	A,10		; UNDERFLOW TO *PC*
	STAX	D
	RET

;	MEMM - ENTER DISPLAY MEMORY MODE
;
;	ENTRY	(BC) = ADDRESS OF DSPMOD

MEMM	XRA	A		; (A) = 0
;	SET	DSPMOD
	STAX	B		; SET DISPLAY MEMORY MODE
;	ERRNZ	DSPMOD-DSPROT-1	; code assumes DSPMOD follows DSPROT
	DCX	B		; (BC) = #DSPROT
	STAX	B		; SET ALL PERIODS ON
	LXI	H,ABUSS+1
	JMP	IOA		; INPUT OCTAL ADDRESS

;	IN - INPUT DATA BYTE.
;
;	OUT - OUTPUT DATA BYTE.
;
;	ENTRY	(HL) = (ABUSS)

IN	MVI	B,MI.IN
	DB	MI.LXID		; SKIP NEXT INSTRUCTION
OUT	MVI	B,MI.OUT
	MOV	A,H		; (A) = VALUE
	MOV	H,L		; (H) = PORT
	MOV	L,B		; (L) = IN/OUT INSTRUCTION
	SHLD	IOWRK
	CALL	IOWRK		; PERFORM IO
	MOV	L,H		; (L) = PORT
	MOV	H,A		; (H) = VALUE
	JMP	SAE		; STORE ABUSS AND EXIT

;	GO - RETURN TO USER MODE
;
;	ENTRY	NONE

GO	JMP	GO.		; ROUTINE IS IN WASTE SPACE

;	SSTEP - SINGLE STEP INSTRUCTION
;
;	ENTRY	NONE

SSTEP				; SINGLE STEP
	DI			; DISABLE INTERRUPTS UNTIL THE RIGHT TIME
	LDA	CTLFLG
	XRI	CB.SSI		; CLEAR SINGLE STEP INHIBIT
	OUT	OP.CTL		; PRIME SINGLE STEP INTERRUPT
SST1	STA	CTLFLG		; SET NEW FLAG VALUES
	POP	H		; CLEAN STACK
	JMP	INTXIT		; RETURN TO USER ROUTINE FOR STEP

;	STPRTN - SINGLE STEP RETURN

STPRTN
	ORI	CB.SSI		; DISABLE SINGLE STEP INTERRUPTION
	OUT	OP.CTL		; TURN OFF SINGLE STEP ENABLE
;	SET	CTLFLG
	STAX	D
	ANI	CB.MTL		; SEE IF IN MONITOR MODE
	JNZ	MTR
	JMP	UIVEC+3		; TRANSFER TO USER'S ROUTINE

;	RMEM - LOAD MEMORY FROM TAPE
;

RMEM	LXI	H,TPABT
	SHLD	TPERRX		; SETUP ERROR EXIT ADDRESS
;	JMP	LOAD

;	LOAD - LOAD MEMORY FROM TAPE
;
;	READ THE NEXT RECORD FROM THE CASSETTE TAPE.
;
;	USE THE LOAD ADDRESS IN THE TAPE RECORD.
;
;	ENTRY	(HL) = ERROR EXIT ADDRESS
;	EXIT	USER P-REG (IN STACK) SET TO ENTRY ADDRESS
;		TO CALLER IF ALL OK
;		TO ERROR EXIT IF TAPE ERRORS DETECTED.

LOAD	LXI	B,177000Q	 ; 400Q-RT.MI*256-256 (BC) = - REQUIRED TYPE AND #
LOA0	CALL	SRS		; SCAN FOR RECORD START
	MOV	L,A		; (HL) = COUNT
	XCHG			; (DE) = COUNT, (HL) = TYPE AND #
	DCR	C		; (C) = - NEXT #
	DAD	B
	MOV	A,H
	PUSH	B		; SAVE TYPE AND #
	PUSH	PSW		; SAVE TYPE CODE
	ANI	177Q		; CLEAR END FLAG BIT
	ORA	L
	MVI	A,2		; SEQUENCE ERROR
	JNZ	TPERR		; IF NOT RIGHT TYPE OF SEQUENCE
	CALL	RNP		; READ ADDR
	MOV	B,H
	MOV	C,A		; (BC) = P-REG ADDRESS
	MVI	A,10
	PUSH	D		; SAVE (DE)
	CALL	LRA.		; LOCATE REG ADDRESS
	POP	D		; RESTORE (DE)
	MOV	M,C		; SET P-REG IN MEM
	INX	H
	MOV	M,B
	CALL	RNP		; READ ADDRESS
	MOV	L,A		; (HL) = ADDRESS, (DE) = COUNT
	SHLD	START

LOA1	CALL	RNB		; READ BYTE
	MOV	M,A
	SHLD	ABUSS		; SET ABUSS FOR DISPLAY
	INX	H
	DCX	D
	MOV	A,D
	ORA	E
	JNZ	LOA1		; IF MORE TO GO

	CALL	CTC		; CHECK TAPE CHECKSUM

;	READ NEXT BLOCK

	POP	PSW		; (A) = FILE TYPE BYTE
	POP	B		; (BC) = -(LAST TYPE, LAST #0
	RLC
	JC	TFT		; ALL DONE - TURN OFF TAPE
	JMP	LOA0		; READ ANOTHER RECORD

;	DUMP - DUMP MEMORY TO MAG TAPE.
;
;	DUMP SPECIFIED MEMORY RANGE TO MAG TAPE.
;
;	ENTRY	(START) = START ADDRESS
;		(ABUSS) = END ADDRESS
;		USER PC = ENTRY POINT ADDRESS
;	EXIT	TO CALLER.

WMEM	LXI	H,TPABT
	SHLD	TPERRX		; TAPE ERROR EXIT

DUMP	MVI	A,UCI.TE
	OUT	OP.TPC		; SETUP TAPE CONTROL
	MVI	A,A.SYN
	MVI	H,32		; (H) = # OF SYNC CHARACTERS
WME1	CALL	WNB
	DCR	H
	JNZ	WME1		; WRITE SYN HEADER
	MVI	A,A.STX
	CALL	WNB		; WRITE STX
	MOV	L,H		; (HL) = 00
	SHLD	CRCSUM		; CLEAR CRC 16
	LXI	H,100401Q	; RT.MI+80H*256+1 FIRST AND LAST MI RECORD
	CALL	WNP
	LHLD	START
	XCHG			; (D,E) = START ADDRESS
	LHLD	ABUSS		; (H,L) = STOP ADDR
	INX	H		; COMPUTE WITH STOP+1
	MOV	A,L
	SUB	E
	MOV	L,A
	MOV	A,H
	SBB	D
	MOV	H,A		; (HL) = COUNT
	CALL	WNP		; WRITE COUNT
	PUSH	H
	MVI	A,10
	PUSH	D		; SAVE (DE)
	CALL	LRA.		; LOCATE P-REG ADDRESS
	MOV	A,M
	INX	H
	MOV	H,M
	MOV	L,A		; (HL) = CONTENTS OF PC
	CALL	WNP		; WRITE HEADER
	POP	H		; (HL) = ADDRESS
	POP	D		; (DE) = COUNT
	CALL	WNP

WME2	MOV	A,M
	CALL	WNB		; WRITE BYTE
	SHLD	ABUSS		; SET ADDRESS FOR DISPLAY
	INX	H
	DCX	D
	MOV	A,D
	ORA	E
	JNZ	WME2		; IF MORE TO GO

;	WRITE CHECKSUM

	LHLD	CRCSUM
	CALL	WNP		; WRITE IT
	CALL	WNP		; FLUSH CHECKSUM
;	JMP	TFT

;	TFT - TURN OFF TAPE.
;
;	STOP THE TAPE TRANSPORT.
;

TFT	XRA	A
	OUT	OP.TPC		; TURN OFF TAPE

;	HORN - MAKE NOISE.
;
;	ENTRY	(A) = (MILLISECOND COUNT)/2
;	EXIT	NONE
;	USES	A,F

ALARM	MVI	A,200/2		; 200 MS BEEP
HORN	PUSH	PSW
	MVI	A,CB.SPK	; TURN ON SPEAKER

HRN0	XTHL			; SAVE (HL), (H) = COUNT
	PUSH	D		; SAVE (DE)
	XCHG			; (D) = LOOP COUNT
	LXI	H,CTLFLG
	XRA	M
	MOV	E,M		; (E) = OLD CTLFLG VALUE
	MOV	M,A		; TURN ON HORN
	MVI	L,LOW TICCNT	; HRJ was TICCNT#256

	MOV	A,D		; (A) = CYCLE COUNT
	ADD	M
HRN2	CMP	M		; WAIT REQUIRED TICCOUNTS
	JNZ	HRN2
	MVI	L,LOW CTLFLG	; HRJ wass CTLFLG#256
	MOV	M,E		; TURN HORN OFF
	POP	D
	POP	H
	RET

;	CTC - VERIFY CHECKSUM.
;
;	ENTRY	TAPE JUST BEFORE CRC
;	EXIT	TO CALLER IF OK
;		TO *TPERR* IF BAD
;	USES	A,F,H,L

CTC	CALL	RNP		; READ NEXT PAIR
	LHLD	CRCSUM
	MOV	A,H
	ORA	L
	RZ			; RETURN IF OK
	MVI	A,1		; CHECKSUM ERROR
;	JMP	TPERR		; (B) = CODE

;	TPERR - PROCESS TAPE ERROR.
;
;	DISPLAY ERR NUMBER IN LOW BYTE OF ABUSS
;
;	IF ERROR NUMBER EVEN, DON'T ALLOW #
;	IF ERROR NUMBER ODD, ALLOW #
;
;	ENTRY	(A) = NUMBER

TPERR	STA	ABUSS
	MOV	B,A		; (B) = CODE
	CALL	TFT		; TURN OFF TAPE

;	IS #, RETURN (IF PARITY ERROR)

	DB	MI.ANI		; FALL THROUGH WITH CARRY CLEAR
TER3	MOV	A,B

	RRC
	RC			; RETURN IF OK

;	BEEP AND FLASH ERROR NUMBER

TER1	CC	ALARM		; ALARM IF PROPER TIME
	CALL	TPXIT		; SEE IF #
	IN	IP.PAD
	CPI	00101111B	; CHECK FOR #
	JZ	TER3		; IF #
	LDA	TICCNT+1
	RAR			; 'C' SET IF 1/2 SECOND
	JMP	TER1

;	TPABT - ABORT TAPE LOAD OR DUMP.
;
;	ENTERED WHEN LOADING OR DUMPING, AND THE '*' KEY
;	IS STRUCK.

TPABT	XRA	A
	OUT	OP.TPC		; OFF TAPE
	JMP	ERROR

;	TPXIT - CHECK FOR USER FORCED EDIT.
;
;	TPXIT CHECKS FOR AN `*` KEYPAD ENTRY. IF SO, TAKE
;	THE TAPE DRIVER ABNORMAL EXIT.
;
;	ENTRY	NONE
;	EXIT	TO *RET* IF NOT '*'
;		(A) = PORT STATUS
;		TO (TPERRX) IF '*' DOWN
;	USES	A,F

TPXIT	IN	IP.PAD
	CPI	01101111B	; *
	IN	IP.TPC		; READ TAPE STATUS
	RNZ			; NOT '*', RETURN WITH STATUS
	LHLD	TPERRX
	PCHL			; ENTER (TPERRX)

;	SRS - SCAN RECORD START
;
;	SRS READS BYTES UNTIL IT RECOGNIZES THE START OF A RECORD.
;
;	THIS REQUIRES
;	AT LEAST 10 SYNC CHARACTERS
;	1 STX CHARACTER
;
;	THE CRC-16 IS THEN INITIALIZED.
;
;	ENTRY	NONE
;	EXIT	TAPE POSITIONED (AND MOVING), CRCSUM=0
;		(DE) = HEADER BYTES
;		(HL) = RECORD COUNT
;	USES	A,F,D,E,H,L

SRS
SRS1	MVI	D,0
	MOV	H,D
	MOV	L,D		; (HL) = 0
SRS2	CALL	RNB		; READ NEXT BYTE
	INR	D
	CPI	A.SYN
	JZ	SRS2		; HAVE SYN
	CPI	A.STX
	JNZ	SRS1		; NOT STX - START OVER

	MVI	A,10
	CMP	D		; SEE IF ENOUGH SYNC CHARACTERS
	JNC	SRS1		; NOT ENOUGH
	SHLD	CRCSUM		; CLEAR CRC-16
	CALL	RNP		; READ LEADER
	MOV	D,H
	MOV	E,A
;	JMP	RNP		; READ COUNT

;	RNP - READ NEXT PAIR.
;
;	RNP READS THE NEXT TWO BYTES FROM THE INPUT DEVICE.
;
;	ENTRY	NONE
;	EXIT	(H,A) = BYTE PAIR
;	USES	A,F,H

RNP	CALL	RNB		; READ NEXT BYTE
	MOV	H,A
;	JMP	RNB		; READ NEXT BYTE

;	RNB - READ NEXT BYTE
;
;	RNB READS THE NEXT SINGLE BYTE FROM THE INPUT DEVICE.
;	THE CHECKSUM IS TAKEN FOR THE CHARACTER.
;
;	ENTRY	NONE
;	EXIT	(A) = CHARACTER
;	USES	A,F

RNB	MVI	A,UCI.RO+UCI.ER+UCI.RE ; TURN ON READER FOR NEXT BYTE
	OUT	OP.TPC
RNB1	CALL	TPXIT		; CHECK FOR *, READ STATUS
	ANI	USR.RXR
	JZ	RNB1		; IF NOT READY
	IN	IP.TPD		; INPUT DATA
;	JMP	CRC		; CHECKSUM

;	CRC - COMPUTE CRC-16
;
;	CRC COMPUTES A CRC-16 CHECKSUM FOR THE POLYNOMIAL
;
;	(X + 1) * (X^15 + X + 1)
;
;	SINCE THE CHECKSUM GENERATED IS A DIVISION REMAINDER,
;	A CHECKSUMED DATA SEQUENCE CAN BE VERIFIED BY RUNNING
;	THE DATA THROUGH CRC, AND THEN RUNNING THE PREVIOUSLY OBTAINED
;	CHECKSUM THROUGH CRC. THE RESULTANT CHECKSUM SHOULD BE 0.
;
;	ENTRY	(CRCSUM) = CURRENT CHECKSUM
;		(A) = BYTE
;	EXIT	(CRCSUM) UPDATED
;		(A) UNCHANGED
;	USES	F

CRC	PUSH	B		; SAVE (BC)
	MVI	B,8		; (B) = BIT COUNT
	PUSH	H
	LHLD	CRCSUM
CRC1	RLC
	MOV	C,A		; (C) = BIT
	MOV	A,L
	ADD	A
	MOV	L,A
	MOV	A,H
	RAL
	MOV	H,A
	RAL
	XRA	C
	RRC
	JNC	CRC2		; IF NOT TO XOR
	MOV	A,H
	XRI	200Q
	MOV	H,A
	MOV A,L
	XRI	5Q
	MOV	L,A
CRC2	MOV	A,C
	DCR	B
	JNZ	CRC1		; IF MORE TO GO
	SHLD	CRCSUM
	POP	H		; RESTORE (HL)
	POP	B		; RESTORE (BC)
	RET			; EXIT

;	WNP - WRITE NEXT PAIR
;
;	WNP WRITE THE NEXT TWO BYTES TO THE CASSETTE DRIVE.
;
;	ENTRY	(H,L) = BYTES
;	EXIT	WRITTEN.
;	USES	A,F

WNP	MOV	A,H
	CALL	WNB
	MOV	A,L
;	JMP	WNB		; WRITE NEXT BYTE

;	WNB - WRITE NEXT BYTE
;
;	WNB WRITE THE NEXT BYTE TO THE CASSETTE TAPE.
;
;	ENTRY	(A) = BYTE
;	EXIT	NONE.
;	USES	F

WNB	PUSH	PSW
WNB1	CALL	TPXIT		; CHECK FOR #, READ STATUS
	ANI	USR.TXR
	JZ	WNB1		; IF MORE TO GO
	MVI	A,UCI.ER+UCI.TE ; ENABLE TRANSMITTER
	OUT	OP.TPC		; TURN ON TAPE
	POP	PSW
	OUT	OP.TPD		; OUTPUT DATA
	JMP	CRC		; COMPUTE CRC

;	LRA - LOCATE REGISTER ADDRESS
;
;	ENTRY	NONE.
;	EXIT	(A) = REGISTER INDEX
;		(H,L) = STORAGE ADDRESS
;		(D,E) = (0,A)
;	USES	A,D,E,H,L,F

LRA	LDA	REGI
LRA.	MOV	E,A
	MVI	D,0
	LHLD	REGPTR
	DAD	D		; (DE) = (REGPTR)+(REGI)
	RET

;	IOA - INPUT OCTAL NUMBER
;
;	ENTRY	(H,L) = ADDRESS OF RECEPTION DOUBLE BYTE.
;	EXIT	TO *RET* IF ERROK
;		TO *RET*+1 IF OK, VALUE IN MEMORY.
;	USES	A,B,E,H,C,F

IOA	CALL	IOB		; INPUT BYTE
	DCX	H

;	IOB - INPUT OCTAL BYTE.
;
;	READ ONE OCTAL BYTE FROM THE KEYSET.
;
;	ENTRY	(H,L) = ADDRESS OF BYTE TO HOLD VALUE
;		'C' SET IF FIRST DIGIT IN (A)
;	EXIT	TO *RET* IF ALL OK
;		TO *ERROR* IF ERROR
;	USES	A,D,E,H,L,F

IOB	MVI	D,3		; (D) = DIGIT COUNT
IOB1	CNC	RCK		; READ CONSOLE KEYSET

	CPI	8
	JNC	ERROR		; IF ILLEGAL DIGIT

	MOV	E,A		; (E) = VALUE
	MOV	A,M
	RLC			; SHIFT 3
	RLC
	RLC
	ANI	370Q
	ORA	E
	MOV	M,A		; REPLACE
	DCR	D
	JNZ	IOB1		; IF NOT DONE
	MVI	A,30/2		; BEEP FOR 30 MS
	JMP	HORN

;	DOD - DECODE FOR OCTAL DISPLAY
;
;	ENTRY	(H,L) = ADDRESS OF LED REFRESH AREA
;		(B) = *OR* PATTERN TO FORCE ON BARS OR PERIODS
;		(A) = OCTAL VALUE
;	EXIT	(H,L) = HEX DIGIT ADDRESS
;	USES	A,B,C,D,H,L

DOD	PUSH	D
	MVI	D,DODA/256
	MVI	C,3
DOD1	RAL			; LEFT 3 PLACES
	RAL
	RAL
	PUSH	PSW		; SAVE FOR NEXT DIGIT
	ANI	7
	ADI	LOW DODA	; HRJ was DODA#256
	MOV	E,A		; (D) = INDEX
	LDAX	D		; (A) = PATTERN
	XRA	B
	ANI	177Q
	XRA	B
	MOV	M,A		; SET IN MEMORY
	INX	H
	MOV	A,B
	RLC
	MOV	B,A
	POP	PSW		; (A) = VALUE
	DCR	C
	JNZ	DOD1		; IF MORE TO GO
	POP	D
	RET			; RETURN

;	UFD - UPDATE FRONT PANEL DISPLAYS.
;
;	UFD IS CALLED BY THE CLOCK INTERRUPT PROCESSOR WHEN IT IS
;	TIME TO UPDATE THE DISPLAY CONTENTS. CURRENTLY, THIS IS DONE
;	EVERY 32 INTERRUPTS, OR ABOUT 32 TIMES A SECOND.
;
;	ENTRY	(H,L) = ADDRESS OF REFCNT
;	EXIT	NONE
;	USES	ALL

UFD	MVI	A,UO.DDU
	ANA	B
	RNZ			; IF NOT TO HANDLE UPDATE

	MVI	L,LOW DSPROT	; HRJ was DSPROT#256
	MOV	A,M
	RLC
	MOV	M,A		; ROTATE PATTERN
	MOV	B,A
	INX	H
;	ERRNZ	DSPMOD-DSPROT-1	; code assumes DSPMOD follows DSPROT
	MOV	A,M		; (A) = DSPMOD
	ANI	2
	LHLD	ABUSS
	JZ	UFD1		; IF MEMORY

;	AM DISPLAYING REGISTERS

	CALL	LRA		; LOCATE REGISTER ADDRESS
	PUSH	H
	LXI	H,DSPA
	DAD	D		; (H,L) = ADDRESS OF REG NAME PATTERNS
	MOV	A,M
	INX	H
	MOV	H,M
	MOV	L,A		; (H,L) = REG NAME PATTERN
	XTHL
	ORA	H		; CLEAR 'Z'
	MOV	A,M
	INX	H
	MOV	H,M
	MOV	L,A		; (HL) = ADDRESS OF REGISTER PAIR CONTENTS

;	SETUP DISPLAY

UFD1	PUSH	PSW
	XCHG
	LXI	H,ALEDS
	MOV	A,D
	CALL	DOD		; FORMAT ABANK HIGH HALF
	MOV	A,E
	CALL	DOD		; FORMAT ABANK LOW HALF
	POP	PSW
	LDAX	D
	JZ	DOD		; IF MEMORY, DECODE BYTE VALUE

;	IS REGISTER, SET REGISTER NAME,

	MVI	M,377Q		; CLEAR DIGIT
	POP	H
	SHLD	DLEDS+1
	RET

;	RCK - READ CONSOLE KEYPAD.
;
;	RCK IS CALLED TO READ A KEYSTROKE FROM THE CONSOLE KEYPAD.
;	WHENEVER A KEY IS ACCEPTED.
;	RCK PERFORMS DEBOUNCING, AND AUTO-REPEAT. A *BIP* IS SOUNDED
;	WHEN A VALUE IS ACCEPTED.
;
;	KEY PAD VALUES:
;
;	1111 1110  -  0
;	1111 1100  -  1
;	1111 1010  -  2
;	1111 1000  -  3
;	1111 0110  -  4
;	1111 0100  -  5
;	1111 0010  -  6
;	1111 0000  -  7
;	1110 1111  -  8
;	1100 1111  -  9
;	1010 1111  -  +
;	1000 1111  -  -
;	0110 1111  -  *
;	0100 1111  -  /
;	0010 1111  0  #
;	0000 1111  -  .
;
;
;	ENTRY	NONE
;	EXIT	TO CALLER WHEN A KEY IS HIT
;		(A) = 0 - '0'
;		      1 - '1'
;		      2 - '2'
;		      3 - '3'
;		      4 - '4'
;		      5 - '5'
;		      6 - '6'
;		      7 - '7'
;		      8 - '8'
;		      9 - '9'
;		     10 - '+ '
;		     11 - '-'
;		     12 - '*'
;		     13 - '/'
;		     14 - '#'
;		     15 - '.'
;	USES	A,F

RCK	PUSH	H
	PUSH	B
	MVI	C,400/20	; WAIT 400 MS
	LXI	H,RCKA

RCK1	IN	IP.PAD		; INPUT PAD VALUE
	MOV	B,A		; (B) = VALUE
	MVI	A,20/2		; WAIT 20 MS
	CALL	DLY
	MOV	A,B
	CMP	M
	JNZ	RCK2		; HAVE A CHANGE
	DCR	C
	JNZ	RCK1		; WAIT N CYCLE

;	HAVE KEY VALUE

RCK2	MOV	M,A		; UPDATE RCKA
	XRI	376Q		; INVERT ALL BUT GROUP 0 FLAG
	RRC
	JNC	RCK3		; HIT BANK 0
	RRC
	RRC
	RRC
	RRC
	JNC	RCK1		; NO HIT AT ALL
RCK3	MOV	B,A		; (B) = CODE
	MVI	A,4/2
	CALL	HORN		; MAKE BIP
	MOV	A,B
	ANI	17Q
	POP	B
	POP	H
	RET			; RETURN

;	DISPLAY SEGMENT CODING:
;
;	BYTE = 76 5453 210
;
;	   1
;	  ---
;	6|   |2
;	 | 0 |
;	  ---
;	5|   |3
;	 |   |
;	  --- o7
;	   4

;	Register index to 7-segment pattern
;
;	NOTE: MiniH8 is inverse of H8

DSPA:	DW	675BH		; SP
	DW	636FH		; AF
	DW	7279H		; BC
	DW	733DH		; DE
	DW	706DH		; HL
	DW	3167H		; PC

;	Octal to 7-segment pattern
;
;	NOTE: MiniH8 is inverse of H8


DODA:	DB	7EH		; 0
	DB	0CH		; 1
	DB	37H		; 2
	DB	1FH		; 3
	DB	4DH		; 4
	DB	5BH		; 5
	DB	7BH		; 6
	DB	0EH		; 7
	DB	7FH		; 8
	DB	5FH		; 9
	
	DB	0		; One unused byte

;	I/O ROUTINES TO BE COPIED INTO AND USED IN RAM.
;
;	MUST CONTINUE TO 3777A FOR PROPER COPY.
;	THE TABLE MUST ALSO BE BACKWARDS TO THE FINAL RAM.

	ORG	0400H-7

PRSROM:	DB	1	; REFIND
	DB	0	; CTLFLG
	DB	0	; MFLAG
	DB	0	; DSPMOD
	DB	0	; DSPROT
	DB	10	; REGI
	DB	MI.RET




	ORG	0400H
;
;	Here is a modified version of Jon Chapman's
;	GWMON. Jumping here invokes the console monitor loop.
;	All initialization code has been moved to the main
;	PAM-8 section.
;
;	- gfr
;
;SM8085R1 -- GWMON-80 Small Monitor for 8085 SBC rev 1
;
;This customization uses the 8085's built-in serial I/O and
;is configured for the Glitch Works 8085 SBC rev 1 memory
;map. By Jon Chapman, Glitch Works.
;
;;Modified by Lee Hart for mini H8 - 9 Aug 2026
;;double semicolons denote changes from Jon Chapman's code
;;resume editing at ------------
;;
;; other double-semicolon edits by Glenn Roberts marked 'gfr'

;
;Hardware Equates
;
;;Mini H8 memory map, 27C256 32k ROM, jumper P3 in ROM position
;; ROM at 0-1FFFh, 8000-FFFF (0-1FFFh mirrors 8000-9FFFh)
;; RAM at 2000-7FFFh

; get console ready for I/O
;
GWMON	EQU	*

	XRA	A		;NUL in A
	CALL	COUT		;Clear the line
	
	LXI	H, SIGNON$	;SM signon
	CALL	PRTCLS
;
;WSTART -- Warm start routine
;
;Falls through to the command processor.
;
WSTART: LXI	SP,STACK	; Reload stack pointer

;
;SCP -- GWMON-80 Small Command Processor
;
;This is the small command processor for Glitch Works
;Monitor for 8080/8085/Z80 and compatible.
;


;
;CMDLP -- Small command processor loop
;
;Get a character from the console device and immediately 
;handle it by passing off to helper function.
;
;Falls through to ERROR if an invalid command is specified.
;
CMDLP:	LXI	H,WSTART	; (HL) = warm start address
	PUSH	H		; prime stack for RET

	LXI	H,PROMPT$	; console prompt
	CALL	PRTCLS		; print it
	CALL	CIN		; wait for single character
	ORI	20H		; allow lowercase input
;
;	Command dispatch
;
	LXI	H,CMDTAB-1
CMDLP1:	INX	H		; Point to next valid command char
	CMP	M		; match?
	JZ	RUNCMD		; yes, run command handler
	MOV	B,A		; save user entry
	MOV	A,M		; examine command
	ORA	A		; set flags
	MOV	A,B		; restore user entry
	INX	H		; Get past handler address
	INX	H
	JNZ	CMDLP1		; fall through if at end of table

;
;ERRMSG -- Print generic error message and abort
;
;Falls through to PRTERR.
;
ERRMSG:	LXI	H,ERR$		;Fall through to PRTERR

;
;PRTERR -- Print a null-terminated error string
;
;entry: HL contains pointer to start of null-terminated string
;exit: string at HL printed to console
;exit: program execution returned to command loop
;
PRTERR:	CALL	PRTCLS
	JMP	WSTART		;Warm start, restore SP

;
;RUNCMD -- Run a command handler from CMDTAB
;
;entry: H register points to command letter
;exit: control transferred to command handler
;
RUNCMD:	CALL	PRTSPC
	INX	H		;Point to low handler address
	MOV	E,M
	INX	H
	MOV	D,M
	XCHG
	PCHL

;
;GETADR -- Get a 16-bit address from the console
;
;pre: none
;post: HL contains address from console
;
GETADR:	CALL	GETHEX
	MOV	H,A
	CALL	GETHEX
	MOV	L,A
	RET

;
;GETHEX -- Get byte from console as hex
;
;Enter at GETHE2 with character in A register from EDTCMD.
;
;entry: none
;exit: A register contains byte from hex input
;exit: Carry flag set if non-hex character received
;
GETHEX:	CALL	CIN
GETHE2:	PUSH	H
	MOV	H,A
	CALL	CIN
	MOV	L,A
	CALL	HEXBYT
	POP	H
	JC	ERRMSG		;Invalid hex char, abort
	RET
;;end of INCLUDE 'SCP.INC'
					
;;	INCLUDE	'common.inc' (included inline)
;
;COMMON -- Functions Common to SM and XM
;
;These functions are used by both the SM and XM versions
;of GWMON-80.
;


;
;CIN -- Get a char from the console and echo
;
;Returns through COUT.
;
;entry: console device is initialized
; exit: received char is in A register
;		received char is echoed
;
CIN:	CALL	CINNE
	JMP	COUT

;
;HEXBYT -- Convert pair of ASCII characters to byte
;
;entry: H register contains high ASCII coded hex nybble
;		L register contains low ASCII coded hex nybble
; exit: A register contains converted byte
;		CY flag set if non-hex character input
;		Z flag set if conversion results in 0x00
;
HEXBYT:	MOV	A,H
	CALL	ASCHEX
	RC
	RLC
	RLC
	RLC
	RLC
	MOV	H,A
	MOV	A,L
	CALL	ASCHEX
	RC
	ORA	H
	RET

;
;ASCHEX -- Convert ASCII character to hex nybble
;
;entry: A register contains ASCII coded nybble
; exit: A register contains nybble
;		CY flag set if ASCII character is invalid hex
;
ASCHEX:	SUI	'0'		; remove ASCII bias
	RC			; Return error if less than 0
	CPI	10		; check for hex
	CMC			; Clear CY
	RM			; if [0..9] ... done
	ANI	01011111B	; Upper case
	SUI	'A'-'9'-1	; ASCII to hex bias
	CPI	16		; check for hexadecimal range
	CMC			; return error if >= 16
	RET

;
;HEXDMP -- Hex dump memory to console
;
;This routine prints the contents of memory starting at HL
;and ending at DE in 16-byte blocks.
;
;entry: HL register pair contains starting address
;		DE register pair contains ending address
; exit:	contents of memory printed to console
;
HEXDMP:	MVI	B,0		;Initialize B as completion flag

HEXDM1:	CALL	PRTADR
	MVI	C,16		;C = line loop counter
HEXDM2:	CALL	PRTSPC
	CALL	DMPLOC
	MOV	A,E		;A = low byte of end address
	CMP	L		;Compare current low byte
	JNZ	HEXDM3
	MOV	A,D		;A = high byte of end address
	CMP	H		;Compare current high byte
	JNZ	HEXDM3
	DCR	B		;B = nonzero, done

HEXDM3:	INX	H		;Increment current address pointer
	DCR	C
	JNZ	HEXDM2		;Print more lines

	MOV	A,B
	ORA	A
	JZ	HEXDM1		;Yes, dump more memory
	RET			;No, done

;
;PRTADR -- Print an address to the console
;
;Prints CR, LF, a 16-bit address, a space, and a colon. 
;Destroys A register contents.
;
;Returns through COUT.
;
;entry: HL pair contains address to print
; exit: HL printed to console as hex
;
PRTADR: CALL	CRLF
	MOV	A,H
	CALL	PRTHEX
	MOV	A,L
	CALL	PRTHEX
	MVI	A,':'
	JMP	COUT

;
;DMPLOC -- Print a byte at HL to console
;
;Falls through to PRTHEX.
;
;pre: HL pair contains address of byte
;post: byte at HL printed to console
;
DMPLOC:	MOV	A,M

;
;PRTHEX -- Output byte to console as hex
;
;Falls through to PRTNIB.
;
;entry: A register contains byte to be output
; exit: byte is output to console as hex
;
PRTHEX: PUSH	PSW		;Save A register on stack
	RRC			;Rotate high nybble down
	RRC
	RRC
	RRC
	CALL	PRTNIB		;Print high nybble
	POP	PSW		;Restore A register

;
;PRTNIB -- Print hex nybble on console
;
;Returns through COUT.
;
;entry: A register contains nybble
; exit: nybble printed to console
;
PRTNIB:	ANI	0FH		;Mask off low nybble
	ADI	90H
	DAA
	ACI	40H
	DAA
	JMP	COUT

;
;PRTSPC -- Print a space to the console
;
;Returns through COUT.
;
;pre: none
;post: ASCII space printed to console
;
PRTSPC:	MVI	A,' '
	JMP	COUT

;
;CRLF -- Print a CR, LF
;
;Returns through COUT.
;
;entry: none
; exit: CR, LF printed to console
;
CRLF:	MVI	A,CR
	CALL	COUT
	MVI	A,LF
	JMP	COUT
;
;PRTCLS -- Print CR, LF, and a high bit terminated string
;
;Falls through to PRTSTR
;
;entry: HL contains pointer to start of string
; exit: CR, LF, and string at HL printed to console
;
PRTCLS:	CALL	CRLF

;
;PRTSTR -- Print a high bit terminated string
;
;Destroys contents of A register.
;
;entry: HL contains pointer to start of string
; exit: string at HL printed to console
;
PRTSTR:	MOV	A, M
	ANI	07FH		;Strip high bit
	CALL	COUT
	MOV	A,M
	ORA	A		;Set flags
	RM			;High bit set, done
	INX	H
	JMP	PRTSTR
;;end of INCLUDE 'common.inc'

;; ---------------------
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Small Monitor Strings
;
;These strings are terminated by setting the high bit in the
;last character.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SIGNON$:	db 'GWMON-80 1.1 S', 'M' + 80H
PROMPT$:	db LF, '>' + 80H
CSERR$:		db 'CKSUM '
ERR$:		db 'ERRO', 'R' + 80H

;;end of INCLUDE 'sm.inc'

;;	INCLUDE	'scmdstd.inc'	;SM standard commands
;
;SCMDSTD -- Small Monitor Standard Commands
;
;This file contains implementations of all standard SM
;commands. The command table is located at the end of the
;file.
;

;
;HDCMD -- Hex dump command
;
HDCMD:	CALL	GETADR		;HL = start address
	XCHG			;DE = start address
	CALL	PRTSPC
	CALL	GETADR		;HL = end address
	XCHG			;HL = start, DE = end
	JMP	HEXDMP		;Return through HEXDMP

;
;EDTCMD -- Edit memory command
;
;Breaks out to main command loop through GETHEX jump to
;WSTART.
;
EDTCMD:	CALL	GETADR		;HL = address to open
EDTCM1:	CALL	PRTADR		;Print location address
	CALL	PRTSPC
	CALL	DMPLOC		;Print contents of location
	CALL	PRTSPC
	CALL	CIN		;Get user input
	CPI	NEXTLOC		;Check for NEXTLOC character
	JZ	EDTCM2		;Yes, go to next location
	CALL	GETHE2		;No, process as hex input
	MOV	M,A
	CALL	PRTSPC
	CALL	DMPLOC		;Print contents of location (verification)
EDTCM2:	INX	H
	JMP	EDTCM1

;
;GOCMD -- Call out to a specified address
;
;The stack is primed with the GWMON-80 warm start address.
;Called program can return control to GWMON-80 through a RET
;as long as the stack is not disturbed.
;
GOCMD:	CALL	GETADR		;HL = Address to call
	PCHL			;Go to specified address

;
;INPCMD -- Input to port command; print value to console
;
;	Revised to use PAM-8 port I/O routine
;		-gfr
;
INPCMD:	CALL	GETHEX		; Get port from console
	MOV	L,A		; save in (L)
	CALL	PRTSPC		; space separator
	CALL	IN		; input via PAM-8 IN routine
	JMP	PRTHEX		; display the result

;
;OUTCMD -- Output to port command
;
;	Revised to use PAM-8 port I/O routine
;		-gfr
;
OUTCMD:	CALL	GETHEX		; get port number
	MOV	L,A		; (L) = port
	CALL	PRTSPC		; space separator
	CALL	GETHEX		; get value to output
	MOV	H,A		; (H) = value
	JMP	OUT		; output via PAM-8 OUT routine

;
;LODCMD -- Load an Intel HEX file from console
;
;This loader accepts data with both CR (*NIX) and
;CR,LF (DOS/Windows) terminated lines.
;
;Intel HEX record may be ended with:
;   * DATA (0x00) record with length of 0
;   * Any nonzero record type
;
; exit: Intel HEX file loaded, or error printed
;
LODCMD:	CALL	CRLF
LODCM1:	CALL	CINNE
	CPI	':'
	JNZ	LODCM1		;Wait for start colon
	CALL	COUT		;Print start colon
	CALL	GETHEX		;Get record length
	JZ	LODCM4		;Length == 0, done
	MOV	B,A		;Record length in B
	MOV	C,A		;Start checksumming in C

	CALL	GETADR		;HL = 16-bit starting address
	ADD	C		;A == L from GETADR
	ADD	H
	MOV	C,A		;Checksum

	CALL	GETHEX		;Get record type
	JNZ	LODCM4		;Not Record Type 00 (DATA), done

LODCM2:	CALL	GETHEX		;This is the main record processing loop
	MOV	M,A		;Store char at HL
	ADD	C
	MOV	C,A		;Checksum
	INX	H		;Move memory pointer up
	DCR	B
	JNZ	LODCM2		;Not done with the line
LODCM3:	CALL	GETHEX		;Get checksum byte
	ADD	C
	JNZ	CSUMER		;Checksum bad, print error
	JMP	LODCMD		;Process more records
LODCM4:	CALL	CIN		;Done getting data, eat chars
	CPI	LF
	JNZ	LODCM4		;No LF, keep eating
	RET			;Got LF, return to command loop
CSUMER:	LXI	H,CSERR$	;Print checksum error to console
	JMP	PRTERR		;RET from ERROUT will return to command loop



;
;CMDTAB -- Table/array of commands
;
;This data *must* be the last item in SCMDSTD.INC to allow
;chaining of additional command tables.
;
;Table entry structure:
;    * Single command character, lowercase only
;    * Pointer to implementation routine
;
;The last entry should contain 0x00 for the command char and
;no additional address. It is provided in SCMDNULL.INC
;
CMDTAB:	db	'd'
	dw	HDCMD
	db	'e'
	dw	EDTCMD
	db	'g'
	dw	GOCMD
	db	'i'
	dw	INPCMD
	db	'l'
	dw	LODCMD
	db	'o'
	dw	OUTCMD

;;end of INCLUDE 'scmdstd.inc'

;;	INCLUDE	'scmdnull.inc'	;Command table terminator
;
;SCMDNULL -- SM NULL Command
;
;This should be the last command list included in a SM
;customization. It provides consistent termination to the
;command list.
;
NULCMD:	db	0
				;;end of INCLUDE 'scmdnull.inc'
;;---------------
;;	INCLUDE	'8085sio1.inc'	;Intel 8085 SID/SOD driver
;
;8085SIO1 -- Console I/O Drivers for 8085 Built-In Serial
;
;Use the SID and SOD pins on the Intel 8085 for bit-bang
;serial I/O. This driver uses fixed bitrate constants for 
;delay routines used to pace serial transmit/receive.
;
;Derived from Intel Application Note AP-29, August 1977.
;


;; IRQSET - set up interrupt vectors - gfr
;;
IRQSET:	MVI	A,00001011b	;; bit 2 unmask only RST 7.5)
	SIM			;; apply the mask
	EI			;; globally enable interrupts
	RET
	
;
;CINNE -- Get a char from the console, no echo
;
;entry: BITTIME, HALFBIT are initialized
; exit: received char is in A register
;
;; on mini H8 the serial line is LOW in idle state. start bit
;; indicated by low-to-high transition - gfr

CINNE:	PUSH	B		;Preserve registers
	PUSH	H
;
;	Here we just wait for a start bit. This should happen
;	before disabling interrupts - gfr
;
CI1:	RIM			; read RIN signal
	ANI	080h		; check for start bit
	JZ	CI1		; wait 'til we get one...
;
;	Incoming data... here we go!
;
	DI			;Must disable interrupts
	MVI	B,9		;Receive bits counter


	LXI	H,HALFBIT	;Delay one half-bit time, this puts
CI2:	DCR	L		;us in the middle of the start bit
	JNZ	CI2
	DCR	H
	JNZ	CI2
;;
;;	Now start reading the byte - gfr
;;
CI3:	LXI	H,BITTIME	;Delay one bit-time, since we are shifted
CI4:	DCR	L		;a half-bit time through the start bit, this
	JNZ	CI4		;will keep us in the middle of bits for
	DCR	H		;reliable sampling.
	JNZ	CI4

	RIM			;Read the SID line
	CMA			;; invert for mini H8 - gfr
	RAL			;;CY = data bit (invert for mini H8)
	DCR	B		;Determine if this is a stop bit
	JZ	CI5		;;Stop bit, done with char receive (invert H8)

	MOV	A,C		;Not done, rotate a bit in CY into C
	RAR
	MOV	C,A
	NOP			;Equalize COUT and CINNE loop times
	JMP	CI3		;Get more bits

CI5:	POP	H		;Restore HL
	MOV	A,C		;A = received character
	POP	B		;Restore BC
	EI
	CPI	CANCEL		;Check for CANCEL character
	JZ	WSTART		;Yes, warm start monitor
	RET

;
;COUT -- Output a character to the console
;
;This routine *must* preserve the contents of the A register
;or CIN will not function properly.
;
;Interrupts are disabled to maintain critical timing in this
;routine. They are unconditionally re-enabled before return.
;
;entry: A register contains char to be printed
;		BITTIME, HALFBIT are initialized
; exit: character is printed to the console
;		interrupts are enabled
;
COUT:	PUSH	PSW		;Preserve char in A
	PUSH	B		;Preserve registers
	PUSH	H
	DI			;Must disable interrupts
	MOV	C,A		;C = character to output
	XRA	A		;Clear CY
	MVI	B,10		;Bit count for entire serial transaction (10 - gfr)

CO1:	MVI	A,80H		;Set what will become SOD enable bit
	RAR			;Move CY into SOD data bit
	SIM			;Output it on SOD
	LXI	H,BITTIME	;Delay one bit time
CO2:	DCR	L
	JNZ	CO2
	DCR	H
	JNZ	CO2

	STC			;Set CY, will become stop bit	
	MOV	A,C		
	RAR			;Get a bit from the byte to output into CY
	MOV	C,A
	DCR	B		;Decrement bit count
	JNZ	CO1		;Not done, send more bits
		
	POP	H		;Restore registers
	POP	B
	EI

	POP	PSW		;A = char printed
	RET
;
;	PAM-8 uses the first 64 bytes of RAM for working space
;
;	THE FOLLOWING ARE CONTROL CELLS AND FLAGS USED BY THE KEYPAD
;	MONITOR.

	ORG	2000H	; 8192 = beginning of RAM
	
START	DS	2	; DUMP STARTING ADDRESS
;
;	These two bytes are updated in real time to be either
;	IN or OUT instructions and the associated port - gfr
;
IOWRK	DS	2	; IN OR OUT INSTRUCTION
;
;	The following locations are initialized from PRSROM - gfr
;
PRSRAM	DS	1	; RET (from IOWRK)

REGI	DS	1	; INDEX OF REGISTER UNDER DISPLAY
DSPROT	DS	1	; PERIOD FLAG BYTE
DSPMOD	DS	1	; DISPLAY MODE

MFLAG	DS	1	; USER FLAG OPTIONS
			; SEE *UI.XXX* BITS DESCRIBED AT FRONT

CTLFLG	DS	1	; FRONT PANEL CONTROL BITS
REFIND	DS	1	; REFRESH INDEX (0 TO 7)
PRSL	EQU	7	; END OF AREA INITIALIZED FROM ROM



FPLEDS			; FRONT PANEL LED PATTERNS
ALEDS	DS	1	; ADDR 0
	DS	1	; ADDR 1
	DS	1	; ADDR 2

	DS	1	; ADDR 3
	DS	1	; ADDR 4
	DS	1	; ADDR 5

DLEDS	DS	1	; DATA 0
	DS	1	; DATA 1
	DS	1	; DATA 2

ABUSS	DS	2	; ADDRESS BUS
RCKA	DS	1	; RCK SAVE AREA
CRCSUM	DS	2	; CRC-16 CHECKSUM
TPERRX	DS	2	; TAPE ERROR EXIT ADDRESS
TICCNT	DS	2	; CLOCK TIC COUNTER

REGPTR	DS	2	; REGISTER CONTENTS POINTER

UIVEC			; USER INTERRUPT VECTOR
	DS	3	; JUMP TO CLOCK PROCESSOR
	DS	3	; JUMP TO SINGLE STEP PROCESSOR
	DS	3	; JUMP TO I/O 3
	DS	3	; JUMP TO I/O 4
	DS	3	; JUMP TO I/O 5
	DS	3	; JUMP TO I/O 6
	DS	3	; JUMP TO I/O 7

PPSRAM	EQU	*

	END
