; ============================================================================
; SIGNAL/CHECK.ASM - Check for pending signals
; ============================================================================
; Single responsibility: Find first pending unblocked signal
; Dependencies: signal_get_entry, signal_get_current_idx
; ============================================================================

[BITS 64]

section .text

; ============================================================================
; signal_check - Check for pending signals on current process
; ============================================================================
; Input:  none
; Output: EAX = first pending signal number (1-31), or 0 if none
; Clobbers: RAX, RCX, RDX (scratch per System V)
; ============================================================================
signal_check:
    ; Get current process index
    call signal_get_current_idx
    cmp eax, -1
    je .none

    ; Get signal entry
    mov edi, eax
    call signal_get_entry
    test rax, rax
    jz .none

    ; Get pending & ~mask (unblocked pending signals)
    mov ecx, [rax + SIG_OFF_PENDING]
    mov edx, [rax + SIG_OFF_MASK]
    not edx
    and ecx, edx

    ; Find first set bit
    test ecx, ecx
    jz .none
    bsf eax, ecx
    ret

.none:
    xor eax, eax
    ret
