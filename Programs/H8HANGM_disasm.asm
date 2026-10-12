; ════════════════════════════════════════════════════════════════
;  H8HANGM_orig.ABS  —  Heathkit H8 HANGMAN
;  Copyright 1977 Heath Co.
;  Intel 8080 Disassembly (linear, two-pass)
; ────────────────────────────────────────────────────────────────
;  File size   : 4096 bytes
;  Header (8B) : FF 00 40 20 F5 0F 40 20
;    Load addr : 0x2040
;    Byte count: 0x0ff5 (4085 bytes)
;    Entry pt  : 0x2040
; ────────────────────────────────────────────────────────────────
;  Memory map (addresses within 0x2040–0x3037):
;    0x2040        Program entry (JMP → init at 0x301F)
;    0x2043        Secondary entry (JMP → main init at 0x21B7)
;    0x2046-0x2063 I/O subroutine stubs (IN/OUT wrappers)
;    0x2064-0x206C Jump table (3 vectors)
;    0x206D-0x20AC Binary display-data table (hangman figure)
;    0x20AD-0x21A5 Core game engine
;    0x21B7-0x21E4 Main init / game loop
;    0x21E5-0x21FB Interrupt/context switch helper
;    0x21FC-0x2E67 Game routines + inline strings
;    0x2E68-0x301E Word list (high-bit terminates each word)
;    0x301F-0x3034 Startup / stack-init code (entry target)
; ────────────────────────────────────────────────────────────────
;  Known variables (RAM):
;    0x20AA  STATUS_VAR  — game status / mode flags
;    0x2E3A  SAVED_SP    — saved stack pointer (for restart)
;    0x2E44  RETURN_VEC  — saved return address (PCHL target)
;    0x2E66  FRAME_PTR   — frame/stack frame pointer
;  Self-modifying code:
;    At startup 0x301F patches bytes at START+1 (0x2041)
;    so JMP 0x301F becomes JMP 0x2164 on subsequent entries.
; ════════════════════════════════════════════════════════════════

        ORG     0x2040

; ──────────────────────────────────────────────────────
2040:  START:          C3 1F 30    JMP  0x301f             ; → L301F
2043:                  C3 B7 21    JMP  0x21b7             ; → L21B7

; ──────────────────────────────────────────────────────
2046:  L2046:          DB FA       IN   0xfa               ; serial status (UART)
; ──────────────────────────────────────────────────────
2048:  L2048:          C9          RET                   
; ──────────────────────────────────────────────────────
2049:  L2049:          D3 FA       OUT  0xfa               ; serial status (UART)
204B:                  C9          RET                   

; ──────────────────────────────────────────────────────
204C:  L204C:          DB FB       IN   0xfb               ; serial data (UART)
204E:                  C9          RET                   

; ──────────────────────────────────────────────────────
204F:  L204F:          D3 FB       OUT  0xfb               ; serial data (UART)
2051:                  C9          RET                   

; ──────────────────────────────────────────────────────
2052:  L2052:          DB FB       IN   0xfb               ; serial data (UART)
2054:                  C9          RET                   
2055:                  D3 FB       OUT  0xfb               ; serial data (UART)
2057:                  C9          RET                   
2058:                  DB F8       IN   0xf8               ; port-f8 (ACR/status)
205A:                  C9          RET                   
205B:                  D3 F8       OUT  0xf8               ; port-f8 (ACR/status)
205D:                  C9          RET                   
205E:                  DB F9       IN   0xf9               ; port-f9 (data)
2060:                  C9          RET                   

; ──────────────────────────────────────────────────────
2061:  L2061:          D3 F9       OUT  0xf9               ; port-f9 (data)
2063:                  C9          RET                   

; ──────────────────────────────────────────────────────
2064:  L2064:          C3 AD 20    JMP  0x20ad             ; → L20AD
; ──────────────────────────────────────────────────────
2067:  L2067:          C3 DA 20    JMP  0x20da             ; → L20DA
; ──────────────────────────────────────────────────────
206A:  L206A:          C3 F7 20    JMP  0x20f7             ; → L20F7

; ════════════════════════════════════════════════════════
; ── Binary data block ──────────────────────────────────
206D:                   DB 00 3A 5E F1 B0 EB 22 70  ; |.:^..."p|
2075:                   DB F0 78 02 FA DB BF 9B 9F  ; |.x......|
207D:                   DB 8F DF DF 0D 29 2F 0B 73  ; |....)/.s|
2085:                   DB 20 2B 0D FE 9F FF FF 00  ; | +......|
208D:                   DB FF 00 01 77 88 02 6F 90  ; |...w..o.|
2095:                   DB 03 5F A0 04 3F C0 0F 7F  ; |._..?...|
209D:                   DB 02 10 7D 00 11 7E 00 13  ; |..}..~..|
20A5:                   DB 7E 01 7F 48 20 00 00 50  ; |~..H ..P|


; ──────────────────────────────────────────────────────
20AD:  L20AD:          E5          PUSH H                
20AE:                  21 6D 20    LXI  H,0x206d           ; → L206D

; ──────────────────────────────────────────────────────
20B1:  L20B1:          7E          MOV  A,M              
20B2:                  A7          ANA  A                
20B3:                  CA B1 20    JZ   0x20b1             ; → L20B1
20B6:                  F3          DI                    
20B7:                  D5          PUSH D                
20B8:                  35          DCR  M                
20B9:                  56          MOV  D,M              
20BA:                  23          INX  H                
20BB:                  7E          MOV  A,M              
20BC:                  FE 7B       CPI  0x7b             
20BE:                  D2 C8 20    JNC  0x20c8             ; → L20C8
20C1:                  FE 61       CPI  0x61             
20C3:                  DA C8 20    JC   0x20c8             ; → L20C8
20C6:                  D6 20       SUI  0x20             

; ──────────────────────────────────────────────────────
20C8:  L20C8:          F5          PUSH PSW              
; ──────────────────────────────────────────────────────
20C9:  L20C9:          15          DCR  D                
20CA:                  FA D5 20    JM   0x20d5             ; → L20D5
20CD:                  23          INX  H                
20CE:                  7E          MOV  A,M              
20CF:                  2B          DCX  H                
20D0:                  77          MOV  M,A              
20D1:                  23          INX  H                
20D2:                  C3 C9 20    JMP  0x20c9             ; → L20C9

; ──────────────────────────────────────────────────────
20D5:  L20D5:          FB          EI                    
20D6:                  F1          POP  PSW              
20D7:                  D1          POP  D                
20D8:                  E1          POP  H                
20D9:                  C9          RET                   

; ──────────────────────────────────────────────────────
20DA:  L20DA:          F5          PUSH PSW              
; ──────────────────────────────────────────────────────
20DB:  L20DB:          3A AA 20    LDA  0x20aa             ; → STATUS_VAR
20DE:                  1F          RAR                   
20DF:                  DA DB 20    JC   0x20db             ; → L20DB
20E2:                  1F          RAR                   
20E3:                  D2 EC 20    JNC  0x20ec             ; → L20EC
20E6:                  F1          POP  PSW              
20E7:                  C9          RET                   

; ──────────────────────────────────────────────────────
20E8:  L20E8:          35          DCR  M                
20E9:                  3E 07       MVI  A,0x07           
20EB:                  F5          PUSH PSW              

; ──────────────────────────────────────────────────────
20EC:  L20EC:          CD 52 20    CALL 0x2052             ; → L2052
20EF:                  1F          RAR                   
20F0:                  D2 EC 20    JNC  0x20ec             ; → L20EC
20F3:                  F1          POP  PSW              
20F4:                  C3 49 20    JMP  0x2049             ; → L2049

; ──────────────────────────────────────────────────────
20F7:  L20F7:          3E 81       MVI  A,0x81           
20F9:                  CD 4F 20    CALL 0x204f             ; → L204F
20FC:                  CD 61 20    CALL 0x2061             ; → L2061
20FF:                  3E 40       MVI  A,0x40           
2101:                  CD 4F 20    CALL 0x204f             ; → L204F
2104:                  CD 61 20    CALL 0x2061             ; → L2061
2107:                  3E 4E       MVI  A,0x4e           
2109:                  CD 4F 20    CALL 0x204f             ; → L204F
210C:                  CD 61 20    CALL 0x2061             ; → L2061
210F:                  AF          XRA  A                
2110:                  32 6D 20    STA  0x206d             ; → L206D
2113:                  3E C3       MVI  A,0xc3           
2115:                  32 25 20    STA  0x2025             ; → EXT_2025
2118:                  21 23 21    LXI  H,0x2123           ; → L2123
211B:                  22 26 20    SHLD 0x2026             ; → EXT_2026
211E:                  3E 17       MVI  A,0x17           

; ──────────────────────────────────────────────────────
2120:  L2120:          C3 4F 20    JMP  0x204f             ; → L204F
; ──────────────────────────────────────────────────────
2123:  L2123:          E5          PUSH H                
2124:                  F5          PUSH PSW              
2125:                  CD 4C 20    CALL 0x204c             ; → L204C
2128:                  E6 02       ANI  0x02             
212A:                  C4 31 21    CNZ  0x2131             ; → L2131
212D:                  F1          POP  PSW              
212E:                  E1          POP  H                
212F:                  FB          EI                    
2130:                  C9          RET                   

; ──────────────────────────────────────────────────────
2131:  L2131:          21 6D 20    LXI  H,0x206d           ; → L206D
2134:                  3E 1D       MVI  A,0x1d           
2136:                  BE          CMP  M                
2137:                  DC E8 20    CC   0x20e8             ; → L20E8
213A:                  34          INR  M                
213B:                  7E          MOV  A,M              
213C:                  85          ADD  L                
213D:                  6F          MOV  L,A              
213E:                  CD 46 20    CALL 0x2046             ; → L2046
2141:                  E6 7F       ANI  0x7f             
2143:                  77          MOV  M,A              
2144:                  FE 20       CPI  0x20             
2146:                  D0          RNC                   
2147:                  2E 8A       MVI  L,0x8a           

; ──────────────────────────────────────────────────────
2149:  L2149:          23          INX  H                
214A:                  23          INX  H                
214B:                  BE          CMP  M                
214C:                  D8          RC                    
214D:                  23          INX  H                
214E:                  C2 49 21    JNZ  0x2149             ; → L2149
2151:                  3A AA 20    LDA  0x20aa             ; → STATUS_VAR
2154:                  A6          ANA  M                
2155:                  23          INX  H                
2156:                  AE          XRA  M                
2157:                  32 AA 20    STA  0x20aa             ; → STATUS_VAR
215A:                  F5          PUSH PSW              
215B:                  2E 6D       MVI  L,0x6d           
215D:                  35          DCR  M                
215E:                  F1          POP  PSW              
215F:                  F0          RP                    
2160:                  2A A8 20    LHLD 0x20a8             ; → L20A8
2163:                  E9          PCHL                  

; ──────────────────────────────────────────────────────
2164:  L2164:          CD A3 29    CALL 0x29a3             ; → L29A3
2167:                  CD A8 2B    CALL 0x2ba8             ; → L2BA8
216A:                  2A 3A 2E    LHLD 0x2e3a             ; → SAVED_SP
216D:                  F9          SPHL                  
216E:                  2A 1B 20    LHLD 0x201b             ; → EXT_201B
2171:                  22 40 2E    SHLD 0x2e40             ; → L2E40
2174:                  CD 21 2D    CALL 0x2d21             ; → L2D21
2177:                  3C          INR  A                
2178:                  00          NOP                   
2179:                  00          NOP                   
217A:                  00          NOP                   

; ════════════════════════════════════════════════════════
; ── String block (null-terminated) ─────────────────────
217B:                   DB "HANGMAN   ISSUE # 20.00.00.", 0
2197:                   DB "C,O,P,Y,R,I,G,H,T, ,1,9,7,7, ,B,Y", ...

21A8:                  20          DB   0x20             
21A9:                  48          MOV  C,B              
21AA:                  45          MOV  B,L              
21AB:                  41          MOV  B,C              
21AC:                  54          MOV  D,H              
21AD:                  48          MOV  C,B              
21AE:                  20          DB   0x20             
21AF:                  43          MOV  B,E              
21B0:                  4F          MOV  C,A              
21B1:                  2E 00       MVI  L,0x00           
21B3:                  00          NOP                   
21B4:                  CD FC 21    CALL 0x21fc             ; → L21FC

; ──────────────────────────────────────────────────────
21B7:  L21B7:          2A 3A 2E    LHLD 0x2e3a             ; → SAVED_SP
21BA:                  F9          SPHL                  
21BB:                  CD A3 29    CALL 0x29a3             ; → L29A3
21BE:                  21 58 FF    LXI  H,0xff58           ; → EXT_FF58
21C1:                  39          DAD  SP               
21C2:                  22 66 2E    SHLD 0x2e66             ; → FRAME_PTR
21C5:                  CD A8 2B    CALL 0x2ba8             ; → L2BA8
21C8:                  CD 25 23    CALL 0x2325             ; → L2325
21CB:                  CD 87 2A    CALL 0x2a87             ; → L2A87
21CE:                  CD FA 25    CALL 0x25fa             ; → L25FA
21D1:                  CD 76 2A    CALL 0x2a76             ; → L2A76
21D4:                  D6 21       SUI  0x21             

; ──────────────────────────────────────────────────────
21D6:  L21D6:          CD 60 29    CALL 0x2960             ; → L2960
21D9:                  CD 52 26    CALL 0x2652             ; → L2652
21DC:                  CD 29 27    CALL 0x2729             ; → L2729
21DF:                  CD 12 29    CALL 0x2912             ; → L2912
21E2:                  C3 D6 21    JMP  0x21d6             ; → L21D6

; ──────────────────────────────────────────────────────
21E5:  L21E5:          3A AA 20    LDA  0x20aa             ; → STATUS_VAR
21E8:                  E6 20       ANI  0x20             
21EA:                  C8          RZ                    
21EB:                  3A AA 20    LDA  0x20aa             ; → STATUS_VAR
21EE:                  E6 DF       ANI  0xdf             
21F0:                  32 AA 20    STA  0x20aa             ; → STATUS_VAR
21F3:                  2A 3A 2E    LHLD 0x2e3a             ; → SAVED_SP
21F6:                  F9          SPHL                  
21F7:                  FB          EI                    
21F8:                  2A 44 2E    LHLD 0x2e44             ; → RETURN_VEC
21FB:                  E9          PCHL                  

