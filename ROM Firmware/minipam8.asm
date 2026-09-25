; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;
;	MiniPAM8 - monitor for H8 Mini
;	Rev. 0.9.1 Beta
;
;	This is a modified version of PAM/8, originally written by Gordon
;	Letwin 50 years ago! This version is designed to support Lee Hart's
;	"H8 Mini", which incorporates some hardware modifications to simplify
;	the design and allow it to run on single-board 8085-based computer
;	approximately 3" x 6" in size. This code uses 8085-specific instructions,
;	and for timing purposes assumes a 2Mhz CPU clock rate (4Mhz resonator).
;
;	A modified version of Jon Chapman's Glitch Works Monitor GWMON-80
;	has been added to support a console monitor, serial I/O routines, and
;	an ability to load Intel Hex files.
;
;	As with the original PAM/8 this consists of a set of interrupt-time and
;	task-time routines. The interrupt-time routines service the front
;	panel (7-segment LEDs and keypad). There are two options for task-time
;	processing: 1) the front panel or 2) the GWMON console.
;
;	Key changes over PAM/8:
;	- IRQ handling limited to the 3 hardware interrupts on the
;	  H8 Mini: 2ms Clock, RTM/0 and Serial I/O.
;
;	Modified from original Heath-compatible assembly code by Herb Johnson (HRJ)
;	for use with the A85 assembler, 25 July, 2026.
;
;	Other modifications/enhancements by Glenn Roberts (GFR),
;	August-September, 2026.
;
;	Revision History:
;	0.9.0	initial beta
;	0.9.1	added interrupt-driven console input buffer
;
; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;
;	Original comments from Gordon Letwin below (some no longer apply due
;	to hardware differences between the original H8 and the H8 Mini):
;
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
;	H8 Mini equates
;
;	8255 PPI at 0F0-0F3
;
PPI	EQU	0F0H
IO.A	EQU	0
IO.B	EQU	1
IO.C	EQU	2
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
				
STACK	equ	8000H		; Stack at top of RAM (32K for H8 Mini)

;
;	Keypad autorepeat delay (ARDLY) and debounce delay (DBDLY) in ms.
;
ARDLY	EQU	400
DBDLY	EQU	10

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

	INCLUDE	"u8251.asm"	; DEFINE THE 8251 USART BITS

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



;	Interrupt 5.5 - caused by RTM/0 key combination
;
;	On the original H8 RTM/0 generated a level 10 
;	interrupt - basically the clock handler. The CLOCK
;	routine would test for the RTM/0 combination and
;	drop back into the monitor.
;
;	The H8 Mini has its own direct interrupt handler for the
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
	
;	Interrupt 6.5 - Serial I/O
;

	ORG	64Q
	JMP	CINT		; jump directly to handler

	
;	Interrupt 7.5 - generated by 2ms clock
;
;	Every 2ms this interrupt updates the TICCNT counter,
;	then calls Refresh Front Panel (RFP), which refreshes
;	the LED display and checks for keypad hits.
;
	ORG	74Q
INT7.5	CALL	SAVALL		; save user registers
;
;	We need to do nested interrupt handling here, allowing the lower
;	priority (RST 6.5) serial line IRQ to interrupt the front panel
;	refresh. Without this serial data will be lost. First enable interrupts
;	and then specifically mask out the 7.5 ones to allow lower ones in
;
	EI			; ok to interrupt us
	MVI	A,00001101B	; enable RST 6.5 - serial start bit IRQ
	SIM			; apply the mask

	MVI	D,0		; needed for proper RFP execution
	JMP	CLOCK		; process clock interrupt

	ORG	53H
	
;	DLY - Delay time interval
;
;	This routine now lives at 053H (in PAM/8 was 053Q)
;	It is a much simplified version as HORN now done differently.
;
;	ENTRY:	(A) = (ms. delay count)/2
;
;	USES	A,F
;
DLY:	PUSH	H		; (HL) used for working storage
	LXI	H,TICCNT	; (M) = low byte of TICCNT
	ADD	M		; (A) = TICCNT + count (ignore wrap around)
;
;	wait required number of tick counts. Just loop here until
;	the interrupt-driven TICCNT number matches the right number.
;
DLY2:	CMP	M		; wait until ticks have passed
	JNZ	DLY2

	POP	H
	RET

;	CINT - serial I/O interrupt handler
;
;	This interrupt is triggered by a transition from low to high on the
;	SID line, which is an inverted version of the RX signal on the serial
;	input header. This transition indicates the start bit of a 10-bit sequence
;	(start bit, 8-bit data byte,and stop bit).
;
;	This handler first decodes the byte and stores it in a buffer by
;	first incrementing the buffer count and then adding the byte to the
;	tail of the buffer. The task-time code to read data can check the
;	byte count to see if there is any data in the buffer. Currently this
;	routine silently discards any overrun bytes.
;
;	Since the 2ms interrupt (RST 7.5) is a higher priority and involves
;	somewhat lengthy processing, its handler must yield for the RST 6.5
;	handler to process a byte even if it is in the middle of a clock update.
;
;	The SID and SOD pins on the Intel 8085 are used for bit-banged serial I/O.
;	The effective BAUD rate is set by fixed bit rate constants, which are used
;	to delay between bit samples. For more information consult Intel Application
;	Note AP-29, August 1977.
;
CINT:	PUSH	PSW
	PUSH	B
	PUSH	H
