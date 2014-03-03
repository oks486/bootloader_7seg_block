;******************************************************************************
;                                                                             *
;    Filename         bootloader_7seg_block.asm                               *
;    Date             2014/01/11                                              *
;    File Version     1.0                                                     *
;    Target Device    PIC16F1823                                              *
;    Author           oaks@oks486                                             *
;                                                                             *
;                                                                             *
;    *Note*                                                                   *
;    User program need be designed along the following specifications         *
;                                                                             *
;    Program area         : 0x001 - 0x5FF                                     *
;    Reset vector         : 0x001                                             *
;    Interrupt vector     : 0x004 (normal)                                    *
;    RAM area             : no bootloader restriction                         *
;    EEPROM area          : no bootloader restriction                         *
;    Configuration word   : obey the bootloader settings                      *
;                                                                             *
;    XC8 Linker Option (user program only):                                   *
;        Runtime -> Format hex file for download : on                         *
;        Memory model -> ROM ranges              : 1-5ff                      *
;        Additional options -> Codeoffset        : 1                          *
;                                                                             *
;                                                                             *
;******************************************************************************


	list		p=16f1823		; list directive to define processor
	#include	<p16f1823.inc>	; processor specific variable definitions


; --- Configuration word setup ---
	__CONFIG _CONFIG1, _FOSC_INTOSC & _WDTE_OFF & _PWRTE_ON & _MCLRE_OFF & _CP_OFF & _CPD_OFF & _BOREN_OFF & _CLKOUTEN_OFF & _IESO_OFF & _FCMEN_OFF
	__CONFIG _CONFIG2, _WRT_OFF & _PLLEN_OFF & _STVREN_OFF & _BORV_LO & _LVP_OFF



;------------------------------------------------------------------------------
; Constants and Variables definition
;------------------------------------------------------------------------------
; --- Constants ---
START_ADDR		EQU		0x600		; Bootloader start address
INITPERI_ADDR	EQU		0x760		; Initialize routine address 
DISPSEG_ADDR	EQU		0x7A0		; Display segment routine address

DELICODE		EQU		0x0D		; ASCII code of CR
NEWLCODE		EQU		0x5C		; ASCII code of '\'
BLNKCODE		EQU		0x20		; ASCII code of ' '

MODEENT_1		EQU		0xAA		; 1st code of changing to User Mode
MODEENT_2		EQU		0x55		; 2nd code
MODEENT_3		EQU		0xAA		; 3rd code
CMDUPGEX_1		EQU		0x00		; 4th code (Program Excute Mode)
CMDUPGEX_2		EQU		0x55		; 5th code (Program Excute Mode)
CMDUPGWE_1		EQU		0xFF		; 4th code (Program Write Mode)
CMDUPGWE_2		EQU		0xAA		; 5th code (Program Write Mode)

; --- RAM Addresses used by normal operation ---
RECV_DATA		EQU		0x7D		; Received data
RECV_DATA_PRE	EQU		0x7E		; Pre-received data
TEMP			EQU		0x7F		; Temporary use
MDCOUNT			EQU		0x7F		; Index of entrance code of User Mode
									; (Use same register as TEMP)

; --- RAM Addresses used for flash writing ---
	CBLOCK		0x20				; Bank0
		CHKSUM:			1			; Checksum of incoming data
		BYTE_COUNT:		1			; Number of words in a line
		ADDR_H:			1			; Address of flash program memory (upper)
		ADDR_L:			1			; Address of flash program memory (lower)
		DATA_ARRAY:		0x10		; Buffer for incoming data
	ENDC



;------------------------------------------------------------------------------
; Reset vector
;------------------------------------------------------------------------------

	ORG			0x000				; Reset vector
	GOTO		BOOT_START

	ORG			0x001				; This address contains user program's start address.
USER_PROG_START:
	GOTO		$					; Bootloader will overwrite this value.



;------------------------------------------------------------------------------
; Interrupt service routine
;------------------------------------------------------------------------------

	ORG			0x004
	RETFIE							; Return from interrupt



