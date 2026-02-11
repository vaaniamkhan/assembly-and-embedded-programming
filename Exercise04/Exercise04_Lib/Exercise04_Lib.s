            TTL Lab Exercise Four Library
;****************************************************************
;Provides the following subroutines for Lab Exercise Four:
;* InitData
;* LoadData
;* TestData
;Requires the following word variables for interface:
;* P
;* Q
;Requires the following word array for data:
;* Results [2 x 25]
;Name:  R. W. Melton
;Date:  February 15, 2021
;Class:  CMPE-250
;Section:  All sections
;---------------------------------------------------------------
;Keil Simulator Template for KL05
;R. W. Melton
;January 13, 2025
;****************************************************************
;Assembler directives
            THUMB
            OPT    64  ;Turn on listing macro expansions
;****************************************************************
;EQUates
;Standard data masks
BYTE_MASK         EQU  0xFF
NIBBLE_MASK       EQU  0x0F
;Standard data sizes (in bits)
BYTE_BITS         EQU  8
NIBBLE_BITS       EQU  4
;Architecture data sizes (in bytes)
WORD_SIZE         EQU  4  ;Cortex-M0+
HALFWORD_SIZE     EQU  2  ;Cortex-M0+
;Architecture data masks
HALFWORD_MASK     EQU  0xFFFF
;Return                 
RET_ADDR_T_MASK   EQU  1  ;Bit 0 of ret. addr. must be
                          ;set for BX, BLX, or POP
                          ;mask in thumb mode
;---------------------------------------------------------------
;Vectors
VECTOR_TABLE_SIZE EQU 0x000000C0  ;KL05
VECTOR_SIZE       EQU 4           ;Bytes per vector
;---------------------------------------------------------------
;CPU CONTROL:  Control register
;31-2:(reserved)
;   1:SPSEL=current stack pointer select
;           0=MSP (main stack pointer) (reset value)
;           1=PSP (process stack pointer)
;   0:nPRIV=not privileged
;        0=privileged (Freescale/NXP "supervisor") (reset value)
;        1=not privileged (Freescale/NXP "user")
CONTROL_SPSEL_MASK   EQU  2
CONTROL_SPSEL_SHIFT  EQU  1
CONTROL_nPRIV_MASK   EQU  1
CONTROL_nPRIV_SHIFT  EQU  0
;---------------------------------------------------------------
;CPU PRIMASK:  Interrupt mask register
;31-1:(reserved)
;   0:PM=prioritizable interrupt mask:
;        0=all interrupts unmasked (reset value)
;          (value after CPSIE I instruction)
;        1=prioritizable interrrupts masked
;          (value after CPSID I instruction)
PRIMASK_PM_MASK   EQU  1
PRIMASK_PM_SHIFT  EQU  0
;---------------------------------------------------------------
;CPU PSR:  Program status register
;Combined APSR, EPSR, and IPSR
;----------------------------------------------------------
;CPU APSR:  Application Program Status Register
;31  :N=negative flag
;30  :Z=zero flag
;29  :C=carry flag
;28  :V=overflow flag
;27-0:(reserved)
APSR_MASK     EQU  0xF0000000
APSR_SHIFT    EQU  28
APSR_N_MASK   EQU  0x80000000
APSR_N_SHIFT  EQU  31
APSR_Z_MASK   EQU  0x40000000
APSR_Z_SHIFT  EQU  30
APSR_C_MASK   EQU  0x20000000
APSR_C_SHIFT  EQU  29
APSR_V_MASK   EQU  0x10000000
APSR_V_SHIFT  EQU  28
;----------------------------------------------------------
;CPU EPSR
;31-25:(reserved)
;   24:T=Thumb state bit
;23- 0:(reserved)
EPSR_MASK     EQU  0x01000000
EPSR_SHIFT    EQU  24
EPSR_T_MASK   EQU  0x01000000
EPSR_T_SHIFT  EQU  24
;----------------------------------------------------------
;CPU IPSR
;31-6:(reserved)
; 5-0:Exception number=number of current exception
;      0=thread mode
;      1:(reserved)
;      2=NMI
;      3=hard fault
;      4-10:(reserved)
;     11=SVCall
;     12-13:(reserved)
;     14=PendSV
;     15=SysTick
;     16=IRQ0
;     16-47:IRQ(Exception number - 16)
;     47=IRQ31
;     48-63:(reserved)
IPSR_MASK             EQU  0x0000003F
IPSR_SHIFT            EQU  0
IPSR_EXCEPTION_MASK   EQU  0x0000003F
IPSR_EXCEPTION_SHIFT  EQU  0
;----------------------------------------------------------
PSR_N_MASK           EQU  APSR_N_MASK
PSR_N_SHIFT          EQU  APSR_N_SHIFT
PSR_Z_MASK           EQU  APSR_Z_MASK
PSR_Z_SHIFT          EQU  APSR_Z_SHIFT
PSR_C_MASK           EQU  APSR_C_MASK
PSR_C_SHIFT          EQU  APSR_C_SHIFT
PSR_V_MASK           EQU  APSR_V_MASK
PSR_V_SHIFT          EQU  APSR_V_SHIFT
PSR_T_MASK           EQU  EPSR_T_MASK
PSR_T_SHIFT          EQU  EPSR_T_SHIFT
PSR_EXCEPTION_MASK   EQU  IPSR_EXCEPTION_MASK
PSR_EXCEPTION_SHIFT  EQU  IPSR_EXCEPTION_SHIFT
;----------------------------------------------------------
;Stack
SSTACK_SIZE EQU  0x00000100
;****************************************************************
;Program
            AREA    Exercise04_Lib,CODE,READONLY
            EXPORT  InitData
            EXPORT  LoadData
            EXPORT  TestData
            IMPORT  P
            IMPORT  Q
            IMPORT  Results
