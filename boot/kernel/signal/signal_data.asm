; ============================================================================
; SIGNAL_DATA.ASM - Signal table and initialization
; ============================================================================
; Single responsibility: Initialize and access signal table
; ============================================================================

[BITS 64]

section .text

; ============================================================================
; SIGNAL_INIT - Initialize signal subsystem
; ============================================================================
; Input:  none
; Output: none
; Clobbers: RAX, RCX, RDI (scratch)
; ============================================================================
signal_init:
    push rdi
    push rcx
    push rax

    ; Clear signal table
    lea rdi, [signal_table]
    mov rcx, (MAX_PROCESSES * SIG_ENTRY_SIZE) / 8
    xor rax, rax
    rep stosq

    pop rax
    pop rcx
    pop rdi
    ret

; ============================================================================
; SIGNAL_GET_ENTRY - Get signal entry for process by index
; ============================================================================
; Input:  EDI = process index (0 to MAX_PROCESSES-1)
; Output: RAX = pointer to signal entry, or 0 if invalid
; Clobbers: RAX (scratch)
; ============================================================================
signal_get_entry:
    ; Validate index
    cmp edi, MAX_PROCESSES
    jge .invalid

    ; Calculate offset: index * SIG_ENTRY_SIZE
    mov eax, edi
    imul eax, SIG_ENTRY_SIZE
    lea rax, [signal_table + rax]
    ret

.invalid:
    xor eax, eax
    ret

; ============================================================================
; DATA SECTION
; ============================================================================
section .data

align 8
signal_table:   times (MAX_PROCESSES * SIG_ENTRY_SIZE) db 0
