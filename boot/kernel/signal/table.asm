; ============================================================================
; SIGNAL/TABLE.ASM - Signal table data
; ============================================================================
; Single responsibility: Define signal table storage
; Dependencies: SIG_TABLE_SIZE from const.asm
; ============================================================================

[BITS 64]

section .data

align 16
signal_table:
    times SIG_TABLE_SIZE db 0

; ============================================================================
; Restore text section for next includes
; ============================================================================
section .text
