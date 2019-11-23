; MALUVA for PCW (C) 2018 Uto
; LGPL License applies, see LICENSE file
; TO BE COMPILED WITH SJASMPLUS

                        ORG $013C
                        OUTPUT "MLV_PCW.BIN"


                        define BDOS                      $0005   ; MSXDOS function calls
                        define FCB                       $005C   ; File control block address


                        define F_OPEN                    $0F
                        define F_CLOSE                   $10
                        define F_DMAOFF                  $1A
                        define F_RANDOM_BLOCK_READ       $21

                        define DAAD_PRINTMSG_ADDR_ES     $C1F9


            			define JIFFY					$FC9E ; The timer variable


; ********************************************************************                        
;                           CONSTANTS 
; *******************************************************************

Start                   
                        DI
; ---- Preserve registers
                        PUSH    BC
                        PUSH    IX


; --- Check function selected
                        LD      D, A
                        LD      A, (BC)
                        CP      3
                        JP      Z, xMessage
						CP      4
						JR      Z, XPart
						CP 		255
						JP 		Z, RestoreXMessage
                        JR      cleanExit

cleanAndClose           CALL closeFile

cleanExit               POP     IX
                        POP     BC
                        EI
                        RET

                        

; XPart function
XPart				    LD 		A, D
					    ADD		'0'
					    LD      (XMESSFilename), A
					    JP 		cleanExit


; XBeep , beep replacement

XBeep				    LD 		L, D    ; First parameter (duration) to L					
						POP 	IX
						POP 	BC
						INC 	BC
						LD 		A, (BC) ; Third parameter (tone) to A
                        LD      E, A
						XOR 	A
						LD 		D, A  ;  At this point, DE=tone, L=duration
						PUSH 	BC
						PUSH 	IX

						LD   IX,sfxFreqPSG - 48	; DE=get frequency from tone table
						ADD  IX,DE
						LD   E,(IX+0)
						LD   D,(IX+1)

						LD   C,$A1

						XOR  A					; REG#0 ChannelA Tone LowByte
						OUT  ($A0),A
						OUT  (C),E
						INC  A					; REG#1 ChannelA Tone HighByte
						OUT  ($A0),A
						OUT  (C),D

						LD   A,8				; REG#8 ChannelA Volume to 8
						OUT  ($A0),A
						OUT  (C),A

						LD   A,7				; REG#7 Mixer enable ChannelA
						OUT  ($A0),A
						LD   A,00111110b
						OUT  ($A1),A

BeepSilence				EX   DE,HL
						SRL  E
						CALL NZ,SilenceWait
					
						LD   A,7				; REG#7 Mixer disable ChannelA
						OUT  ($A0),A
						LD   A,00111111b
						OUT  ($A1),A

						JP   cleanExit

SilenceWait									; Wait for E = 1/50 seconds
                        EI
						LD  HL,JIFFY			; Cogemos la address donde se cuenta el tiempo en 1/50sec
loop0					LD  A,(HL)
loop1					CP  (HL)
						JR  Z,loop1
						DEC E
						JR  NZ,loop0
                        DI
						RET

