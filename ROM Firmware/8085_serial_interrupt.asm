# =============================================================================
# 8085 ASSEMBLY PROGRAM: INTERRUPT-DRIVEN SERIAL DATA RECEIVER VIA SID & RST 7.5
# =============================================================================
#
# DESCRIPTION:
# This program configures the Intel 8085 microprocessor to receive a stream of
# asynchronous serial data via its hardware Serial Input Data (SID) pin. 
# Transmission timing is synchronized externally using the RST 7.5 interrupt 
# line, which functions as the bit-clock trigger. Every time a bit boundary is 
# ready, the external hardware pulses the RST 7.5 line, invoking the Interrupt 
# Service Routine (ISR) to sample the data and reconstruct the byte.
#
# PROTOCOL DETAILS:
#   - Format: 1 Start Bit (0), 8 Data Bits (LSB first), 1 Stop Bit (1)
#   - Bit Sampling Trigger: External pulse tied to RST 7.5 hardware line.
#
# HARDWARE MAPPING:
#   - SID Pin (Pin 5): Serial data input stream.
#   - RST 7.5 Pin (Pin 7): Edge-triggered external hardware bit-clock.
#   - Memory Buffer: Decoded characters are stored sequentially starting at 3000H.
#
# =============================================================================

          ORG   0000H         ; Power-on / Reset Vector
          JMP   INIT          ; Jump to Main Initialization

# =============================================================================
# INTERRUPT VECTOR TABLE (IVT)
# =============================================================================
          ORG   003CH         ; Vector Address for RST 7.5 Hardware Interrupt
          JMP   RST75_ISR     ; Jump to the Interrupt Service Routine

# =============================================================================
# MAIN INITIALIZATION SECTION
# =============================================================================
          ORG   0100H         ; Main Program Origin
INIT:     LXI   SP, 2FFFH     ; Initialize Stack Pointer (Top of RAM boundary)
          LXI   H, 3000H      ; Initialize Pointer to Data Storage Buffer
          
          MVI   A, 00H        ; Clear State Variables
          STA   BIT_CNT       ; Reset bit counter to 0
          STA   RCV_BUF       ; Clear temporary shifting shift register
          STA   FLG_START     ; Reset Start-bit validation flag

          ; -------------------------------------------------------------------
          ; UNMASK AND CONFIGURE HARDWARE INTERRUPTS VIA SIM
          ; -------------------------------------------------------------------
          ; Accumulator Bit Pattern for SIM Instruction:
          ; D7 (SOD)  = 0 : Serial Output Data latch unaffected
          ; D6 (SDE)  = 0 : Disable Serial Output Data
          ; D5        = 0 : Undefined/Reserved
          ; D4 (R7.5) = 1 : Reset RST 7.5 D-Flip-Flop (Clears any old pending latch)
          ; D3 (MSE)  = 1 : Mask Set Enable (Allows modifying bit masks D2-D0)
          ; D2 (M7.5) = 0 : Unmask RST 7.5 Interrupt (0 = Enabled)
          ; D1 (M6.5) = 1 : Mask RST 6.5 Interrupt (1 = Disabled)
          ; D0 (M5.5) = 1 : Mask RST 5.5 Interrupt (1 = Disabled)
          ; Binary Pattern: 0001 1011 = 1BH
          
          MVI   A, 1BH        ; Load the SIM configuration byte
          SIM                 ; Execute Set Interrupt Mask instruction
          EI                  ; Enable Global Interrupts (Set IE Flip-Flop)

# =============================================================================
# MAIN EXECUTION LOOP
# =============================================================================
MAIN:     NOP                 ; Main thread remains idle, waiting for interrupts
          JMP   MAIN          ; Loop indefinitely while background handles I/O

# =============================================================================
# INTERRUPT SERVICE ROUTINE (ISR) FOR RST 7.5 (EXECUTED PER BIT INTERRUPT)
# =============================================================================
RST75_ISR:
          PUSH  PSW           ; Preserve Accumulator and Flags on Stack
          PUSH  B             ; Preserve BC register pair

          RIM                 ; Read Interrupt Mask & Serial Data Input (SID)
                              ; The SID bit is loaded directly into Accumulator Bit 7 (D7)
          
          MOV   B, A          ; Copy RIM snapshot into Register B for masking operations
          LDA   FLG_START     ; Fetch the current Start-bit status flag
          CPI   00H           ; Check if we are currently searching for a new frame
          JNZ   PROCESS_BITS  ; If FLG_START == 1, branch to sample data bits

          ; -------------------------------------------------------------------
          ; START BIT DETECTION & VALIDATION PHASE
          ; -------------------------------------------------------------------
          MOV   A, B          ; Retrieve the RIM snapshot from Register B
          ANI   80H           ; Isolate Bit 7 (SID Line State)
          CPI   80H           ; If SID is High (80H), it's idle line noise.
          JZ    ISR_EXIT      ; Exit ISR and await the real Start Bit (Low)

          ; Valid Start Bit (Low) detected
          MVI   A, 01H        
          STA   FLG_START     ; Set Start Flag to 1 (Frames future bits as data)
          MVI   A, 08H        
          STA   BIT_CNT       ; Initialize data bit counter to 8 bits
          MVI   A, 00H
          STA   RCV_BUF       ; Clear out the receiver buffer for incoming data
          JMP   ISR_EXIT      ; Exit ISR; next interrupt will be Data Bit 0

          ; -------------------------------------------------------------------
          ; DATA BIT RECONSTRUCTION PHASE
          ; -------------------------------------------------------------------
PROCESS_BITS:
          MOV   A, B          ; Retrieve RIM snapshot containing the raw SID bit
          ANI   80H           ; Isolate Bit 7 (SID)
          
          ; Rotate the isolated SID bit from Bit 7 to Carry Flag (CY)
          RLC                 ; Shifts D7 into Carry Flag (and matches D0)
          
          LDA   RCV_BUF       ; Fetch the shifting composite byte assembly
          RAR                 ; Rotate Right through Carry (Shifts Carry into D7, D7->D6 etc.)
          STA   RCV_BUF       ; Store the updated byte structure back to memory

          ; Decrement and evaluate the countdown loop
          LDA   BIT_CNT       ; Fetch remaining bits to sample
          DCR   A             ; Decrement counter
          STA   BIT_CNT       ; Store updated countdown back
          JNZ   ISR_EXIT      ; If bits remain (Counter > 0), exit to wait for next pulse

          ; -------------------------------------------------------------------
          ; FRAME TERMINATION & STORAGE (ALL 8 BITS CAPTURED)
          ; -------------------------------------------------------------------
          LDA   RCV_BUF       ; Load completely reconstructed 8-bit byte
          MOV   M, A          ; Write the character to the memory location pointed by HL
          INX   H             ; Increment memory pointer for the next character incoming
          
          MVI   A, 00H        
          STA   FLG_START     ; Reset state to look for a new start bit on next sequence

ISR_EXIT:
          POP   B             ; Restore BC register pair from Stack
          POP   PSW           ; Restore Accumulator and Flags
          EI                  ; Re-enable global interrupts before returning
          RET                 ; Return from Interrupt to Main line code

# =============================================================================
# DATA STORAGE DEFINITIONS (SRAM RAM BLOCK Variables)
# =============================================================================
          ORG   2000H         ; Variables mapped to scratchpad memory section
FLG_START: DS    1            ; Frame status tracking byte (00H=Idle, 01H=Receiving)
BIT_CNT:   DS    1            ; Tracks down remaining bits inside data phase
RCV_BUF:   DS    1            ; Working shift register for incoming data assembling

          END