;
;	We know we have a start bit (that generated the interrupt). First
;	we delay 1/2 the bit time (HALFBIT). This puts us in the middle of the
;	start bit. Once we are thus shifted we just sample bits every BITTIME.
;	Use (C) to build the byte (not necessary to clear it as we will overwrite
;	all 8 bits). Use (B) to count the bits.
;
	MVI	B,9		; Received bits counter

	LXI	H,HALFBIT	; Delay one half-bit time
CI2:	DCR	L		; putting us in the middle of the start bit
	JNZ	CI2
	DCR	H
	JNZ	CI2
;
;	Loop over the bits
;
CI3:	LXI	H,BITTIME	; Delay one bit-time. puts us in the middle
CI4:	DCR	L		; of the next bit and will keep
	JNZ	CI4		; us in the middle of bits for
	DCR	H		; reliable sampling.
	JNZ	CI4

	RIM			; Read the SID line
	CMA			; invert it (for H8 Mini)
	RAL			; save the bit in the CY flag
	DCR	B		; decrement the bit counter
	JZ	CI5		; Stop bit, done with char receive!

	MOV	A,C		; get the byte under construction
	RAR			; rotate the bit into place
	MOV	C,A		; and save it
	NOP			; Equalize OUT and IN loop times
	JMP	CI3		; Get more bits
;
;	We now have all 8 bits in (C), store the byte in the buffer
;
CI5:	LXI	H,INBADDR	; (HL) = address of buffer
	CALL	$HLIHL		; (HL) = buffer
	LDA	INBLEN		; (A) = buffer length
	CMP	M		; see if there's room for more
	JC	CI6		; no, just ignore (should do more)
;
;	There's room to store the byte so process it
;
	INR	M		; bump the count
	MOV	A,M		; fetch the count
	ADD	L		; A = L + A
	MOV	L,A		; L += A; (HL) = address of character
	MOV	M,C		; store the character

CI6:	POP	H
	POP	B
	POP	PSW
	EI
	RET

;	PPSROM - PPI Setup code
;
;	Here we use a trick. This is the code to initialize the configuration
;	of the 8255 PPI. There is a catch 22 here because this will momentarily
;	disable the visibility of ROM in low memory. One solution would be to
;	copy the code to RAM and execute it there, but here we use a different
;	approach. The H8 Mini mirrors the low 8K of ROM to 32K,	so the routine is
;	visible at this location plus 32K. We will store it here but call it from
;	a location 8000H higher (PPS).
;
PPSROM:	MVI	A,10001000B	; all bits OUT except PC4..PC7
	OUT	PPI+CTRL
	MVI	A,00010000B	; make sure PA4 stays high (ROM/RAM line)
	OUT	PPI+IO.A
	RET

PPS	EQU	PPSROM+8000H	; where we will actually call it from


;	INIT - initialize system
;
;	INIT is called whenever a hardware master-clear is initiated.
;
;	Setup PAM/8 control cells in RAM.
;	Setup stackpointer, and
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
;	Show something interesting on the LEDs
;
	LXI	H,TICCNT	; Tick counter
	SHLD	ABUSS		; store it
;
;	The original PAM/8 determined the top of RAM by probing
;	every 1K for live RAM and then set the stack pointer
;	there. For the H8 Mini we assume a 32K RAM space and
;	set SP there.
;
	LXI	H,STACK		; Stack at top of RAM
INIT2:	DCX	H		; set to one minus memory limit
	SPHL			; set SP
	PUSH	H		; save *PC* value on stack
	LXI	H,ERROR		; ERROR = general bail out routine
	PUSH	H		; set as 'return address'
;
;	H8 Mini-specific Initializations
;
;	Call the PPI setup code from its "shadow" location 8000H higher
;
	CALL	PPS
;
;	Set up console serial interrupt handler values in RAM
;
	LXI	H,$INBUF	; (HL) = default input buffer
	SHLD	INBADDR		; save that location
	XRA	A		; clear serial I/O byte count
	MOV	M,A		; set byte count to 0
	MVI	A,$INBUFL	; buffer length
	STA	INBLEN		; save that too
;
;	Enable clock and console interrupts
;
	MVI	A,00001001B	; enable RST 7.5 (clock) and RST 6.5 (serial)
	SIM			; apply the mask
	EI			; globally enable interrupts
	
;
;	Use GWMON as main loop while we debug things...
;
	JMP	GWMON
	
;	JMP	SAVALL		; begin front panel monitor

;	Now just fall through to SAVALL and then return to the
;	general bailout routine ERROR.

;
;	SAVALL - save all registers on stack.
;
;	Called when an interrupt is accepted, in order to
;	save the contents of the registers on the stack.
;
;	ENTRY	called directly from the interrupt routine.
;	EXIT	all registers pushed on stack.
;		if not yet in monitor mode, REGPTR = address of registers
;		on stack.
;		(DE) = address of CTLFLG


SAVALL	XTHL			; set H,L on stack top
	PUSH	D
	PUSH	B
	PUSH	PSW
	XCHG			; (D,E) = return address
	LXI	H,10
	DAD	SP		; (H,L) = address of users SP
	PUSH	H		; set on stack as 'register'
	PUSH	D		; set return address
	LXI	D,CTLFLG
	LDAX	D		; (A) = CTLFLG
	CMA
	ANI	CB.MTL+CB.SSI	; save register addr if user or single-step
	RZ			; return if was interrupt or monitor loop
	LXI	H,2
	DAD	SP		; (H,L) = address of 'STACKPTR' on stack
	SHLD	REGPTR
	RET