;------------------------------------------------------------------------------
; Main program
;------------------------------------------------------------------------------

	ORG			START_ADDR
BOOT_TRAP:
	BRA			$					; Trap for illigal user program, wait for reset


BOOT_START:
	CALL		INIT_PERI			; Initialize Peripherals


; --- Receive data from USART --- 
GET_USART_DATA:
	CALL		USART_DATA_RECV		; Wait for byte to be received
	MOVWF		RECV_DATA


; --- Check data --- 
CHECK_MODE_ENT_CODE:
	XORLW		MODEENT_1
	BTFSC		STATUS,Z
	GOTO		CHECK_MODE			; If reception byte is entrance code of User Mode

CHECK_DELIMITER:
	MOVF		RECV_DATA,W
	XORLW		DELICODE
	BTFSS		STATUS,Z
	BRA			CHECK_NEWLINE

	MOVLW		DELICODE
	MOVWF		TXREG				; Send delimiter code to neighbor block
	MOVF		RECV_DATA_PRE,W
	CALL		DISPLAY_SEGMENT		; display LED (argument is W reg)
	MOVF		BLNKCODE,W
	MOVWF		RECV_DATA_PRE		; Clear data
	BRA			GET_USART_DATA

CHECK_NEWLINE:
	MOVF		RECV_DATA,W
	XORLW		NEWLCODE
	BTFSS		STATUS,Z
	BRA			OTHER_CODE

	MOVLW		NEWLCODE
	MOVWF		TXREG				; Send newline code to neighbor block
	MOVF		BLNKCODE,W
	MOVWF		RECV_DATA_PRE		; Clear data
	CALL		DISPLAY_SEGMENT		; display LED (argument is W reg)
	BRA			GET_USART_DATA

OTHER_CODE:
	MOVF		RECV_DATA_PRE,W
	MOVWF		TXREG				; Send reception data to neighbor block
	MOVF		RECV_DATA,W
	MOVWF		RECV_DATA_PRE
	BRA			GET_USART_DATA



; --- Check entrance code for user mode --- 
CHECK_MODE:
	MOVF		RECV_DATA,W
	MOVWF		TXREG				; Send data to neighbor block
	CLRF		MDCOUNT

NEXT_ENTCODE_RECV:
	CALL		USART_DATA_RECV		; Receive next code
	MOVWF		RECV_DATA
	MOVWF		TXREG				; Send data to neighbor block

CHECK_ENTCODE:
	MOVF		MDCOUNT,W
	CALL		MODE_ENT_TBL		; Get entrance code
	XORWF		RECV_DATA,W
	BTFSC		STATUS,Z
	BRA			CHECK_ENTCODE_2		; If reception data and entrance code are corresponding

	MOVF		MDCOUNT,W			; User Mode
	XORLW		0x02
	BTFSS		STATUS,Z
	GOTO		GET_USART_DATA		; Return to normal mode

	MOVLW		0x02				; May be code is program write ...
	ADDWF		MDCOUNT,F
	BRA			CHECK_ENTCODE

CHECK_ENTCODE_2:
	MOVF		MDCOUNT,W
	XORLW		0x03
	BTFSC		STATUS,Z			; Check MDCOUNT value
	GOTO		USER_PROG_START		; Goto user program

	MOVF		MDCOUNT,W
	XORLW		0x05
	BTFSC		STATUS,Z			; Check MDCOUNT value
	GOTO		USER_PROG_WRITE		; Write User Program

	INCF		MDCOUNT,F
	BRA			NEXT_ENTCODE_RECV

; --- Table of entry code ---
MODE_ENT_TBL:
	BRW
	DT			MODEENT_2			; When MDCOUNT = 0
	DT			MODEENT_3
	DT			CMDUPGEX_1			; When MDCOUNT = 2
	DT			CMDUPGEX_2			; When MDCOUNT = 3
	DT			CMDUPGWE_1
	DT			CMDUPGWE_2			; When MDCOUNT = 5



