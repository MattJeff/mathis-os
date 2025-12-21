; ============================================================================
; SIGNAL/TABLE.ASM - Signal table data
; ============================================================================
; Single responsibility: Define signal table storage
; Dependencies: SIG_TABLE_SIZE from const.asm
; ============================================================================

[BITS 64]

section .data

align 8
signal_table:
    dq 0

; ============================================================================
; Restore text section for next includes
; ============================================================================
section .text