;
;	INTXID - Return to program from interrupt.
;
INTXIT	POP	PSW		; remove fake 'stack register'
;
;	Make sure clock interrupts are enabled
;
	RIM			; Read interrupt mask
	ANI	00000011B	; leave 5.5 and 6.5 alone
	ORI	00001000B	; 7.5 LOW (interrupts on)
	SIM			; set new mask
	
	POP	PSW
	POP	B
	POP	D
	POP	H
	EI
	RET
;
;	CLOCK - process clock interrupt
;
;	Entered whenever a 2 millisecond clock interrupt is
;	processed.
;
;	TICCNT is incremented every interrupt, then fall
;	through to RFP to refresh front panel and PCK to
;	probe console keypad.
;
CLOCK	LHLD	TICCNT
	INX	H
	SHLD	TICCNT		; INCREMENT TICCOUNT

;	RFP - Refresh Front Panel (and probe keypad switches)
;
;	This code uses the 8255 PIA lines to do two things: 1) refresh the
;	front panel LEDs and 2) probe to detect front panel keypad closures.
;	This is called for every clock interrupt so it updates only one
;	7-segment LED unit at a time (working right to left).
;	The REFIND variable keeps track of the refresh index.
;
;	Since the H8 Mini makes dual purpose of the PA0..PA3 lines
;	to both select LEDS and switches, it makes sense to simultaneously
;	scan for keyswitch closures.
;
;	ENTRY: 	calling program should set (D) = 0
;
RFP	LXI	H,MFLAG		; ((HL)) = MFLAG
	MOV	A,M		; (A) = current MFLAG value
	MOV	B,A		; save it in (B)
	ANI	UO.NFR		; Test No Front Refresh bit
	INX	H		; code assumes CTLFLG follows MFLAG

	MOV	A,M		; (A) = CTLFLG
	MOV	C,D		; (C) = 0 in case no panel refresh
;
;	The original PAM/8 had an ability to skip over front panel
;	refresh to save CPU time, but since the keypad scan is now
;	accomplished that way we have to be careful. For now 
;	disable this capability. We may be able to re-introduce it
;	differently later...
;
;	JNZ	CLK3		; NFR bit was set - no refresh

	INX	H		; code assumes REFIND follows CTLFLG
;
;	Here (HL) points to the refresh index (REFIND). Since the front
;	panel LED pattern bytes (FPLEDS) immediately follow that location
;	they are indexed from 1 to 9. REFIND was initialized to 1 at startup.
;
	DCR	M		; decrement digit index
	JNZ	CLK2		; still positive, keep going
;
;	A little housekeeping for the upcoming keypad scan: Starting a new
;	refresh cycle. Get ready for a new round of keypad scans:
;	set PCKTMP to 0FFH
;
	MVI	A,0FFH		; default to return if no keys pressed
	STA	PCKTMP		; after scanning all 9.
	
	MVI	M,9		; loop continuously counting down from 9
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
;
;	PCK - Probe Console Keypad
;
;	While we have this line selected we can probe for switch closures by
;	examining PC4..PC7. These input lines are matrixed with the various
;	key switches. If a key is pressed the appropriate value is stored in PCKTMP,
;	per the table below. PCKTMP is initally set to "no key pressed" (0FFH) when
;	the scan cycle begins.
;
;	If no key is pressed on this pass we continue scanning with next clock interrupt.
;	After 9 scans the value of PCKTMP is "published" to PCKVAL, where it can be
;	read by the RCK routine. If no key was pressed during the 9 cycles then
;	PCKVAL will be 0FFH.
;
;	Key Values to be returned in PCKVAL:
;
;	Key	  Value (decimal)
;	0-9		0-9
;	'+'		10
;	'-'		11
;	'*'		12
;	'/'		13
;	'#'		14
;	'.'		15
;     <no key>		255
;
PCK:	PUSH	B		; using B for scratch
;
;	PC4..PC7 are four input lines on the PPI chip that are matrixed
;	with the various switches.
;
;	PC4	KNUM	Active "low"; Number [1..9]
;	PC5	KMATH	Active "low"; '.', '*', '-', '+'
;	PC6	KR	Active "high";'/' (RST)
;	PC7	K0	Active "high", '0'
;
	IN	PPI+IO.C	; read PC4..PC7
	XRI	00110000B	; make all signals "active high"
	MOV	B,A		; keep a copy
	ANI	KR		; check for '/'
	JNZ	PCKR		; pressed, jump
	
	MOV	A,B		; restore reading
	ANI	K0		; check for '0'
	JNZ	PCKZ		; pressed, jump
	
	MOV	A,B		; restore reading
	ANI	KNUM		; check for [1..9]
	JNZ	PCKN
	
	MOV	A,B		; restore reading
	ANI	KMATH		; check for '.', '*', '-', '+'
	JZ	PCKQ		; no match to any, skip to end