; Frequencies table
sfxFreqPSG				DW	0xD65, 0xC9D, 0xBEB, 0xB42, 0xA9A, 0xA04, 0x971, 0x8E8, 0x86B, 0x7E2, 0x77F, 0x719	// Octave 1 (48-70) 
						DW	0x6B3, 0x64E, 0x5F5, 0x5A1, 0x54D, 0x502, 0x4B9, 0x474, 0x434, 0x3F9, 0x3C0, 0x38C	// Octave 2 (72-98)
						DW	0x359, 0x327, 0x2F6, 0x2D1, 0x2A7, 0x281, 0x25C, 0x23A, 0x21A, 0x1FD, 0x1E0, 0x1C6, // Octave 3 (96-118) 
						DW	0x1AD, 0x194, 0x17D, 0x168, 0x153, 0x141, 0x12E, 0x11D, 0x10D, 0x0FE, 0x0F0, 0x0E3  // Octave 4 (120-142)
						DW	0x0D6, 0x0CA, 0x0BF, 0x0B4, 0x0AA, 0x0A0, 0x097, 0x08F, 0x087, 0x07F, 0x078, 0x072	// Octave 5 (144-166) 
						DW	0x06B, 0x065, 0x05F, 0x05A, 0x055, 0x050, 0x04C, 0x047, 0x043, 0x040, 0x03C, 0x039	// Octave 6 (168-190)
						DW	0x036, 0x033, 0x030, 0x02D, 0x02A, 0x028, 0x026, 0x024, 0x022, 0x020, 0x01E, 0x01C	// Octave 7 (192-214) 
						DW	0x01B, 0x019, 0x018, 0x017, 0x015, 0x014, 0x013, 0x012, 0x011, 0x010, 0x00F, 0x00E  // Octave 8 (216-238)


; Xmessage printing
xMessage			    LD 		L, D ;  Offset MSB
				    	POP 	IX
				    	POP 	BC
				    	INC 	BC	 ; We need not only to increase BC, but also make sure when exiting it returns increased, and cleanExit will restore it from stack so we have to update valus at stack
				    	LD 		A, (BC)
				    	PUSH 	BC
				    	PUSH 	IX
				    	LD 		H, A ; Offset LSB
                        LD      (Offset), HL
                        
; ------- Open file      
                        LD      HL, XMESSFilename
                        CALL    openFile                        ; Prepares the FCB and opens the file
                        OR      A                               ; On failure to open, exit
                        JP      NZ, cleanExit



; -------- Calculate offset in number of CP/M records
                        
                        LD      HL, (Offset)                    ; Restore offset where the message is and divide by 128 (which is taking the 9 most significative bits of HL)
                                                                
                        ADD     HL, HL                          ; HLx2, shifts all bits left and most significative bit goes to carry flag
                        LD      L, H                            ; Take the upper 8 bits and move to L
                        LD      H, 0                            ; Let the most significative byte ay H be 0
                        RL      H                               ; And move carry flag to H. Now HL = offset / 128

; ------- Read file (read 5 x 128 byte blocks)                  ; See WorkBuffer variable comment below to know why five

                        LD      DE, WorkBuffer                  ; Set the workbuffer as target
                        LD      B, 5                            ; iterate 5 times

ReadLoop                LD      (FCB+$21), HL                   ; Define file offset where to read from. Actually offset for CP/M 3.0 (CP/M Plus) is defined by 18 bit at $21,$22,$23. We skip $21 so it's zero
                        PUSH    BC
                        PUSH    DE
                        PUSH    HL
                        LD      C, F_DMAOFF                     ; Set where to read to (or write to )
                        CALL    BDOS
                        LD      C, F_RANDOM_BLOCK_READ
                        LD      DE, FCB
                        CALL    BDOS
                        POP     HL                              ; POP old HL
                        INC     HL                                  
                        EX      DE, HL                          ; Preserve HL in DE
                        POP     HL                              ; POP old DE
                        LD      BC, 128         
                        ADD     HL, BC                          ; HL =HL +128
                        EX      DE, HL                          ; Now DE=DE+128 and HL=HL+1
                        POP     BC
                        DJNZ    ReadLoop
                     