;----------------------------------------------------------------------
InitData    PROC    {R0-R5,R8-R14}
;**********************************************************************
;Initializes test data array index in R7 and test data result mismatch
;count in R6.
;Output:  R6, R7
;Modifies:  R6, R7, APSR
;**********************************************************************
            MOVS    R6,#0      ;Number mismatches = 0
            MOVS    R7,#0      ;Array Index = 0
            BX      LR
            ENDP    ;InitData
;----------------------------------------------------------------------
LoadData    PROC    {R0-R6,R8-R14}
;**********************************************************************
;On each call, loads next test (dividend, divisor) pair from Array 
;into variable (P,  Q) pair, as determined by current array index in 
;R7.  C reflects failure (1 = no more data) or success (0 = data).
;Output:  Variables P and Q
;         C bit of APSR
;Modifies:  R7, APSR
;**********************************************************************
            PUSH    {R0-R3}       ;save non-output registers modified
            ADR     R3,Array      ;&(Array[0])
            ADDS    R3,R3,R7      ;ArrayPtr
            ADR     R1,ArrayPast  ;First address past end of array
            CMP     R3,R1         ;if (more data) {
            BHS     LoadDataEmpty
            LDM     R3!,{R0-R1}   ;  R0 = *(ArrayPtr++)
                                  ;  R1 = *(ArrayPtr++)
            LDR     R2,PPtr       ;  R0 = &P
            LDR     R3,QPtr       ;  R1 = &Q
            STR     R0,[R2,#0]    ;  P = ArrayPtr[0]
            STR     R1,[R3,#0]    ;  Q = ArrayPtr[1]
            ADDS    R7,R7,#8      ;  Array Index += 2
            MOVS    R0,#0         ;  clear carry to report success
            LSRS    R0,R0,#1      ;}
LoadDataDone
            POP     {R0-R3}       ;restore modified registers
            BX      LR            ;return
LoadDataEmpty
            MOVS    R0,#1         ;else {
            LSRS    R0,R0,#1      ;  set carry to report failure
            B       LoadDataDone  ;}
            ENDP    ;LoadData
;----------------------------------------------------------------------
TestData    PROC    {R0-R5,R7-R14}
;**********************************************************************
;On each call, stores (P,Q) (quotient, remainder) pair to next location
;in Results and checks values against next location in Answers.  Next
;location is determined by current array index in R7 less 8.  If
;results do not match answers, count mismatch is incremented in R6.
;Output:  R6
;Modifies:  R6, ASPR
;**********************************************************************
            PUSH    {R0-R3}        ;Save non-output registers modified
            LDR     R0,ResultsPtr  ;&(Results[0])
            ADR     R1,Answers     ;&(Answers[0])
            ADDS    R0,R0,R7       ;&(ResultsPtr[2])
            ADDS    R1,R1,R7       ;&(AnswersPtr[2])
            SUBS    R0,R0,#8       ;ResultsPtr
            SUBS    R1,R1,#8       ;AnswersPtr
            LDR     R2,PPtr        ;&P
            LDR     R3,QPtr        ;&Q
            LDR     R2,[R2,#0]     ;P
            LDR     R3,[R3,#0]     ;Q
            STM     R0!,{R2-R3}    ;ResultsPtr[0] = P
                                   ;ResultsPtr[1] = Q
            LDR     R0,[R1,#0]     ;if ((AnswersPtr[0] == P)
            CMP     R0,R2
            BNE     TestDataMismatch
            LDR     R0,[R1,#4]     ;     && (AnswersPtr[1] == Q)) }
            CMP     R0,R3          ;  results o.k.
            BNE     TestDataMismatch
TestDataDone                       ;}            
            POP     {R0-R3}        ;Restore registers modified
            BX      LR             ;return
TestDataMismatch                   ;else {
            ADDS    R6,R6,#1       ;  increment mismatch count
            B       TestDataDone   ;}
            ENDP    ;TestData
            ALIGN            
PPtr        DCD     P
QPtr        DCD     Q
ResultsPtr  DCD     Results
Array       DCD     0,0
            DCD     1,0
            DCD     0,1
            DCD     16,1                
            DCD     16,2                
            DCD     16,4                
            DCD     16,8                
            DCD     16,16
            DCD     16,32            
            DCD     7,1                
            DCD     7,2
            DCD     7,3
            DCD     7,4
            DCD     7,5
            DCD     7,6
            DCD     7,7
            DCD     7,8
            DCD     0x80000000,0x80000000
            DCD     0x80000000,0x80000001
            DCD     0xFFFFFFFF,0x000F0000
ArrayPast
Answers     DCD     0xFFFFFFFF,0xFFFFFFFF
            DCD     0xFFFFFFFF,0xFFFFFFFF
            DCD     0,0
            DCD     16,0
            DCD     8,0                
            DCD     4,0                
            DCD     2,0                
            DCD     1,0                
            DCD     0,16
            DCD     7,0                
            DCD     3,1
            DCD     2,1
            DCD     1,3
            DCD     1,2
            DCD     1,1
            DCD     1,0
            DCD     0,7
            DCD     1,0
            DCD     0,0x80000000
            DCD     0x1111,0xFFFF
            ALIGN
            END
