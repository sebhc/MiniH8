;Flash a LED on SOD
;Top of RAM @ 0x4000

START:  LXI H, 4000h
        SPHL

FLASH:  MVI A, 0C0h
        SIM
        CALL DELAY
        MVI A, 40h
        SIM
        CALL DELAY
        JMP FLASH

;Delay, return to HL when done.
DELAY:  MVI A, 0FFh
        MOV B, A
PT1:    DCR A
PT2:    DCR B
        JNZ PT2
        CPI 00h
        JNZ PT1
        RET
	
	END START
	