; ──────────────────────────────────────────────────────
21FC:  L21FC:          CD 21 2D    CALL 0x2d21             ; → L2D21
21FF:                  F3          DI                    
2200:                  00          NOP                   
2201:                  00          NOP                   
2202:                  49          MOV  C,C              
2203:                  4E          MOV  C,M              
2204:                  53          MOV  D,E              
2205:                  54          MOV  D,H              
2206:                  52          MOV  D,D              
2207:                  55          MOV  D,L              
2208:                  43          MOV  B,E              
2209:                  54          MOV  D,H              
220A:                  49          MOV  C,C              
220B:                  4F          MOV  C,A              
220C:                  4E          MOV  C,M              
220D:                  53          MOV  D,E              
220E:                  20          DB   0x20             
220F:                  46          MOV  B,M              
2210:                  4F          MOV  C,A              
2211:                  52          MOV  D,D              
2212:                  20          DB   0x20             
2213:                  48          MOV  C,B              
2214:                  41          MOV  B,C              
2215:                  4E          MOV  C,M              
2216:                  47          MOV  B,A              
2217:                  4D          MOV  C,L              
2218:                  41          MOV  B,C              
2219:                  4E          MOV  C,M              
221A:                  3A 00 00    LDA  0x0000             ; → EXT_0000
221D:                  85          ADD  L                
221E:                  59          MOV  E,C              
221F:                  4F          MOV  C,A              
2220:                  55          MOV  D,L              
2221:                  20          DB   0x20             
2222:                  41          MOV  B,C              
2223:                  52          MOV  D,D              
2224:                  45          MOV  B,L              
2225:                  20          DB   0x20             
2226:                  54          MOV  D,H              
2227:                  4F          MOV  C,A              
2228:                  20          DB   0x20             
2229:                  47          MOV  B,A              
222A:                  55          MOV  D,L              
222B:                  45          MOV  B,L              
222C:                  53          MOV  D,E              
222D:                  53          MOV  D,E              
222E:                  20          DB   0x20             
222F:                  41          MOV  B,C              
2230:                  20          DB   0x20             
2231:                  57          MOV  D,A              
2232:                  4F          MOV  C,A              
2233:                  52          MOV  D,D              
2234:                  44          MOV  B,H              
2235:                  2C          INR  L                
2236:                  20          DB   0x20             
2237:                  50          MOV  D,B              
2238:                  49          MOV  C,C              
2239:                  43          MOV  B,E              
223A:                  4B          MOV  C,E              
223B:                  45          MOV  B,L              
223C:                  44          MOV  B,H              
223D:                  20          DB   0x20             
223E:                  41          MOV  B,C              
223F:                  54          MOV  D,H              
2240:                  20          DB   0x20             
2241:                  52          MOV  D,D              
2242:                  41          MOV  B,C              
2243:                  4E          MOV  C,M              
2244:                  44          MOV  B,H              
2245:                  4F          MOV  C,A              
2246:                  4D          MOV  C,L              
2247:                  2C          INR  L                
2248:                  20          DB   0x20             
2249:                  42          MOV  B,D              
224A:                  59          MOV  E,C              
224B:                  20          DB   0x20             
224C:                  47          MOV  B,A              
224D:                  55          MOV  D,L              
224E:                  45          MOV  B,L              
224F:                  53          MOV  D,E              
2250:                  53          MOV  D,E              
2251:                  49          MOV  C,C              
2252:                  4E          MOV  C,M              
2253:                  47          MOV  B,A              
2254:                  00          NOP                   
2255:                  54          MOV  D,H              
2256:                  48          MOV  C,B              
2257:                  45          MOV  B,L              
2258:                  20          DB   0x20             
2259:                  4C          MOV  C,H              
225A:                  45          MOV  B,L              
225B:                  54          MOV  D,H              
225C:                  54          MOV  D,H              
225D:                  45          MOV  B,L              
225E:                  52          MOV  D,D              
225F:                  53          MOV  D,E              
2260:                  2E 20       MVI  L,0x20           
2262:                  20          DB   0x20             
2263:                  54          MOV  D,H              
2264:                  48          MOV  C,B              
2265:                  45          MOV  B,L              
2266:                  20          DB   0x20             
2267:                  50          MOV  D,B              
2268:                  45          MOV  B,L              
2269:                  4E          MOV  C,M              
226A:                  41          MOV  B,C              
226B:                  4C          MOV  C,H              
226C:                  54          MOV  D,H              
226D:                  59          MOV  E,C              
226E:                  20          DB   0x20             
226F:                  46          MOV  B,M              
2270:                  4F          MOV  C,A              
2271:                  52          MOV  D,D              
2272:                  20          DB   0x20             
2273:                  47          MOV  B,A              
2274:                  55          MOV  D,L              
2275:                  45          MOV  B,L              
2276:                  53          MOV  D,E              
2277:                  53          MOV  D,E              
2278:                  49          MOV  C,C              
2279:                  4E          MOV  C,M              
227A:                  47          MOV  B,A              
227B:                  20          DB   0x20             
227C:                  57          MOV  D,A              
227D:                  52          MOV  D,D              
227E:                  4F          MOV  C,A              
227F:                  4E          MOV  C,M              
2280:                  47          MOV  B,A              
2281:                  20          DB   0x20             
2282:                  49          MOV  C,C              
2283:                  53          MOV  D,E              
2284:                  20          DB   0x20             
2285:                  54          MOV  D,H              
2286:                  48          MOV  C,B              
2287:                  45          MOV  B,L              
2288:                  20          DB   0x20             
2289:                  41          MOV  B,C              
228A:                  44          MOV  B,H              
228B:                  44          MOV  B,H              
228C:                  49          MOV  C,C              
228D:                  54          MOV  D,H              
228E:                  49          MOV  C,C              
228F:                  4F          MOV  C,A              
2290:                  4E          MOV  C,M              
2291:                  20          DB   0x20             
2292:                  4F          MOV  C,A              
2293:                  46          MOV  B,M              
2294:                  20          DB   0x20             
2295:                  00          NOP                   
2296:                  41          MOV  B,C              
2297:                  52          MOV  D,D              
2298:                  4D          MOV  C,L              
2299:                  53          MOV  D,E              
229A:                  2C          INR  L                
229B:                  20          DB   0x20             
229C:                  4C          MOV  C,H              
229D:                  45          MOV  B,L              
229E:                  47          MOV  B,A              
229F:                  53          MOV  D,E              
22A0:                  2C          INR  L                
22A1:                  20          DB   0x20             
22A2:                  45          MOV  B,L              
22A3:                  54          MOV  D,H              
22A4:                  43          MOV  B,E              
22A5:                  2E 20       MVI  L,0x20           
22A7:                  54          MOV  D,H              
22A8:                  4F          MOV  C,A              
22A9:                  20          DB   0x20             
22AA:                  41          MOV  B,C              
22AB:                  20          DB   0x20             
22AC:                  50          MOV  D,B              
22AD:                  49          MOV  C,C              
22AE:                  43          MOV  B,E              
22AF:                  54          MOV  D,H              
22B0:                  55          MOV  D,L              
22B1:                  52          MOV  D,D              
22B2:                  45          MOV  B,L              
22B3:                  20          DB   0x20             
22B4:                  4F          MOV  C,A              
22B5:                  46          MOV  B,M              
22B6:                  20          DB   0x20             
22B7:                  41          MOV  B,C              
22B8:                  20          DB   0x20             
22B9:                  48          MOV  C,B              
22BA:                  41          MOV  B,C              
22BB:                  4E          MOV  C,M              
22BC:                  47          MOV  B,A              
22BD:                  49          MOV  C,C              
22BE:                  4E          MOV  C,M              
22BF:                  47          MOV  B,A              
22C0:                  20          DB   0x20             
22C1:                  4D          MOV  C,L              
22C2:                  41          MOV  B,C              
22C3:                  4E          MOV  C,M              
22C4:                  2E 20       MVI  L,0x20           
22C6:                  20          DB   0x20             
22C7:                  45          MOV  B,L              
22C8:                  49          MOV  C,C              
22C9:                  47          MOV  B,A              
22CA:                  48          MOV  C,B              
22CB:                  54          MOV  D,H              
22CC:                  20          DB   0x20             
22CD:                  57          MOV  D,A              
22CE:                  52          MOV  D,D              
22CF:                  4F          MOV  C,A              
22D0:                  4E          MOV  C,M              
22D1:                  47          MOV  B,A              
22D2:                  00          NOP                   
22D3:                  47          MOV  B,A              
22D4:                  55          MOV  D,L              
22D5:                  45          MOV  B,L              
22D6:                  53          MOV  D,E              
22D7:                  53          MOV  D,E              
22D8:                  45          MOV  B,L              
22D9:                  53          MOV  D,E              
22DA:                  20          DB   0x20             
22DB:                  41          MOV  B,C              
22DC:                  4E          MOV  C,M              
22DD:                  44          MOV  B,H              
22DE:                  20          DB   0x20             
22DF:                  59          MOV  E,C              
22E0:                  4F          MOV  C,A              
22E1:                  55          MOV  D,L              
22E2:                  20          DB   0x20             
22E3:                  4C          MOV  C,H              
22E4:                  4F          MOV  C,A              
22E5:                  53          MOV  D,E              
22E6:                  45          MOV  B,L              
22E7:                  20          DB   0x20             
22E8:                  54          MOV  D,H              
22E9:                  48          MOV  C,B              
22EA:                  45          MOV  B,L              
22EB:                  20          DB   0x20             
22EC:                  47          MOV  B,A              
22ED:                  41          MOV  B,C              
22EE:                  4D          MOV  C,L              
22EF:                  45          MOV  B,L              
22F0:                  2E 00       MVI  L,0x00           
22F2:                  00          NOP                   
22F3:                  CD 21 2D    CALL 0x2d21             ; → L2D21
22F6:                  2B          DCX  H                
22F7:                  54          MOV  D,H              
22F8:                  4F          MOV  C,A              
22F9:                  20          DB   0x20             
22FA:                  44          MOV  B,H              
22FB:                  49          MOV  C,C              
22FC:                  53          MOV  D,E              
22FD:                  43          MOV  B,E              
22FE:                  41          MOV  B,C              
22FF:                  52          MOV  D,D              
2300:                  44          MOV  B,H              
2301:                  20          DB   0x20             
2302:                  41          MOV  B,C              
2303:                  20          DB   0x20             
2304:                  53          MOV  D,E              
2305:                  45          MOV  B,L              
2306:                  4C          MOV  C,H              
2307:                  45          MOV  B,L              
2308:                  43          MOV  B,E              
2309:                  54          MOV  D,H              
230A:                  45          MOV  B,L              
230B:                  44          MOV  B,H              
230C:                  20          DB   0x20             
230D:                  57          MOV  D,A              
230E:                  4F          MOV  C,A              
230F:                  52          MOV  D,D              
2310:                  44          MOV  B,H              
2311:                  2C          INR  L                
2312:                  20          DB   0x20             
2313:                  50          MOV  D,B              
2314:                  52          MOV  D,D              
2315:                  45          MOV  B,L              
2316:                  53          MOV  D,E              
2317:                  53          MOV  D,E              
2318:                  20          DB   0x20             
2319:                  43          MOV  B,E              
231A:                  54          MOV  D,H              
231B:                  52          MOV  D,D              
231C:                  4C          MOV  C,H              
231D:                  2D          DCR  L                
231E:                  43          MOV  B,E              
231F:                  2E 00       MVI  L,0x00           
2321:                  00          NOP                   
2322:                  C3 78 29    JMP  0x2978             ; → L2978

; ──────────────────────────────────────────────────────
2325:  L2325:          CD 21 2D    CALL 0x2d21             ; → L2D21
2328:                  3A 00 44    LDA  0x4400             ; → EXT_4400
232B:                  4F          MOV  C,A              
232C:                  20          DB   0x20             
232D:                  59          MOV  E,C              
232E:                  4F          MOV  C,A              
232F:                  55          MOV  D,L              
2330:                  20          DB   0x20             
2331:                  57          MOV  D,A              
2332:                  41          MOV  B,C              
2333:                  4E          MOV  C,M              
2334:                  54          MOV  D,H              
2335:                  20          DB   0x20             
2336:                  54          MOV  D,H              
2337:                  4F          MOV  C,A              
2338:                  20          DB   0x20             
2339:                  41          MOV  B,C              
233A:                  44          MOV  B,H              
233B:                  44          MOV  B,H              
233C:                  20          DB   0x20             
233D:                  59          MOV  E,C              
233E:                  4F          MOV  C,A              
233F:                  55          MOV  D,L              
2340:                  52          MOV  D,D              
2341:                  20          DB   0x20             
2342:                  4F          MOV  C,A              
2343:                  57          MOV  D,A              
2344:                  4E          MOV  C,M              
2345:                  20          DB   0x20             
2346:                  57          MOV  D,A              
2347:                  4F          MOV  C,A              
2348:                  52          MOV  D,D              
2349:                  44          MOV  B,H              
234A:                  53          MOV  D,E              
234B:                  20          DB   0x20             
234C:                  54          MOV  D,H              
234D:                  4F          MOV  C,A              
234E:                  20          DB   0x20             
234F:                  54          MOV  D,H              
2350:                  48          MOV  C,B              
2351:                  45          MOV  B,L              
2352:                  20          DB   0x20             
2353:                  4C          MOV  C,H              
2354:                  49          MOV  C,C              
2355:                  53          MOV  D,E              
2356:                  54          MOV  D,H              
2357:                  3F          CMC                   
2358:                  20          DB   0x20             
2359:                  28          DB   0x28             
235A:                  59          MOV  E,C              
235B:                  20          DB   0x20             
235C:                  4F          MOV  C,A              
235D:                  52          MOV  D,D              
235E:                  20          DB   0x20             
235F:                  4E          MOV  C,M              
2360:                  29          DAD  H                
2361:                  20          DB   0x20             
2362:                  3A CD 65    LDA  0x65cd             ; → EXT_65CD
2365:                  2A CD FA    LHLD 0xfacd             ; → EXT_FACD
2368:                  2C          INR  L                
2369:                  32 36 2E    STA  0x2e36             ; → L2E36
236C:                  FE 4E       CPI  0x4e             
236E:                  C8          RZ                    
236F:                  CD 21 2D    CALL 0x2d21             ; → L2D21
2372:                  34          INR  M                
2373:                  00          NOP                   
2374:                  44          MOV  B,H              
2375:                  4F          MOV  C,A              
2376:                  20          DB   0x20             
2377:                  59          MOV  E,C              
2378:                  4F          MOV  C,A              
2379:                  55          MOV  D,L              
237A:                  20          DB   0x20             
237B:                  57          MOV  D,A              
237C:                  41          MOV  B,C              
237D:                  4E          MOV  C,M              
237E:                  54          MOV  D,H              
237F:                  20          DB   0x20             
2380:                  54          MOV  D,H              
2381:                  48          MOV  C,B              
2382:                  45          MOV  B,L              
2383:                  20          DB   0x20             
2384:                  50          MOV  D,B              
2385:                  52          MOV  D,D              
2386:                  45          MOV  B,L              
2387:                  53          MOV  D,E              
2388:                  45          MOV  B,L              
2389:                  4E          MOV  C,M              
238A:                  54          MOV  D,H              
238B:                  20          DB   0x20             
238C:                  57          MOV  D,A              
238D:                  4F          MOV  C,A              
238E:                  52          MOV  D,D              
238F:                  44          MOV  B,H              
2390:                  20          DB   0x20             
2391:                  4C          MOV  C,H              
2392:                  49          MOV  C,C              
2393:                  53          MOV  D,E              
2394:                  54          MOV  D,H              
2395:                  20          DB   0x20             
2396:                  45          MOV  B,L              
2397:                  52          MOV  D,D              
2398:                  41          MOV  B,C              
2399:                  53          MOV  D,E              
239A:                  45          MOV  B,L              
239B:                  44          MOV  B,H              
239C:                  3F          CMC                   
239D:                  28          DB   0x28             
239E:                  59          MOV  E,C              
239F:                  20          DB   0x20             
23A0:                  4F          MOV  C,A              
23A1:                  52          MOV  D,D              
23A2:                  20          DB   0x20             
23A3:                  4E          MOV  C,M              
23A4:                  29          DAD  H                
23A5:                  20          DB   0x20             
23A6:                  3A CD 65    LDA  0x65cd             ; → EXT_65CD
23A9:                  2A CD FA    LHLD 0xfacd             ; → EXT_FACD
23AC:                  2C          INR  L                
23AD:                  FE 4E       CPI  0x4e             
23AF:                  CA B7 23    JZ   0x23b7             ; → L23B7
23B2:                  21 69 2E    LXI  H,0x2e69           ; → L2E69
23B5:                  AF          XRA  A                
23B6:                  77          MOV  M,A              

