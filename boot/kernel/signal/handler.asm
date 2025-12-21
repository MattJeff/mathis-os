; ============================================================================
; SIGNAL/HANDLER.ASM - Set/get signal handlers
; ============================================================================
; Single responsibility: Manage signal handler registration
; Dependencies: signal_get_entry, signal_get_current_idx
; ============================================================================

[BITS 64]

section .text

; ============================================================================
; sys_signal - Set signal handler for current process
; ============================================================================
; Input:  RDI = signal number (1-31)
;         RSI = new handler address (or SIG_DFL/SIG_IGN)
; Output: RAX = previous handler, or -1 on error
; Clobbers: RAX, RCX, RDX, R8-R11 (scratch per System V)
; ============================================================================
sys_signal:
    push r12
    push r13

    mov r12, rdi                    ; Save signal number
    mov r13, rsi                    ; Save new handler

    ; Validate signal (1-31, not SIGKILL/SIGSTOP)
    test r12, r12
    jz .error
    cmp r12, SIG_MAX
    jge .error
    cmp r12, SIGKILL
    je .error
    cmp r12, SIGSTOP
    je .error

    ; Get current process index
    call signal_get_current_idx
    cmp eax, -1
    je .error

    ; Get signal entry
    mov edi, eax
    call signal_get_entry
    test rax, rax
    jz .error

    ; Calculate handler offset: base + SIG_OFF_HANDLERS + (signum * 8)
    lea rcx, [rax + SIG_OFF_HANDLERS]
    lea rcx, [rcx + r12 * 8]

    ; Swap handlers
    mov rdx, [rcx]                  ; Get old handler
    mov [rcx], r13                  ; Set new handler
    mov rax, rdx                    ; Return old

    pop r13
    pop r12
    ret

.error:
    mov rax, -1
    pop r13
    pop r12
    ret
