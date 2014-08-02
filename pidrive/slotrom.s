PISLOT	EQU	ROMSLOT
BOOTDEV	EQU	ROMSLOT*16
	ORG	$C000+ROMSLOT*256
;*
;* ACIA REGISTERS
;*
ACIADR	EQU	$C088+PISLOT*16
ACIASR	EQU	$C089+PISLOT*16
ACIACR	EQU	$C08A+PISLOT*16
ACIAMR	EQU	$C08B+PISLOT*16
;*
;* APPLE I/O LOCATIONS
;*
INDCTR	EQU	$0400
KEYBD	EQU	$C000
STROBE	EQU	$C010
;*
;* DRIVER SCRATCHPAD
;*
PAD0	EQU	$0478+ROMSLOT
PAD1	EQU	$04F8+ROMSLOT
PAD2	EQU	$0578+ROMSLOT
PAD3	EQU	$05F8+ROMSLOT
PAD4	EQU	$0678+ROMSLOT
PAD5	EQU	$06F8+ROMSLOT
PAD6	EQU	$0778+ROMSLOT
PAD7	EQU	$07F8+ROMSLOT
;*
;* UTIL ROUTINES
;*
WAIT	EQU	$FCA8
COUT	EQU	$FDED
CROUT	EQU	$FD8E
PRBYTE	EQU	$FDDA
PRHEX	EQU	$FDE3
PRNTAX	EQU	$F941
RDKEY	EQU	$FD0C
RDCHAR	EQU	$FD35
GETLN	EQU	$FD6A
;*
;* ZERO PAGE PARAMETERS
;*
PDCMD	EQU	$42
PDUNIT	EQU	$43
PDBUFF	EQU	$44
PDBUFL	EQU	$44
PDBUFH	EQU	$45
PDBLKL	EQU	$46
PDBLKH	EQU	$47
;*
;* PRODOS COMMANDS
;*
PDSTAT	EQU	0
PDREAD	EQU	1
PDWRITE	EQU	2
PDFORMT	EQU	3
;*
;* PRODOS ERRORS
;*
PDNOERR	EQU	$00
PDIOERR	EQU	$27
PDNODEV	EQU	$28
PDWRPRT	EQU	$2B
;*
;* AUTOSTART BOOT SIGNATURE
;*
	LDX	#$20
	LDY	#$00
	LDX	#$03
	STX	$3C
;*
;* INIT ACIA
;*
	STY	PAD1            ; CLEAR SYNCED FLAG
	STY	ACIASR		; RESET STATUS REGISTER
	LDA	#$0B
	STA	ACIACR		; SET CONTROL REGISTER
	LDA	#$10
	STA	ACIAMR		; SET COMMAND REGISTER (115K BAUD)
;*
;* CREATE COMMAND BUFFER FOR BOOT BLOCK
;*
	STY	PDUNIT
	STY	PDBUFL
	STY	PDBLKL
	STY	PDBLKH
	INY                     ; LDY	#PDREAD
	STY	PDCMD
	LDY     #$08
        STY	PDBUFH
	JSR	DOCMD
	BCC	BOOT
	LDA	$00
	BEQ     CONT
        RTS
CONT:	JMP	$FABA		; JUMP BACK TO AUTOSTART BOOT SCANNER ROM
BOOT:	LDX	#BOOTDEV
	STX	PDUNIT
	JMP	$801
;*
;* PRODOS INTELLIGENT DEVICE ENTRYPOINT
;*
DOCMD:	PHP
	SEI
	LDA	PAD1
	CMP	#$81
	BEQ	SNDCMD
;*
;* SYNC WITH HOST
;*
SYNC:	LDA	#$80
	STA	ACIADR
	LDA	INDCTR
	PHA
	INX
	TXA
	AND	#$07
	TAX
	LDA	SPIN,X
	STA	INDCTR
	LDA	#$FF
	JSR	WAIT
	PLA
	STA	INDCTR
	LDA	KEYBD
	BPL	CHKRSP
	STA	STROBE
	BMI	IOERR
SPIN:	DB	$A1, $AF, $AD, $DC, $A1, $AF, $AD, $DC
CHKRSP:	LDA	ACIASR
	AND	#$08
	BEQ	SYNC
	LDA	ACIADR
	CMP	#$81
	BNE	SYNC
	STA	PAD1
SNDCMD:	LDA	PDUNIT
	ASL
	LDA	PDCMD
	ROL
	ASL
	ORA	#$A0
	STA	PAD0
	JSR	SENDACC
	LDA	PDBLKL
	JSR	SENDACC
	LDA	PDBLKH
	JSR	SENDACC
CHKACK: JSR	RECVACC
	TAX
	DEX
	CPX	PAD0
	BNE	CHKACK
 	LDY	PDCMD
	BEQ	STATUS
	LDX	#$02		; # OF PAGES TO XFER
	DEY			; CPY #PDREAD
	BEQ	RDBLK
	DEY			; CMP #PDWRITE
	BEQ	WRBLK
IOERR:	LDA	#PDIOERR
CMDERR:	PLP
	SEC
	RTS
RDBLK:	JSR	RECVACC
	STA	(PDBUFF),Y
	INY
	BNE	RDBLK
	INC	PDBUFH
	DEX
	BNE	RDBLK
STATUS: LDX	#$FF
        DEY			; LDY	#$FF
CMDEX:	JSR	RECVACC
	BNE	CMDERR
	PLP
	CLC
	RTS
WRBLK:	LDA	(PDBUFF),Y
	JSR	SENDACC
	INY
	BNE	WRBLK
	INC	PDBUFH
	DEX
	BNE	WRBLK
        BEQ	CMDEX
;*
;* ACIA I/O ROUTINES
;*
SENDACC:
	PHA
SENDWT:	LDA	ACIASR
	AND	#$10
	BEQ	SENDWT
	PLA
	STA	ACIADR
	RTS
RECVACC:
RECVWT:	LDA	ACIASR
	AND	#$08
	BEQ	RECVWT
	LDA	ACIADR
	RTS
ENDCMD:
	.REPEAT $C000+ROMSLOT*256+250-*
	DB	$FF
	.ENDREP
	DB	"Pi"
	DW	0
	DB	$97
	DB	<DOCMD
	.ASSERT	* = $C000+(ROMSLOT+1)*256, error, "Code not page size"
