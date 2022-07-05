; A digital 4x7 digit display witch keeps track of button presses
;
; 2020 R. Branten
; Written for use with the AtTiny26L-8pi
;
; Clock set to 1Mhz internal clock

.NOLIST
.include "tn26def.inc"
.LIST

;===============================================================================
; REGISTERS
;
; Register  | Name                  | Function
;-----------|-------------------------------------------------------
; R1        | arithmicRegisterA     | Calculations
; R2        | arithmicRegisterB     | Calculations
; R3        | arithmicRegisterC     | Calculations
; R4        | arithmicRegisterD     | Calculations
; R16       | registerA             | General purpose
; R17       | registerB             | General purpose
; R18       | delayRegisterA        | Delaying program execution
; R19       | delayRegisterB        | Delaying program execution
; R20       | digit1                | Storing ones of 7-segment
; R21       | digit2                | Storing tens of 7-segment
; R22       | digit3                | Storing hundreds of 7-segment
; R23       | digit4                | Storing thousands of 7-segment
; R24       | counterLow            | LSB of counter
; R25       | counterHigh           | MSB of counter
;
.DEF registerA = R16
.DEF registerB = R17
.DEF arithmicRegisterA = R1
.DEF arithmicRegisterB = R2
.DEF arithmicRegisterC = R3
.DEF arithmicRegisterD = R4
.DEF buttonPushRegister = R18
.DEF counterHigh = R25
.DEF counterLow = R24
.DEF delayRegisterB = R19

; Digit numbering
; +-----+ +-----+ +-----+ +-----+
; |     | |     | |     | |     |
; |  4  | |  3  | |  2  | |  1  |
; | R23 | | R22 | | R21 | | R22 |
; +-----+ +-----+ +-----+ +-----+
;
.DEF digit1 = R20
.DEF digit2 = R21
.DEF digit3 = R22
.DEF digit4 = R23

;===============================================================================
; PINS
;
; Port  | Name          | Function                      | Direction | Init
;-------|---------------|-------------------------------|-----------|------
; PA0   | display4      | Ground fourth segment         | OUTPUT    | LOW
; PA1   | display2      | Ground third segment          | OUTPUT    | LOW
; PA2   | display3      | Ground second segment         | OUTPUT    | LOW
; PA3   | display1      | Ground first segment          | OUTPUT    | LOW
; PB0   | incrementPin  | Trigger ISR                   | INPUT     | LOW
; PB1   | decrementPin  | Trigger ISR                   | INPUT     | LOW
; PB4   | latchPin      | Latching of shift register    | OUTPUT    | LOW
; PB5   | clockPin      | Clock of shift register       | OUTPUT    | LOW
; PB6   | dataPin       | Data to shift register        | OUTPUT    | LOW
;
; Inputs
.EQU incrementPin = PB0                                     ; PCINT0
.EQU decrementPin = PB1                                     ; PCINT0

; Outputs
.EQU latchPin = PB4     ; pin 07 of the Attiny to pin number 12 of the 74HC595
.EQU clockPin = PB5     ; pin 08 of the Attiny to pin number 11 of the 74HC595
.EQU dataPin = PB6      ; pin 09 of the Attiny to pin number 14 of the 74HC595
.EQU display4 = PA0
.EQU display2 = PA1
.EQU display3 = PA2
.EQU display1 = PA3

;===============================================================================
; CONSTANTS
; Segment numbers
; +--[1]--+
; |       |
;[2]     [3]
; |       |
; +--[4]--+
; |       |
;[5]     [6]
; |       |
; +--[7]--+   [8]
;

.EQU displayDigit0 = 0b00000011
.EQU displayDigit1 = 0b01111011
.EQU displayDigit2 = 0b00100101
.EQU displayDigit3 = 0b00110001
.EQU displayDigit4 = 0b01011001
.EQU displayDigit5 = 0b10010001
.EQU displayDigit6 = 0b10000001
.EQU displayDigit7 = 0b00111011
.EQU displayDigit8 = 0b00000001
.EQU displayDigit9 = 0b00010001

;===============================================================================
; VECTORS
;
.CSEG
.ORG $0000
    RJMP    RESET                                           ; Hardware Pin and Watchdog Reset
    RETI                                                    ; External Interrupt Request 0
    RJMP    PIN_CHANGE                                      ; Pin Change Interrupt
    RETI                                                    ; Timer/Counter1 Compare Match 1A
    RETI                                                    ; Timer/Counter1 Compare Match 1B
    RETI                                                    ; Timer/Counter1 Overflow
    RJMP    TIM0_OVF                                        ; Timer/Counter0 Overflow
    RETI                                                    ; USI Start
    RETI                                                    ; USI Overflow
    RETI                                                    ; EEPROM Ready
    RETI                                                    ; Analog Comparator
    RETI                                                    ; ADC Conversion Complete

