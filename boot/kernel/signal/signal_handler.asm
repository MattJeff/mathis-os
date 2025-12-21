; ============================================================================
; SIGNAL_HANDLER.ASM - Set/get signal handlers
; ============================================================================
; Single responsibility: Manage signal handler registration
; ============================================================================

[BITS 64]

section .text

; ============================================================================
; SYS_SIGNAL - Set signal handler
; ============================================================================
; Input:  RDI = signal number, RSI = new handler (addr or SIG_DFL/SIG_IGN)
; Output: RAX = previous handler, -1 on error
; Clobbers: RAX, RCX, RDX (scratch)
; ============================================================================
sys_signal:
    push rbx
    push r12
    push r13

    mov r12, rdi                        ; Save signal number
    mov r13, rsi                        ; Save new handler

    ; Validate signal number
    test r12, r12
    jz .error
    cmp r12, MAX_SIGNALS
    jge .error

    ; Cannot catch SIGKILL or SIGSTOP
    cmp r12, SIGKILL
    je .error
    cmp r12, SIGSTOP
    je .error

    ; Get current process index
    call signal_get_current_index
    cmp eax, -1
    je .error

    ; Get signal entry
    mov edi, eax
    call signal_get_entry
    test rax, rax
    jz .error

    mov rbx, rax                        ; Signal entry base

    ; Calculate handler offset: base + SIG_HANDLERS_OFF + signum * 8
    lea rcx, [rbx + SIG_HANDLERS_OFF]
    lea rcx, [rcx + r12 * 8]

    ; Get old handler
    mov rdx, [rcx]

    ; Set new handler
    mov [rcx], r13

    mov rax, rdx                        ; Return old handler
    pop r13
    pop r12
    pop rbx
    ret

.error:
    mov rax, -1
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; SIGNAL_GET_CURRENT_INDEX - Get index of current process
; ============================================================================
; Output: EAX = process index (0-7), or -1 if not found
; ============================================================================
signal_get_current_index:
    mov rax, [current_process]
    test rax, rax
    jz .not_found

    ; Calculate index: (current - process_table) / PCB_SIZE
    lea rcx, [process_table]
    sub rax, rcx
    xor edx, edx
    mov ecx, PCB_SIZE
    div ecx                             ; RAX = index

    cmp eax, MAX_PROCESSES
    jge .not_found
    ret

.not_found:
    mov eax, -1
    ret