;
;	A "math" key pressed ('#', '.', '*', '-' or '+')
;
;	First we need to test whether this came from the SM ('#')
;	switch. To test that we need to momentarily turn off all refresh
;	lines (LED segments will briefly extinguish).
;
PCKM:	IN	PPI+IO.A	; read Port A status
	MOV	C,A		; save it (for restoration later)
	ANI	11110000B	; clear refresh lines
	OUT	PPI+IO.A	; turn off all lines
	IN	PPI+IO.C	; re-read the inputs
	MOV	B,A		; save it
;
;	now immediately turn the LEDs back on (hopefully nobody noticed!)
;	
	MOV	A,C		; get back desired line state
	OUT	PPI+IO.A	; select it
	
	MOV	A,B		; now let's see if KMATH was asserted
	ANI	KMATH		; (remember "low" = key pressed)
	JNZ	PCKM1		; "high" -> no key pressed (not SM)
	MVI	A,14		; "low" -> SM ('#') key was pressed
	JMP	PCK1		; done!
;
;	Set key value according to original PAM/8 scheme:
; E = 1:	'.'	15
; E = 2:	'*'	12
; E = 3:	'-'	11
; E = 4:	'+'	10
;
; for E = 2, 3 or 4 just subtract from 14. E = 1 is special case
;
PCKM1:	MVI	A,14
	SUB	E		; A = 14 - (E)
	CPI	13		; 13 should be 15
	JC	PCK1		; <13 is OK
	ADI	2		; make the adjustment
	JMP	PCK1
;
;	RST ('/') pressed
;
PCKR:	MVI	A,13		; '/' = 13
	JMP	PCK1		; done
;
;	'0' pressed
;
PCKZ:	XRA	A		; '0' = 0
	JMP	PCK1		; done
;
;	'1' through '9' pressed
;
PCKN:	MOV	A,E		; return the scan number
	JMP	PCK1		; done
;
;	Come here with (A) = keycode if key press was detected
;
PCK1:	STA	PCKTMP		; save the key value


PCKQ:	POP	B		; restore B, and done ...
	DCR	E		; set 'Z' flag
	JNZ	PCKX		; not done yet
;
;	Done with 9 scans, move "temp" value to actual
;
	LDA	PCKTMP		; load our scratch copy
	STA	PCKVAL		; make it official
;
;	End of keypad processing
;
PCKX	EQU	*
;
;	See if time to decode display values
;
	LXI	H,TICCNT	; check the clock
	MOV	A,M		; low byte only
	ANI	31		; multiple of 32?
;
;	every 32 interrupts update the front panel and
;	check for key presses
;
	CZ	UFD		; Update front panel display
;
;	Exit clock interrupt
;
;	For now simply exit here. Code that follows is to handle
;	processing of HLT instructions
;
	JMP	INTXIT


;	LXI	B,CTLFLG
;	LDAX	B		; (A) = CTLFLG
;	ANI	CB.MTL
;	JNZ	INTXIT		; IF IN MONITOR CODE
;	DCX	B
;	ERRNZ	CTLFLG-MFLAG-1	; code assumes CTLFLG follows MFLAG
;	LDAX	B		; (A) = MFLAG
;	ERRNZ	UO.HLT-200Q	; ASSUME HIGH-ORDER
;	RAL
;	JC	CLK4		; SKIP IT

;	NOT IN MONITOR MODE, CHECK FOR HALT

;	MVI	A,10		; (A) = INDEX OF *P* REG
;	CALL	LRA.		; LOCATE REGISTER ADDRESS
;	MOV	E,M
;	INX	H
;	MOV	D,M		; (D,E) = PC CONTENTS
;	DCX	D
;	LDAX	D
;	CPI	MI.HLT		; CHECK FOR HALT
;	JZ	ERROR		; IF HALT, BE IN MONITOR MODE

;	CHECK FOR 'RETURN TO MONITOR' KEY ENTRY.
;CLK4	EQU	*
;	 IN	 IP.PAD
;	 CPI	 56Q		 ; SEE IF '0' AND '#'
;	 JNZ	 CUI1		 ; IF NOT, ALLOW USER PROCESSING OF CLOCK

;	ERROR - Command error or general bail out
;
;	Error is called as a 'bail-out' routine.
;
;	It resets the operational mode, and restores the stackpointer.
;
;	ENTRY	NONE
;	EXIT	TO MTR LOOP
;		CTLFLG SET
;		MFLAG CLEARED
;	USES	ALL

ERROR:	LXI	H,MFLAG
	MOV	A,M		; (A) = MFLAG
	ANI	377Q-UO.DDU-UO.NFR ; Re-enable displays
	MOV	M,A		; replace
	INX	H		; next point to CTLFLG
	MVI	M,CB.SSI+CB.MTL+CB.CLI+CB.SPK ; Restore *CTLFLG*
;	ERRNZ	CTLFLG-MFLAG-1	; code assumes CTLFLG follows MFLAG
	EI
	LHLD	REGPTR
	SPHL			; Restore stack pointer to empty state
	CALL	ALARM		; Alarm for 200 ms
;	JMP	MTR

; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;
;	MTR - Monitor Loop.
;
;	This is the main executive loop for the front panel emulator.
;
; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
MTR:	EI

MTR1:	LXI	H,MTR1		; set top of the monitor loop
	PUSH	H		; as return address
	LXI	B,DSPMOD	; (BC) = #DSPMOD
	LDAX	B		; (A) = DSPMOD
	ANI	1		; (A) = 1 if in alter mode