;===============================================================================
; SETUP
;
RESET:
    CLI                                                     ; Disable interrupts

    LDI     registerA, RAMEND
    OUT     SP, registerA                                   ; Set stack pointer, 8 bits on the attiny26

    ; Port A, direction
    LDI     registerA, (1<<display4) | (1<<display3) | (1<<display2) | (1<<display1)
    OUT     DDRA, registerA

    ; Port A, init status
    CBI     PORTA, display1
    CBI     PORTA, display2
    CBI     PORTA, display3
    CBI     PORTA, display1

    ; Port B, direction
    LDI     registerA, (1<<latchPin) | (1<<clockPin) | (1<<dataPin)
    OUT     DDRB, registerA

    ; Port B, init status
    CBI     PORTB, latchPin
    CBI     PORTB, clockPin
    CBI     PORTB, dataPin

    ; Interrupt PCINT1 enable
    LDI     registerA, (1<<PCIE0)
    OUT     GIMSK, registerA

    ; Set counter to zero
    LDI     counterLow, 0
    LDI     counterHigh, 0

    SEI                                                     ; Enable interrupts
    RJMP    main


;===============================================================================
; MAIN PROGRAM LOOP
;
main:
    RCALL   checkButtonStatus
    RCALL   setDigits
    RCALL   outputCounter
    RJMP    main

;===============================================================================
; REGULAR SUBROUTINES
;


;-------------------------------------------------------------------------------
; CHECK BUTTONS
;
checkButtonStatus:
    ; Check for increment button
    IN      registerA, PINB                                 ; High pins on port B
    LDI     registerB, (1<<incrementPin)
    AND     registerA, registerB                            ; Keep only increment pin by using and
    CP      registerA, registerB
    BRNE    incrementNotPressed_1                           ; Increment button not pressed
    ; Incement is pressed, check incrementButtonStatus
    LDI     registerA, 1
    CP      incrementButtonStatus, registerA
    BRNE    incrementNotPressed_1
    LDI     registerA, 0
    MOV     incrementButtonStatus, registerA
    BREQ    incrementCounter
incrementNotPressed_1:
    ; Check for decrementbutton
    IN      registerA, PINB                                 ; High pins on port A
    LDI     registerB, (1<<decrementPin)
    AND     registerA, registerB                            ; Keep only decrement pin by using and
    CP      registerA, registerB
    BRNE    decrementNotPressed_1                           ; Decrement button not pressed
    ; Decrement is pressed, check decrementButtonStatus
    LDI     registerA, 1
    CP      decrementButtonStatus, registerA
    BRNE    decrementNotPressed_1
    LDI     registerA, 0
    MOV     decrementButtonStatus, registerA
    BREQ    decrementCounter
decrementNotPressed_1:
    RET


;-------------------------------------------------------------------------------
; INCREMENT COUNTER
;
incrementCounter:
    LDI     registerA, 1
    CPSE    arithmicRegisterC, registerA
    RET                                                     ; Prevent repeat on hold button pressed
    CLR     arithmicRegisterC                               ; Clear flag
    LDI     registerA, HIGH(9999)
    CP      counterHigh, registerA
    BRLO    doIncrement
    LDI     registerA, LOW(9999)                            ; Above 9984, check lower half
    CP      counterLow, registerA
    BRSH    maximumReached

doIncrement:
    ADIW    counterHigh:counterLow, 1
    BRCS    maximumReached
    RET
maximumReached:
    LDI     counterLow, LOW(9999)                           ; Above 65535, fill low bytes
    LDI     counterHigh, HIGH(9999)                         ; Above 65535, fill high bytes
    RET


;-------------------------------------------------------------------------------
; DECREMENT COUNTER
;
decrementCounter:
    LDI     registerA, 0
    CP      registerA, counterHigh
    BRSH    doDecrement
    CP      registerA, counterLow
    BREQ    minimumReached

doDecrement:
    SBIW    counterHigh:counterLow, 1
    BRCS    minimumReached
    RET
minimumReached:
    CLR     counterLow
    CLR     counterHigh
    RET


;-------------------------------------------------------------------------------
; GETTING DIGITS FROM COUNTER
;
setDigits:
    ; Push original counter to stack
    PUSH    counterHigh
    PUSH    counterLow
    RCALL   setThousands
    RCALL   setHundreds
    RCALL   setTens
    RCALL   setOnes
    ; Pop original counter from stack
    POP     counterLow
    POP     counterHigh
    RET