; ──────────────────────────────────────────────────────
23B7:  L23B7:          CD 21 2D    CALL 0x2d21             ; → L2D21
23BA:                  E4 00 00    CPO  0x0000             ; → EXT_0000
23BD:                  85          ADD  L                
23BE:                  54          MOV  D,H              
23BF:                  48          MOV  C,B              
23C0:                  45          MOV  B,L              
23C1:                  20          DB   0x20             
23C2:                  57          MOV  D,A              
23C3:                  4F          MOV  C,A              
23C4:                  52          MOV  D,D              
23C5:                  44          MOV  B,H              
23C6:                  53          MOV  D,E              
23C7:                  20          DB   0x20             
23C8:                  59          MOV  E,C              
23C9:                  4F          MOV  C,A              
23CA:                  55          MOV  D,L              
23CB:                  20          DB   0x20             
23CC:                  41          MOV  B,C              
23CD:                  44          MOV  B,H              
23CE:                  44          MOV  B,H              
23CF:                  20          DB   0x20             
23D0:                  4D          MOV  C,L              
23D1:                  55          MOV  D,L              
23D2:                  53          MOV  D,E              
23D3:                  54          MOV  D,H              
23D4:                  20          DB   0x20             
23D5:                  48          MOV  C,B              
23D6:                  41          MOV  B,C              
23D7:                  56          MOV  D,M              
23D8:                  45          MOV  B,L              
23D9:                  20          DB   0x20             
23DA:                  4C          MOV  C,H              
23DB:                  45          MOV  B,L              
23DC:                  53          MOV  D,E              
23DD:                  53          MOV  D,E              
23DE:                  20          DB   0x20             
23DF:                  54          MOV  D,H              
23E0:                  48          MOV  C,B              
23E1:                  41          MOV  B,C              
23E2:                  4E          MOV  C,M              
23E3:                  20          DB   0x20             
23E4:                  32 30 20    STA  0x2030             ; → EXT_2030
23E7:                  41          MOV  B,C              
23E8:                  4C          MOV  C,H              
23E9:                  50          MOV  D,B              
23EA:                  48          MOV  C,B              
23EB:                  41          MOV  B,C              
23EC:                  42          MOV  B,D              
23ED:                  45          MOV  B,L              
23EE:                  54          MOV  D,H              
23EF:                  49          MOV  C,C              
23F0:                  43          MOV  B,E              
23F1:                  20          DB   0x20             
23F2:                  43          MOV  B,E              
23F3:                  48          MOV  C,B              
23F4:                  41          MOV  B,C              
23F5:                  52          MOV  D,D              
23F6:                  41          MOV  B,C              
23F7:                  43          MOV  B,E              
23F8:                  54          MOV  D,H              
23F9:                  45          MOV  B,L              
23FA:                  52          MOV  D,D              
23FB:                  53          MOV  D,E              
23FC:                  20          DB   0x20             
23FD:                  2E 00       MVI  L,0x00           
23FF:                  41          MOV  B,C              
2400:                  46          MOV  B,M              
2401:                  54          MOV  D,H              
2402:                  45          MOV  B,L              
2403:                  52          MOV  D,D              
2404:                  20          DB   0x20             
2405:                  45          MOV  B,L              
2406:                  41          MOV  B,C              
2407:                  43          MOV  B,E              
2408:                  48          MOV  C,B              
2409:                  20          DB   0x20             
240A:                  57          MOV  D,A              
240B:                  4F          MOV  C,A              
240C:                  52          MOV  D,D              
240D:                  44          MOV  B,H              
240E:                  2C          INR  L                
240F:                  20          DB   0x20             
2410:                  50          MOV  D,B              
2411:                  52          MOV  D,D              
2412:                  45          MOV  B,L              
2413:                  53          MOV  D,E              
2414:                  53          MOV  D,E              
2415:                  20          DB   0x20             
2416:                  54          MOV  D,H              
2417:                  48          MOV  C,B              
2418:                  45          MOV  B,L              
2419:                  20          DB   0x20             
241A:                  52          MOV  D,D              
241B:                  45          MOV  B,L              
241C:                  54          MOV  D,H              
241D:                  55          MOV  D,L              
241E:                  52          MOV  D,D              
241F:                  4E          MOV  C,M              
2420:                  20          DB   0x20             
2421:                  4B          MOV  C,E              
2422:                  45          MOV  B,L              
2423:                  59          MOV  E,C              
2424:                  20          DB   0x20             
2425:                  54          MOV  D,H              
2426:                  4F          MOV  C,A              
2427:                  20          DB   0x20             
2428:                  53          MOV  D,E              
2429:                  49          MOV  C,C              
242A:                  47          MOV  B,A              
242B:                  4E          MOV  C,M              
242C:                  49          MOV  C,C              
242D:                  46          MOV  B,M              
242E:                  59          MOV  E,C              
242F:                  20          DB   0x20             
2430:                  54          MOV  D,H              
2431:                  48          MOV  C,B              
2432:                  45          MOV  B,L              
2433:                  20          DB   0x20             
2434:                  45          MOV  B,L              
2435:                  4E          MOV  C,M              
2436:                  44          MOV  B,H              
2437:                  20          DB   0x20             
2438:                  4F          MOV  C,A              
2439:                  46          MOV  B,M              
243A:                  20          DB   0x20             
243B:                  54          MOV  D,H              
243C:                  48          MOV  C,B              
243D:                  45          MOV  B,L              
243E:                  20          DB   0x20             
243F:                  57          MOV  D,A              
2440:                  4F          MOV  C,A              
2441:                  52          MOV  D,D              
2442:                  44          MOV  B,H              
2443:                  2E 00       MVI  L,0x00           
2445:                  49          MOV  C,C              
2446:                  46          MOV  B,M              
2447:                  20          DB   0x20             
2448:                  59          MOV  E,C              
2449:                  4F          MOV  C,A              
244A:                  55          MOV  D,L              
244B:                  20          DB   0x20             
244C:                  4D          MOV  C,L              
244D:                  41          MOV  B,C              
244E:                  4B          MOV  C,E              
244F:                  45          MOV  B,L              
2450:                  20          DB   0x20             
2451:                  41          MOV  B,C              
2452:                  20          DB   0x20             
2453:                  4D          MOV  C,L              
2454:                  49          MOV  C,C              
2455:                  53          MOV  D,E              
2456:                  54          MOV  D,H              
2457:                  41          MOV  B,C              
2458:                  4B          MOV  C,E              
2459:                  45          MOV  B,L              
245A:                  2C          INR  L                
245B:                  20          DB   0x20             
245C:                  50          MOV  D,B              
245D:                  52          MOV  D,D              
245E:                  45          MOV  B,L              
245F:                  53          MOV  D,E              
2460:                  53          MOV  D,E              
2461:                  20          DB   0x20             
2462:                  54          MOV  D,H              
2463:                  48          MOV  C,B              
2464:                  45          MOV  B,L              
2465:                  20          DB   0x20             
2466:                  52          MOV  D,D              
2467:                  55          MOV  D,L              
2468:                  42          MOV  B,D              
2469:                  4F          MOV  C,A              
246A:                  55          MOV  D,L              
246B:                  54          MOV  D,H              
246C:                  20          DB   0x20             
246D:                  4F          MOV  C,A              
246E:                  52          MOV  D,D              
246F:                  20          DB   0x20             
2470:                  44          MOV  B,H              
2471:                  45          MOV  B,L              
2472:                  4C          MOV  C,H              
2473:                  45          MOV  B,L              
2474:                  54          MOV  D,H              
2475:                  45          MOV  B,L              
2476:                  20          DB   0x20             
2477:                  4B          MOV  C,E              
2478:                  45          MOV  B,L              
2479:                  59          MOV  E,C              
247A:                  20          DB   0x20             
247B:                  54          MOV  D,H              
247C:                  4F          MOV  C,A              
247D:                  20          DB   0x20             
247E:                  43          MOV  B,E              
247F:                  41          MOV  B,C              
2480:                  4E          MOV  C,M              
2481:                  43          MOV  B,E              
2482:                  45          MOV  B,L              
2483:                  4C          MOV  C,H              
2484:                  20          DB   0x20             
2485:                  54          MOV  D,H              
2486:                  48          MOV  C,B              
2487:                  45          MOV  B,L              
2488:                  20          DB   0x20             
2489:                  57          MOV  D,A              
248A:                  4F          MOV  C,A              
248B:                  52          MOV  D,D              
248C:                  44          MOV  B,H              
248D:                  00          NOP                   
248E:                  59          MOV  E,C              
248F:                  4F          MOV  C,A              
2490:                  55          MOV  D,L              
2491:                  20          DB   0x20             
2492:                  41          MOV  B,C              
2493:                  52          MOV  D,D              
2494:                  45          MOV  B,L              
2495:                  20          DB   0x20             
2496:                  54          MOV  D,H              
2497:                  59          MOV  E,C              
2498:                  50          MOV  D,B              
2499:                  49          MOV  C,C              
249A:                  4E          MOV  C,M              
249B:                  47          MOV  B,A              
249C:                  2E 00       MVI  L,0x00           
249E:                  00          NOP                   
249F:                  CD 21 2D    CALL 0x2d21             ; → L2D21
24A2:                  50          MOV  D,B              
24A3:                  57          MOV  D,A              
24A4:                  48          MOV  C,B              
24A5:                  45          MOV  B,L              
24A6:                  4E          MOV  C,M              
24A7:                  20          DB   0x20             
24A8:                  59          MOV  E,C              
24A9:                  4F          MOV  C,A              
24AA:                  55          MOV  D,L              
24AB:                  20          DB   0x20             
24AC:                  41          MOV  B,C              
24AD:                  52          MOV  D,D              
24AE:                  45          MOV  B,L              
24AF:                  20          DB   0x20             
24B0:                  46          MOV  B,M              
24B1:                  49          MOV  C,C              
24B2:                  4E          MOV  C,M              
24B3:                  49          MOV  C,C              
24B4:                  53          MOV  D,E              
24B5:                  48          MOV  C,B              
24B6:                  45          MOV  B,L              
24B7:                  44          MOV  B,H              
24B8:                  2C          INR  L                
24B9:                  20          DB   0x20             
24BA:                  50          MOV  D,B              
24BB:                  52          MOV  D,D              
24BC:                  45          MOV  B,L              
24BD:                  53          MOV  D,E              
24BE:                  53          MOV  D,E              
24BF:                  20          DB   0x20             
24C0:                  54          MOV  D,H              
24C1:                  48          MOV  C,B              
24C2:                  45          MOV  B,L              
24C3:                  20          DB   0x20             
24C4:                  52          MOV  D,D              
24C5:                  45          MOV  B,L              
24C6:                  54          MOV  D,H              
24C7:                  55          MOV  D,L              
24C8:                  52          MOV  D,D              
24C9:                  4E          MOV  C,M              
24CA:                  20          DB   0x20             
24CB:                  4B          MOV  C,E              
24CC:                  45          MOV  B,L              
24CD:                  59          MOV  E,C              
24CE:                  20          DB   0x20             
24CF:                  41          MOV  B,C              
24D0:                  47          MOV  B,A              
24D1:                  41          MOV  B,C              
24D2:                  49          MOV  C,C              
24D3:                  4E          MOV  C,M              
24D4:                  20          DB   0x20             
24D5:                  54          MOV  D,H              
24D6:                  4F          MOV  C,A              
24D7:                  20          DB   0x20             
24D8:                  45          MOV  B,L              
24D9:                  58          MOV  E,B              
24DA:                  49          MOV  C,C              
24DB:                  54          MOV  D,H              
24DC:                  20          DB   0x20             
24DD:                  54          MOV  D,H              
24DE:                  48          MOV  C,B              
24DF:                  45          MOV  B,L              
24E0:                  20          DB   0x20             
24E1:                  00          NOP                   
24E2:                  49          MOV  C,C              
24E3:                  4E          MOV  C,M              
24E4:                  53          MOV  D,E              
24E5:                  45          MOV  B,L              
24E6:                  52          MOV  D,D              
24E7:                  54          MOV  D,H              
24E8:                  49          MOV  C,C              
24E9:                  4F          MOV  C,A              
24EA:                  4E          MOV  C,M              
24EB:                  20          DB   0x20             
24EC:                  4D          MOV  C,L              
24ED:                  4F          MOV  C,A              
24EE:                  44          MOV  B,H              
24EF:                  45          MOV  B,L              
24F0:                  2E 00       MVI  L,0x00           
24F2:                  00          NOP                   
24F3:                  CD 78 29    CALL 0x2978             ; → L2978

; ──────────────────────────────────────────────────────
24F6:  L24F6:          3E 3A       MVI  A,0x3a           
24F8:                  CD FA 2C    CALL 0x2cfa             ; → L2CFA
24FB:                  16 13       MVI  D,0x13           
24FD:                  21 F9 2D    LXI  H,0x2df9           ; → L2DF9
2500:                  CD 64 20    CALL 0x2064             ; → L2064
2503:                  FE 0D       CPI  0x0d             
2505:                  C8          RZ                    
2506:                  C3 0C 25    JMP  0x250c             ; → L250C

; ──────────────────────────────────────────────────────
2509:  L2509:          CD 64 20    CALL 0x2064             ; → L2064
; ──────────────────────────────────────────────────────
250C:  L250C:          FE 7F       CPI  0x7f             
250E:                  CA 58 25    JZ   0x2558             ; → L2558
2511:                  FE 0D       CPI  0x0d             
2513:                  CA 67 25    JZ   0x2567             ; → L2567
2516:                  CD 85 29    CALL 0x2985             ; → L2985
2519:                  DA 50 25    JC   0x2550             ; → L2550
251C:                  77          MOV  M,A              
251D:                  23          INX  H                
251E:                  CD FA 2C    CALL 0x2cfa             ; → L2CFA
2521:                  15          DCR  D                
2522:                  C2 09 25    JNZ  0x2509             ; → L2509
2525:                  CD 21 2D    CALL 0x2d21             ; → L2D21
2528:                  24          INR  H                
2529:                  00          NOP                   
252A:                  57          MOV  D,A              
252B:                  4F          MOV  C,A              
252C:                  52          MOV  D,D              
252D:                  44          MOV  B,H              
252E:                  20          DB   0x20             
252F:                  54          MOV  D,H              
2530:                  4F          MOV  C,A              
2531:                  4F          MOV  C,A              
2532:                  20          DB   0x20             
2533:                  4C          MOV  C,H              
2534:                  41          MOV  B,C              
2535:                  52          MOV  D,D              
2536:                  47          MOV  B,A              
2537:                  45          MOV  B,L              
2538:                  2E 20       MVI  L,0x20           
253A:                  20          DB   0x20             
253B:                  50          MOV  D,B              
253C:                  4C          MOV  C,H              
253D:                  45          MOV  B,L              
253E:                  41          MOV  B,C              
253F:                  53          MOV  D,E              
2540:                  45          MOV  B,L              
2541:                  20          DB   0x20             
2542:                  54          MOV  D,H              
2543:                  52          MOV  D,D              
2544:                  59          MOV  E,C              
2545:                  20          DB   0x20             
2546:                  41          MOV  B,C              
2547:                  47          MOV  B,A              
2548:                  41          MOV  B,C              
2549:                  49          MOV  C,C              
254A:                  4E          MOV  C,M              
254B:                  2E 00       MVI  L,0x00           
254D:                  C3 F6 24    JMP  0x24f6             ; → L24F6

; ──────────────────────────────────────────────────────
2550:  L2550:          CD 21 2D    CALL 0x2d21             ; → L2D21
2553:                  01 07 C3    LXI  B,0xc307           ; → EXT_C307
2556:                  09          DAD  B                
2557:                  25          DCR  H                

; ──────────────────────────────────────────────────────
2558:  L2558:          CD 21 2D    CALL 0x2d21             ; → L2D21
255B:                  08          DB   0x08             
255C:                  44          MOV  B,H              
255D:                  45          MOV  B,L              
255E:                  4C          MOV  C,H              
255F:                  45          MOV  B,L              
2560:                  54          MOV  D,H              
2561:                  45          MOV  B,L              
2562:                  44          MOV  B,H              
2563:                  00          NOP                   
2564:                  C3 F6 24    JMP  0x24f6             ; → L24F6

; ──────────────────────────────────────────────────────
2567:  L2567:          CD CC 2B    CALL 0x2bcc             ; → L2BCC
256A:                  2B          DCX  H                
256B:                  7E          MOV  A,M              
256C:                  F6 80       ORI  0x80             
256E:                  77          MOV  M,A              
256F:                  21 66 2E    LXI  H,0x2e66           ; → FRAME_PTR
2572:                  11 F9 2D    LXI  D,0x2df9           ; → L2DF9
2575:                  01 3E 2E    LXI  B,0x2e3e           ; → L2E3E
2578:                  CD 26 2C    CALL 0x2c26             ; → L2C26
257B:                  DA C8 25    JC   0x25c8             ; → L25C8
257E:                  CA F6 24    JZ   0x24f6             ; → L24F6
2581:                  CD 21 2D    CALL 0x2d21             ; → L2D21
2584:                  40          MOV  B,B              
2585:                  00          NOP                   
2586:                  44          MOV  B,H              
2587:                  55          MOV  D,L              
2588:                  50          MOV  D,B              
2589:                  4C          MOV  C,H              
258A:                  49          MOV  C,C              
258B:                  43          MOV  B,E              
258C:                  41          MOV  B,C              
258D:                  54          MOV  D,H              
258E:                  45          MOV  B,L              
258F:                  20          DB   0x20             
2590:                  43          MOV  B,E              
2591:                  4F          MOV  C,A              
2592:                  50          MOV  D,B              
2593:                  59          MOV  E,C              
2594:                  20          DB   0x20             
2595:                  4F          MOV  C,A              
2596:                  46          MOV  B,M              
2597:                  20          DB   0x20             
2598:                  57          MOV  D,A              
2599:                  4F          MOV  C,A              
259A:                  52          MOV  D,D              
259B:                  44          MOV  B,H              
259C:                  20          DB   0x20             
259D:                  46          MOV  B,M              
259E:                  4F          MOV  C,A              
259F:                  55          MOV  D,L              
25A0:                  4E          MOV  C,M              
25A1:                  44          MOV  B,H              
25A2:                  20          DB   0x20             
25A3:                  49          MOV  C,C              
25A4:                  4E          MOV  C,M              
25A5:                  20          DB   0x20             
25A6:                  54          MOV  D,H              
25A7:                  41          MOV  B,C              
25A8:                  42          MOV  B,D              
25A9:                  4C          MOV  C,H              
25AA:                  45          MOV  B,L              
25AB:                  2E 00       MVI  L,0x00           
25AD:                  50          MOV  D,B              
25AE:                  4C          MOV  C,H              
25AF:                  45          MOV  B,L              
25B0:                  41          MOV  B,C              
25B1:                  53          MOV  D,E              
25B2:                  45          MOV  B,L              
25B3:                  20          DB   0x20             
25B4:                  54          MOV  D,H              
25B5:                  52          MOV  D,D              
25B6:                  59          MOV  E,C              
25B7:                  20          DB   0x20             
25B8:                  41          MOV  B,C              
25B9:                  4E          MOV  C,M              
25BA:                  4F          MOV  C,A              
25BB:                  54          MOV  D,H              
25BC:                  48          MOV  C,B              
25BD:                  45          MOV  B,L              
25BE:                  52          MOV  D,D              
25BF:                  20          DB   0x20             
25C0:                  57          MOV  D,A              
25C1:                  4F          MOV  C,A              
25C2:                  52          MOV  D,D              
25C3:                  44          MOV  B,H              
25C4:                  00          NOP                   
25C5:                  C3 F6 24    JMP  0x24f6             ; → L24F6