;	CMA			; H8 Mini uses opposite sense - gfr
	STA	DSPROT		; rotate LED periods if alter
;
;	Read a key from the keypad and take appropriate action
;
	CALL	RCK		; read console keypad
	LHLD	ABUSS		; (HL) = ABUSS
	CPI	10		; test for [0..9]
	JNC	MTR4		; everything else is "always valid"
	MOV	E,A		; save RCK result
	LDAX	B		; (A) = DSPMOD
	RRC			; move low bit to CY
	JC	MTR5		; if in alter mode
	MOV	A,E		; (A) = code
;
;	"Always Valid": have a command (not a value)
;
MTR4	SUI	4		; Offset so "Go" is zero
	JC	ERROR		; if bad
	MOV	E,A		; save it
	PUSH	H		; save ABUSS value
	LXI	H,MTRA		; point to dispatch table
	MVI	D,0		; (DE) = offset
	DAD	D		; (HL) = address of table entry
	MOV	E,M		; (DE) = offset to processor
	DAD	D		; (HL) = address of processor
;
;	Prepare to dispatch to processor. Put dispatch address on the
;	stack (RET will jump there), point DE to REG Index, set
;	'Z' if memory and load A with DSPMOD
;
	XTHL			; set address, (HL) = (ABUSS)
	LXI	D,REGI		; (DE) = address of reg index
	LDAX	B		; (A) = DSPMOD
	ANI	2		; set 'Z' if memory
	LDAX	B		; (A) = DSPMOD
	RET			; jump to processor
;
;	Command dispatch table (NOTE single byte offsets so
;	it is important that the dispatch routine not be farther away than
;	256 bytes)
;
MTRA:	DB	GO-$		; 4 - go
	DB	IN- $		; 5 - input
	DB	OUT-$		; 6 - output
	DB	SSTEP-$		; 7 - single step
	DB	ABORT-$		; 8 - cassette load (N/A)
	DB	ABORT-$		; 9 - cassette dump (N/A)
	DB	NEXT-$		; + - next
	DB	LAST-$		; - - last
	DB	ABORT-$		; * - abort
	DB	RW-$		; / - display/alter
	DB	MEMM-$		; # - memory mode
	DB	REGM-$		; . - register mode

;	Process memory/register alterations.
;
;	This code is entered if
;
;	1) we are in alter mode, and
;	2) a key from 0-7 was entered.

MTR5	RRC
	MOV	A,E		; (A) = U
	JC	MTR6		; is register
	STC			; indicate 1st digit is in (A)
	CALL	IOB		; input octal byte
	INX	H		; display next location

;	SAE - Store ABUSS and exit.
;
;	ENTRY:	(HL) = ABUSS value
;	EXIT:	to (RET)
;	USES:	NONE
;
SAE	SHLD	ABUSS
	RET
;
;	alter register
;
MTR6	PUSH	PSW		; save code
	CALL	LRA		; locate register address
	ANA	A
	JZ	ERROR		; not allowed to alter stackpointer
	INX	H
	POP	PSW		; restore value and carry flag
	JMP	IOA		; input octal address
;
;	REGM - enter register display mode.
;
;	ENTRY:	(A) = DSPMOD
;		(BC) = #DSPMOD
;
REGM	MVI	A,00000010B	; Set dispolay to register mode
	STAX	B		; set display register mode
;	ERRNZ	DSPMOD-DSPROT-1	; code assumesDSPMOD follows DSPROT
	DCX	B		; (BC) = #DSPROT
	XRA	A
	CMA			; H8 Mini uses '1' for LED segment on - gfr
	STAX	B		; set all periods on
	CALL	RCK		; read key entry
	DCR	A		; displace
	CPI	6
	JNC	ERROR		; not 1-6
	RLC
	STAX	D		; set new reg ind
	RET

;	RW - toggle display/alter mode.
;
;	ENTRY	(A) = DSPMOD
;		(BC) = ADDRESS OF DSPMOD

RW	XRI	1
	STAX	B
	RET

;	NEXT - Increment display element
;
;	ENTRY	(HL) = (ABUSS)
;		(DE) = address of REGIND
;
NEXT	INX	H
	JZ	SAE		; if memory, store values and exit
;
;	Is register mode.
;
	LDAX	D		; (A) = REGI
	ADI	2		; increment register index
	STAX	D		; wrap to *SP*
	CPI	12
	RC			; if not too large, exit
	XRA	A		; overflow
	STAX	D
ABORT	RET

;	LAST - Increment display element
;
;	ENTRY	(HL) = (ABUSS)
;		(DE) = address of REGIND
;
LAST	DCX	H
	JZ	SAE		; if memory, store and exit
;
;	Is register mode
;
LST2	LDAX	D		; (A) = REGI
	SUI	2
	STAX	D
	RNC			; If OK
	MVI	A,10		; Underflow to *PC*
	STAX	D
	RET
;
;	MEMM - Enter display memory mode
;
;	ENTRY	(BC) = Address of DSPMOD
;
MEMM	XRA	A		; (A) = 0
	STAX	B		; set display memory mode
;	ERRNZ	DSPMOD-DSPROT-1	; code assumes DSPMOD follows DSPROT
	DCX	B		; (BC) = #DSPROT
	CMA			; H8 Mini uses '1' for 
	STAX	B		; set all periods on
	LXI	H,ABUSS+1
	JMP	IOA		; input octal address