; --- Write user program to flash memory ---
USER_PROG_WRITE:
	BANKSEL		LATA
	MOVLW		B'00010000'			; Control RA5 during flash write process
	MOVWF		LATA				; PORTA output data
	MOVLW		B'00111111'			;
	MOVWF		LATC				; PORTC output data

	CALL		ALL_ERASE_FLASH		; Erase user area (0x001-0x5FF)

	MOVLW		HIGH DATA_ARRAY
	MOVWF		FSR0H

; --- Receive and parse a line ---
GET_HEXLINE:
	CALL		USART_DATA_RECV		; Wait for ':' data
	MOVWF		TXREG				; Send data to neighbor block
	XORLW		':'
	BTFSS		STATUS,Z
	BRA			GET_HEXLINE

	CALL		INIT_DATA_ARRAY		; Initialize array
	BANKSEL		CHKSUM
	CLRF		CHKSUM

	CALL		GET_HEXBYTE			; Byte count
	MOVWF		BYTE_COUNT
	ADDLW		0xEF				; BYTE_COUNT <= 0x10
	BTFSC		STATUS,C
	GOTO		WR_ERROR

	ADDLW		0x11				; BYTE_COUNT => 0
	BTFSS		STATUS,C
	GOTO		WR_ERROR

	CALL		GET_HEXBYTE			; Address (upper)
	MOVWF		ADDR_H
	SUBLW		0x0B				; ADDR_H < 0xC00 (bootloader area 0x600)
	BTFSS		STATUS,C
	GOTO		WR_ERROR

	CALL		GET_HEXBYTE			; Address (lower)
	MOVWF		ADDR_L
	BCF			STATUS,C
	RRF			ADDR_H,F			; Calculate program word address (divide by 2)
	RRF			ADDR_L,F

	CALL		GET_HEXBYTE			; Record type
	MOVWF		TEMP
	XORLW		0x04
	BTFSC		STATUS,Z			; If record type is Extended Linear Address Record
	BRA			GET_EXADDR

	MOVF		TEMP,W
	XORLW		0x01
	BTFSC		STATUS,Z			; If record type is End of File
	GOTO		WR_DONE

	MOVF		TEMP,W
	XORLW		0x00
	BTFSS		STATUS,Z			; If extend address is Data Record
	BRA			GET_HEXLINE			; If not value above, ignore this line

	MOVLW		LOW DATA_ARRAY
	MOVWF		FSR0L

GET_DATA:
	CALL		GET_HEXBYTE			; Get program data
	MOVWI		FSR0++
	DECFSZ		BYTE_COUNT,F
	BRA			GET_DATA

	CALL		GET_HEXBYTE			; Cheacksum
	MOVF		CHKSUM,F
	BTFSS		STATUS,Z			; If checksum is 0, go to write process
	GOTO		WR_ERROR

; --- Treatment reset vector ---
CHECK_RESET_VEC:
	MOVF		ADDR_H,F
	BTFSS		STATUS,Z
	BRA			GO_WRITE			; If upper address is not 0
	MOVF		ADDR_L,F
	BTFSS		STATUS,Z
	BRA			GO_WRITE			; If lower address is not 0

	MOVLW		LOW DATA_ARRAY		; If address is 0, set data to 0xFFFF not to change reset vecotr
	MOVWF		FSR0L

	MOVLW		0xFF
	MOVWI		FSR0++
	MOVWI		FSR0++

GO_WRITE:
	CALL		WRITE_FLASH
	BRA			GET_HEXLINE

GET_EXADDR:
	CALL		GET_HEXBYTE			; Get upper extend address
	XORLW		0x00
	BTFSS		STATUS,Z			; If value is not 0, flash program finish
	GOTO		WR_DONE

	CALL		GET_HEXBYTE			; Get lower extend address
	XORLW		0x00
	BTFSS		STATUS,Z			; If value is not 0, flash program finish
	GOTO		WR_DONE

	BRA			GET_HEXLINE			; If value is 0, receive following data

WR_DONE:
	BANKSEL		TXSTA
	BTFSS		TXSTA,TRMT			; Wait for sending data
	BRA			$-1
	RESET							; software reset

