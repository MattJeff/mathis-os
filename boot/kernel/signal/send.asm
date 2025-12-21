; ============================================================================
; SIGNAL/SEND.ASM - Send signal to process
; ============================================================================
; Single responsibility: Set pending signal bit for target process
; Dependencies: signal_get_entry, SIG_OFF_PENDING, SIG_MAX
; ============================================================================

[BITS 64]

section .text

; ============================================================================
; signal_send - Send signal to process by index
; ============================================================================
; Input:  EDI = process index (0 to MAX_PROCESSES-1)
;         ESI = signal number (1 to SIG_MAX-1)
; Output: EAX = 0 on success, -1 on error
; Clobbers: RAX, RCX, RDX (scratch per System V)
; ============================================================================
signal_send:
    ; Validate signal number (must be 1-31)
    test esi, esi
    jz .error
    cmp esi, SIG_MAX
    jge .error

    ; Save signal number
    mov ecx, esi

    ; Get signal entry for process
    call signal_get_entry
    test rax, rax
    jz .error

    ; Set pending bit atomically
    lock bts dword [rax + SIG_OFF_PENDING], ecx

    xor eax, eax
    ret

.error:
    mov eax, -1
    ret