setThousands:
    ; Should be above 00000011 11101000 (1000)
    LDI     digit4, 0                                       ; Default digit 4 to zero
    LDI     registerA, 0b00000011
    CP      counterHigh, registerA
    BRSH    thousandStart                                   ; More than 1000, start counting
    RET
thousandStart:
    INC     digit4
    SUBI    counterLow, LOW(1000)                           ; Subtract two low bytes: AL=AL-LOW(420)
    SBCI    counterHigh, HIGH(1000)                         ; Subtract high bytes and include Carry Flag
    CP      counterHigh, registerA
    BRSH    thousandStart                                   ; More than 100, substract some more
    RET

setHundreds:
    ; Should be above 00000000 01100100 (100)
    LDI     digit3, 0                                       ; Default digit 3 to zero
    LDI     registerA, 0b00000001
    LDI     registerB, 0b01100100
    CP      counterHigh, registerA
    BRSH    hundredStart                                    ; More than 100, start counting
    CP      counterLow, registerB
    BRSH    hundredStart                                    ; More than 100, start counting
    RET
hundredStart:
    INC     digit3
    SBIW    counterHigh:counterLow, 50
    SBIW    counterHigh:counterLow, 50
    LDI     registerA, 0b00000001
    CP      counterHigh, registerA
    BRSH    hundredStart                                    ; More than 100, substract some more
    CP      counterLow, registerB
    BRSH    hundredStart                                    ; More than 100, substract some more
    RET

setTens:
    ; Should be above 00000000 00001010 (10)
    LDI     digit2, 0                                       ; Default digit 4 to zero
    LDI     registerA, 0b00001010
    CP      counterLow, registerA
    BRSH    tenStart                                        ; More than 10, start counting
    RET
tenStart:
    INC     digit2
    SBCI    counterLow, 10
    CP      counterLow, registerA
    BRSH    tenStart                                        ; More than 10, substract some more
    RET

setOnes:
    ; Should be above 00000000 00000001 (1)
    LDI     digit1, 0
    LDI     registerA, 0b00000001
    CP      counterLow, registerA
    BRSH    oneStart
    RET
oneStart:
    INC     digit1
    DEC     counterLow
    CP      counterLow, registerA
    BRSH    oneStart                                        ; More then 1, substract some more
    RET


;-------------------------------------------------------------------------------
; DRIVING SEGMENT DISPLAY
;
outputCounter:
    CLI                                                     ; Disable interrupts
    ; drive digit 1 [X][ ][ ][ ]
    MOV     registerA, digit4
    RCALL   getShiftValue                                   ; Get value to be shifted out
    MOV     arithmicRegisterA, registerB
    LDI     registerB, (1<<display1)
    RCALL   driveDisplay

    ; drive digit 2 [ ][X][ ][ ]
    MOV     registerA, digit3
    RCALL   getShiftValue                                   ; Get value to be shifted out
    MOV     arithmicRegisterA, registerB
    LDI     registerB, (1<<display2)
    RCALL   driveDisplay

    ; drive digit 3 [ ][ ][X][ ]
    MOV     registerA, digit2
    RCALL   getShiftValue                                   ; Get value to be shifted out
    MOV     arithmicRegisterA, registerB
    LDI     registerB, (1<<display3)
    RCALL   driveDisplay

    ; drive digit 4 [ ][ ][ ][X]
    MOV     registerA, digit1
    RCALL   getShiftValue                                   ; Get value to be shifted out
    MOV     arithmicRegisterA, registerB
    LDI     registerB, (1<<display4)
    RCALL   driveDisplay

    SEI                                                     ; Enable interrupts

    RET

driveDisplay:
    ; Shift in bits
    RCALL   shiftStart
    ; Set correct display pin high, see registerB (display(n))
    OUT     PORTA, registerB
    NOP                                                     ; Wait
    NOP                                                     ; Wait
    RCALL   delay
    ; Stop driving display pin
    EOR     registerB, registerB
    OUT     PORTA, registerB
    RET

shiftStart:
    ; Repeat shift 8 times
    LDI     registerA, 8
    MOV     arithmicRegisterB, registerA
    LDI     registerA, 0
shiftIn:
    ; Logic shift left to get value to be shifted in SREG 'C' flag
    LSL     arithmicRegisterA
    BRCS    shiftHigh
    CBI     PORTB, dataPin
    RJMP    doShift
shiftHigh:
    SBI     PORTB, dataPin