WR_ERROR:
	BANKSEL		LATA
	CLRF		LATA				; PORTA output data
	CLRF		LATC				; PORTC output data

	BRA			$					; Loop and wait for power off



;------------------------------------------------------------------------------
; Initialize DATA_ARRAY for write flash memory
;------------------------------------------------------------------------------
INIT_DATA_ARRAY:
	MOVLW		LOW DATA_ARRAY
	MOVWF		FSR0L

NEXT_WORD:
	MOVLW		0xFF				; Initialize DATA_ARRAY
	MOVWI		FSR0++				; Instruction word is ignored 2 bit of MSB. (0x3FFF)
									; Even if 0xFFFF left, it is not written to flash memory
	MOVF		FSR0L,W
	SUBLW		LOW (DATA_ARRAY + 0x0F)
	BTFSC		STATUS,C
	BRA			NEXT_WORD

	RETURN


;------------------------------------------------------------------------------
; Receive ASCII hex word and construct a byte
;------------------------------------------------------------------------------
GET_HEXBYTE:
	CALL		USART_DATA_RECV
	MOVWF		TXREG				; Send data to neighbor block

	SUBLW		'9'
	BTFSS		STATUS,C			; Check number or alphabet
	ADDLW		0x07				; If data is A to F
	SUBLW		0x09				; If data is 0 to 9
	MOVWF		TEMP
	SWAPF		TEMP,F

	CALL		USART_DATA_RECV
	MOVWF		TXREG				; Send data to neighbor block

	SUBLW		'9'
	BTFSS		STATUS,C			; Check number or alphabet
	ADDLW		0x07				; If data is A to F
	SUBLW		0x09				; If data is 0 to 9
	IORWF		TEMP,W

	BANKSEL		CHKSUM
	ADDWF		CHKSUM,F			; Calculate checksum

	RETURN


;------------------------------------------------------------------------------
; Erase flash memory
;------------------------------------------------------------------------------
ALL_ERASE_FLASH:
	BANKSEL		EEADRL
	CLRF		EEADRH				; MSB of address
	CLRF		EEADRL				; LSB of address

ERASE_START:
	BCF 		EECON1,CFGS
	MOVLW		0xB4
	IORWF		EECON1,F			; EEPGD | LWLO | FREE | WREN = B'10110100'

	MOVLW		0X55
	MOVWF		EECON2
	MOVLW		0XAA
	MOVWF		EECON2
	BSF			EECON1,WR
	NOP
	NOP
	BTFSC		EECON1,WR
	BRA			$-1

	MOVF		EEADRH,W			; Check EEADRH/L = 0x000
	ANDLW		0x0F
	BTFSS		STATUS,Z
	BRA			ERASE_NEXT_ADDR
	MOVF		EEADRL,F
	BTFSS		STATUS,Z
	BRA			ERASE_NEXT_ADDR

SAFE_BOOTSECT:
	BCF 		EECON1,FREE
	BCF 		EECON1,LWLO

	MOVLW		(HIGH START_ADDR) | 0x28	; 0x000 is reset vector of bootloader. Instruction is 'GOTO (START_ADDR)'
	MOVWF		EEDATH						; Restore the instruction immediately to prevent boot inability
	MOVLW		(LOW START_ADDR) + 0x01
	MOVWF		EEDATL

	MOVLW		0X55
	MOVWF		EECON2
	MOVLW		0XAA
	MOVWF		EECON2
	BSF			EECON1,WR
	NOP
	NOP
	BTFSC		EECON1,WR
	BRA			$-1

ERASE_NEXT_ADDR:
	MOVLW		0x10
	ADDWF		EEADRL,F
	BTFSS		STATUS,C
	BRA			ERASE_START

	INCF		EEADRH,F
	MOVLW		0x86
	SUBWF		EEADRH,W
	BTFSS		STATUS,C			; if EEADRH/L < 0x600(0x8600)
	BRA			ERASE_START

ERASE_END:
	CLRF		EECON1
	RETURN


