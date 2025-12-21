; ============================================================================
; SIGNAL/TABLE.ASM - Signal table reference
; ============================================================================
; Single responsibility: Provide signal_table symbol
; The actual data is in data_all.asm to avoid forward reference issues
; ============================================================================

[BITS 64]

section .text

; signal_table is defined in data_all.asm as signal_table_data
; We create an alias here for compatibility
%define signal_table signal_table_data