doShift:
    ; Cycle clock
    SBI     PORTB, clockPin
    NOP
    NOP
    CBI     PORTB, clockPin
    ; End if all shifted out
    DEC     arithmicRegisterB
    CP      arithmicRegisterB, registerA
    BRNE    shiftIn
    ; Toggle latch
    SBI     PORTB, latchPin
    NOP
    NOP
    CBI     PORTB, latchPin
    RET

getShiftValue:
    ; Set data to be shifted out
    ; The digit should be loaded in registerA
    LDI     registerB, 0
    CP      registerA, registerB
    BRNE    shiftValue_1
    LDI     registerB, displayDigit0                        ; Set shift bits to 0
    RET
shiftValue_1:
    INC     registerB
    CP      registerA, registerB
    BRNE    shiftValue_2
    LDI     registerB, displayDigit1                        ; Set shift bits to 1
    RET
shiftValue_2:
    INC     registerB
    CP      registerA, registerB
    BRNE    shiftValue_3
    LDI     registerB, displayDigit2                        ; Set shift bits to 2
    RET
shiftValue_3:
    INC     registerB
    CP      registerA, registerB
    BRNE    shiftValue_4
    LDI     registerB, displayDigit3                        ; Set shift bits to 3
    RET
shiftValue_4:
    INC     registerB
    CP      registerA, registerB
    BRNE    shiftValue_5
    LDI     registerB, displayDigit4                        ; Set shift bits to 4
    RET
shiftValue_5:
    INC     registerB
    CP      registerA, registerB
    BRNE    shiftValue_6
    LDI     registerB, displayDigit5                        ; Set shift bits to 5
    RET
shiftValue_6:
    INC     registerB
    CP      registerA, registerB
    BRNE    shiftValue_7
    LDI     registerB, displayDigit6                        ; Set shift bits to 6
    RET
shiftValue_7:
    INC     registerB
    CP      registerA, registerB
    BRNE    shiftValue_8
    LDI     registerB, displayDigit7                        ; Set shift bits to 7
    RET
shiftValue_8:
    INC     registerB
    CP      registerA, registerB
    BRNE    shiftValue_9
    LDI     registerB, displayDigit8                        ; Set shift bits to 8
    RET
shiftValue_9:
    LDI     registerB, displayDigit9                        ; Set shift bits to 9
    RET

delay:
    LDI     delayRegisterA, 255
    LDI     delayRegisterB, 0
delayStart:
    DEC     delayRegisterA
    CP      delayRegisterA, delayRegisterB
    BRNE    delayStart
    RET

setTimer:
    ; Use the 8-bit timer0
    ; We want to wait about 10ms or 10000us
    ; If we use a prescaler of 1024 we get about 9.77ms which is close enough
    LDI     registerA, (1<<CS02)                        ; Clock select bit2
    OR      registerA, (1<<CS00)                        ; Clock select bit0, registerA = (1<<CS02|1<<CS00)
    OUT     TCCR0B, registerA                           ; Set prescaler to /1024
    LDI     registerA, (1<<TOV0)                        ; Load timer overflow flag
    OUT     TIFR0, registerA                            ; Reset by writing a 1
    LDI     registerA, (1<<TOIE0)                       ; Load overflow interrupt flag for timer 0
    STS     TIMSK0, registerA                           ; Enable overflow interrupt flag for timer 0
    RET

;===============================================================================
; ISR SUBROUTINES
;
PIN_CHANGE:
    CLI                                                     ; Disable interrupt
    ; Push registers on stack
    PUSH    registerA
    PUSH    registerB

    RJMP    setTimer                                        ; (Re)set timer

    ; Pop registers from stack
    POP     registerB
    POP     registerA
    SEI                                                     ; Enable interrupt
    RETI

TIM0_OVF:
    CLI                                                     ; Disable interrupt
    ; Push registers on stack
    PUSH    registerA
    PUSH    registerB

    ; Clear stop the timer by setting Clock select to 0
    LDI     registerA, 0x000000
    OUT     TCCR0B, registerA

    ; The timer was started because of a button that was pressed
    IN      registerA, PINB                                 ; Load port A
    LDI     registerB, (1<<incrementPin)                    ; Set value for increment
    CP      registerA, registerB                            ; Compare, only increment pin should remain
    SBRS    SREG, 0x00000010                                ; Check if zero flag is set, if not skip next instruction
    RJMP    incrementCounter
    LDI     registerB, (1<<decrementPin)                    ; Set value for decrement
    CP      registerA, registerB                            ; Compare, only decrement pin should remain
    SBRS    SREG, 0x00000010                                ; Check if zero flag is set, if not skip next instruction
    RJMP    decrementCounter

    ; Pop registers from stack
    POP     registerB
    POP     registerA
    SEI                                                     ; Enable interrupt
    RETI