;	IN - Input a data byte
;
;	OUT - Output a data byte
;
;	ENTRY:	(HL) = (ABUSS)
;		(H) = value (for OUT)
;		(L) = port
;
;	EXIT:	ABUSS updated
;		(A) = value (for IN)
;
IN	MVI	B,MI.IN		; Store the IN instruction in RAM
	DB	MI.LXID		; clever trick (skip over 'OUT' if doing 'IN')
OUT	MVI	B,MI.OUT	; store the OUT instruction in RAM
	MOV	A,H		; (A) = value
	MOV	H,L		; (H) = port
	MOV	L,B		; (L) = IN/OUT instruction
	SHLD	IOWRK		; Store instruction and port
	CALL	IOWRK		; do the actual I/O call
	MOV	L,H		; (L) = port
	MOV	H,A		; (H) = value
	JMP	SAE		; store ABUSS and exit
;
;	GO - return to user mode
;
;	ENTRY	NONE

GO	MVI     A,CB.SSI+CB.CLI+CB.SPK ; off monitor mode light
        JMP     SST1            ; return to user program


;	SSTEP - SINGLE STEP INSTRUCTION
;
;	ENTRY	NONE

SSTEP:	DI			; disable interrupts until the right time
	LDA	CTLFLG
	XRI	CB.SSI		; clear single step inhibit
	OUT	OP.CTL		; prime single step interrupt

SST1	STA	CTLFLG		; set new flag values
	POP	H		; clean stack
	JMP	INTXIT		; return to user routine for step
;
;	STPRTN - Single step return
;
STPRTN:	ORI	CB.SSI		; disable single step interruption
	OUT	OP.CTL		; turn off single step enable
	STAX	D
	ANI	CB.MTL		; see if in monitor mode
	JNZ	MTR
	JMP	UIVEC+3		; transfer to user's routine
;
;	HORN - make noise
;
;	This routine works completely differently than the PAM/8
;	version. The H8 Mini has to continuously toggle the speaker to
;	generate a tone (the H8 just has to turn on/off a 1kHz square wave).
;	For best results interrupts should be disabled (2ms clock interrupts
;	will otherwise affect the sound).
;
;	To be compatible with the H8 we play "high" C (C6) at 1046.5 Hz.
;
;	ENTRY	(A) = duration (ms.)
;
;	USES	A,F
;
ALARM:	MVI	A,200		; 200 ms. beep

HORN:	PUSH	B		; BC used for working storage
	MOV	C,A		; C = duration
	DI			; interrupts off
	CALL	BLANK		; blank the LEDs
;
;	Set speaker to "high" state
;
	IN	PPI+IO.A	; Read Port A settings
	ANI	00111111B	; Clear top two bits (PA6-7)
	ORI	10000000B	; PA7 on; PA6 off
	OUT	PPI+IO.A	; set speaker bits
;
;	Play the tone
;
HDLY1:	MVI	B,53		; half period
;
;	9 uS delay loop
;
HDLY2:	NOP			; 4 T-states
	DCR	B		; 4 T-states
	JNZ	HDLY2		; 10 T-states
;
;	Toggle the speaker
;
	IN	PPI+IO.A	; Read Port A settings
	XRI	11000000B	; toggle PA6, PA7
	OUT	PPI+IO.A	; set speaker bits
	RAL			; test bit 7
	JC	HDLY1		; now wait the other half period
	
	DCR	C		; decrement duration counter
	JNZ	HDLY1		; repeat cycle 'til done
	
	EI
	POP	B
	RET


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
;		(B) = MFLAG 	(gfr)
;
;	EXIT	NONE
;	USES	ALL

UFD	MVI	A,UO.DDU	; Disable Display Update
	ANA	B		; in MFLAG?
	RNZ			; IF NOT TO HANDLE UPDATE

	MVI	L,LOW DSPROT	; (HL) = DSPROT (same page)
	MOV	A,M		; fetch period pattern
	RLC			; rotate it left
	MOV	M,A		; and save
	MOV	B,A
	INX	H		; now point to DSPMOD
;	ERRNZ	DSPMOD-DSPROT-1	; code assumes DSPMOD follows DSPROT
	MOV	A,M		; (A) = DSPMOD
	ANI	00000010B	; Memory display mode?
	LHLD	ABUSS
	JZ	UFD1		; IF MEMORY

;	Displaying registers

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

;	Displaying Memory

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

	MVI	M,0		; CLEAR DIGIT - gfr
	POP	H
	SHLD	DLEDS+1
	RET

;	$HLIHL - Load HL indirect through HL
;
;	(HL) = ((HL))
;
;	USES:	A,H,L
$HLIHL:	MOV	A,M
	INX	H
	MOV	H,M
	MOV	L,A
	RET

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
;;Modified by Lee Hart for H8 Mini - 9 Aug 2026
;;double semicolons denote changes from Jon Chapman's code
;;resume editing at ------------
;;
;
;Hardware Equates
;
;;H8 Mini memory map, 27C256 32k ROM, jumper P3 in ROM position
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
SIGNON$:	DB 'GWMON-80 1.1 S', 'M' + 80H
PROMPT$:	DB LF, '>' + 80H
CSERR$:		DB 'CKSUM '
ERR$:		DB 'ERRO', 'R' + 80H

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
; First suspend all clock interrupts (RST 7.5) and clear LEDs. We leave
; other interrupts running in anticipation of interrupt-driven serial
; I/O in the future.
;
LODCMD:	RIM			; Read interrupt mask
	ANI	00000011B	; leave 5.5 and 6.5 alone
	ORI	00001100B	; 7.5 HIGH (interrupts off)
	SIM			; set new mask
	
	CALL	BLANK		; blank the LEDs
