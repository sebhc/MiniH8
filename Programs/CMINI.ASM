***	Heath H8 Software Console Driver for the H8 Mini
*
*	Glenn Roberts (GFR), September 2026
*

	ORG	040100A		Start of User RAM
	
**	Assembly Constants

RESTART	EQU	222222A		Dummy RESTART label
CONFIG	EQU	333333A		Dummy CONFIG label


***	CONSL - System Console and I/O Driver.
*
*
*	Notes on H8 Mini Implementation:
*
*	- Interrupt-driven serial console I/O will have already been initiated
*	  by the ROM. We only need to relocate the buffer space here
*
*	- Port I/O probably doesn't make any sense. For now let's ignore these
*	  (mapped to 000Q)


**	Key locations in H8 Mini Firmware

CINNE	EQU	0406H		read character from console
COUT	EQU	0409H		write character to console
INBADDR	EQU	2036H		Location of $INBUF
INBLEN	EQU	2038H		Length of buffer

**	I/O Port addresses.

IP.CDP	EQU	000Q		Console data in port
OP.CDP	EQU	000Q		Console data out port
IP.CIS	EQU	000Q		Console input status in port
OP.CIS	EQU	000Q		Console input status out port
IP.COS	EQU	000Q		Console output status in port
OP.COS	EQU	000Q		Console output status out port

IP.TDP	EQU	000Q		Tape data in port
OP.TDP	EQU	000Q		Tape data out port
IP.TSP	EQU	000Q		Tape status in port
OP.TSP	EQU	000Q		Tape status out port


**	$CSCTL (Console Control Flag) bits.
*
*	These bits are set in $CSCTL when the appropriate control
*	characters are struck.
*
*	These can be examined at task time, or when the users control
*	Character routine is entered (at interrupt time)

CC.HLD	EQU	01		Suspend output
CC.DMP	EQU	02		Discard output
CC.CTLA	EQU	010Q		Ctl-A
CC.CTLB	EQU	020Q		Ctl-B
CC.CTLC	EQU	040Q		Ctl-C
CC.CTLD	EQU	100Q		Ctl-D

**	Program Entry Points

ENTRY	JMP	CONFIG

RTN22	JMP	RESTART		warm start

**	Port Routines.
*
*	All programs must use these routines, to allow port address
*	changeability.

$CDIN	IN	IP.CDP		Console Data In
$RET	RET

$CDOUT	OUT	OP.CDP		Console Data Out
	RET

$CISI	IN	IP.CIS		Console Input Status In
	RET

$CISO	OUT	OP.CIS		Console Input Status Out
	RET

$COSI	IN	IP.COS		Console Output Status In
	RET

$COSO	OUT	OP.COS		Console Output Status Out
	RET

$TDIN	IN	IP.TDP		Tape Data In
	RET

$TDOUT	OUT	OP.TDP		Tape Data Out
	RET

$TSIN	IN	IP.TSP		Tape Status In
	RET

$TSOUT	OUT	OP.TSP		Tape Status Out
	RET


**	Remote Entry Points for Console Driver.
*

$RCHAR	JMP	$RCHAR.		Read one character	

$WCHAR	JMP	$WCHAR.		Write one character

$PRSCL	JMP	$PRSCL.		Preset Console UART

**	Data and Buffers
*
$INBUF	DB	0		Input buffer count
	DS	30		Type ahead buffer. First byte = next character.

$INBUFL	EQU	*-$INBUF-2	max length of buffer

**	Control Character Table.
*
*	DB	CHAR,MASK,VALUE
*
*	If char, $CSLCTL = ($CSLCTL .AND. MASK) .OR. VALUE
	
$CSIB	DB	00Q,377Q,000Q	Ctl-@ (00 - NULL)
	DB	01Q,167Q,210Q	Ctl-A
	DB	02Q,157Q,220Q	Ctl-B
	DB	03Q,137Q,240Q	Ctl-C
	DB	04Q,077Q,300Q	Ctl-D
	DB	17Q,177Q,002Q	Ctl-O
	DB	20Q,175Q,000Q	Ctl-P
	DB	21Q,176Q,000Q	Ctl-Q
	DB	23Q,176Q,001Q	Ctl-S
	DB	177Q		End of table
	
$CSIC	DW	$RET		Address of user routine for Ctl-A Through Ctl-D

$CSLCTL	DB	0		Console Control Byte
COLNO	DB	0		Console cursor position
	DB	80		Console width
	
.	SET	$INBUF/1000A
	ERRNZ	*/1000A-.	All data must be in same page
	SPACE	4,10
**	$RCHAR - Read Single Character.
*
*	$RCHAR is called to read a console character.
*	
*	For backward compatibility (e.g. with original H9 terminal)
*	characters are converted to upper case.
*
*	ENTRY:	None
*	EXIT:	(A) = char
*	USES:	A,F


$RCHAR.	CALL	CINNE		use code in ROM to read console
	CALL	TOUPPER		make upper case
	RET

** TOUPPER - convert lower case to upper
*
TOUPPER	CPI	'z'+1		see if lower case		
	JNC	TOUP1		greater than 'z' - not lower case
	CPI	'a'
	JC	TOUP1		less than 'a' - not lower case
	SUI	'a'-'A'		make upper
TOUP1	RET


**	$WCHAR - Write Single Character.
*
*	$WCHAR output a single character to the console
*
*	ENTRY:	(A) = character
*	EXIT:	NONE
*	USES:	NONE


$WCHAR.	CALL	COUT		call COUT in monitor
	RET

	SPACE	4,10
**	$PRSCL - Preset Console Drivers.
*
*	Primary job is to move the $INBUF buffer to our own space
*	from the limited (2-byte) one provided by the ROM.
*
*	ENTRY:	NONE
*	EXIT:	NONE
*	USES:	A,F


$PRSCL.	DI			hold the interruptions please
	LXI	H,$INBUF	point to our local buffer
	MVI	M,0		set byte count to zero
	SHLD	INBADDR		inform the monitor of location
	MVI	A,$INBUFL	buffer length - 2
	STA	INBLEN		inform the monitor
	EI			ok, have at it!
	RET
	
	END
