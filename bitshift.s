.global _start
.section .text

_start:
    MOV R1, #0xF0F0F0F0  ; Load a test value into R1

    LSL R2, R1, #4        ; Logical Shift Left R1 by 4, store result in R2
    LSR R3, R1, #4        ; Logical Shift Right R1 by 4, store result in R3
    ASR R4, R1, #4        ; Arithmetic Shift Right R1 by 4, store result in R4
    ROR R5, R1, #4        ; Rotate Right R1 by 4, store result in R5
    RRX R6, R1            ; Rotate Right with Extend R1 by 1, store result in R6

loop:
    B loop                ; Infinite loop to prevent the program from exiting