; ──────────────────────────────────────────────────────
25C8:  L25C8:          CD 21 2D    CALL 0x2d21             ; → L2D21
25CB:                  2D          DCR  L                
25CC:                  00          NOP                   
25CD:                  54          MOV  D,H              
25CE:                  41          MOV  B,C              
25CF:                  42          MOV  B,D              
25D0:                  4C          MOV  C,H              
25D1:                  45          MOV  B,L              
25D2:                  20          DB   0x20             
25D3:                  49          MOV  C,C              
25D4:                  53          MOV  D,E              
25D5:                  20          DB   0x20             
25D6:                  46          MOV  B,M              
25D7:                  55          MOV  D,L              
25D8:                  4C          MOV  C,H              
25D9:                  4C          MOV  C,H              
25DA:                  2E 20       MVI  L,0x20           
25DC:                  20          DB   0x20             
25DD:                  4E          MOV  C,M              
25DE:                  4F          MOV  C,A              
25DF:                  20          DB   0x20             
25E0:                  4D          MOV  C,L              
25E1:                  4F          MOV  C,A              
25E2:                  52          MOV  D,D              
25E3:                  45          MOV  B,L              
25E4:                  20          DB   0x20             
25E5:                  57          MOV  D,A              
25E6:                  4F          MOV  C,A              
25E7:                  52          MOV  D,D              
25E8:                  44          MOV  B,H              
25E9:                  53          MOV  D,E              
25EA:                  20          DB   0x20             
25EB:                  4D          MOV  C,L              
25EC:                  41          MOV  B,C              
25ED:                  59          MOV  E,C              
25EE:                  20          DB   0x20             
25EF:                  42          MOV  B,D              
25F0:                  45          MOV  B,L              
25F1:                  20          DB   0x20             
25F2:                  41          MOV  B,C              
25F3:                  44          MOV  B,H              
25F4:                  44          MOV  B,H              
25F5:                  45          MOV  B,L              
25F6:                  44          MOV  B,H              
25F7:                  2E 00       MVI  L,0x00           
25F9:                  C9          RET                   

; ──────────────────────────────────────────────────────
25FA:  L25FA:          21 69 2E    LXI  H,0x2e69           ; → L2E69
25FD:                  7E          MOV  A,M              
25FE:                  A7          ANA  A                
25FF:                  C2 3B 26    JNZ  0x263b             ; → L263B
2602:                  CD 21 2D    CALL 0x2d21             ; → L2D21
2605:                  32 00 54    STA  0x5400             ; → EXT_5400
2608:                  48          MOV  C,B              
2609:                  45          MOV  B,L              
260A:                  20          DB   0x20             
260B:                  57          MOV  D,A              
260C:                  4F          MOV  C,A              
260D:                  52          MOV  D,D              
260E:                  44          MOV  B,H              
260F:                  20          DB   0x20             
2610:                  4C          MOV  C,H              
2611:                  49          MOV  C,C              
2612:                  53          MOV  D,E              
2613:                  54          MOV  D,H              
2614:                  20          DB   0x20             
2615:                  49          MOV  C,C              
2616:                  53          MOV  D,E              
2617:                  20          DB   0x20             
2618:                  45          MOV  B,L              
2619:                  4D          MOV  C,L              
261A:                  50          MOV  D,B              
261B:                  54          MOV  D,H              
261C:                  59          MOV  E,C              
261D:                  2E 20       MVI  L,0x20           
261F:                  20          DB   0x20             
2620:                  50          MOV  D,B              
2621:                  4C          MOV  C,H              
2622:                  45          MOV  B,L              
2623:                  41          MOV  B,C              
2624:                  53          MOV  D,E              
2625:                  45          MOV  B,L              
2626:                  20          DB   0x20             
2627:                  45          MOV  B,L              
2628:                  4E          MOV  C,M              
2629:                  54          MOV  D,H              
262A:                  45          MOV  B,L              
262B:                  52          MOV  D,D              
262C:                  20          DB   0x20             
262D:                  53          MOV  D,E              
262E:                  4F          MOV  C,A              
262F:                  4D          MOV  C,L              
2630:                  45          MOV  B,L              
2631:                  20          DB   0x20             
2632:                  57          MOV  D,A              
2633:                  4F          MOV  C,A              
2634:                  52          MOV  D,D              
2635:                  44          MOV  B,H              
2636:                  53          MOV  D,E              
2637:                  00          NOP                   
2638:                  C3 B7 21    JMP  0x21b7             ; → L21B7

; ──────────────────────────────────────────────────────
263B:  L263B:          11 00 00    LXI  D,0x0000           ; → EXT_0000
; ──────────────────────────────────────────────────────
263E:  L263E:          7E          MOV  A,M              
263F:                  23          INX  H                
2640:                  A7          ANA  A                
2641:                  CA 4C 26    JZ   0x264c             ; → L264C
2644:                  F2 3E 26    JP   0x263e             ; → L263E
2647:                  23          INX  H                
2648:                  13          INX  D                
2649:                  C3 3E 26    JMP  0x263e             ; → L263E

; ──────────────────────────────────────────────────────
264C:  L264C:          EB          XCHG                  
264D:                  22 3C 2E    SHLD 0x2e3c             ; → L2E3C
2650:                  EB          XCHG                  
2651:                  C9          RET                   

; ──────────────────────────────────────────────────────
2652:  L2652:          AF          XRA  A                
2653:                  32 3F 2E    STA  0x2e3f             ; → L2E3F

; ──────────────────────────────────────────────────────
2656:  L2656:          CD A3 2C    CALL 0x2ca3             ; → L2CA3
2659:                  44          MOV  B,H              
265A:                  4D          MOV  C,L              
265B:                  2A 3C 2E    LHLD 0x2e3c             ; → L2E3C
265E:                  54          MOV  D,H              
265F:                  5D          MOV  E,L              
2660:                  CD E3 2B    CALL 0x2be3             ; → L2BE3
2663:                  21 69 2E    LXI  H,0x2e69           ; → L2E69
2666:                  06 00       MVI  B,0x00           

; ──────────────────────────────────────────────────────
2668:  L2668:          1B          DCX  D                
2669:                  7A          MOV  A,D              
266A:                  A7          ANA  A                
266B:                  FA 78 26    JM   0x2678             ; → L2678

; ──────────────────────────────────────────────────────
266E:  L266E:          7E          MOV  A,M              
266F:                  23          INX  H                
2670:                  A7          ANA  A                
2671:                  F2 6E 26    JP   0x266e             ; → L266E
2674:                  23          INX  H                
2675:                  C3 68 26    JMP  0x2668             ; → L2668

; ──────────────────────────────────────────────────────
2678:  L2678:          E5          PUSH H                
; ──────────────────────────────────────────────────────
2679:  L2679:          7E          MOV  A,M              
267A:                  A7          ANA  A                
267B:                  23          INX  H                
267C:                  F2 79 26    JP   0x2679             ; → L2679
267F:                  7E          MOV  A,M              
2680:                  E1          POP  H                
2681:                  A7          ANA  A                
2682:                  CA 12 27    JZ   0x2712             ; → L2712
2685:                  21 3F 2E    LXI  H,0x2e3f           ; → L2E3F
2688:                  34          INR  M                
2689:                  C2 56 26    JNZ  0x2656             ; → L2656
268C:                  CD 78 29    CALL 0x2978             ; → L2978
268F:                  CD 21 2D    CALL 0x2d21             ; → L2D21
2692:                  69          MOV  L,C              
2693:                  00          NOP                   
2694:                  41          MOV  B,C              
2695:                  4C          MOV  C,H              
2696:                  4D          MOV  C,L              
2697:                  4F          MOV  C,A              
2698:                  53          MOV  D,E              
2699:                  54          MOV  D,H              
269A:                  20          DB   0x20             
269B:                  41          MOV  B,C              
269C:                  4C          MOV  C,H              
269D:                  4C          MOV  C,H              
269E:                  20          DB   0x20             
269F:                  4F          MOV  C,A              
26A0:                  46          MOV  B,M              
26A1:                  20          DB   0x20             
26A2:                  54          MOV  D,H              
26A3:                  48          MOV  C,B              
26A4:                  45          MOV  B,L              
26A5:                  20          DB   0x20             
26A6:                  57          MOV  D,A              
26A7:                  4F          MOV  C,A              
26A8:                  52          MOV  D,D              
26A9:                  44          MOV  B,H              
26AA:                  53          MOV  D,E              
26AB:                  20          DB   0x20             
26AC:                  48          MOV  C,B              
26AD:                  41          MOV  B,C              
26AE:                  56          MOV  D,M              
26AF:                  45          MOV  B,L              
26B0:                  20          DB   0x20             
26B1:                  42          MOV  B,D              
26B2:                  45          MOV  B,L              
26B3:                  45          MOV  B,L              
26B4:                  4E          MOV  C,M              
26B5:                  20          DB   0x20             
26B6:                  43          MOV  B,E              
26B7:                  48          MOV  C,B              
26B8:                  4F          MOV  C,A              
26B9:                  53          MOV  D,E              
26BA:                  45          MOV  B,L              
26BB:                  4E          MOV  C,M              
26BC:                  2E 20       MVI  L,0x20           
26BE:                  20          DB   0x20             
26BF:                  49          MOV  C,C              
26C0:                  46          MOV  B,M              
26C1:                  20          DB   0x20             
26C2:                  59          MOV  E,C              
26C3:                  4F          MOV  C,A              
26C4:                  55          MOV  D,L              
26C5:                  20          DB   0x20             
26C6:                  57          MOV  D,A              
26C7:                  49          MOV  C,C              
26C8:                  53          MOV  D,E              
26C9:                  48          MOV  C,B              
26CA:                  20          DB   0x20             
26CB:                  00          NOP                   
26CC:                  54          MOV  D,H              
26CD:                  4F          MOV  C,A              
26CE:                  20          DB   0x20             
26CF:                  53          MOV  D,E              
26D0:                  54          MOV  D,H              
26D1:                  41          MOV  B,C              
26D2:                  52          MOV  D,D              
26D3:                  54          MOV  D,H              
26D4:                  20          DB   0x20             
26D5:                  4F          MOV  C,A              
26D6:                  56          MOV  D,M              
26D7:                  45          MOV  B,L              
26D8:                  52          MOV  D,D              
26D9:                  2C          INR  L                
26DA:                  20          DB   0x20             
26DB:                  48          MOV  C,B              
26DC:                  49          MOV  C,C              
26DD:                  54          MOV  D,H              
26DE:                  20          DB   0x20             
26DF:                  54          MOV  D,H              
26E0:                  48          MOV  C,B              
26E1:                  45          MOV  B,L              
26E2:                  20          DB   0x20             
26E3:                  22 47 4F    SHLD 0x4f47             ; → EXT_4F47
26E6:                  22 20 4B    SHLD 0x4b20             ; → EXT_4B20
26E9:                  45          MOV  B,L              
26EA:                  59          MOV  E,C              
26EB:                  20          DB   0x20             
26EC:                  4F          MOV  C,A              
26ED:                  4E          MOV  C,M              
26EE:                  20          DB   0x20             
26EF:                  46          MOV  B,M              
26F0:                  52          MOV  D,D              
26F1:                  4F          MOV  C,A              
26F2:                  4E          MOV  C,M              
26F3:                  54          MOV  D,H              
26F4:                  20          DB   0x20             
26F5:                  50          MOV  D,B              
26F6:                  41          MOV  B,C              
26F7:                  4E          MOV  C,M              
26F8:                  45          MOV  B,L              
26F9:                  4C          MOV  C,H              
26FA:                  2E 00       MVI  L,0x00           
26FC:                  AF          XRA  A                
26FD:                  CD 4F 20    CALL 0x204f             ; → L204F
2700:                  21 08 20    LXI  H,0x2008           ; → EXT_2008
2703:                  7E          MOV  A,M              
2704:                  E6 7F       ANI  0x7f             
2706:                  77          MOV  M,A              
2707:                  76          HLT                   
2708:                  21 08 20    LXI  H,0x2008           ; → EXT_2008
270B:                  7E          MOV  A,M              
270C:                  F6 80       ORI  0x80             
270E:                  77          MOV  M,A              
270F:                  C3 64 21    JMP  0x2164             ; → L2164

; ──────────────────────────────────────────────────────
2712:  L2712:          11 0D 2E    LXI  D,0x2e0d           ; → L2E0D
; ──────────────────────────────────────────────────────
2715:  L2715:          7E          MOV  A,M              
2716:                  04          INR  B                
2717:                  E6 7F       ANI  0x7f             
2719:                  12          STAX D                
271A:                  BE          CMP  M                
271B:                  13          INX  D                
271C:                  23          INX  H                
271D:                  CA 15 27    JZ   0x2715             ; → L2715
2720:                  AF          XRA  A                
2721:                  12          STAX D                
2722:                  3C          INR  A                
2723:                  77          MOV  M,A              
2724:                  78          MOV  A,B              
2725:                  32 38 2E    STA  0x2e38             ; → L2E38
2728:                  C9          RET                   

; ──────────────────────────────────────────────────────
2729:  L2729:          CD CC 2B    CALL 0x2bcc             ; → L2BCC
272C:                  CD CC 2B    CALL 0x2bcc             ; → L2BCC
272F:                  AF          XRA  A                
2730:                  32 39 2E    STA  0x2e39             ; → L2E39
2733:                  21 57 2D    LXI  H,0x2d57           ; → L2D57
2736:                  CD 78 29    CALL 0x2978             ; → L2978
2739:                  CD AE 29    CALL 0x29ae             ; → L29AE
273C:                  CD 21 2D    CALL 0x2d21             ; → L2D21
273F:                  11 4C 45    LXI  D,0x454c           ; → EXT_454C
2742:                  54          MOV  D,H              
2743:                  54          MOV  D,H              
2744:                  45          MOV  B,L              
2745:                  52          MOV  D,D              
2746:                  53          MOV  D,E              
2747:                  20          DB   0x20             
2748:                  47          MOV  B,A              
2749:                  55          MOV  D,L              
274A:                  45          MOV  B,L              
274B:                  53          MOV  D,E              
274C:                  53          MOV  D,E              
274D:                  45          MOV  B,L              
274E:                  44          MOV  B,H              
274F:                  3A 20 21    LDA  0x2120             ; → L2120
2752:                  4A          MOV  C,D              
2753:                  2E 7E       MVI  L,0x7e           
2755:                  E6 7F       ANI  0x7f             
2757:                  CA 6E 27    JZ   0x276e             ; → L276E

; ──────────────────────────────────────────────────────
275A:  L275A:          CD FA 2C    CALL 0x2cfa             ; → L2CFA
275D:                  23          INX  H                
275E:                  7E          MOV  A,M              
275F:                  A7          ANA  A                
2760:                  CA 7C 27    JZ   0x277c             ; → L277C
2763:                  3E 2C       MVI  A,0x2c           
2765:                  CD FA 2C    CALL 0x2cfa             ; → L2CFA
2768:                  7E          MOV  A,M              
2769:                  E6 7F       ANI  0x7f             
276B:                  C3 5A 27    JMP  0x275a             ; → L275A

; ──────────────────────────────────────────────────────
276E:  L276E:          CD 21 2D    CALL 0x2d21             ; → L2D21
2771:                  0A          LDAX B                
2772:                  2A 2A 2A    LHLD 0x2a2a             ; → L2A2A
2775:                  4E          MOV  C,M              
2776:                  4F          MOV  C,A              
2777:                  4E          MOV  C,M              
2778:                  45          MOV  B,L              
2779:                  2A 2A 2A    LHLD 0x2a2a             ; → L2A2A

; ──────────────────────────────────────────────────────
277C:  L277C:          CD CC 2B    CALL 0x2bcc             ; → L2BCC
277F:                  21 5F 2D    LXI  H,0x2d5f           ; → L2D5F
2782:                  CD AE 29    CALL 0x29ae             ; → L29AE
2785:                  CD 21 2D    CALL 0x2d21             ; → L2D21
2788:                  0D          DCR  C                
2789:                  54          MOV  D,H              
278A:                  48          MOV  C,B              
278B:                  45          MOV  B,L              
278C:                  20          DB   0x20             
278D:                  57          MOV  D,A              
278E:                  4F          MOV  C,A              
278F:                  52          MOV  D,D              
2790:                  44          MOV  B,H              
2791:                  20          DB   0x20             
2792:                  49          MOV  C,C              
2793:                  53          MOV  D,E              
2794:                  3A 20 11    LDA  0x1120             ; → EXT_1120
2797:                  21 2E 3A    LXI  H,0x3a2e           ; → EXT_3A2E
279A:                  38          DB   0x38             
279B:                  2E 47       MVI  L,0x47           

