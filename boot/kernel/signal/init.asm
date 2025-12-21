; ============================================================================
; SIGNAL/INIT.ASM - Signal subsystem initialization
; ============================================================================
; Single responsibility: Clear signal table at boot
; Dependencies: signal_table from table.asm, SIG_TABLE_SIZE from const.asm
; ============================================================================

[BITS 64]

section .text

; ============================================================================
; signal_init - Initialize signal subsystem
; ============================================================================
; Input:  none
; Output: none
; Clobbers: RAX, RCX, RDI (scratch per System V)
; ============================================================================
signal_init:
    ; Clear entire signal table with rep stosq
    lea rdi, [rel signal_table]
    mov ecx, SIG_TABLE_SIZE / 8
    xor eax, eax
    rep stosq
    ret