;------------------------------------------------------------------------------
; Write flash memory
;------------------------------------------------------------------------------
WRITE_FLASH:
	MOVLW		LOW ADDR_H
	MOVWF		FSR0L

	BANKSEL		EEADRL
	MOVIW		FSR0++				; Load ADDR_H
	MOVWF		EEADRH				; MSB of address
	MOVIW		FSR0++				; Load ADDR_L
	MOVWF		EEADRL				; LSB of address

	BCF 		EECON1,CFGS
	MOVLW		0xA4
	IORWF		EECON1,F			; EEPGD | WREN | LWLO = B'10100100'

WRITE_START:
	MOVIW		FSR0++				; Load DATA_ARRAY data byte into lower
	MOVWF		EEDATL
	MOVIW		FSR0++				; Load DATA_ARRAY data byte into upper
	MOVWF		EEDATH

	MOVLW		0X55
	MOVWF		EECON2
	MOVLW		0XAA
	MOVWF		EECON2
	BSF			EECON1,WR
	NOP
	NOP
	BTFSC		EECON1,WR
	BRA			$-1

	INCF		EEADRL,F			; Set next flash address

	MOVF		FSR0L,W
	XORLW		LOW (DATA_ARRAY + 0x0E)
	BTFSC		STATUS,Z
	BCF			EECON1,LWLO			; If last one word, actually start Flash memory writting

	MOVF		FSR0L,W
	SUBLW		LOW (DATA_ARRAY + 0x0F)
	BTFSC		STATUS,C
	BRA			WRITE_START			; If last word written, go to end

WRITE_END:
	CLRF		EECON1
	RETURN



;------------------------------------------------------------------------------
; Initialize peripherals
;------------------------------------------------------------------------------
	ORG			INITPERI_ADDR

INIT_PERI:
	BANKSEL		OSCCON
	MOVLW		B'01111000'			; IRCF(6-3) = 16MHz
	MOVWF		OSCCON

CLOCK_STBL_WAIT:
	BTFSS		OSCSTAT,HFIOFS		; PLL wait
	BRA			CLOCK_STBL_WAIT

; --- Port initialize ---
	BANKSEL		LATA
	MOVLW		B'00111111'
	MOVWF		LATA				; PORTA output data
	MOVWF		LATC				; PORTC output data

	BANKSEL		WPUA
	MOVLW		B'00000100'			; PORTA pull-up (unused pin)
	MOVWF		WPUA
	CLRF		WPUC				; PORTA pull-up (no pull-up)

	BANKSEL		ANSELA
    CLRF		ANSELA				; PORTA Analog input disable
    CLRF		ANSELC				; PORTC Analog input disable

	BANKSEL		TRISA
	MOVLW		B'00000110'
    MOVWF		TRISA				; PORTA direction
	CLRF		TRISC				; PORTC direction

	BANKSEL		APFCON
	MOVLW		B'10000100'			; Port Fuction setting
	MOVWF		APFCON				; Tx=RA0, Rx=RA1

; --- USART initialize ---
	BANKSEL		SPBRGL
    CLRF		BAUDCON
	MOVLW		0x19				; Value for baudrate 9600
	MOVWF		SPBRGL				; Set to baudrate couneter

	MOVLW		B'10010000'
	MOVWF		RCSTA				; SPEN(7) = 1, CREN(4) = 1
	MOVLW		B'00100000'
	MOVWF		TXSTA				; TXEN(5) = 1, SYNC(4) = 0

	CLRF		BSR					; Bank0

	RETURN


;------------------------------------------------------------------------------
; Data reception
;------------------------------------------------------------------------------
USART_DATA_RECV:
	BANKSEL		PIR1
	BTFSS		PIR1,RCIF			; Check RCIF bit
	BRA			$ - 1				; If data has not been received

	BANKSEL		RCREG
	MOVF		RCREG,W

	RETURN


;------------------------------------------------------------------------------
; Display 7 segment LED
;------------------------------------------------------------------------------
	ORG			DISPSEG_ADDR