; ──────────────────────────────────────────────────────
279D:  L279D:          1A          LDAX D                
279E:                  CD FA 2C    CALL 0x2cfa             ; → L2CFA
27A1:                  3E 20       MVI  A,0x20           
27A3:                  CD FA 2C    CALL 0x2cfa             ; → L2CFA
27A6:                  13          INX  D                
27A7:                  05          DCR  B                
27A8:                  C2 9D 27    JNZ  0x279d             ; → L279D
27AB:                  CD CC 2B    CALL 0x2bcc             ; → L2BCC
27AE:                  21 67 2D    LXI  H,0x2d67           ; → L2D67
27B1:                  CD AE 29    CALL 0x29ae             ; → L29AE
27B4:                  3A 38 2E    LDA  0x2e38             ; → L2E38
27B7:                  47          MOV  B,A              

; ──────────────────────────────────────────────────────
27B8:  L27B8:          3E 2D       MVI  A,0x2d           
27BA:                  CD FA 2C    CALL 0x2cfa             ; → L2CFA
27BD:                  3E 20       MVI  A,0x20           
27BF:                  CD FA 2C    CALL 0x2cfa             ; → L2CFA
27C2:                  05          DCR  B                
27C3:                  C2 B8 27    JNZ  0x27b8             ; → L27B8
27C6:                  CD CC 2B    CALL 0x2bcc             ; → L2BCC
27C9:                  21 6F 2D    LXI  H,0x2d6f           ; → L2D6F
27CC:                  CD AE 29    CALL 0x29ae             ; → L29AE
27CF:                  CD 78 29    CALL 0x2978             ; → L2978
27D2:                  3A 35 2E    LDA  0x2e35             ; → L2E35
27D5:                  A7          ANA  A                
27D6:                  C2 D2 28    JNZ  0x28d2             ; → L28D2
27D9:                  CD 21 2D    CALL 0x2d21             ; → L2D21
27DC:                  0C          INR  C                
27DD:                  59          MOV  E,C              
27DE:                  4F          MOV  C,A              
27DF:                  55          MOV  D,L              
27E0:                  52          MOV  D,D              
27E1:                  20          DB   0x20             
27E2:                  47          MOV  B,A              
27E3:                  55          MOV  D,L              
27E4:                  45          MOV  B,L              
27E5:                  53          MOV  D,E              
27E6:                  53          MOV  D,E              
27E7:                  3A 20 CD    LDA  0xcd20             ; → EXT_CD20
27EA:                  8C          ADC  H                
27EB:                  29          DAD  H                
27EC:                  3A 6D 20    LDA  0x206d             ; → L206D
27EF:                  A7          ANA  A                
27F0:                  CA 08 29    JZ   0x2908             ; → L2908
27F3:                  CD 64 20    CALL 0x2064             ; → L2064
27F6:                  CD 85 29    CALL 0x2985             ; → L2985
27F9:                  D2 04 28    JNC  0x2804             ; → L2804

; ──────────────────────────────────────────────────────
27FC:  L27FC:          3E 07       MVI  A,0x07           
27FE:                  CD FA 2C    CALL 0x2cfa             ; → L2CFA
2801:                  C3 E9 27    JMP  0x27e9             ; → L27E9

; ──────────────────────────────────────────────────────
2804:  L2804:          F6 80       ORI  0x80             
2806:                  32 42 2E    STA  0x2e42             ; → L2E42
2809:                  21 47 2E    LXI  H,0x2e47           ; → L2E47
280C:                  11 42 2E    LXI  D,0x2e42           ; → L2E42
280F:                  CD 26 2C    CALL 0x2c26             ; → L2C26
2812:                  C2 FC 27    JNZ  0x27fc             ; → L27FC
2815:                  3A 42 2E    LDA  0x2e42             ; → L2E42
2818:                  E6 7F       ANI  0x7f             
281A:                  4F          MOV  C,A              
281B:                  CD FA 2C    CALL 0x2cfa             ; → L2CFA
281E:                  21 0D 2E    LXI  H,0x2e0d           ; → L2E0D
2821:                  11 21 2E    LXI  D,0x2e21           ; → L2E21
2824:                  06 00       MVI  B,0x00           

; ──────────────────────────────────────────────────────
2826:  L2826:          79          MOV  A,C              
2827:                  BE          CMP  M                
2828:                  C2 2D 28    JNZ  0x282d             ; → L282D
282B:                  04          INR  B                
282C:                  12          STAX D                

; ──────────────────────────────────────────────────────
282D:  L282D:          13          INX  D                
282E:                  23          INX  H                
282F:                  7E          MOV  A,M              
2830:                  A7          ANA  A                
2831:                  C2 26 28    JNZ  0x2826             ; → L2826
2834:                  CD 8C 29    CALL 0x298c             ; → L298C
2837:                  0E 00       MVI  C,0x00           
2839:                  78          MOV  A,B              
283A:                  A7          ANA  A                
283B:                  C2 85 28    JNZ  0x2885             ; → L2885
283E:                  3A 6D 20    LDA  0x206d             ; → L206D
2841:                  A7          ANA  A                
2842:                  C2 71 28    JNZ  0x2871             ; → L2871
2845:                  3A 39 2E    LDA  0x2e39             ; → L2E39
2848:                  A7          ANA  A                
2849:                  C2 71 28    JNZ  0x2871             ; → L2871
284C:                  0C          INR  C                
284D:                  CD 21 2D    CALL 0x2d21             ; → L2D21
2850:                  20          DB   0x20             
2851:                  20          DB   0x20             
2852:                  20          DB   0x20             
2853:                  20          DB   0x20             
2854:                  20          DB   0x20             
2855:                  20          DB   0x20             
2856:                  53          MOV  D,E              
2857:                  4F          MOV  C,A              
2858:                  52          MOV  D,D              
2859:                  52          MOV  D,D              
285A:                  59          MOV  E,C              
285B:                  2E 20       MVI  L,0x20           
285D:                  20          DB   0x20             
285E:                  4C          MOV  C,H              
285F:                  45          MOV  B,L              
2860:                  54          MOV  D,H              
2861:                  54          MOV  D,H              
2862:                  45          MOV  B,L              
2863:                  52          MOV  D,D              
2864:                  20          DB   0x20             
2865:                  4E          MOV  C,M              
2866:                  4F          MOV  C,A              
2867:                  54          MOV  D,H              
2868:                  20          DB   0x20             
2869:                  49          MOV  C,C              
286A:                  4E          MOV  C,M              
286B:                  20          DB   0x20             
286C:                  57          MOV  D,A              
286D:                  4F          MOV  C,A              
286E:                  52          MOV  D,D              
286F:                  44          MOV  B,H              
2870:                  00          NOP                   

; ──────────────────────────────────────────────────────
2871:  L2871:          3A 37 2E    LDA  0x2e37             ; → L2E37
2874:                  3C          INR  A                
2875:                  32 37 2E    STA  0x2e37             ; → L2E37
2878:                  FE 08       CPI  0x08             
287A:                  C2 F5 28    JNZ  0x28f5             ; → L28F5
287D:                  CD C1 29    CALL 0x29c1             ; → L29C1
2880:                  AF          XRA  A                
2881:                  32 6D 20    STA  0x206d             ; → L206D
2884:                  C9          RET                   

; ──────────────────────────────────────────────────────
2885:  L2885:          3A 6D 20    LDA  0x206d             ; → L206D
2888:                  A7          ANA  A                
2889:                  C2 B5 28    JNZ  0x28b5             ; → L28B5
288C:                  3A 39 2E    LDA  0x2e39             ; → L2E39
288F:                  A7          ANA  A                
2890:                  C2 B5 28    JNZ  0x28b5             ; → L28B5
2893:                  0C          INR  C                
2894:                  CD 21 2D    CALL 0x2d21             ; → L2D21
2897:                  1D          DCR  E                
2898:                  20          DB   0x20             
2899:                  20          DB   0x20             
289A:                  20          DB   0x20             
289B:                  20          DB   0x20             
289C:                  20          DB   0x20             
289D:                  47          MOV  B,A              
289E:                  4F          MOV  C,A              
289F:                  4F          MOV  C,A              
28A0:                  44          MOV  B,H              
28A1:                  20          DB   0x20             
28A2:                  43          MOV  B,E              
28A3:                  48          MOV  C,B              
28A4:                  4F          MOV  C,A              
28A5:                  49          MOV  C,C              
28A6:                  43          MOV  B,E              
28A7:                  45          MOV  B,L              
28A8:                  2E 20       MVI  L,0x20           
28AA:                  4B          MOV  C,E              
28AB:                  45          MOV  B,L              
28AC:                  45          MOV  B,L              
28AD:                  50          MOV  D,B              
28AE:                  20          DB   0x20             
28AF:                  49          MOV  C,C              
28B0:                  54          MOV  D,H              
28B1:                  20          DB   0x20             
28B2:                  55          MOV  D,L              
28B3:                  50          MOV  D,B              
28B4:                  00          NOP                   

; ──────────────────────────────────────────────────────
28B5:  L28B5:          21 21 2E    LXI  H,0x2e21           ; → L2E21
28B8:                  3A 38 2E    LDA  0x2e38             ; → L2E38
28BB:                  47          MOV  B,A              

; ──────────────────────────────────────────────────────
28BC:  L28BC:          7E          MOV  A,M              
28BD:                  23          INX  H                
28BE:                  FE 20       CPI  0x20             
28C0:                  CA F5 28    JZ   0x28f5             ; → L28F5
28C3:                  05          DCR  B                
28C4:                  C2 BC 28    JNZ  0x28bc             ; → L28BC
28C7:                  21 35 2E    LXI  H,0x2e35           ; → L2E35
28CA:                  34          INR  M                
28CB:                  AF          XRA  A                
28CC:                  32 6D 20    STA  0x206d             ; → L206D
28CF:                  C3 29 27    JMP  0x2729             ; → L2729

; ──────────────────────────────────────────────────────
28D2:  L28D2:          21 43 2E    LXI  H,0x2e43           ; → L2E43
28D5:                  34          INR  M                
28D6:                  CD 21 2D    CALL 0x2d21             ; → L2D21
28D9:                  1A          LDAX D                
28DA:                  2A 2A 2A    LHLD 0x2a2a             ; → L2A2A
28DD:                  2A 2A 2A    LHLD 0x2a2a             ; → L2A2A
28E0:                  2A 59 4F    LHLD 0x4f59             ; → EXT_4F59
28E3:                  55          MOV  D,L              
28E4:                  20          DB   0x20             
28E5:                  48          MOV  C,B              
28E6:                  41          MOV  B,C              
28E7:                  56          MOV  D,M              
28E8:                  45          MOV  B,L              
28E9:                  20          DB   0x20             
28EA:                  57          MOV  D,A              
28EB:                  4F          MOV  C,A              
28EC:                  4E          MOV  C,M              
28ED:                  2A 2A 2A    LHLD 0x2a2a             ; → L2A2A
28F0:                  2A 2A 2A    LHLD 0x2a2a             ; → L2A2A
28F3:                  2A C9 3A    LHLD 0x3ac9             ; → EXT_3AC9
28F6:                  6D          MOV  L,L              
28F7:                  20          DB   0x20             
28F8:                  A7          ANA  A                
28F9:                  CA 29 27    JZ   0x2729             ; → L2729
28FC:                  0D          DCR  C                
28FD:                  F2 29 27    JP   0x2729             ; → L2729
2900:                  3E 01       MVI  A,0x01           
2902:                  32 39 2E    STA  0x2e39             ; → L2E39
2905:                  C3 E9 27    JMP  0x27e9             ; → L27E9

; ──────────────────────────────────────────────────────
2908:  L2908:          3A 39 2E    LDA  0x2e39             ; → L2E39
290B:                  A7          ANA  A                
290C:                  CA E9 27    JZ   0x27e9             ; → L27E9
290F:                  C3 29 27    JMP  0x2729             ; → L2729

; ──────────────────────────────────────────────────────
2912:  L2912:          CD 21 2D    CALL 0x2d21             ; → L2D21
2915:                  07          RLC                   
2916:                  00          NOP                   
2917:                  94          SUB  H                
2918:                  57          MOV  D,A              
2919:                  4F          MOV  C,A              
291A:                  4E          MOV  C,M              
291B:                  3A 20 3A    LDA  0x3a20             ; → EXT_3A20
291E:                  43          MOV  B,E              
291F:                  2E 5F       MVI  L,0x5f           
2921:                  16 00       MVI  D,0x00           
2923:                  D6 0A       SUI  0x0a             
2925:                  3E 01       MVI  A,0x01           
2927:                  DA 2B 29    JC   0x292b             ; → L292B
292A:                  3C          INR  A                

; ──────────────────────────────────────────────────────
292B:  L292B:          CD C5 2C    CALL 0x2cc5             ; → L2CC5
292E:                  CD 21 2D    CALL 0x2d21             ; → L2D21
2931:                  07          RLC                   
2932:                  85          ADD  L                
2933:                  4C          MOV  C,H              
2934:                  4F          MOV  C,A              
2935:                  53          MOV  D,E              
2936:                  54          MOV  D,H              
2937:                  3A 20 3A    LDA  0x3a20             ; → EXT_3A20
293A:                  46          MOV  B,M              
293B:                  2E 5F       MVI  L,0x5f           
293D:                  16 00       MVI  D,0x00           
293F:                  D6 0A       SUI  0x0a             
2941:                  3E 01       MVI  A,0x01           
2943:                  DA 47 29    JC   0x2947             ; → L2947
2946:                  3C          INR  A                

; ──────────────────────────────────────────────────────
2947:  L2947:          CD C5 2C    CALL 0x2cc5             ; → L2CC5
294A:                  CD 8C 29    CALL 0x298c             ; → L298C
294D:                  CD 78 29    CALL 0x2978             ; → L2978
2950:                  C9          RET                   

; ──────────────────────────────────────────────────────
2951:  L2951:          06 14       MVI  B,0x14           
2953:                  3E 2A       MVI  A,0x2a           

; ──────────────────────────────────────────────────────
2955:  L2955:          CD FA 2C    CALL 0x2cfa             ; → L2CFA
2958:                  05          DCR  B                
2959:                  C2 55 29    JNZ  0x2955             ; → L2955
295C:                  CD CC 2B    CALL 0x2bcc             ; → L2BCC
295F:                  C9          RET                   

; ──────────────────────────────────────────────────────
2960:  L2960:          AF          XRA  A                
2961:                  32 35 2E    STA  0x2e35             ; → L2E35
2964:                  32 37 2E    STA  0x2e37             ; → L2E37
2967:                  32 4A 2E    STA  0x2e4a             ; → L2E4A
296A:                  21 21 2E    LXI  H,0x2e21           ; → L2E21
296D:                  06 14       MVI  B,0x14           
296F:                  3E 20       MVI  A,0x20           

; ──────────────────────────────────────────────────────
2971:  L2971:          77          MOV  M,A              
2972:                  23          INX  H                
2973:                  05          DCR  B                
2974:                  C2 71 29    JNZ  0x2971             ; → L2971
2977:                  C9          RET                   

; ──────────────────────────────────────────────────────
2978:  L2978:          F5          PUSH PSW              
2979:                  F3          DI                    
297A:                  3A AA 20    LDA  0x20aa             ; → STATUS_VAR
297D:                  E6 FD       ANI  0xfd             
297F:                  32 AA 20    STA  0x20aa             ; → STATUS_VAR
2982:                  FB          EI                    
2983:                  F1          POP  PSW              
2984:                  C9          RET                   

; ──────────────────────────────────────────────────────
2985:  L2985:          FE 41       CPI  0x41             
2987:                  D8          RC                    
2988:                  FE 5B       CPI  0x5b             
298A:                  3F          CMC                   
298B:                  C9          RET                   

; ──────────────────────────────────────────────────────
298C:  L298C:          C5          PUSH B                
298D:                  F5          PUSH PSW              
298E:                  01 00 00    LXI  B,0x0000           ; → EXT_0000

; ──────────────────────────────────────────────────────
2991:  L2991:          3A 6D 20    LDA  0x206d             ; → L206D
2994:                  A7          ANA  A                
2995:                  C2 A0 29    JNZ  0x29a0             ; → L29A0
2998:                  0D          DCR  C                
2999:                  C2 91 29    JNZ  0x2991             ; → L2991
299C:                  05          DCR  B                
299D:                  C2 91 29    JNZ  0x2991             ; → L2991

