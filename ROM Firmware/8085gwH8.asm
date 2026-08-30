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

;; have begun adding some PAM-8 functionality. RAM starts at 2000
;; the first 40h bytes are reserved for PAM use. User programs 
;; may be ORGed at 2040h (040.100 in split octal notation) or above.
;;		- gfr
;;

TICCNT	equ	201BH		;; 2ms clock tick counter

;STACK	equ	0000H
STACK	equ	8000H	;;Stack at top of RAM (or 8000h for mini H8) gfr

	ORG	0000H		;Reset jump to monitor, leave room for
	JMP	CSTART		;interrupt vectors.
;;
;;	room for interrupt vectors - gfr
;;

;;	Interrupt handler for RST7.5 - gfr
;;
;;	This code is executed whenever a 2-millisecond
;;	clock interrupt occurs.
;;
;;	currently just increments the TICCNT counter, however
;;	this is also where other scheduled services can be handled
;;	(e.g. 7-segment display update).
;;
	ORG	03CH
INT7.5	PUSH	PSW
	PUSH	B
	PUSH	D
	PUSH	H

;; update the tick count
	
	LHLD	TICCNT
	INX	H
	SHLD	TICCNT
	
	POP	H
	POP	D
	POP	B
	POP	PSW
	
	EI
	RET
	

	
	ORG	0100H		;Actual start of monitor

;;	INCLUDE	'vectors.inc'	;Standard GWMON-80 jump table
;;	(included inline)
JMPTAB:	JMP	CSTART	;Cold start, initializes hardware
	JMP	WSTART		;Warm start
	JMP	COUT		;Output A register to console
	JMP	CIN			;Input A register from console, waits
CSTART:	
					;;end of INCLUDE 'vectors.inc'
					
;;	INCLUDE	'sm.inc' ;The small monitor (included inline)
;
;SM -- GWMON-80 Small Monitor
;
;This is the small monitor for GWMON-80. It includes the
;small command processor and common monitor routines.
;
;Small Monitor Equates
;
DYNIN	equ	STACK-3
DYNOUT	equ	STACK-6

;
;SMSTRT -- SM cold start routine
;
;; after this code the following is installed just above the STACK:
;;
;;	DYNOUT	OUT xx
;;		RET
;;	DYNIN	IN xx
;;		RET
;; the 'xx' values are port numbers filled in dynamically by
;; INPCMD and OUTCMD
;;			- gfr
;;
SMSTRT:	LXI	SP, STACK	;Set up stack pointer
	LXI	H, 0C9D3H	;; OUT and RET
	PUSH	H
	LXI	D, 0DBC9H	;; RET and IN
	PUSH	D
	PUSH	H		;; OUT and RET

	CALL	IOSET		;Do I/O module setup
	CALL	IRQSET		;; initialize interrupts - gfr
	LXI	H, SIGNON$	;SM signon
	CALL	PRTCLS

;
;WSTART -- Warm start routine
;
;Falls through to the command processor.
;
WSTART: LXI	SP,STACK-6	;Reload stack pointer
				;don't clobber dynamic IN/OUT area

;;	INCLUDE	'scp.inc'	; (included inline)
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
CMDLP:	LXI	H, WSTART	;HL = warm start address
	PUSH	H		;Prime stack for RET
	LXI	H, PROMPT$
	CALL	PRTCLS
	CALL	CIN
	ORI	20H		;allow lowercase input

	LXI	H,CMDTAB-1
CMDLP1:	INX	H		;Point to next command char
	CMP	M
	JZ	RUNCMD		;Match, run command handler
	MOV	B,A
	MOV	A,M
	ORA	A
	MOV	A,B
	INX	H		;Get past handler address
	INX	H
	JNZ	CMDLP1

;
;ERROR -- Print generic error message and abort
;
;Falls through to PRTERR.
;
ERROR:	LXI	H,ERR$		;Fall through to PRTERR

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
	JC	ERROR		;Invalid hex char, abort
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
;ASCII Equates
;
CTLC	equ	03
BS	equ	08
LF	equ	10
CR	equ	13

CANCEL	equ	CTLC		;Escape/cancel character, CTRL+C
NEXTLOC	equ	CR		;Keystroke for next location in E
				;defaults to CR

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
ASCHEX:	SUI	'0'		;ASCII to decimal bias
	RC			;Return if less than '0'
	CPI	0AH
	CMC			;Clear CY
	RM			;0x0 - 0x9, done
	ANI	5FH		;Upcase
	SUI	07H		;ASCII to hex bias
	CPI	10H
	CMC			;Set CY if > 'F'
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
;INPCMD -- Input to port command
;
;Returns through PRTHEX.
;
;entry: DYNIN memory area has been initialized
; exit: byte from specififed port printed to console
;
INPCMD:	CALL	GETHEX
	STA	DYNIN+1		;Store operand
	CALL	PRTSPC
	CALL	DYNIN
	JMP	PRTHEX

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
;OUTCMD -- Output to port command
;
;Returns through DYNOUT.
;
;entry: DYNOUT memory area has been initialized
; exit: specified byte has been written to specified port
;
OUTCMD:	CALL	GETHEX
	STA	DYNOUT+1	;Store operand
	CALL	PRTSPC
	CALL	GETHEX
	JMP	DYNOUT

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
;; mini H8 uses 4MHz crystal, so BITTIME and HALFBIT change.

;BITTIME	equ	0112H		;9600 BPS with 6.144 MHz crystal
;HALFBIT	equ	0109H		;Half-bit time

;; Using Intel Application Note AP-29 the following are computed for
;; 9600 BPS with 4.0 MHz crystal - gfr
;;
;BITTIME	equ	010AH		;9600 BPS with 4.0 MHz crystal
;HALFBIT	equ	0106H		;Half-bit time

;; below for 2400 baud - gfr 

BITTIME	equ	0137H		;2400 BPS with 4.0 MHz crystal
HALFBIT	equ	011CH		;Half-bit time
;
;SETUP -- Prepare the system for running the monitor
;
;Output a NUL to clear the line after a reset. Returns
;through COUT.
;
;entry: none
; exit: console ready for I/O
;
IOSET:	XRA	A		;NUL in A
	JMP	COUT		;Clear the line

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
	DI			;Must disable interrupts
	MVI	B,9		;Receive bits counter

CI1:	RIM			;Check for start bit
	ANI	080h		;; look only at bit seven - gfr
	JZ	CI1		;; no start bit seen yet - gfr
;	JM	CI1		;; No start bit, wait (invert for mini H8)

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
;;			;;end of INCLUDE '8085sio1.inc'
	END
