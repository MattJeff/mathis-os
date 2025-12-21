; ============================================================================
; EXC_HANDLERS.ASM - CPU Exception Handler Stubs (INT 0x00 - 0x1F)
; ============================================================================
; Minimal stubs that push exception info and jump to common handler
; Exceptions WITH error code: 8, 10-14, 17, 21, 29, 30
; Exceptions WITHOUT error code: all others (we push 0)
; ============================================================================

[BITS 64]

; ============================================================================
; HANDLERS WITHOUT ERROR CODE (push fake 0)
; ============================================================================

exc_handler_00:                 ; #DE - Divide Error
    push qword 0
    push qword 0
    jmp exc_common

exc_handler_01:                 ; #DB - Debug
    push qword 0
    push qword 1
    jmp exc_common

exc_handler_02:                 ; NMI - Non-Maskable Interrupt
    push qword 0
    push qword 2
    jmp exc_common

exc_handler_03:                 ; #BP - Breakpoint
    push qword 0
    push qword 3
    jmp exc_common

exc_handler_04:                 ; #OF - Overflow
    push qword 0
    push qword 4
    jmp exc_common

exc_handler_05:                 ; #BR - Bound Range Exceeded
    push qword 0
    push qword 5
    jmp exc_common

exc_handler_06:                 ; #UD - Invalid Opcode
    push qword 0
    push qword 6
    jmp exc_common

exc_handler_07:                 ; #NM - No FPU
    push qword 0
    push qword 7
    jmp exc_common

exc_handler_09:                 ; Coprocessor Segment Overrun
    push qword 0
    push qword 9
    jmp exc_common

exc_handler_0f:                 ; Reserved
    push qword 0
    push qword 15
    jmp exc_common

exc_handler_10:                 ; #MF - x87 FPU Error
    push qword 0
    push qword 16
    jmp exc_common

exc_handler_12:                 ; #MC - Machine Check
    push qword 0
    push qword 18
    jmp exc_common

exc_handler_13:                 ; #XM - SIMD Exception
    push qword 0
    push qword 19
    jmp exc_common

exc_handler_14:                 ; Virtualization Exception
    push qword 0
    push qword 20
    jmp exc_common

exc_handler_16:                 ; Reserved
    push qword 0
    push qword 22
    jmp exc_common

exc_handler_17:                 ; Reserved
    push qword 0
    push qword 23
    jmp exc_common

exc_handler_18:                 ; Reserved
    push qword 0
    push qword 24
    jmp exc_common

exc_handler_19:                 ; Reserved
    push qword 0
    push qword 25
    jmp exc_common

exc_handler_1a:                 ; Reserved
    push qword 0
    push qword 26
    jmp exc_common

exc_handler_1b:                 ; Reserved
    push qword 0
    push qword 27
    jmp exc_common

exc_handler_1c:                 ; Hypervisor Injection
    push qword 0
    push qword 28
    jmp exc_common

exc_handler_1f:                 ; Reserved
    push qword 0
    push qword 31
    jmp exc_common

; ============================================================================
; HANDLERS WITH ERROR CODE (CPU pushes it, we just push exc number)
; ============================================================================

exc_handler_08:                 ; #DF - Double Fault
    push qword 8
    jmp exc_common

exc_handler_0a:                 ; #TS - Invalid TSS
    push qword 10
    jmp exc_common

exc_handler_0b:                 ; #NP - Segment Not Present
    push qword 11
    jmp exc_common

exc_handler_0c:                 ; #SS - Stack-Segment Fault
    push qword 12
    jmp exc_common

exc_handler_0d:                 ; #GP - General Protection Fault
    push qword 13
    jmp exc_common

exc_handler_0e:                 ; #PF - Page Fault
    push qword 14
    jmp exc_common

exc_handler_11:                 ; #AC - Alignment Check
    push qword 17
    jmp exc_common

exc_handler_15:                 ; #CP - Control Protection
    push qword 21
    jmp exc_common

exc_handler_1d:                 ; VMM Communication Exception
    push qword 29
    jmp exc_common

exc_handler_1e:                 ; Security Exception
    push qword 30
    jmp exc_common
