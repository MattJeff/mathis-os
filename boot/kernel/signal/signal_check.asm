; ============================================================================
; SIGNAL_CHECK.ASM - Check and deliver pending signals
; ============================================================================
; Single responsibility: Process pending signals for current process
; ============================================================================

[BITS 64]

section .text

; ============================================================================
; SIGNAL_CHECK - Check for pending signals on current process
; ============================================================================
; Input:  none
; Output: EAX = first pending signal, 0 if none
; Note: Does NOT clear the pending bit - use signal_deliver for that
; ============================================================================
signal_check:
    push rbx

    ; Get current process index
    call signal_get_current_index
    cmp eax, -1
    je .no_signal

    ; Get signal entry
    mov edi, eax
    call signal_get_entry
    test rax, rax
    jz .no_signal

    ; Check pending bitmap (masked by block mask)
    mov ebx, [rax + SIG_PENDING_OFF]
    mov ecx, [rax + SIG_MASK_OFF]
    not ecx
    and ebx, ecx                        ; pending & ~mask

    test ebx, ebx
    jz .no_signal

    ; Find first pending signal
    bsf eax, ebx
    pop rbx
    ret

.no_signal:
    xor eax, eax
    pop rbx
    ret

; ============================================================================
; SIGNAL_DELIVER - Deliver next pending signal
; ============================================================================
; Input:  none
; Output: none
; Note: Called before returning to user mode (after syscall/interrupt)
; ============================================================================
signal_deliver:
    push rbx
    push r12

    ; Get current process index
    call signal_get_current_index
    cmp eax, -1
    je .done

    mov r12d, eax                       ; Save process index

    ; Get signal entry
    mov edi, eax
    call signal_get_entry
    test rax, rax
    jz .done

    mov rbx, rax                        ; Signal entry

    ; Get pending (masked)
    mov eax, [rbx + SIG_PENDING_OFF]
    mov ecx, [rbx + SIG_MASK_OFF]
    not ecx
    and eax, ecx

    test eax, eax
    jz .done

    ; Find and clear first pending
    bsf ecx, eax
    lock btr dword [rbx + SIG_PENDING_OFF], ecx

    ; Get handler
    lea rax, [rbx + SIG_HANDLERS_OFF]
    mov rdi, [rax + rcx * 8]

    ; Check handler type
    cmp rdi, SIG_IGN
    je .done                            ; Ignored

    cmp rdi, SIG_DFL
    je .default_action

    ; User handler - TODO: setup trampoline
    jmp .done

.default_action:
    ; Default actions based on signal type
    cmp ecx, SIGKILL
    je .terminate
    cmp ecx, SIGTERM
    je .terminate
    cmp ecx, SIGSEGV
    je .terminate
    cmp ecx, SIGABRT
    je .terminate
    jmp .done

.terminate:
    ; Kill the process
    mov edi, r12d
    call signal_terminate_process

.done:
    pop r12
    pop rbx
    ret

; ============================================================================
; SIGNAL_TERMINATE_PROCESS - Terminate process by index
; ============================================================================
; Input:  EDI = process index
; ============================================================================
signal_terminate_process:
    push rbx

    ; Get PCB
    mov eax, edi
    imul eax, PCB_SIZE
    lea rbx, [process_table + rax]

    ; Mark as zombie
    mov byte [rbx + PCB_STATE], PROC_STATE_ZOMBIE

    pop rbx
    ret