;
;	Loop over records
;
LODCM0:	CALL	CRLF		; start a new ouput line
LODCM1:	CALL	CINNE		; read a byte
	CPI	':'		; all records start with ':'
	JNZ	LODCM1		; Wait for start colon
;
;	Have new record
;
	CALL	COUT		; Print starting colon
	CALL	GETHEX		; Get record length
	JZ	LODCM4		; Length == 0, done
	MOV	B,A		; Record length in B
	MOV	C,A		; Start checksumming in C

	CALL	GETADR		; HL = 16-bit starting address
	ADD	C		; A == L from GETADR
	ADD	H
	MOV	C,A		; Checksum

	CALL	GETHEX		; Get record type
	JNZ	LODCM4		; Not Record Type 00 (DATA), done
;
;	Process the record
;
LODCM2:	CALL	GETHEX		; This record processing loop
	MOV	M,A		; Store char at HL
	ADD	C
	MOV	C,A		; update checksum
	INX	H		; point to next destination
	DCR	B		; decrement the line count
	JNZ	LODCM2		; Not done with the line
	
LODCM3:	CALL	GETHEX		; Get checksum byte
	ADD	C
	JNZ	CSUMER		; Checksum bad, print error
	JMP	LODCM0		; Process more records
;
;	Done getting data, eat remaining characters.
;
LODCM4:	CALL	CIN		; grab a byte
	CPI	LF		; end of line?
	JNZ	LODCM4		; No LF, keep eating
	JMP	LODEXT		; Got LF, done!
;
;	Checksum error
;
CSUMER:	LXI	H,CSERR$	; Print checksum error to console
	CALL	PRTERR
;
;	Exit, reenable clock interrupts and LED refresh.
;
LODEXT:	RIM			; Read interrupt mask
	ANI	00000011B	; leave 5.5 and 6.5 alone
	ORI	00001000B	; 7.5 LOW (interrupts on)
	SIM			; set new mask

	LDA	MFLAG		; get MFLAG byte
	ANI	377Q-UO.NFR	; turn on FP refresh
	STA	MFLAG		; save it
	RET			; and done...

;
;	CMDTAB -- Table/array of commands
;
;	Table entry structure:
;	  * Single command character, lowercase only (0x00 = end)
;	  * Pointer to implementation routine
;
CMDTAB:	DB	'd'
	DW	HDCMD
	DB	'e'
	DW	EDTCMD
	DB	'g'
	DW	GOCMD
	DB	'i'
	DW	INPCMD
	DB	'l'
	DW	LODCMD
	DB	'o'
	DW	OUTCMD
	
NULCMD:	DB	0		; terminate command list

				;;end of INCLUDE 'scmdnull.inc'
;;---------------
;;	INCLUDE	'8085sio1.inc'	;Intel 8085 SID/SOD driver
;
;8085SIO1 -- Console I/O Drivers for 8085 Built-In Serial
;
;

	
;
;	CINNE -- Get a char from the console, no echo
;
;	This is a blocking read. We wait until a character is available.
;	Since serial I/O is interrupt-driven we simply look to see if
;	a byte is available. If not, we wait otherwise retrieve the byte
;	and shift the buffer contents down one. We put interrupts on hold
;	while we're playing with these values.
;
CINNE:	PUSH	H
	PUSH	B
	
	LXI	H,INBADDR	; (HL) = address of buffer location
	CALL	$HLIHL		; (HL) = buffer
CINN1:	MOV	A,M		; get byte count
	ORA	A		; test for zero
	JZ	CINN1		; loop if nothing there
;
;	we have a byte in the buffer! - load it and return
;
	DI			; don't step on the IRQ handler
	
	DCR	M		; decrement the byte count
	MOV	C,M		; (C) = count - 1
	INX	H		; point to byte to be read
	MOV	B,M		; (B) = character we want
	
CINN2:	DCR	C		; move others down
	JM	CINN3		; no more
	INX	H		; next one
	MOV	A,M		; fetch it
	DCX	H		; back one
	MOV	M,A		; store it
	INX	H		; fix pointer
	JMP	CINN2		; and loop
	
CINN3:	EI			; restore interrupts
	MOV	A,B		; get back our byte
	
	POP	B
	POP	H
	
	CPI	CANCEL		; Check for CANCEL character
	JZ	WSTART		; Yes, warm start monitor
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

;	END GWMON Code

;
;	BLANK - ensure that all LED segments are extinguished.
;
;	This is useful when interrupts are disabled for any noticeable period of
;	time, otherwise some LED segments will appear to be "stuck" on (as the
;	interrupt-driven refresh cycle was stopped mid refresh.)  Typically
;	immediately preceded by a DI instruction.
;
;	USES:	A,F
;
BLANK:	PUSH	B		; BC used for working storage

	IN	PPI+IO.A	; read port A settings
	ANI	11110000B	; clear LED selects (PA0..PA3)
	MOV	B,A		; save it
	MVI	C,9		; 9 LEDs, work right to left
