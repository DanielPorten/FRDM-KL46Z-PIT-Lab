    TTL Serial I/O Driver
;****************************************************************
;Configures KL46Z for timer operations.
;Name:  Daniel Porten
;Date:  10/17/2017
;Class:  CMPE-250
;Section:  L1: Tuesday, 2-4PM
;---------------------------------------------------------------
;Keil Template for KL46
;R. W. Melton
;September 25, 2017
;****************************************************************
;Assembler directives
            THUMB
            OPT    64  ;Turn on listing macro expansions
;****************************************************************
;Include files
            GET  MKL46Z4.s     ;Included by start.s
            OPT  1   ;Turn on listing
;****************************************************************
;EQUates
;---------------------------------------------------------------
;NVIC_ICER
;31-00:CLRENA=masks for HW IRQ sources;
;             read:   0 = unmasked;   1 = masked
;             write:  0 = no effect;  1 = mask
;22:PIT IRQ mask
;12:UART0 IRQ mask
NVIC_ICER_PIT_MASK    EQU  PIT_IRQ_MASK
NVIC_ICER_UART0_MASK  EQU  UART0_IRQ_MASK
;---------------------------------------------------------------
;NVIC_ICPR
;31-00:CLRPEND=pending status for HW IRQ sources;
;             read:   0 = not pending;  1 = pending
;             write:  0 = no effect;
;                     1 = change status to not pending
;22:PIT IRQ pending status
;12:UART0 IRQ pending status
NVIC_ICPR_PIT_MASK    EQU  PIT_IRQ_MASK
NVIC_ICPR_UART0_MASK  EQU  UART0_IRQ_MASK
;---------------------------------------------------------------
;NVIC_IPR0-NVIC_IPR7
;2-bit priority:  00 = highest; 11 = lowest
;--PIT
PIT_IRQ_PRIORITY    EQU  0
NVIC_IPR_PIT_MASK   EQU  (3 << PIT_PRI_POS)
NVIC_IPR_PIT_PRI_0  EQU  (PIT_IRQ_PRIORITY << UART0_PRI_POS)
;--UART0
UART0_IRQ_PRIORITY    EQU  3
NVIC_IPR_UART0_MASK   EQU  (3 << UART0_PRI_POS)
NVIC_IPR_UART0_PRI_3  EQU  (UART0_IRQ_PRIORITY << UART0_PRI_POS)
;---------------------------------------------------------------
;NVIC_ISER
;31-00:SETENA=masks for HW IRQ sources;
;             read:   0 = masked;     1 = unmasked
;             write:  0 = no effect;  1 = unmask
;22:PIT IRQ mask
;12:UART0 IRQ mask
NVIC_ISER_PIT_MASK    EQU  PIT_IRQ_MASK
NVIC_ISER_UART0_MASK  EQU  UART0_IRQ_MASK
;---------------------------------------------------------------
;PIT_LDVALn:  PIT load value register n
;31-00:TSV=timer start value (period in clock cycles - 1)
;Clock ticks for 0.01 s at 24 MHz count rate
;0.01 s * 24,000,000 Hz = 240,000
;TSV = 240,000 - 1
PIT_LDVAL_10ms  EQU  239999
;---------------------------------------------------------------
;PIT_MCR:  PIT module control register
;1-->    0:FRZ=freeze (continue'/stop in debug mode)
;0-->    1:MDIS=module disable (PIT section)
;               RTI timer not affected
;               must be enabled before any other PIT setup
PIT_MCR_EN_FRZ  EQU  PIT_MCR_FRZ_MASK
;---------------------------------------------------------------
;PIT_TCTRLn:  PIT timer control register n
;0-->   2:CHN=chain mode (enable)
;1-->   1:TIE=timer interrupt enable
;1-->   0:TEN=timer enable
PIT_TCTRL_CH_IE  EQU  (PIT_TCTRL_TEN_MASK :OR: PIT_TCTRL_TIE_MASK)
;---------------------------------------------------------------
;PORTx_PCRn (Port x pin control register n [for pin n])
;___->10-08:Pin mux control (select 0 to 8)
;Use provided PORT_PCR_MUX_SELECT_2_MASK
;---------------------------------------------------------------
;Port A
PORT_PCR_SET_PTA1_UART0_RX  EQU  (PORT_PCR_ISF_MASK :OR: \
                                  PORT_PCR_MUX_SELECT_2_MASK)
PORT_PCR_SET_PTA2_UART0_TX  EQU  (PORT_PCR_ISF_MASK :OR: \
                                  PORT_PCR_MUX_SELECT_2_MASK)
;---------------------------------------------------------------
;SIM_SCGC4
;1->10:UART0 clock gate control (enabled)
;Use provided SIM_SCGC4_UART0_MASK
;---------------------------------------------------------------
;SIM_SCGC5
;1->09:Port A clock gate control (enabled)
;Use provided SIM_SCGC5_PORTA_MASK
;---------------------------------------------------------------
;SIM_SOPT2
;01=27-26:UART0SRC=UART0 clock source select
;         (PLLFLLSEL determines MCGFLLCLK' or MCGPLLCLK/2)
; 1=   16:PLLFLLSEL=PLL/FLL clock select (MCGPLLCLK/2)
SIM_SOPT2_UART0SRC_MCGPLLCLK  EQU  \
                                 (1 << SIM_SOPT2_UART0SRC_SHIFT)
SIM_SOPT2_UART0_MCGPLLCLK_DIV2 EQU \
    (SIM_SOPT2_UART0SRC_MCGPLLCLK :OR: SIM_SOPT2_PLLFLLSEL_MASK)
;---------------------------------------------------------------
;SIM_SOPT5
; 0->   16:UART0 open drain enable (disabled)
; 0->   02:UART0 receive data select (UART0_RX)
;00->01-00:UART0 transmit data select source (UART0_TX)
SIM_SOPT5_UART0_EXTERN_MASK_CLEAR  EQU  \
                               (SIM_SOPT5_UART0ODE_MASK :OR: \
                                SIM_SOPT5_UART0RXSRC_MASK :OR: \
                                SIM_SOPT5_UART0TXSRC_MASK)
;---------------------------------------------------------------
;UART0_BDH
;    0->  7:LIN break detect IE (disabled)
;    0->  6:RxD input active edge IE (disabled)
;    0->  5:Stop bit number select (1)
;00001->4-0:SBR[12:0] (UART0CLK / [9600 * (OSR + 1)]) 
;UART0CLK is MCGPLLCLK/2
;MCGPLLCLK is 96 MHz
;MCGPLLCLK/2 is 48 MHz
;SBR = 48 MHz / (9600 * 16) = 312.5 --> 312 = 0x138
UART0_BDH_9600  EQU  0x01
;---------------------------------------------------------------
;UART0_BDL
;26->7-0:SBR[7:0] (UART0CLK / [9600 * (OSR + 1)])
;UART0CLK is MCGPLLCLK/2
;MCGPLLCLK is 96 MHz
;MCGPLLCLK/2 is 48 MHz
;SBR = 48 MHz / (9600 * 16) = 312.5 --> 312 = 0x138
UART0_BDL_9600  EQU  0x38
;---------------------------------------------------------------
;UART0_C1
;0-->7:LOOPS=loops select (normal)
;0-->6:DOZEEN=doze enable (disabled)
;0-->5:RSRC=receiver source select (internal--no effect LOOPS=0)
;0-->4:M=9- or 8-bit mode select 
;        (1 start, 8 data [lsb first], 1 stop)
;0-->3:WAKE=receiver wakeup method select (idle)
;0-->2:IDLE=idle line type select (idle begins after start bit)
;0-->1:PE=parity enable (disabled)
;0-->0:PT=parity type (even parity--no effect PE=0)
UART0_C1_8N1  EQU  0x00
;---------------------------------------------------------------
;UART0_C2
;0-->7:TIE=transmit IE for TDRE (disabled)
;0-->6:TCIE=transmission complete IE for TC (disabled)
;0-->5:RIE=receiver IE for RDRF (disabled)
;0-->4:ILIE=idle line IE for IDLE (disabled)
;1-->3:TE=transmitter enable (enabled)
;1-->2:RE=receiver enable (enabled)
;0-->1:RWU=receiver wakeup control (normal)
;0-->0:SBK=send break (disabled, normal)
UART0_C2_T_R    EQU  (UART0_C2_TE_MASK :OR: UART0_C2_RE_MASK)
UART0_C2_T_RI   EQU  (UART0_C2_RIE_MASK :OR: UART0_C2_T_R)
UART0_C2_TI_RI  EQU  (UART0_C2_TIE_MASK :OR: UART0_C2_T_RI)
;---------------------------------------------------------------
;UART0_C3
;0-->7:R8T9=9th data bit for receiver (not used M=0)
;           10th data bit for transmitter (not used M10=0)
;0-->6:R9T8=9th data bit for transmitter (not used M=0)
;           10th data bit for receiver (not used M10=0)
;0-->5:TXDIR=UART_TX pin direction in single-wire mode
;            (no effect LOOPS=0)
;0-->4:TXINV=transmit data inversion (not inverted)
;0-->3:ORIE=overrun IE for OR (disabled)
;0-->2:NEIE=noise error IE for NF (disabled)
;0-->1:FEIE=framing error IE for FE (disabled)
;0-->0:PEIE=parity error IE for PF (disabled)
UART0_C3_NO_TXINV  EQU  0x00
;---------------------------------------------------------------
;UART0_C4
;    0-->  7:MAEN1=match address mode enable 1 (disabled)
;    0-->  6:MAEN2=match address mode enable 2 (disabled)
;    0-->  5:M10=10-bit mode select (not selected)
;01111-->4-0:OSR=over sampling ratio (16)
;               = 1 + OSR for 3 <= OSR <= 31
;               = 16 for 0 <= OSR <= 2 (invalid values)
UART0_C4_OSR_16           EQU  0x0F
UART0_C4_NO_MATCH_OSR_16  EQU  UART0_C4_OSR_16
;---------------------------------------------------------------
;UART0_C5
;  0-->  7:TDMAE=transmitter DMA enable (disabled)
;  0-->  6:Reserved; read-only; always 0
;  0-->  5:RDMAE=receiver full DMA enable (disabled)
;000-->4-2:Reserved; read-only; always 0
;  0-->  1:BOTHEDGE=both edge sampling (rising edge only)
;  0-->  0:RESYNCDIS=resynchronization disable (enabled)
UART0_C5_NO_DMA_SSR_SYNC  EQU  0x00
;---------------------------------------------------------------
;UART0_S1
;0-->7:TDRE=transmit data register empty flag; read-only
;0-->6:TC=transmission complete flag; read-only
;0-->5:RDRF=receive data register full flag; read-only
;1-->4:IDLE=idle line flag; write 1 to clear (clear)
;1-->3:OR=receiver overrun flag; write 1 to clear (clear)
;1-->2:NF=noise flag; write 1 to clear (clear)
;1-->1:FE=framing error flag; write 1 to clear (clear)
;1-->0:PF=parity error flag; write 1 to clear (clear)
UART0_S1_CLEAR_FLAGS  EQU  0x1F
;---------------------------------------------------------------
;UART0_S2
;1-->7:LBKDIF=LIN break detect interrupt flag (clear)
;             write 1 to clear
;1-->6:RXEDGIF=RxD pin active edge interrupt flag (clear)
;              write 1 to clear
;0-->5:(reserved); read-only; always 0
;0-->4:RXINV=receive data inversion (disabled)
;0-->3:RWUID=receive wake-up idle detect
;0-->2:BRK13=break character generation length (10)
;0-->1:LBKDE=LIN break detect enable (disabled)
;0-->0:RAF=receiver active flag; read-only
UART0_S2_NO_RXINV_BRK10_NO_LBKDETECT_CLEAR_FLAGS  EQU  0xC0
;---------------------------------------------------------------
LF EQU 10
CR EQU 13
NULL EQU 0
MAX_STRING EQU 79

;Queue Operation
IN_PTR EQU 0
OUT_PTR EQU 4
BUFF_START EQU 8
BUFF_PAST EQU 12
BUFF_SIZE EQU 16
NUM_INQUEUE EQU 17
Tx_Rx_Q_BUF_SZ EQU 80
Q_REC_SZ EQU 18
;****************************************************************
;Program
;Linker requires Reset_Handler
            AREA    MyCode,CODE,READONLY
            ENTRY
            EXPORT  Reset_Handler
            IMPORT  Startup
Reset_Handler  PROC  {},{}
main
;---------------------------------------------------------------
;Mask interrupts
            CPSID   I
;KL46 system startup with 48-MHz system clock
            BL      Startup
;---------------------------------------------------------------
;>>>>> begin main program code <<<<<
			BL		Init_UART0_IRQ		;initialize UART0 for interrupts
			CPSIE	I					;unmask interrupts
			LDR		R0,=RunStopWatch
			MOVS	R1,#0
			STRB	R1,[R0,#0]			;RunStopWatch == 0
			LDR		R0,=Count
			STR		R1,[R0,#0]			;Count == 0
			BL		Init_PIT_IRQ		;initialize PIT

			LDR		R0,=EnterName		
			MOVS	R1,#MAX_STRING
			BL		PutStringSB			;print name prompt
			BL		GetUserInput
			LDR		R0,=EnterDate
			BL		PutStringSB			;print date prompt
			BL		GetUserInput
			LDR		R0,=EnterTA
			BL		PutStringSB			;print TA prompt
			BL		GetUserInput
			LDR		R0,=GoodBye
			BL		PutStringSB			;goodbye!
;>>>>>   end main program code <<<<<
;Stay here
            B       .
            ENDP
;>>>>> begin subroutine code <<<<<
GetUserInput PROC {R0-R14},{}
;------------------------------------
;gets user input and times how long it takes
;inputs; none
;outputs; none
;------------------------------------
			PUSH	{R0-R2,LR}
			LDR		R0,=Count
			MOVS	R2,#0
			STR		R2,[R0,#0]			;count == 0
			LDR		R0,=RunStopWatch
			MOVS	R1,#1
			STRB	R1,[R0,#0]			;begin timing (RunStopWatch == 1)
			BL		GetStringSB			;get user input
			STRB	R2,[R0,#0]			;end timing   (RunStopWatch == 0)
			
			MOVS	R0,#'<'
			BL		PutChar
			LDR		R0,=Count
			LDR		R0,[R0,#0]
			BL		PutNumU
			LDR		R0,=TimeReturn
			MOVS	R1,#MAX_STRING
			BL		PutStringSB			;print time elapsed
			POP		{R0-R2,PC}
			ENDP
				
PIT_ISR PROC {R0-R14},{}
;------------------------------------
;Handles PIT interrupts.
;R0,R1 handled by ISR mechanics; no need to push.
;------------------------------------
			CPSID	I
			LDR 	R0,=RunStopWatch
			CMP		R0,#0						;if RunStopWatch != 0
			BEQ		EndPIT_ISR					;else go to end of ISR
			LDR		R0,=Count	
			LDR		R1,[R0,#0]
			ADDS	R1,R1,#1
			STR		R1,[R0,#0]					;increment count
EndPIT_ISR
			LDR		R0,=PIT_CH0_BASE
			LDR		R1,=PIT_TFLG_TIF_MASK
			STR		R1,[R0,#PIT_TFLG_OFFSET]	;clear interrupt
			
			CPSIE	I
			BX		LR
			ENDP
			
Init_PIT_IRQ PROC {R0-R14},{}
;------------------------------------
;Initializes PIT to generate interrupts
;every .01s from channel 0.
;No inputs. No outputs.
;Leaves all registers unchanged.
;------------------------------------
			PUSH	{R0-R2}
			; -- Enable PIT Module Clock
			LDR		R1,=SIM_SCGC6
			LDR		R2,=SIM_SCGC6_PIT_MASK
			LDR		R0,[R1,#0]
			ORRS	R0,R0,R2
			STR		R0,[R1,#0]
			
			; -- Disable PIT Timer 0
			LDR		R0,=PIT_CH0_BASE
			LDR		R1,=PIT_TCTRL_TEN_MASK
			LDR		R2,[R0,#PIT_TCTRL_OFFSET]
			BICS	R2,R2,R1
			STR		R2,[R0,#PIT_TCTRL_OFFSET]
			
			; -- Set PIT interrupt priority
			LDR		R0,=PIT_IPR
			LDR		R1,=NVIC_IPR_PIT_MASK
			LDR		R2,[R0,#0]
			BICS	R2,R2,R1
			STR		R2,[R0,#0]
			
			; -- Clear pending PIT interrupts
			LDR		R0,=NVIC_ICPR
			LDR		R1,=NVIC_ICPR_PIT_MASK
			STR		R1,[R0,#0]
			
			; -- Unmask PIT interrupts
			LDR		R0,=NVIC_ISER
			LDR		R1,=PIT_IRQ_MASK
			STR		R1,[R0,#0]
			
			; -- Enable PIT Module
			LDR		R0,=PIT_BASE
			LDR		R1,=PIT_MCR_EN_FRZ
			STR		R1,[R0,#PIT_MCR_OFFSET]
			
			; -- Set Timer 0 period
			LDR		R0,=PIT_CH0_BASE
			LDR		R1,=PIT_LDVAL_10ms
			STR		R1,[R0,#PIT_LDVAL_OFFSET]
			
			; -- Enable PIT Timer 0 with interrupts
			LDR		R0,=PIT_CH0_BASE
			MOVS	R1,#PIT_TCTRL_CH_IE
			STR		R1,[R0,#PIT_TCTRL_OFFSET]
			
			POP		{R0-R2}
			BX		LR
			ENDP
			
GetChar     PROC {R1-R14},{} 
;------------------------------------
;Loads character data from UART0 into R0
;Input; none
;Output; R0
;Changed Registers; R0
;------------------------------------
			PUSH	{R1,LR}
GetCharLoop			
			LDR 	R1,=RxQRecord				;critical code:
			CPSID	I							;mask interrupts
			BL 		Dequeue						;attempt to dequeue
			CPSIE	I							;unmask interrupts
			BCS 	GetCharLoop					;if dequeue failed,
												;loop, wait until char
			POP		{R1,PC}
			ENDP
				
PutChar		PROC {R0-R14},{} 
;------------------------------------
;Stores character data from R0 into the data of
;UART0.
;Input; R0
;Output; none
;Changed registers; none
;------------------------------------
			PUSH	{R1-R2,LR}
PutCharLoop
			LDR 	R1,=TxQRecord				;critical code:
			CPSID	I							;mask interrupts
			BL 		Enqueue						;attempt to enqueue
			CPSIE	I							;unmask interrupts
			BCS		PutCharLoop					;if enqueue failed,
												;loop, wait until enqueue
			LDR		R2,=UART0_BASE
			MOVS 	R1,#UART0_C2_TI_RI
			STRB 	R1,[R2,#UART0_C2_OFFSET]	;enable transmit interrupts
			POP		{R1-R2,PC}
			ENDP
				
UART0_ISR 		PROC {R0-R14},{}
;------------------------------------
; Handles UART0 Interrupts.
;------------------------------------
			PUSH	{LR}
			CPSID 	I							;mask interrupts
			LDR 	R1,=UART0_BASE
			MOVS 	R2,#UART0_C2_TIE_MASK
			LDRB 	R3,[R1,#UART0_C2_OFFSET]
			TST 	R3,R2
			BEQ 	RxHandling					;if not(TIE) then go to Rx
TxHandling	
			MOVS	R2,#UART0_S1_TDRE_MASK
			LDRB 	R3,[R1,#UART0_S1_OFFSET]
			TST 	R3,R2
			BEQ 	RxHandling					;if not(Tx) branch
			LDR 	R1,=TxQRecord
			BL 		Dequeue						;get character from TxQueue
			BCS 	TxDisableInterrupts			;dequeue success
			LDR 	R1,=UART0_BASE				;store to UART0
			STRB 	R0,[R1,#UART0_D_OFFSET]
			B 		EndUART0_ISR
TxDisableInterrupts
			LDR 	R0,=UART0_BASE				;dequeue failure; no characters to transmit
			MOVS 	R1,#UART0_C2_T_RI			;disable Txinterrupts
			STRB 	R1,[R0,#UART0_C2_OFFSET]
			B 		EndUART0_ISR
RxHandling
			LDR 	R1,=UART0_BASE
			LDRB 	R0,[R1,#UART0_D_OFFSET]		;load character from UART0
			LDR 	R1,=RxQRecord		
			BL 		Enqueue						;enqueue it into RxRecord
EndUART0_ISR
			CPSIE I								;unmask interrupts
			POP		{PC}
			ENDP
				
Init_UART0_IRQ	PROC {R0-R14},{} 
;------------------------------------
;Initializes UART0 for interrupts.
;Takes no input
;Gives no output
;Modifies no registers permanently
;------------------------------------
			PUSH{R0-R3,LR}
			;-- Initialize TxQ/RxQ
			LDR R0,=TxQ
			LDR R1,=TxQRecord
			LDR R2,=Tx_Rx_Q_BUF_SZ
			BL InitQueue		;initialize TxQ
			
			LDR R0,=RxQ
			LDR R1,=RxQRecord
			LDR R2,=Tx_Rx_Q_BUF_SZ
			BL InitQueue		;initializes RxQ
			
			;-- Set SIM_SOPT2 for UART0 PLL CLK / 2
			LDR R0,=SIM_SOPT2
			LDR R1,=SIM_SOPT2_UART0SRC_MASK
			LDR R2,[R0,#0] 			;current SIM_SOPT2
			BICS R2,R2,R1			;only clears UART0SRC bits
			LDR R1,=SIM_SOPT2_UART0_MCGPLLCLK_DIV2
			ORRS R2,R2,R1			;only changes UART0 bits
			STR R2,[R0,#0]			;update SIM_SOPT2
			;-- Same as in Polling
			
			;-- Set SIM_SOPT5 for UART0 External
			LDR R0,=SIM_SOPT5
			LDR R1,=SIM_SOPT5_UART0_EXTERN_MASK_CLEAR
			LDR R2,[R0,#0]			;current SIM_SOPT5
			BICS R2,R2,R1			;only UARTO Bits cleared
			STR R2,[R0,#0]			;store SIM_SOPT5
			;-- Same as in Polling
			
			;-- Set SIM_SCGC4 for UART0 CLOCK ENABLED
			LDR R0,=SIM_SCGC4
			LDR R1,=SIM_SCGC4_UART0_MASK
			LDR R2,[R0,#0]			;current SIM_SCGC4
			ORRS R2,R2,R1			;only uart bits set
			STR R2,[R0,#0]			;store SIM_SCGC4
			;-- Same as in Polling
			
			;-- Set SIM_CGC5 for Port A Clock Enabled
			LDR R0,=SIM_SCGC5
			LDR R1,=SIM_SCGC5_PORTA_MASK
			LDR R2,[R0,#0]			;current SIM-SCGC5
			ORRS R2,R2,R1			;only PORTA bit set
			STR R2,[R0,#0]			;update SIM_SCGC5
			;-- Same as in Polling
			
			;-- Set Pins for UART0 Rx and Tx
			LDR R0,=PORTA_PCR1
			LDR R1,=PORT_PCR_SET_PTA1_UART0_RX
			STR R1,[R0,#0]
			LDR R0,=PORTA_PCR2
			LDR R1,=PORT_PCR_SET_PTA2_UART0_TX
			STR R1,[R0,#0]
			;-- Same as in Polling
			
			;-- Disable UART0
			LDR R0,=UART0_BASE
			MOVS R1,#UART0_C2_T_R
			LDRB R2,[R0,#UART0_C2_OFFSET]
			BICS R2,R2,R1
			STRB R2,[R0,#UART0_C2_OFFSET]
			;-- Same as in Polling
			
			;-- initialization
			
			;-- Initialize NVIC for UART0 Interrupts
			LDR R0,=UART0_IPR
			MOVS R2,#NVIC_IPR_UART0_PRI_3
			LDR R3,[R0,#0]
			ORRS R3,R3,R2
			STR R3,[R0,#0]
			
			;-- Clear all pending interrupts
			LDR R0,=NVIC_ICPR
			LDR R1,=NVIC_ICPR_UART0_MASK
			STR R1,[R0,#0]
			
			;-- Unmask UART0 Interrupts
			LDR R0,=NVIC_ISER
			LDR R1,=NVIC_ISER_UART0_MASK
			STR R1,[R0,#0]
			
			;-- set UART0 baud rate
			LDR R0,=UART0_BASE
			MOVS R1,#UART0_BDH_9600
			STRB R1,[R0,#UART0_BDH_OFFSET]
			MOVS R1,#UART0_BDL_9600
			STRB R1,[R0,#UART0_BDL_OFFSET]
			
			;-- set UART0 character format
			MOVS R1,#UART0_C1_8N1
			STRB R1,[R0,#UART0_C1_OFFSET]
			MOVS R1,#UART0_C3_NO_TXINV
			STRB R1,[R0,#UART0_C3_OFFSET]
			MOVS R1,#UART0_C4_NO_MATCH_OSR_16
			STRB R1,[R0,#UART0_C4_OFFSET]
			MOVS R1,#UART0_C5_NO_DMA_SSR_SYNC
			STRB R1,[R0,#UART0_C5_OFFSET]
			MOVS R1,#UART0_S1_CLEAR_FLAGS
			STRB R1,[R0,#UART0_S1_OFFSET]
			MOVS R1,#UART0_S2_NO_RXINV_BRK10_NO_LBKDETECT_CLEAR_FLAGS
			STRB R1,[R0,#UART0_S2_OFFSET]
			
			;-- enable UART0 Transmitter, Reciever, and Recieve interrupt.
			MOVS R1,#UART0_C2_T_RI
			STRB R1,[R0,#UART0_C2_OFFSET]

			POP{R0-R3,PC}
			ENDP
			
InitQueue PROC {R0-R14},{}
;-------------------
; Initializes a queue.
; Input: R0; queue buffer address
; Input: R1; queue record address
; Input: R2; queue buffer size
;-------------------
    PUSH {R0-R2}
    STR R0,[R1,#IN_PTR]
    STR R0,[R1,#OUT_PTR]
    STR R0,[R1,#BUFF_START]		;the in pointer, out pointer, and start of the buffer are all the same for a new queue
    ADDS R0,R0,R2
    STR R0,[R1,#BUFF_PAST]		;the end of the queue is the number of items after the start of the queue (for item size 1)
    STRB R2,[R1,#BUFF_SIZE]
    MOVS R0,#0
    STRB R0,[R1,#NUM_INQUEUE]	;a new queue has no items stored
    POP {R0-R2}
    BX LR
    ENDP

Enqueue PROC {R0-R14},{}
;-----------------------
; Attempts to put a character in queue; returns C flag set if failure
; Input: R0; character to enqueue
; Input: R1; queue record address	
; Output: C flag
;-----------------------
    PUSH {R0-R3}
    LDRB R2,[R1,#NUM_INQUEUE]	;compares number in queue
    LDRB R3,[R1,#BUFF_SIZE]		;to maximum queue size	
    CMP R2,R3					;if queue is full, branch and return failure
    BHS EnqueueFailed

    LDR R3,[R1,#IN_PTR]
    STRB R0,[R3,#0]				;store R0 at the in-pointer of queue
    ADDS R2,R2,#1
    STRB R2,[R1,#NUM_INQUEUE]	;increment and store the number of elements in queue
    ADDS R3,R3,#1				;increment in-pointer of queue
    LDR R2,[R1,#BUFF_PAST]		
    CMP R3,R2					;check if R3 is in range
    BHS EnqueueCircular			;if not, loop around

    STR R3,[R1,#IN_PTR]			;if it is in range; store it
    B EnqueueSuccess

EnqueueCircular
    LDR R3,[R1,#BUFF_START]		;load into R3 the first address in buffer
    STR R3,[R1,#IN_PTR]			;and store it as inpointer
    B EnqueueSuccess

EnqueueFailed
    MRS R0,APSR
    MOVS R1,#0x20
    LSLS R1,R1,#24
    ORRS R0,R0,R1
    MSR APSR,R0					;set C flag
    B EndEnqueue

EnqueueSuccess
    MRS R0,APSR
    MOVS R1,#0x20
    LSLS R1,R1,#24
    BICS R0,R0,R1
    MSR APSR,R0					;clear C flag
    B EndEnqueue

EndEnqueue
    POP {R0-R3}
    BX LR
    ENDP

Dequeue	PROC {R1-R14},{}
;-----------------------
; Attempts to get a character from the queue; sets C flag to indicate failure
; Input: R1; queue record address
; Output: R0; dequeued character	
; Output: C flag
;-----------------------
    PUSH {R1-R3}
    LDRB R2,[R1,#NUM_INQUEUE]	;loads the number of items in the queue
    CMP R2,#0			;you can't dequeue if there are no items
    BEQ DequeueFailed		;so branch to failure

    LDR R3,[R1,#OUT_PTR]		;otherwise, load the address of the out pointer
    LDRB R0,[R3,#0]			;then load the byte at that pointer
    SUBS R2,R2,#1			;decrement the number of items in the queue
    STRB R2,[R1,#NUM_INQUEUE]	;and store again
    ADDS R3,R3,#1			;Add 1 to the out pointer's address
    LDR R2,[R1,#BUFF_PAST]		
    CMP R3,R2			;check if the out pointer is outside the queue
    BHS DequeueCircular		;if so, circle around

    STR R3,[R1,#OUT_PTR]		;else just store R3
    B DequeueSuccess		;branch to success

DequeueCircular
    LDR R3,[R1,#BUFF_START]		;load into R3 the first address in buffer
    STR R3,[R1,#OUT_PTR]		;and store it as outpointer
    B DequeueSuccess		;branch to success

DequeueFailed
    MRS R2,APSR
    MOVS R1,#0x20
    LSLS R1,R1,#24
    ORRS R2,R2,R1
    MSR APSR,R2					;set C flag
    B EndDequeue

DequeueSuccess
    MRS R2,APSR
    MOVS R1,#0x20
    LSLS R1,R1,#24
    BICS R2,R2,R1
    MSR APSR,R2					;clear C flag
    B EndDequeue

EndDequeue
    POP {R1-R3}
    BX LR
    ENDP

    
GetStringSB PROC {R0-R14},{}
;---------------------------
; Reads a string from terminal keyboard until enter is pressed,
; and stores it in memory at R0.
; Does not allow more than Max_String characters.
; Input: R0- Memory location to store string.
; Uses: GetChar, PutChar
;---------------------------
	PUSH {R0-R2,LR}
	MOVS R2,R0            ;moves the memory address R0 into R2
	SUBS R1,R1,#1	      ;R1 <- MaxString-1 characters
GetStringLoop

	BL GetChar            ;gets a character into R0
	CMP R0,#0xD
	BEQ EndGetString		;branches on character return
	BL PutChar
	STRB R0,[R2,#0]	      ;stores the character at R0 into R2
	ADDS R2,R2,#1	      ;increments the memory location at R2
	SUBS R1,R1,#1	      ;subtracts 1 from the string length
	BNE GetStringLoop     ;if you still have characters left; (R1!=0), continue.

OverflowLoop
	BL GetChar            ;gets a character into R0
	CMP R0,#0xD
	BEQ EndGetString      ;end string on Carriage Return
	B OverflowLoop	      ;stay here until branch to end of string

EndGetString
	MOVS R0,#0
	STRB R0,[R2,#0]	   ;null terminates string
	MOVS R0,#LF	      ;line feeds to next line
	BL PutChar
	MOVS R0,#CR			;returns cursor to start of line
	BL PutChar

	POP  {R0-R2,PC}
	ENDP

PutStringSB PROC {R0-R14},{}
;---------------------------
; Displays a null-terminated string from memory,
; starting at the address where R0 points, to the
; terminal screen.
; Does not print more than MAX_STRING characters
; Input: R0; pointer to source string
; Modify: APSR
; Uses: PutChar
;---------------------------
	PUSH {R0-R2,LR}
	MOVS R2,R0	      ;puts the memory address R0 into R2

PutStringLoop
	LDRB R0,[R2,#0]        ;loads first byte of string stored at R2
	CMP R0,#0
	BEQ EndPutString       ;branches on null character
	BL PutChar
	ADDS R2,R2,#1          ;increments memory location at R2
	SUBS R1,R1,#1          ;decrements the string length
	BEQ EndPutString       ;ends printing if R1 characters have been printed
	B PutStringLoop        ;else branches to loop

EndPutString
	POP {R0-R2,PC}
	ENDP

PutNumU PROC {R0-R14},{}
;-----------------------
;Prints the decimal representation of the unsigned
;word value in R0.
; Input: R0; value to be printed.
;-----------------------
	PUSH {R0-R2,LR}
	MOVS R1,R0	;places value to be printed in R1
	LDR R2,=BILDIV
	LDR R2,[R2,#0] ;loads 1,000,000,000 into R2
	
	CMP R0,#0
	BEQ PrintZero ;Branches if the value to be printed is zero (special case)
	
InitialPutNumULoop
	MOVS R0,R2
	BL DIVU		;divides R1 (now holding value to be printed) by R0 (holding the maximum power of 10)
	CMP R1,#0	
	BEQ EndPutNumU	;branches on remainder 0
	CMP R0,#0
	BNE PrintingLoop ;else branches if R0 is a non0 character

	PUSH{R0-R1} 	;divides R2/10
	MOVS R1,R2
	MOVS R0,#10
	BL DIVU			;this decrements the value of R2 so successive divisions
	MOVS R2,R0		;divide by smaller power of 10, getting closer and closer to division by 1.
	POP {R0,R1}		;this gets each digit of the decimal in turn.
	B InitialPutNumULoop

PrintingLoop
	ADDS R0,R0,#48
	BL PutChar	;converts quotient to ascii and prints

	PUSH{R0-R1} 	;divides R2/10
	MOVS R1,R2
	MOVS R0,#10
	BL DIVU			;this decrements the value of R2 so successive divisions
	MOVS R2,R0		;divide by smaller power of 10, getting closer and closer to division by 1.
	POP {R0,R1}		;this gets each digit of the decimal in turn.

	MOVS R0,R2	;moves R2/10 into R0 (divisor)
	BL DIVU
	CMP R1,#0	;branches if remainder == 0
	BEQ EndPutNumU
	B PrintingLoop
	
PrintZero		;Prints a single zero to the terminal and stops.
	MOVS R0,#48
	BL PutChar
	B EndPutNumUPrinting
	
ZeroPrintLoop
	MOVS R0,#48
	BL PutChar
	
	PUSH{R0-R1} 	;divides R2/10
	MOVS R1,R2
	MOVS R0,#10
	BL DIVU			;this decrements the value of R2 so successive divisions
	MOVS R2,R0		;divide by smaller power of 10, getting closer and closer to division by 1.
	POP {R0,R1}		;this gets each digit of the decimal in turn.
	
	CMP R2,#1
	BNE ZeroPrintLoop
	B EndPutNumUPrinting
	
EndPutNumU
	ADDS R0,R0,#48  ;prints the last character
	BL PutChar
	
	CMP R2,#1		;if R2 != 1, that is, in case 10, 20, ect, then print remaining zeroes.
	BNE ZeroPrintLoop
EndPutNumUPrinting
	POP {R0-R2,PC}
	ENDP

DIVU        PROC {R2-R14},{}
;***************************************************************
;divides R1/R0: stores quotient in R0 and remainder in R1
;uses R2 to temporarily store quotient
;sets C flag if an attempt to divide by 0 is detected
;***************************************************************
            CMP R0,#0
            BEQ DIVO            ;checks if divide by 0

            PUSH {R2}           ;pushes R2 onto stack for quotient tracking
            MOVS R2,#0          ;empties R2

WHILEDIVU   CMP R1,R0  
            BLO ENDWHILEDIVU    ;if R1<R0, branch to the end of program
            SUBS R1,R1,R0       ;otherwise, subtract R0 from R1
            ADDS R2,R2,#1       ;and add 1 to R2
            B WHILEDIVU

ENDWHILEDIVU MOVS R0,R2
            POP {R2}        
            PUSH {R0,R1}
            MRS R0,APSR 
            MOVS R1,#0x20
            LSLS R1,R1,#24
            BICS R0,R0,R1       ;clears C flag
            MSR APSR,R0         ;sets APSR equal to R0
            POP {R1,R0}
            B ENDDIVU

DIVO        PUSH {R0,R1}        ;pushes R0 and R1 onto stack
            MRS R0,APSR         ;sets R0 equal to APSR
            MOVS R1,#0x20
            LSLS R1,R1,#24
            ORRS R0,R0,R1       ;sets C flag
            MSR APSR,R0         ;sets APSR equal to R0
            POP {R1,R0}         ;pops R0, R1
	
ENDDIVU	    BX LR
            ENDP
;>>>>>   end subroutine code <<<<<
            ALIGN
;****************************************************************
;Vector Table Mapped to Address 0 at Reset
;Linker requires __Vectors to be exported
            AREA    RESET, DATA, READONLY
            EXPORT  __Vectors
            EXPORT  __Vectors_End
            EXPORT  __Vectors_Size
            IMPORT  __initial_sp
            IMPORT  Dummy_Handler
            IMPORT  HardFault_Handler
__Vectors 
                                      ;ARM core vectors
            DCD    __initial_sp       ;00:end of stack
            DCD    Reset_Handler      ;01:reset vector
            DCD    Dummy_Handler      ;02:NMI
            DCD    HardFault_Handler  ;03:hard fault
            DCD    Dummy_Handler      ;04:(reserved)
            DCD    Dummy_Handler      ;05:(reserved)
            DCD    Dummy_Handler      ;06:(reserved)
            DCD    Dummy_Handler      ;07:(reserved)
            DCD    Dummy_Handler      ;08:(reserved)
            DCD    Dummy_Handler      ;09:(reserved)
            DCD    Dummy_Handler      ;10:(reserved)
            DCD    Dummy_Handler      ;11:SVCall (supervisor call)
            DCD    Dummy_Handler      ;12:(reserved)
            DCD    Dummy_Handler      ;13:(reserved)
            DCD    Dummy_Handler      ;14:PendableSrvReq (pendable request 
                                      ;   for system service)
            DCD    Dummy_Handler      ;15:SysTick (system tick timer)
            DCD    Dummy_Handler      ;16:DMA channel 0 xfer complete/error
            DCD    Dummy_Handler      ;17:DMA channel 1 xfer complete/error
            DCD    Dummy_Handler      ;18:DMA channel 2 xfer complete/error
            DCD    Dummy_Handler      ;19:DMA channel 3 xfer complete/error
            DCD    Dummy_Handler      ;20:(reserved)
            DCD    Dummy_Handler      ;21:command complete; read collision
            DCD    Dummy_Handler      ;22:low-voltage detect;
                                      ;   low-voltage warning
            DCD    Dummy_Handler      ;23:low leakage wakeup
            DCD    Dummy_Handler      ;24:I2C0
            DCD    Dummy_Handler      ;25:I2C1
            DCD    Dummy_Handler      ;26:SPI0 (all IRQ sources)
            DCD    Dummy_Handler      ;27:SPI1 (all IRQ sources)
            DCD    UART0_ISR	      ;28:UART0 (Tx/Rx)
            DCD    Dummy_Handler      ;29:UART1 (status; error)
            DCD    Dummy_Handler      ;30:UART2 (status; error)
            DCD    Dummy_Handler      ;31:ADC0
            DCD    Dummy_Handler      ;32:CMP0
            DCD    Dummy_Handler      ;33:TPM0
            DCD    Dummy_Handler      ;34:TPM1
            DCD    Dummy_Handler      ;35:TPM2
            DCD    Dummy_Handler      ;36:RTC (alarm)
            DCD    Dummy_Handler      ;37:RTC (seconds)
            DCD    PIT_ISR      	  ;38:PIT (all IRQ sources)
            DCD    Dummy_Handler      ;39:I2S0
            DCD    Dummy_Handler      ;40:USB0
            DCD    Dummy_Handler      ;41:DAC0
            DCD    Dummy_Handler      ;42:TSI0
            DCD    Dummy_Handler      ;43:MCG
            DCD    Dummy_Handler      ;44:LPTMR0
            DCD    Dummy_Handler      ;45:Segment LCD
            DCD    Dummy_Handler      ;46:PORTA pin detect
            DCD    Dummy_Handler      ;47:PORTC and PORTD pin detect
__Vectors_End
__Vectors_Size  EQU     __Vectors_End - __Vectors
            ALIGN
;****************************************************************
;Constants
            AREA    MyConst,DATA,READONLY
;>>>>> begin constants here <<<<<
EnterName	DCB		"Enter your name.",CR,LF,">",NULL
TimeReturn	DCB		" x 0.01 s",CR,LF,NULL
EnterDate	DCB		"Enter the date.",CR,LF,">",NULL
EnterTA		DCB		"Enter the last name of a 250 lab TA.",CR,LF,">",NULL
GoodBye		DCB		"Thank you. Goodbye!",CR,LF,NULL
			ALIGN
BILDIV  	DCD 0x3B9ACA00
;>>>>>   end constants here <<<<<
            ALIGN
;****************************************************************
;Variables
            AREA    MyData,DATA,READWRITE
;>>>>> begin variables here <<<<<
Count SPACE 4
	ALIGN
RunStopWatch SPACE 1
	ALIGN
TxQ SPACE Tx_Rx_Q_BUF_SZ
	ALIGN
TxQRecord SPACE Q_REC_SZ
	ALIGN
RxQ SPACE Tx_Rx_Q_BUF_SZ
	ALIGN
RxQRecord SPACE Q_REC_SZ
	ALIGN
MyString SPACE MAX_STRING

;>>>>>   end variables here <<<<<
            ALIGN
            END