DISPLAY_SEGMENT:
	MOVWF		TEMP				; Store W value to TEMP

	BANKSEL		LATA
	MOVLW		B'00111111'
	MOVWF		LATA				; PORTA output data
	MOVWF		LATC				; PORTC output data

CHECK_DOT:
	BTFSS		TEMP,7				; Dot code (MSB=1) check
	BRA			CHECK_NUMCODE
	BCF			LATC,RC2			; If dot exist, PORTC (RC2) is set to 0
	BCF			TEMP,7				; Dot code (MSB=1) remove

CHECK_NUMCODE:
	MOVF		TEMP,W
	SUBLW		'9'
	BTFSS		STATUS,C
	BRA			CHECK_A2FCODE1		; If data > '9' then check A-F code

	SUBLW		0x09
	BTFSS		STATUS,C
	BRA			DISP_BLANK			; If data < '0' then set blank code
	BRA			DISP_PORT_CTRL

CHECK_A2FCODE1:
	MOVF		TEMP,W
	SUBLW		'F'
	BTFSS		STATUS,C
	BRA			CHECK_A2FCODE2		; If data > 'F' then check a-f code

	SUBLW		0x05
	BTFSS		STATUS,C
	BRA			DISP_BLANK			; If data < 'A' then set blank code

	ADDLW		0x0a
	BRA			DISP_PORT_CTRL

CHECK_A2FCODE2:
	MOVF		TEMP,W
	SUBLW		'f'
	BTFSS		STATUS,C
	BRA			DISP_BLANK			; If data > 'f' then set blank code

	SUBLW		0x05
	BTFSS		STATUS,C
	BRA			DISP_BLANK			; If data < 'a' then set blank code

	ADDLW		0x0a
	BRA			DISP_PORT_CTRL

DISP_BLANK:
	MOVLW		0x10

DISP_PORT_CTRL:
	MOVWF		TEMP				; Store W value to TEMP

	CALL		DISP_PORTA			; Get segment output data
	ANDWF		LATA,F				; Set data to PORTA

	MOVF		TEMP,W
	CALL		DISP_PORTC			; Get segment output data
	ANDWF		LATC,F				; Set data to PORTC

	RETURN

; --- Data table for segment output ---
DISP_PORTA:
	BRW								; Add index value with PC
	DT			B'00100000'			; segment data '0'
	DT			B'00110000'			; segment data '1'
	DT			B'00010000'			; segment data '2'
	DT			B'00010000'			; segment data '3'
	DT			B'00000000'			; segment data '4'
	DT			B'00000000'			; segment data '5'
	DT			B'00000000'			; segment data '6'
	DT			B'00110000'			; segment data '7'
	DT			B'00000000'			; segment data '8'
	DT			B'00000000'			; segment data '9'
	DT			B'00000000'			; segment data 'A'
	DT			B'00000000'			; segment data 'B'
	DT			B'00100000'			; segment data 'C'
	DT			B'00010000'			; segment data 'D'
	DT			B'00000000'			; segment data 'E'
	DT			B'00000000'			; segment data 'F'
	DT			B'00111111'			; segment data ' '

DISP_PORTC:
	BRW								; Add index value with PC
	DT			B'00000100'			; segment data '0'
	DT			B'00111100'			; segment data '1'
	DT			B'00000110'			; segment data '2'
	DT			B'00001100'			; segment data '3'
	DT			B'00111100'			; segment data '4'
	DT			B'00001101'			; segment data '5'
	DT			B'00000101'			; segment data '6'
	DT			B'00011100'			; segment data '7'
	DT			B'00000100'			; segment data '8'
	DT			B'00001100'			; segment data '9'
	DT			B'00010100'			; segment data 'A'
	DT			B'00100101'			; segment data 'B'
	DT			B'00000111'			; segment data 'C'
	DT			B'00100100'			; segment data 'D'
	DT			B'00000111'			; segment data 'E'
	DT			B'00010111'			; segment data 'F'
	DT			B'00111111'			; segment data ' '


;------------------------------------------------------------------------------

	END