BLOOP:	ADD	C		; address an LED
	OUT	PPI+IO.A	; select it
	XRA	A		; zero = all segments off
	OUT	PPI+IO.B	; turn off all segments
	MOV	A,B		; get back mask
	DCR	C		; count down
	JNZ	BLOOP		; and loop through all 9

	POP	B
	RET


;	DLYNOI - Delay with No Interrupts. Delays the specified number of
;	2ms intervals, e.g. if A = 100/2 then delay 100 ms.
;
;	Functionally equivalent to the original Heath DLY routine
;	but for use when interrupts are disabled. Uses simple nested
;	loop counters to delay.
;
;	Timing parameters are tuned for an 8085 running at 2Mhz.
;
;	USES:	A,F
;
; =====================================================================
DLYNOI:	PUSH	B		; BC used for working storage
	MOV	B,A		; B = outer loop counter
;
;	Each inner loop takes 18 T-states or 9 uS of time. 222 repetitions
;	gives 1,998 uS of time.
;
OUTER:	MVI	C,222		; 222 * 9 ~= 2 ms
INNER:	NOP			; kill time (4 T-states)
	DCR	C		; decrement inner counter (4 T-states)
	JNZ	INNER		; count down (10 T-states each jump)
	
	DCR	B		; decrement outer counter
	JNZ	OUTER		; loop 'til done
	
	POP	B		; restore BC
	RET

;	RCK - Read Console Keypad
;
;	RCK is called to read a keystroke from the console keypad.
;	Read operations are blocking - the routine will wait until a key
;	is pressed before returning.
;
;	This version differs substantially from the original PAM/8 version.
;	The H8 Mini multiplexes the LED panel refresh with keypad reads. Reading a
;	keystroke, therefore, is broken into two components: an interrupt-time
;	service routine (PCK) and a task-time routine to return the result (RCK).
;	Probe Console Keypad (PCK) is called at each 2ms interrupt, however it takes
;	9 calls to scan all possible keys, therefore it can take up to 18ms to
;	detect and return a keystroke.
;
;	RCK performs debouncing, and auto-repeat. a *bip* is sounded
;	when a value is accepted.
;
;	EXIT:	Key value in (A):
;
;	Key	  Value (decimal)
;	0-9		0-9
;	'+'		10
;	'-'		11
;	'*'		12
;	'/'		13
;	'#'		14
;	'.'		15
;
;	USES	A,F
;
RCK:	PUSH	H
	PUSH	B
	
	MVI	C,ARDLY/DBDLY	; loop for auto-repeat
	LXI	H,RCKA		; point to keypad byte
;
;	First wait for some keyboard action
;
RCK1:	LDA	PCKVAL		; get most recent key hit
	MOV	B,A		; save it
	MVI	A,DBDLY/2	; delay to debounce
	CALL	DLY
	MOV	A,B		; get back candidate
	
	CMP	M		; compare to RCKA
	JNZ	RCK2		; have a change
	DCR	C		; wait N cycles (auto repeat)
	JNZ	RCK1		; changed, start over

RCK2:	MOV	M,A
	ORA	A		; set flag bits
	JM	RCK1		; bit 7 set... no key pressed
;
;	have a key
;	
;
;	Make noise here...
;
	ANI	17Q		; make sure it's 4 bits
	
	POP	B
	POP	H
	RET

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
;	NOTE: H8 Mini is inverse of H8

DSPA:	DW	675BH		; SP
	DW	636FH		; AF
	DW	7279H		; BC
	DW	733DH		; DE
	DW	706DH		; HL
	DW	3167H		; PC

;	Octal to 7-segment pattern
;
;	NOTE: H8 Mini is inverse of H8


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

; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;
;	Tape routines from PAM/8 - these are specific to the H8 hardware
;	and need to be either removed or rewritten 
;	
;
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

;	RMEM - LOAD MEMORY FROM TAPE
;

RMEM	LXI	H,TPABT
	SHLD	TPERRX		; SETUP ERROR EXIT ADDRESS
	JMP	LOAD

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



;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;
;	RAM storage
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

	ORG	2000H	; 8192 = beginning of RAM

;
;	PAM-8 uses the first 64 bytes of RAM for working space
;
;	THE FOLLOWING ARE CONTROL CELLS AND FLAGS USED BY THE KEYPAD
;	MONITOR.
	
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

;
;	REGI:	2	AF
;		4	BC
;		6	DE
;		8	HL
;		A	Pc
;
REGI	DS	1	; INDEX OF REGISTER UNDER DISPLAY
DSPROT	DS	1	; PERIOD FLAG BYTE
DSPMOD	DS	1	; DISPLAY MODE (if bit 0 set then in Alter mode)

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
;
;	new RAM locations for MiniPAM8
;
PCKVAL	DS	1	; PCK value from most recent scan (9 ticks)
PCKTMP	DS	1	; temporary candidate keypad response from PCK
;
;	We want to limit our monitor RAM storage to 40H or fewer bytes
;	so we have only a small serial handler buffer here (2 bytes)
;	but the user can overwrite these values to make it as
;	large as need be.
;
INBADDR	DW	$INBUF	; points to location of input buffer
INBLEN	DB	$INBUFL	; max length of buffer
$INBUF	DB	0	; input buffer count
	DS	2	; very small buffer
$INBUFL	EQU	*-$INBUF-2	; max length of buffer


	END