; ──────────────────────────────────────────────────────
29A0:  L29A0:          F1          POP  PSW              
29A1:                  C1          POP  B                
29A2:                  C9          RET                   

; ──────────────────────────────────────────────────────
29A3:  L29A3:          21 48 20    LXI  H,0x2048           ; → L2048
29A6:                  22 A8 20    SHLD 0x20a8             ; → L20A8
29A9:                  AF          XRA  A                
29AA:                  32 AA 20    STA  0x20aa             ; → STATUS_VAR
29AD:                  C9          RET                   

; ──────────────────────────────────────────────────────
29AE:  L29AE:          3A 37 2E    LDA  0x2e37             ; → L2E37
29B1:                  CD DC 2B    CALL 0x2bdc             ; → L2BDC
29B4:                  7E          MOV  A,M              
29B5:                  21 77 2D    LXI  H,0x2d77           ; → L2D77
29B8:                  CD DC 2B    CALL 0x2bdc             ; → L2BDC
29BB:                  7E          MOV  A,M              
29BC:                  23          INX  H                
29BD:                  CD 2F 2D    CALL 0x2d2f             ; → L2D2F
29C0:                  C9          RET                   

; ──────────────────────────────────────────────────────
29C1:  L29C1:          CD 21 2D    CALL 0x2d21             ; → L2D21
29C4:                  14          INR  D                
29C5:                  00          NOP                   
29C6:                  00          NOP                   
29C7:                  3D          DCR  A                
29C8:                  3D          DCR  A                
29C9:                  3D          DCR  A                
29CA:                  20          DB   0x20             
29CB:                  20          DB   0x20             
29CC:                  2D          DCR  L                
29CD:                  2D          DCR  L                
29CE:                  2D          DCR  L                
29CF:                  00          NOP                   
29D0:                  82          ADD  D                
29D1:                  21 20 28    LXI  H,0x2820           ; → L2820
29D4:                  2B          DCX  H                
29D5:                  20          DB   0x20             
29D6:                  2B          DCX  H                
29D7:                  29          DAD  H                
29D8:                  8B          ADC  E                
29D9:                  CD 51 29    CALL 0x2951             ; → L2951
29DC:                  CD 21 2D    CALL 0x2d21             ; → L2D21
29DF:                  08          DB   0x08             
29E0:                  82          ADD  D                
29E1:                  21 20 20    LXI  H,0x2020           ; → EXT_2020
29E4:                  2D          DCR  L                
29E5:                  2D          DCR  L                
29E6:                  2D          DCR  L                
29E7:                  8C          ADC  H                
29E8:                  CD 51 29    CALL 0x2951             ; → L2951
29EB:                  CD 21 2D    CALL 0x2d21             ; → L2D21
29EE:                  32 82 21    STA  0x2182             ; → L2182
29F1:                  5F          MOV  E,A              
29F2:                  5F          MOV  E,A              
29F3:                  5F          MOV  E,A              
29F4:                  49          MOV  C,C              
29F5:                  8D          ADC  L                
29F6:                  2A 2A 90    LHLD 0x902a             ; → EXT_902A
29F9:                  2A 2A 00    LHLD 0x002a             ; → EXT_002A
29FC:                  81          ADD  C                
29FD:                  3C          INR  A                
29FE:                  2D          DCR  L                
29FF:                  2D          DCR  L                
2A00:                  2D          DCR  L                
2A01:                  2D          DCR  L                
2A02:                  49          MOV  C,C              
2A03:                  2D          DCR  L                
2A04:                  2D          DCR  L                
2A05:                  2D          DCR  L                
2A06:                  2D          DCR  L                
2A07:                  3E 88       MVI  A,0x88           
2A09:                  2A 2A 85    LHLD 0x852a             ; → EXT_852A
2A0C:                  52          MOV  D,D              
2A0D:                  20          DB   0x20             
2A0E:                  49          MOV  C,C              
2A0F:                  20          DB   0x20             
2A10:                  50          MOV  D,B              
2A11:                  86          ADD  M                
2A12:                  2A 2A 00    LHLD 0x002a             ; → EXT_002A
2A15:                  86          ADD  M                
2A16:                  4F          MOV  C,A              
2A17:                  8D          ADC  L                
2A18:                  2A 2A 90    LHLD 0x902a             ; → EXT_902A
2A1B:                  2A 2A 00    LHLD 0x002a             ; → EXT_002A
2A1E:                  86          ADD  M                
2A1F:                  4F          MOV  C,A              

; ──────────────────────────────────────────────────────
2A20:  L2A20:          8D          ADC  L                
2A21:                  CD 51 29    CALL 0x2951             ; → L2951
2A24:                  CD 21 2D    CALL 0x2d21             ; → L2D21
2A27:                  05          DCR  B                
2A28:                  85          ADD  L                
2A29:                  2A 20 2A    LHLD 0x2a20             ; → L2A20
2A2C:                  8C          ADC  H                
2A2D:                  CD 51 29    CALL 0x2951             ; → L2951
2A30:                  CD 21 2D    CALL 0x2d21             ; → L2D21
2A33:                  20          DB   0x20             
2A34:                  84          ADD  H                
2A35:                  2A 83 2A    LHLD 0x2a83             ; → L2A83
2A38:                  00          NOP                   
2A39:                  84          ADD  H                
2A3A:                  2A 83 2A    LHLD 0x2a83             ; → L2A83
2A3D:                  00          NOP                   
2A3E:                  83          ADD  E                
2A3F:                  2D          DCR  L                
2A40:                  2D          DCR  L                
2A41:                  83          ADD  E                
2A42:                  2D          DCR  L                
2A43:                  2D          DCR  L                
2A44:                  8A          ADC  D                
2A45:                  54          MOV  D,H              
2A46:                  48          MOV  C,B              
2A47:                  45          MOV  B,L              
2A48:                  20          DB   0x20             
2A49:                  57          MOV  D,A              
2A4A:                  4F          MOV  C,A              
2A4B:                  52          MOV  D,D              
2A4C:                  44          MOV  B,H              
2A4D:                  20          DB   0x20             
2A4E:                  57          MOV  D,A              
2A4F:                  41          MOV  B,C              
2A50:                  53          MOV  D,E              
2A51:                  3A 20 20    LDA  0x2020             ; → EXT_2020
2A54:                  21 46 2E    LXI  H,0x2e46           ; → L2E46
2A57:                  34          INR  M                
2A58:                  21 0D 2E    LXI  H,0x2e0d           ; → L2E0D

; ──────────────────────────────────────────────────────
2A5B:  L2A5B:          7E          MOV  A,M              
2A5C:                  A7          ANA  A                
2A5D:                  C8          RZ                    
2A5E:                  CD FA 2C    CALL 0x2cfa             ; → L2CFA
2A61:                  23          INX  H                
2A62:                  C3 5B 2A    JMP  0x2a5b             ; → L2A5B

; ──────────────────────────────────────────────────────
2A65:  L2A65:          CD 64 20    CALL 0x2064             ; → L2064
2A68:                  FE 59       CPI  0x59             
2A6A:                  C8          RZ                    
2A6B:                  FE 4E       CPI  0x4e             
2A6D:                  C8          RZ                    
2A6E:                  3E 07       MVI  A,0x07           
2A70:                  CD FA 2C    CALL 0x2cfa             ; → L2CFA
2A73:                  C3 65 2A    JMP  0x2a65             ; → L2A65

; ──────────────────────────────────────────────────────
2A76:  L2A76:          E1          POP  H                
2A77:                  5E          MOV  E,M              
2A78:                  23          INX  H                
2A79:                  56          MOV  D,M              
2A7A:                  23          INX  H                
2A7B:                  E5          PUSH H                
2A7C:                  EB          XCHG                  
2A7D:                  22 44 2E    SHLD 0x2e44             ; → RETURN_VEC
2A80:                  21 E5 21    LXI  H,0x21e5           ; → L21E5

; ──────────────────────────────────────────────────────
2A83:  L2A83:          22 A8 20    SHLD 0x20a8             ; → L20A8
2A86:                  C9          RET                   

; ──────────────────────────────────────────────────────
2A87:  L2A87:          3A 36 2E    LDA  0x2e36             ; → L2E36
2A8A:                  FE 4E       CPI  0x4e             
2A8C:                  C8          RZ                    
2A8D:                  CD 78 29    CALL 0x2978             ; → L2978
2A90:                  CD 21 2D    CALL 0x2d21             ; → L2D21
2A93:                  37          STC                   
2A94:                  00          NOP                   
2A95:                  00          NOP                   
2A96:                  44          MOV  B,H              
2A97:                  4F          MOV  C,A              
2A98:                  20          DB   0x20             
2A99:                  59          MOV  E,C              
2A9A:                  4F          MOV  C,A              
2A9B:                  55          MOV  D,L              
2A9C:                  20          DB   0x20             
2A9D:                  57          MOV  D,A              
2A9E:                  41          MOV  B,C              
2A9F:                  4E          MOV  C,M              
2AA0:                  54          MOV  D,H              
2AA1:                  20          DB   0x20             
2AA2:                  54          MOV  D,H              
2AA3:                  4F          MOV  C,A              
2AA4:                  20          DB   0x20             
2AA5:                  53          MOV  D,E              
2AA6:                  41          MOV  B,C              
2AA7:                  56          MOV  D,M              
2AA8:                  45          MOV  B,L              
2AA9:                  20          DB   0x20             
2AAA:                  59          MOV  E,C              
2AAB:                  4F          MOV  C,A              
2AAC:                  55          MOV  D,L              
2AAD:                  52          MOV  D,D              
2AAE:                  20          DB   0x20             
2AAF:                  57          MOV  D,A              
2AB0:                  4F          MOV  C,A              
2AB1:                  52          MOV  D,D              
2AB2:                  44          MOV  B,H              
2AB3:                  20          DB   0x20             
2AB4:                  4C          MOV  C,H              
2AB5:                  49          MOV  C,C              
2AB6:                  53          MOV  D,E              
2AB7:                  54          MOV  D,H              
2AB8:                  20          DB   0x20             
2AB9:                  4F          MOV  C,A              
2ABA:                  4E          MOV  C,M              
2ABB:                  20          DB   0x20             
2ABC:                  54          MOV  D,H              
2ABD:                  41          MOV  B,C              
2ABE:                  50          MOV  D,B              
2ABF:                  45          MOV  B,L              
2AC0:                  3F          CMC                   
2AC1:                  20          DB   0x20             
2AC2:                  28          DB   0x28             
2AC3:                  59          MOV  E,C              
2AC4:                  20          DB   0x20             
2AC5:                  4F          MOV  C,A              
2AC6:                  52          MOV  D,D              
2AC7:                  20          DB   0x20             
2AC8:                  4E          MOV  C,M              
2AC9:                  29          DAD  H                
2ACA:                  3A CD 65    LDA  0x65cd             ; → EXT_65CD
2ACD:                  2A CD FA    LHLD 0xfacd             ; → EXT_FACD
2AD0:                  2C          INR  L                
2AD1:                  FE 4E       CPI  0x4e             
2AD3:                  C8          RZ                    
2AD4:                  CD 21 2D    CALL 0x2d21             ; → L2D21
2AD7:                  A5          ANA  L                
2AD8:                  00          NOP                   
2AD9:                  00          NOP                   
2ADA:                  54          MOV  D,H              
2ADB:                  4F          MOV  C,A              
2ADC:                  20          DB   0x20             
2ADD:                  53          MOV  D,E              
2ADE:                  41          MOV  B,C              
2ADF:                  56          MOV  D,M              
2AE0:                  45          MOV  B,L              
2AE1:                  20          DB   0x20             
2AE2:                  54          MOV  D,H              
2AE3:                  48          MOV  C,B              
2AE4:                  45          MOV  B,L              
2AE5:                  20          DB   0x20             
2AE6:                  4C          MOV  C,H              
2AE7:                  49          MOV  C,C              
2AE8:                  53          MOV  D,E              
2AE9:                  54          MOV  D,H              
2AEA:                  2C          INR  L                
2AEB:                  20          DB   0x20             
2AEC:                  50          MOV  D,B              
2AED:                  52          MOV  D,D              
2AEE:                  45          MOV  B,L              
2AEF:                  50          MOV  D,B              
2AF0:                  41          MOV  B,C              
2AF1:                  52          MOV  D,D              
2AF2:                  45          MOV  B,L              
2AF3:                  20          DB   0x20             
2AF4:                  54          MOV  D,H              
2AF5:                  48          MOV  C,B              
2AF6:                  45          MOV  B,L              
2AF7:                  20          DB   0x20             
2AF8:                  43          MOV  B,E              
2AF9:                  41          MOV  B,C              
2AFA:                  53          MOV  D,E              
2AFB:                  53          MOV  D,E              
2AFC:                  45          MOV  B,L              
2AFD:                  54          MOV  D,H              
2AFE:                  54          MOV  D,H              
2AFF:                  45          MOV  B,L              
2B00:                  20          DB   0x20             
2B01:                  50          MOV  D,B              
2B02:                  4C          MOV  C,H              
2B03:                  41          MOV  B,C              
2B04:                  59          MOV  E,C              
2B05:                  45          MOV  B,L              
2B06:                  52          MOV  D,D              
2B07:                  2F          CMA                   
2B08:                  52          MOV  D,D              
2B09:                  45          MOV  B,L              
2B0A:                  43          MOV  B,E              
2B0B:                  4F          MOV  C,A              
2B0C:                  52          MOV  D,D              
2B0D:                  44          MOV  B,H              
2B0E:                  45          MOV  B,L              
2B0F:                  52          MOV  D,D              
2B10:                  2C          INR  L                
2B11:                  00          NOP                   
2B12:                  54          MOV  D,H              
2B13:                  48          MOV  C,B              
2B14:                  45          MOV  B,L              
2B15:                  4E          MOV  C,M              
2B16:                  20          DB   0x20             
2B17:                  50          MOV  D,B              
2B18:                  52          MOV  D,D              
2B19:                  45          MOV  B,L              
2B1A:                  53          MOV  D,E              
2B1B:                  53          MOV  D,E              
2B1C:                  20          DB   0x20             
2B1D:                  54          MOV  D,H              
2B1E:                  48          MOV  C,B              
2B1F:                  45          MOV  B,L              
2B20:                  20          DB   0x20             
2B21:                  44          MOV  B,H              
2B22:                  55          MOV  D,L              
2B23:                  4D          MOV  C,L              
2B24:                  50          MOV  D,B              
2B25:                  20          DB   0x20             
2B26:                  4B          MOV  C,E              
2B27:                  45          MOV  B,L              
2B28:                  59          MOV  E,C              
2B29:                  20          DB   0x20             
2B2A:                  4F          MOV  C,A              
2B2B:                  4E          MOV  C,M              
2B2C:                  20          DB   0x20             
2B2D:                  54          MOV  D,H              
2B2E:                  48          MOV  C,B              
2B2F:                  45          MOV  B,L              
2B30:                  20          DB   0x20             
2B31:                  48          MOV  C,B              
2B32:                  38          DB   0x38             
2B33:                  20          DB   0x20             
2B34:                  46          MOV  B,M              
2B35:                  52          MOV  D,D              
2B36:                  4F          MOV  C,A              
2B37:                  4E          MOV  C,M              
2B38:                  54          MOV  D,H              
2B39:                  20          DB   0x20             
2B3A:                  50          MOV  D,B              
2B3B:                  41          MOV  B,C              
2B3C:                  4E          MOV  C,M              
2B3D:                  45          MOV  B,L              
2B3E:                  4C          MOV  C,H              
2B3F:                  2E 20       MVI  L,0x20           
2B41:                  20          DB   0x20             
2B42:                  57          MOV  D,A              
2B43:                  48          MOV  C,B              
2B44:                  45          MOV  B,L              
2B45:                  4E          MOV  C,M              
2B46:                  20          DB   0x20             
2B47:                  44          MOV  B,H              
2B48:                  55          MOV  D,L              
2B49:                  4D          MOV  C,L              
2B4A:                  50          MOV  D,B              
2B4B:                  49          MOV  C,C              
2B4C:                  4E          MOV  C,M              
2B4D:                  47          MOV  B,A              
2B4E:                  00          NOP                   
2B4F:                  49          MOV  C,C              
2B50:                  53          MOV  D,E              
2B51:                  20          DB   0x20             
2B52:                  43          MOV  B,E              
2B53:                  4F          MOV  C,A              
2B54:                  4D          MOV  C,L              
2B55:                  50          MOV  D,B              
2B56:                  4C          MOV  C,H              
2B57:                  45          MOV  B,L              
2B58:                  54          MOV  D,H              
2B59:                  45          MOV  B,L              
2B5A:                  2C          INR  L                
2B5B:                  20          DB   0x20             
2B5C:                  50          MOV  D,B              
2B5D:                  52          MOV  D,D              
2B5E:                  45          MOV  B,L              
2B5F:                  53          MOV  D,E              
2B60:                  53          MOV  D,E              
2B61:                  20          DB   0x20             
2B62:                  54          MOV  D,H              
2B63:                  48          MOV  C,B              
2B64:                  45          MOV  B,L              
2B65:                  20          DB   0x20             
2B66:                  47          MOV  B,A              
2B67:                  4F          MOV  C,A              
2B68:                  20          DB   0x20             
2B69:                  4B          MOV  C,E              
2B6A:                  45          MOV  B,L              
2B6B:                  59          MOV  E,C              
2B6C:                  20          DB   0x20             
2B6D:                  54          MOV  D,H              
2B6E:                  4F          MOV  C,A              
2B6F:                  20          DB   0x20             
2B70:                  52          MOV  D,D              
2B71:                  45          MOV  B,L              
2B72:                  53          MOV  D,E              
2B73:                  55          MOV  D,L              
2B74:                  4D          MOV  C,L              
2B75:                  45          MOV  B,L              
2B76:                  20          DB   0x20             
2B77:                  50          MOV  D,B              
2B78:                  4C          MOV  C,H              
2B79:                  41          MOV  B,C              
2B7A:                  59          MOV  E,C              
2B7B:                  2E 00       MVI  L,0x00           
2B7D:                  21 66 2E    LXI  H,0x2e66           ; → FRAME_PTR
2B80:                  11 65 2E    LXI  D,0x2e65           ; → L2E65
2B83:                  CD 60 2C    CALL 0x2c60             ; → L2C60
2B86:                  23          INX  H                
2B87:                  23          INX  H                
2B88:                  22 14 20    SHLD 0x2014             ; → EXT_2014
2B8B:                  3E 00       MVI  A,0x00           
2B8D:                  32 07 20    STA  0x2007             ; → EXT_2007
2B90:                  21 40 20    LXI  H,0x2040           ; → START
2B93:                  22 00 20    SHLD 0x2000             ; → EXT_2000
2B96:                  21 08 20    LXI  H,0x2008           ; → EXT_2008
2B99:                  7E          MOV  A,M              
2B9A:                  E6 7F       ANI  0x7f             
2B9C:                  77          MOV  M,A              
2B9D:                  76          HLT                   
2B9E:                  21 08 20    LXI  H,0x2008           ; → EXT_2008
2BA1:                  7E          MOV  A,M              
2BA2:                  F6 80       ORI  0x80             
2BA4:                  77          MOV  M,A              
2BA5:                  C3 40 20    JMP  0x2040             ; → START