; ------- Print message 
                        LD      HL, (Offset)    ; The original message offset includes the part we already calculated in 128 byte records, plus a remainder which is where the message actually starts in the first 128 record
                        LD      A, L
                        AND     $7F             ; So we get that reminder (AND $7F)
                        LD      L, A
                        LD      H, 0            
                        LD      BC, WorkBuffer  ; And add it to WorkBuffer
                        ADD     HL, BC          ; to get the address where real message starts in HL
                        PUSH    HL


                        ; OK, this below needs to be explained: I didn't find a way to call the DAAD function to print text and make it work with an xmessage already loaded in RAM. Everything
						; worked but the \n or  #n carriage return. The function was at address $1629 in the spanish interpreter. Then I decided to do the following: try to make the text
						; being printed by the MES condact, and to do that I as going to execute a MES condact. How do I do that?
						; 1) I modified first entry in the messages offsets table, preserving the value there before, to the address where the xmessage is loaded in RAM
						; 2) I was udpating BC and making sure it is returned modified to the stack. DAAD uses BC as it's internal "PC" register, so changing BC actually makes DAAD run 
						;    opcodes somewhere else. I pointed it to a zone in RAM (see below) where I already had sorted two condacts: MES 0, and EXTERN 0 255. MES 0 prints the text 
						;    using MES condact and then EXTERN 0 255...
						; 3) is another function in Maluva I'm using to restore the Message 0 pointer, and restoring BC, so the execution continues just after the XMES/XMESSAGE call


						LD 		HL, $0110      ; DAAD Header pointer to MESSAGES table
						LD 		E, (HL)
						INC 	HL
						LD 		D, (HL)
						EX      HL, DE		   ; HL points to message pointers table
						LD 		E, (HL)
						INC		HL
						LD 		D, (HL)  		; Now DE has the value of first message pointer, and HL points to where that pointer is

						LD      (PreserveFirstMES),DE
						POP		DE				; Restore the message offset
						LD 		(HL), D
						DEC		HL
						LD 		(HL), E			; Store the offset at first message pointer 

						POP 	IX
						POP 	BC
						LD 		(PreserveBC), BC
						LD 		BC, FakeCondacts - 1		; Make DAAD "PC" point to our fake condacts
						PUSH 	BC
						PUSH 	IX


						JP      cleanAndClose  ; Close file and exit

						; So this is an unreachable (by the Z80 CPU) piece of codem which is actually DAAD code 
FakeCondacts			DB 		$4D, 0,     $3D, 0, $FF   ; MES 0 EXTERN 0 255

                        
RestoreXMessage			LD 		HL, $0110      ; DAAD Header pointer to MESSAGES table
						LD 		E, (HL)
						INC 	HL
						LD 		D, (HL)
						LD 		HL, PreserveFirstMES
						LDI
						LDI
						POP 	IX
						POP 	BC
						LD 		BC, (PreserveBC)
						EI
						RET



; ********************************************************************                        
;                           AUX FUNCTIONS
; *******************************************************************

;- -------------------------------------------------------------------------------------------
; Input: DE= address to read/write to, it's input to F_SET_TRANSFER_ADDRESS
setRandomReadAddress
                        


;----------------------------------------------------------------------------
prepareFCB              PUSH    HL
clearFCB                LD      HL, FCB                       ; Fills FCB with Zeroes
                        XOR     A
                        LD      (HL), A
                        LD      DE, FCB +1
                        LD      BC, 1Eh + 11
                        LDIR                   
                        POP     HL                      ; And copies Filename on FCB to open/create
                        LD      DE, FCB + 1           
                        LD      BC, 11
                        LDIR                                                           
                        RET


; openFile -----------------------------------------------------------------
;input:   HL --> points to 11 chars filename
openFile                CALL    prepareFCB
                        LD      C, F_OPEN
                        LD      DE, FCB
                        CALL    BDOS                  
                        RET

; closefile --------------------------------------------------------------------------------------------------------------
closeFile               LD      C, F_CLOSE
                        LD      DE, FCB
                        CALL    BDOS                  
                        RET

; ---------------------------------------------------------------------------
XMESSFilename			DB      "0       XMB"
Offset                  DW      0
PreserveFirstMES		DW      0
PreserveBC				DW      0
WorkBuffer              DS      128*5                                        ; for XMEssages. CP/M only allow reading files by  128 byte records, so in the worst case a 512 byte message may take up to 5 records
; ---------------------------------------------------------------------------