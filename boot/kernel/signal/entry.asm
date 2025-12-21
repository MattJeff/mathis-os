; ============================================================================
; SIGNAL/ENTRY.ASM - Get signal entry for process
; ============================================================================
; Single responsibility: Calculate signal entry address for process index
; Dependencies: signal_table, SIG_ENTRY_SIZE, MAX_PROCESSES
; ============================================================================

[BITS 64]

section .text

; ============================================================================
; signal_get_entry - Get signal entry pointer for process index
; ============================================================================
; Input:  EDI = process index (0 to MAX_PROCESSES-1)
; Output: RAX = pointer to signal entry, or 0 if invalid
; Clobbers: RAX (scratch per System V)
; ============================================================================
signal_get_entry:
    ; Validate index
    cmp edi, MAX_PROCESSES
    jge .invalid

    ; Calculate: signal_table + (index * SIG_ENTRY_SIZE)
    mov eax, edi
    imul eax, SIG_ENTRY_SIZE
    lea rax, [rel signal_table + rax]
    ret

.invalid:
    xor eax, eax
    ret

; ============================================================================
; signal_get_current_idx - Get index of current process
; ============================================================================
; Input:  none
; Output: EAX = process index (0 to MAX_PROCESSES-1), or -1 if none
; Clobbers: RAX, RCX, RDX (scratch per System V)
; ============================================================================
signal_get_current_idx:
    mov rax, [rel current_process]
    test rax, rax
    jz .not_found

    ; Calculate: (current_process - process_table) / PCB_SIZE
    lea rcx, [rel process_table]
    sub rax, rcx
    xor edx, edx
    mov ecx, PCB_SIZE
    div ecx

    ; Validate result
    cmp eax, MAX_PROCESSES
    jge .not_found
    ret

.not_found:
    mov eax, -1
    ret