; ──────────────────────────────────────────────────────
2BA8:  L2BA8:          CD 6A 20    CALL 0x206a             ; → L206A
2BAB:                  3E 00       MVI  A,0x00           
2BAD:                  32 43 2E    STA  0x2e43             ; → L2E43
2BB0:                  32 46 2E    STA  0x2e46             ; → L2E46
2BB3:                  21 69 2E    LXI  H,0x2e69           ; → L2E69

; ──────────────────────────────────────────────────────
2BB6:  L2BB6:          7E          MOV  A,M              
2BB7:                  23          INX  H                
2BB8:                  A7          ANA  A                
2BB9:                  F2 B6 2B    JP   0x2bb6             ; → L2BB6
2BBC:                  AF          XRA  A                
2BBD:                  77          MOV  M,A              
2BBE:                  23          INX  H                
2BBF:                  7E          MOV  A,M              
2BC0:                  A7          ANA  A                
2BC1:                  C2 B6 2B    JNZ  0x2bb6             ; → L2BB6
2BC4:                  21 08 20    LXI  H,0x2008           ; → EXT_2008
2BC7:                  7E          MOV  A,M              
2BC8:                  F6 80       ORI  0x80             
2BCA:                  77          MOV  M,A              
2BCB:                  C9          RET                   

; ──────────────────────────────────────────────────────
2BCC:  L2BCC:          CD 21 2D    CALL 0x2d21             ; → L2D21
2BCF:                  06 0D       MVI  B,0x0d           
2BD1:                  0A          LDAX B                
2BD2:                  80          ADD  B                
2BD3:                  80          ADD  B                
2BD4:                  80          ADD  B                
2BD5:                  80          ADD  B                
2BD6:                  00          NOP                   
2BD7:                  00          NOP                   
2BD8:                  00          NOP                   
2BD9:                  00          NOP                   
2BDA:                  00          NOP                   
2BDB:                  C9          RET                   

; ──────────────────────────────────────────────────────
2BDC:  L2BDC:          D5          PUSH D                
2BDD:                  5F          MOV  E,A              
2BDE:                  16 00       MVI  D,0x00           
2BE0:                  19          DAD  D                
2BE1:                  D1          POP  D                
2BE2:                  C9          RET                   

; ──────────────────────────────────────────────────────
2BE3:  L2BE3:          7A          MOV  A,D              
2BE4:                  2F          CMA                   
2BE5:                  57          MOV  D,A              
2BE6:                  7B          MOV  A,E              
2BE7:                  2F          CMA                   
2BE8:                  5F          MOV  E,A              
2BE9:                  13          INX  D                
2BEA:                  7A          MOV  A,D              
2BEB:                  B3          ORA  E                
2BEC:                  CA 22 2C    JZ   0x2c22             ; → L2C22
2BEF:                  AF          XRA  A                

; ──────────────────────────────────────────────────────
2BF0:  L2BF0:          62          MOV  H,D              
2BF1:                  6B          MOV  L,E              
2BF2:                  09          DAD  B                
2BF3:                  D2 00 2C    JNC  0x2c00             ; → L2C00
2BF6:                  3C          INR  A                
2BF7:                  62          MOV  H,D              
2BF8:                  6B          MOV  L,E              
2BF9:                  29          DAD  H                
2BFA:                  EB          XCHG                  
2BFB:                  DA F0 2B    JC   0x2bf0             ; → L2BF0
2BFE:                  EB          XCHG                  
2BFF:                  3D          DCR  A                

; ──────────────────────────────────────────────────────
2C00:  L2C00:          60          MOV  H,B              
2C01:                  69          MOV  L,C              
2C02:                  01 00 00    LXI  B,0x0000           ; → EXT_0000

; ──────────────────────────────────────────────────────
2C05:  L2C05:          F5          PUSH PSW              
2C06:                  19          DAD  D                
2C07:                  DA 10 2C    JC   0x2c10             ; → L2C10
2C0A:                  7D          MOV  A,L              
2C0B:                  93          SUB  E                
2C0C:                  6F          MOV  L,A              
2C0D:                  7C          MOV  A,H              
2C0E:                  9A          SBB  D                
2C0F:                  67          MOV  H,A              

; ──────────────────────────────────────────────────────
2C10:  L2C10:          79          MOV  A,C              
2C11:                  17          RAL                   
2C12:                  4F          MOV  C,A              
2C13:                  78          MOV  A,B              
2C14:                  17          RAL                   
2C15:                  47          MOV  B,A              
2C16:                  37          STC                   
2C17:                  7A          MOV  A,D              
2C18:                  1F          RAR                   
2C19:                  57          MOV  D,A              
2C1A:                  7B          MOV  A,E              
2C1B:                  1F          RAR                   
2C1C:                  5F          MOV  E,A              
2C1D:                  F1          POP  PSW              
2C1E:                  3D          DCR  A                
2C1F:                  F2 05 2C    JP   0x2c05             ; → L2C05

; ──────────────────────────────────────────────────────
2C22:  L2C22:          EB          XCHG                  
2C23:                  60          MOV  H,B              
2C24:                  69          MOV  L,C              
2C25:                  C9          RET                   

; ──────────────────────────────────────────────────────
2C26:  L2C26:          C5          PUSH B                
2C27:                  D5          PUSH D                
2C28:                  CD 60 2C    CALL 0x2c60             ; → L2C60
2C2B:                  C2 33 2C    JNZ  0x2c33             ; → L2C33
2C2E:                  F6 01       ORI  0x01             
2C30:                  C3 5C 2C    JMP  0x2c5c             ; → L2C5C

; ──────────────────────────────────────────────────────
2C33:  L2C33:          EB          XCHG                  
2C34:                  2A A0 2C    LHLD 0x2ca0             ; → L2CA0
2C37:                  7D          MOV  A,L              
2C38:                  93          SUB  E                
2C39:                  7C          MOV  A,H              
2C3A:                  9A          SBB  D                
2C3B:                  EB          XCHG                  
2C3C:                  DA 5D 2C    JC   0x2c5d             ; → L2C5D
2C3F:                  D1          POP  D                
2C40:                  D5          PUSH D                

; ──────────────────────────────────────────────────────
2C41:  L2C41:          1A          LDAX D                
2C42:                  77          MOV  M,A              
2C43:                  A7          ANA  A                
2C44:                  23          INX  H                
2C45:                  13          INX  D                
2C46:                  F2 41 2C    JP   0x2c41             ; → L2C41
2C49:                  3A A2 2C    LDA  0x2ca2             ; → L2CA2
2C4C:                  57          MOV  D,A              
2C4D:                  C3 54 2C    JMP  0x2c54             ; → L2C54

; ──────────────────────────────────────────────────────
2C50:  L2C50:          0A          LDAX B                
2C51:                  77          MOV  M,A              
2C52:                  23          INX  H                
2C53:                  03          INX  B                

; ──────────────────────────────────────────────────────
2C54:  L2C54:          15          DCR  D                
2C55:                  F2 50 2C    JP   0x2c50             ; → L2C50
2C58:                  3E 00       MVI  A,0x00           
2C5A:                  77          MOV  M,A              
2C5B:                  AF          XRA  A                

; ──────────────────────────────────────────────────────
2C5C:  L2C5C:          A7          ANA  A                
; ──────────────────────────────────────────────────────
2C5D:  L2C5D:          D1          POP  D                
2C5E:                  C1          POP  B                
2C5F:                  C9          RET                   

; ──────────────────────────────────────────────────────
2C60:  L2C60:          C5          PUSH B                
2C61:                  D5          PUSH D                
2C62:                  5E          MOV  E,M              
2C63:                  23          INX  H                
2C64:                  56          MOV  D,M              
2C65:                  EB          XCHG                  
2C66:                  22 A0 2C    SHLD 0x2ca0             ; → L2CA0
2C69:                  EB          XCHG                  
2C6A:                  23          INX  H                
2C6B:                  7E          MOV  A,M              
2C6C:                  32 A2 2C    STA  0x2ca2             ; → L2CA2
2C6F:                  23          INX  H                

; ──────────────────────────────────────────────────────
2C70:  L2C70:          D1          POP  D                
2C71:                  D5          PUSH D                
2C72:                  7E          MOV  A,M              
2C73:                  B7          ORA  A                
2C74:                  C2 7B 2C    JNZ  0x2c7b             ; → L2C7B
2C77:                  3C          INR  A                
2C78:                  D1          POP  D                
2C79:                  C1          POP  B                
2C7A:                  C9          RET                   

; ──────────────────────────────────────────────────────
2C7B:  L2C7B:          1A          LDAX D                
2C7C:                  BE          CMP  M                
2C7D:                  C2 89 2C    JNZ  0x2c89             ; → L2C89
2C80:                  A7          ANA  A                
2C81:                  FA 9B 2C    JM   0x2c9b             ; → L2C9B
2C84:                  23          INX  H                
2C85:                  13          INX  D                
2C86:                  C3 7B 2C    JMP  0x2c7b             ; → L2C7B

; ──────────────────────────────────────────────────────
2C89:  L2C89:          7E          MOV  A,M              
2C8A:                  A7          ANA  A                
2C8B:                  23          INX  H                
2C8C:                  F2 89 2C    JP   0x2c89             ; → L2C89
2C8F:                  3A A2 2C    LDA  0x2ca2             ; → L2CA2
2C92:                  85          ADD  L                
2C93:                  6F          MOV  L,A              
2C94:                  3E 00       MVI  A,0x00           
2C96:                  8C          ADC  H                
2C97:                  67          MOV  H,A              
2C98:                  C3 70 2C    JMP  0x2c70             ; → L2C70

; ──────────────────────────────────────────────────────
2C9B:  L2C9B:          AF          XRA  A                
2C9C:                  23          INX  H                
2C9D:                  D1          POP  D                
2C9E:                  C1          POP  B                
2C9F:                  C9          RET                   

; ──────────────────────────────────────────────────────
2CA0:  L2CA0:          3A FD BC    LDA  0xbcfd             ; → EXT_BCFD
; ──────────────────────────────────────────────────────
2CA3:  L2CA3:          2A 40 2E    LHLD 0x2e40             ; → L2E40
2CA6:                  16 0F       MVI  D,0x0f           

; ──────────────────────────────────────────────────────
2CA8:  L2CA8:          7C          MOV  A,H              
2CA9:                  A7          ANA  A                
2CAA:                  1F          RAR                   
2CAB:                  67          MOV  H,A              
2CAC:                  7D          MOV  A,L              
2CAD:                  1F          RAR                   
2CAE:                  6F          MOV  L,A              
2CAF:                  17          RAL                   
2CB0:                  17          RAL                   
2CB1:                  17          RAL                   
2CB2:                  17          RAL                   
2CB3:                  AD          XRA  L                
2CB4:                  17          RAL                   
2CB5:                  17          RAL                   
2CB6:                  17          RAL                   
2CB7:                  E6 40       ANI  0x40             
2CB9:                  B4          ORA  H                
2CBA:                  67          MOV  H,A              
2CBB:                  15          DCR  D                
2CBC:                  C2 A8 2C    JNZ  0x2ca8             ; → L2CA8
2CBF:                  22 40 2E    SHLD 0x2e40             ; → L2E40
2CC2:                  C9          RET                   
2CC3:                  3E 05       MVI  A,0x05           

; ──────────────────────────────────────────────────────
2CC5:  L2CC5:          E5          PUSH H                
; ──────────────────────────────────────────────────────
2CC6:  L2CC6:          F5          PUSH PSW              
2CC7:                  21 EA 2C    LXI  H,0x2cea           ; → L2CEA
2CCA:                  07          RLC                   
2CCB:                  CD DC 2B    CALL 0x2bdc             ; → L2BDC
2CCE:                  7E          MOV  A,M              
2CCF:                  23          INX  H                
2CD0:                  66          MOV  H,M              
2CD1:                  6F          MOV  L,A              
2CD2:                  EB          XCHG                  
2CD3:                  3E FF       MVI  A,0xff           

; ──────────────────────────────────────────────────────
2CD5:  L2CD5:          19          DAD  D                
2CD6:                  3C          INR  A                
2CD7:                  DA D5 2C    JC   0x2cd5             ; → L2CD5
2CDA:                  C6 30       ADI  0x30             
2CDC:                  CD FA 2C    CALL 0x2cfa             ; → L2CFA
2CDF:                  7D          MOV  A,L              
2CE0:                  93          SUB  E                
2CE1:                  5F          MOV  E,A              
2CE2:                  7C          MOV  A,H              
2CE3:                  9A          SBB  D                
2CE4:                  57          MOV  D,A              
2CE5:                  F1          POP  PSW              
2CE6:                  3D          DCR  A                
2CE7:                  C2 C6 2C    JNZ  0x2cc6             ; → L2CC6

; ──────────────────────────────────────────────────────
2CEA:  L2CEA:          E1          POP  H                
2CEB:                  C9          RET                   
2CEC:                  FF          RST  7                
2CED:                  FF          RST  7                
2CEE:                  F6 FF       ORI  0xff             
2CF0:                  9C          SBB  H                
2CF1:                  FF          RST  7                
2CF2:                  18          DB   0x18             
2CF3:                  FC F0 D8    CM   0xd8f0             ; → EXT_D8F0

; ──────────────────────────────────────────────────────
2CF6:  L2CF6:          E3          XTHL                  
2CF7:                  7E          MOV  A,M              
2CF8:                  23          INX  H                
2CF9:                  E3          XTHL                  

; ──────────────────────────────────────────────────────
2CFA:  L2CFA:          F5          PUSH PSW              
2CFB:                  E6 7F       ANI  0x7f             
2CFD:                  CD 67 20    CALL 0x2067             ; → L2067
2D00:                  E5          PUSH H                
2D01:                  21 AB 20    LXI  H,0x20ab           ; → L20AB
2D04:                  34          INR  M                
2D05:                  FE 20       CPI  0x20             
2D07:                  D2 0B 2D    JNC  0x2d0b             ; → L2D0B
2D0A:                  35          DCR  M                

; ──────────────────────────────────────────────────────
2D0B:  L2D0B:          FE 08       CPI  0x08             
2D0D:                  C2 11 2D    JNZ  0x2d11             ; → L2D11
2D10:                  35          DCR  M                

; ──────────────────────────────────────────────────────
2D11:  L2D11:          FE 0D       CPI  0x0d             
2D13:                  C2 18 2D    JNZ  0x2d18             ; → L2D18
2D16:                  36 00       MVI  M,0x00           

; ──────────────────────────────────────────────────────
2D18:  L2D18:          7E          MOV  A,M              
2D19:                  23          INX  H                
2D1A:                  BE          CMP  M                
2D1B:                  D4 CC 2B    CNC  0x2bcc             ; → L2BCC
2D1E:                  E1          POP  H                
2D1F:                  F1          POP  PSW              
2D20:                  C9          RET                   

; ──────────────────────────────────────────────────────
2D21:  L2D21:          E3          XTHL                  
2D22:                  7E          MOV  A,M              
2D23:                  23          INX  H                
2D24:                  E5          PUSH H                
2D25:                  CD DC 2B    CALL 0x2bdc             ; → L2BDC
2D28:                  E3          XTHL                  
2D29:                  CD 2F 2D    CALL 0x2d2f             ; → L2D2F
2D2C:                  E1          POP  H                
2D2D:                  E3          XTHL                  
2D2E:                  C9          RET                   

; ──────────────────────────────────────────────────────
2D2F:  L2D2F:          A7          ANA  A                
2D30:                  C8          RZ                    
2D31:                  F5          PUSH PSW              
2D32:                  7E          MOV  A,M              
2D33:                  23          INX  H                
2D34:                  A7          ANA  A                
2D35:                  FA 44 2D    JM   0x2d44             ; → L2D44
2D38:                  CC CC 2B    CZ   0x2bcc             ; → L2BCC
2D3B:                  CD FA 2C    CALL 0x2cfa             ; → L2CFA

; ──────────────────────────────────────────────────────
2D3E:  L2D3E:          F1          POP  PSW              
2D3F:                  3D          DCR  A                
2D40:                  C2 2F 2D    JNZ  0x2d2f             ; → L2D2F
2D43:                  C9          RET                   

; ──────────────────────────────────────────────────────
2D44:  L2D44:          3D          DCR  A                
2D45:                  F4 F6 2C    CP   0x2cf6             ; → L2CF6
2D48:                  00          NOP                   
2D49:                  A7          ANA  A                

; ──────────────────────────────────────────────────────
2D4A:  L2D4A:          F2 3E 2D    JP   0x2d3e             ; → L2D3E
2D4D:                  F5          PUSH PSW              
2D4E:                  CD F6 2C    CALL 0x2cf6             ; → L2CF6
2D51:                  20          DB   0x20             
2D52:                  F1          POP  PSW              
2D53:                  3D          DCR  A                
2D54:                  C3 4A 2D    JMP  0x2d4a             ; → L2D4A

; ──────────────────────────────────────────────────────
2D57:  L2D57:          00          NOP                   
2D58:                  05          DCR  B                
2D59:                  05          DCR  B                
2D5A:                  05          DCR  B                
2D5B:                  05          DCR  B                
2D5C:                  05          DCR  B                
2D5D:                  05          DCR  B                
2D5E:                  05          DCR  B                

; ──────────────────────────────────────────────────────
2D5F:  L2D5F:          27          DAA                   
2D60:                  27          DAA                   
2D61:                  2A 36 36    LHLD 0x3636             ; → EXT_3636
2D64:                  36 36       MVI  M,0x36           
2D66:                  36 47       MVI  M,0x47           
2D68:                  47          MOV  B,A              
2D69:                  47          MOV  B,A              
2D6A:                  47          MOV  B,A              
2D6B:                  49          MOV  C,C              
2D6C:                  49          MOV  C,C              
2D6D:                  49          MOV  C,C              
2D6E:                  49          MOV  C,C              

; ──────────────────────────────────────────────────────
2D6F:  L2D6F:          4D          MOV  C,L              
2D70:                  4D          MOV  C,L              
2D71:                  4D          MOV  C,L              
2D72:                  4D          MOV  C,L              
2D73:                  4D          MOV  C,L              
2D74:                  52          MOV  D,D              
2D75:                  5D          MOV  E,L              
2D76:                  6E          MOV  L,M              

; ──────────────────────────────────────────────────────
2D77:  L2D77:          04          INR  B                
2D78:                  0A          LDAX B                
2D79:                  0A          LDAX B                
2D7A:                  0A          LDAX B                
2D7B:                  94          SUB  H                
2D7C:                  21 3D 3D    LXI  H,0x3d3d           ; → EXT_3D3D
2D7F:                  3D          DCR  A                
2D80:                  20          DB   0x20             
2D81:                  20          DB   0x20             
2D82:                  2D          DCR  L                
2D83:                  2D          DCR  L                
2D84:                  2D          DCR  L                
2D85:                  00          NOP                   
2D86:                  82          ADD  D                
2D87:                  21 20 28    LXI  H,0x2820           ; → L2820
2D8A:                  2E 20       MVI  L,0x20           
2D8C:                  2E 29       MVI  L,0x29           
2D8E:                  00          NOP                   
2D8F:                  82          ADD  D                
2D90:                  21 20 20    LXI  H,0x2020           ; → EXT_2020
2D93:                  2D          DCR  L                
2D94:                  2D          DCR  L                
2D95:                  2D          DCR  L                
2D96:                  00          NOP                   
2D97:                  82          ADD  D                
2D98:                  21 5F 5F    LXI  H,0x5f5f           ; → EXT_5F5F
2D9B:                  5F          MOV  E,A              
2D9C:                  49          MOV  C,C              
2D9D:                  8D          ADC  L                
2D9E:                  02          STAX B                
2D9F:                  0A          LDAX B                
2DA0:                  94          SUB  H                
2DA1:                  0B          DCX  B                
2DA2:                  20          DB   0x20             
2DA3:                  3C          INR  A                
2DA4:                  2D          DCR  L                
2DA5:                  2D          DCR  L                
2DA6:                  2D          DCR  L                
2DA7:                  2D          DCR  L                
2DA8:                  49          MOV  C,C              
2DA9:                  00          NOP                   
2DAA:                  86          ADD  M                
2DAB:                  4F          MOV  C,A              
2DAC:                  8D          ADC  L                
2DAD:                  10          DB   0x10             
2DAE:                  20          DB   0x20             
2DAF:                  3C          INR  A                
2DB0:                  2D          DCR  L                
2DB1:                  2D          DCR  L                
2DB2:                  2D          DCR  L                
2DB3:                  2D          DCR  L                
2DB4:                  49          MOV  C,C              
2DB5:                  2D          DCR  L                
2DB6:                  2D          DCR  L                
2DB7:                  2D          DCR  L                
2DB8:                  2D          DCR  L                
2DB9:                  3E 00       MVI  A,0x00           
2DBB:                  86          ADD  M                
2DBC:                  4F          MOV  C,A              
2DBD:                  8D          ADC  L                
2DBE:                  01 A1 03    LXI  B,0x03a1           ; → EXT_03A1
2DC1:                  86          ADD  M                
2DC2:                  4F          MOV  C,A              
2DC3:                  9A          SBB  D                
2DC4:                  04          INR  B                
2DC5:                  0A          LDAX B                
2DC6:                  0A          LDAX B                
2DC7:                  0A          LDAX B                
2DC8:                  94          SUB  H                
2DC9:                  0A          LDAX B                
2DCA:                  85          ADD  L                
2DCB:                  2A 00 84    LHLD 0x8400             ; → EXT_8400
2DCE:                  2A 00 84    LHLD 0x8400             ; → EXT_8400
2DD1:                  2A 00 94    LHLD 0x9400             ; → EXT_9400
2DD4:                  10          DB   0x10             
2DD5:                  85          ADD  L                
2DD6:                  2A 20 2A    LHLD 0x2a20             ; → L2A20
2DD9:                  00          NOP                   
2DDA:                  84          ADD  H                
2DDB:                  2A 83 2A    LHLD 0x2a83             ; → L2A83
2DDE:                  00          NOP                   
2DDF:                  84          ADD  H                
2DE0:                  2A 83 2A    LHLD 0x2a83             ; → L2A83
2DE3:                  00          NOP                   
2DE4:                  94          SUB  H                
2DE5:                  13          INX  D                
2DE6:                  85          ADD  L                
2DE7:                  2A 20 2A    LHLD 0x2a20             ; → L2A20
2DEA:                  00          NOP                   
2DEB:                  84          ADD  H                
2DEC:                  2A 83 2A    LHLD 0x2a83             ; → L2A83
2DEF:                  00          NOP                   
2DF0:                  84          ADD  H                
2DF1:                  2A 83 2A    LHLD 0x2a83             ; → L2A83
2DF4:                  00          NOP                   
2DF5:                  83          ADD  E                
2DF6:                  2D          DCR  L                
2DF7:                  2D          DCR  L                
2DF8:                  8F          ADC  A                

; ──────────────────────────────────────────────────────
2DF9:  L2DF9:          3A 85 81    LDA  0x8185             ; → EXT_8185
2DFC:                  00          NOP                   
2DFD:                  E0          RPO                   
2DFE:                  14          INR  D                
2DFF:                  81          ADD  C                
2E00:                  B1          ORA  C                
2E01:                  70          MOV  M,B              
2E02:                  F0          RP                    
2E03:                  71          MOV  M,C              
2E04:                  35          DCR  M                
2E05:                  F0          RP                    
2E06:                  34          INR  M                
2E07:                  F1          POP  PSW              
2E08:                  CE 0C       ACI  0x0c             
2E0A:                  08          DB   0x08             
2E0B:                  05          DCR  B                
2E0C:                  8E          ADC  M                

; ──────────────────────────────────────────────────────
2E0D:  L2E0D:          05          DCR  B                
2E0E:                  4D          MOV  C,L              
2E0F:                  CF          RST  1                
2E10:                  2F          CMA                   
2E11:                  10          DB   0x10             
2E12:                  FD FF 32    CALL 0x32ff             ; → EXT_32FF
2E15:                  1D          DCR  E                
2E16:                  67          MOV  H,A              
2E17:                  7C          MOV  A,H              
2E18:                  80          ADD  B                
2E19:                  51          MOV  D,C              
2E1A:                  80          ADD  B                
2E1B:                  D0          RNC                   
2E1C:                  00          NOP                   
2E1D:                  90          SUB  B                
2E1E:                  88          ADC  B                
2E1F:                  F0          RP                    
2E20:                  F3          DI                    

; ──────────────────────────────────────────────────────
2E21:  L2E21:          30          DB   0x30             
2E22:                  E4 B0 B4    CPO  0xb4b0             ; → EXT_B4B0
2E25:                  B0          ORA  B                
2E26:                  B4          ORA  H                
2E27:                  F1          POP  PSW              
2E28:                  08          DB   0x08             
2E29:                  C4 40 00    CNZ  0x0040             ; → EXT_0040
2E2C:                  48          MOV  C,B              
2E2D:                  44          MOV  B,H              
2E2E:                  04          INR  B                
2E2F:                  0F          RRC                   
2E30:                  00          NOP                   
2E31:                  18          DB   0x18             
2E32:                  00          NOP                   
2E33:                  30          DB   0x30             
2E34:                  81          ADD  C                

; ──────────────────────────────────────────────────────
2E35:  L2E35:          20          DB   0x20             
; ──────────────────────────────────────────────────────
2E36:  L2E36:          F9          SPHL                  
; ──────────────────────────────────────────────────────
2E37:  L2E37:          F3          DI                    
; ──────────────────────────────────────────────────────
2E38:  L2E38:          F4 94 00    CP   0x0094             ; → EXT_0094
2E3B:                  00          NOP                   

; ──────────────────────────────────────────────────────
2E3C:  L2E3C:          3A D0 00    LDA  0x00d0             ; → EXT_00D0
; ──────────────────────────────────────────────────────
2E3F:  L2E3F:          00          NOP                   
; ──────────────────────────────────────────────────────
2E40:  L2E40:          3A F0 70    LDA  0x70f0             ; → EXT_70F0
; ──────────────────────────────────────────────────────
2E43:  L2E43:          B0          ORA  B                
; ──────────────────────────────────────────────────────
2E44:  RETURN_VEC:     B4          ORA  H                
2E45:                  F0          RP                    

; ──────────────────────────────────────────────────────
2E46:  L2E46:          B0          ORA  B                
; ──────────────────────────────────────────────────────
2E47:  L2E47:          65          MOV  H,L              
2E48:                  2E 00       MVI  L,0x00           

; ──────────────────────────────────────────────────────
2E4A:  L2E4A:          3A 4E 46    LDA  0x464e             ; → EXT_464E
2E4D:                  42          MOV  B,D              
2E4E:                  D6 0E       SUI  0x0e             
2E50:                  E1          POP  H                
2E51:                  00          NOP                   
2E52:                  A0          ANA  B                
2E53:                  30          DB   0x30             
2E54:                  1C          INR  E                
2E55:                  21 60 B1    LXI  H,0xb160           ; → EXT_B160
2E58:                  CD 94 F8    CALL 0xf894             ; → EXT_F894
2E5B:                  98          SBB  B                
2E5C:                  92          SUB  D                
2E5D:                  DA 9F CE    JC   0xce9f             ; → EXT_CE9F
2E60:                  2F          CMA                   
2E61:                  33          INX  SP               
2E62:                  AF          XRA  A                
2E63:                  20          DB   0x20             
2E64:                  2C          INR  L                

; ──────────────────────────────────────────────────────
2E65:  L2E65:          80          ADD  B                
; ──────────────────────────────────────────────────────
2E66:  FRAME_PTR:      3A F9 01    LDA  0x01f9             ; → EXT_01F9

; ════════════════════════════════════════════════════════
; ── Word list (high-bit terminates last char) ──────────
2E69:                   ; "JUDGEMENT"
2E73:                   ; "INSURANCE"
2E7D:                   ; "ORIGINAL"
2E86:                   ; "PROGRAM"
2E8E:                   ; "MAGIC"
2E94:                   ; "COMPUTER"
2E9D:                   ; "HISTORY"
2EA5:                   ; "MAGNIFICIENT"
2EB2:                   ; "ENTERTAIN"
2EBC:                   ; "ACHIEVE"
2EC4:                   ; "EXPERIMENT"
2ECF:                   ; "CAPABILITY"
2EDA:                   ; "TECHNOLOGY"
2EE5:                   ; "MATRIMONIAL"
2EF1:                   ; "QUIESCENT"
2EFB:                   ; "MAHOGANY"
2F04:                   ; "STRATEGICAL"
2F10:                   ; "OBJECTIVE"
2F1A:                   ; "ROBOT"
2F20:                   ; "RANDOM"
2F27:                   ; "CALCULATE"
2F31:                   ; "METHOD"
2F38:                   ; "FURNITURE"
2F42:                   ; "ARCHITECTURAL"
2F50:                   ; "PAPER"
2F56:                   ; "COMMON"
2F5D:                   ; "IMPLEMENT"
2F67:                   ; "FOCUS"
2F6D:                   ; "ASTHMA"
2F74:                   ; "PHLEGM"
2F7B:                   ; "SOUVENIR"
2F84:                   ; "RUINATION"
2F8E:                   ; "PROSTRATION"
2F9A:                   ; "CATACLYSM"
2FA4:                   ; "SHIFTLESS"
2FAE:                   ; "SOUFFLE"
2FB6:                   ; "DEITY"
2FBC:                   ; "DECIPHERABLE"
2FC9:                   ; "FRENZIED"
2FD2:                   ; "RHYTHM"
2FD9:                   ; "COLUMN"
2FE0:                   ; "PSYCHOTHERAPY"
2FEE:                   ; "EGOTISTICAL"
2FFA:                   ; "SLOTHFUL"
3003:                   ; "MANY"
3008:                   ; "CLERK"
300E:                   ; "ALTER"
3014:                   ; "KNOWLEDGE"


; ──────────────────────────────────────────────────────
301F:  L301F:          21 64 21    LXI  H,0x2164           ; → L2164
3022:                  22 41 20    SHLD 0x2041             ; → START+1
3025:                  2A 3A 2E    LHLD 0x2e3a             ; → SAVED_SP
3028:                  7C          MOV  A,H              
3029:                  B5          ORA  L                
302A:                  C2 31 30    JNZ  0x3031             ; → L3031
302D:                  39          DAD  SP               
302E:                  22 3A 2E    SHLD 0x2e3a             ; → SAVED_SP

; ──────────────────────────────────────────────────────
3031:  L3031:          F9          SPHL                  
3032:                  C3 40 20    JMP  0x2040             ; → START
3035:                  4F          MOV  C,A              
3036:                  C4 00       CNZ  0x0000             ; → EXT_0000