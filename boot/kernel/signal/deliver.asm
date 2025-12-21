; ============================================================================
; SIGNAL/DELIVER.ASM - Deliver pending signal to current process
; ============================================================================
; Single responsibility: Process one pending signal
; Dependencies: signal_get_entry, signal_get_current_idx, process_table
; ============================================================================

[BITS 64]

section .text

; ============================================================================
; signal_deliver - Deliver next pending signal
; ============================================================================
; Input:  none
; Output: none
; Clobbers: RAX, RCX, RDX, RDI, RSI, R8-R11 (scratch per System V)
; ============================================================================
signal_deliver:
    push rbx
    push r12

    ; Get current process index
    call signal_get_current_idx
    cmp eax, -1
    je .done

    mov r12d, eax                   ; Save process index

    ; Get signal entry
    mov edi, eax
    call signal_get_entry
    test rax, rax
    jz .done

    mov rbx, rax                    ; Save signal entry

    ; Get pending & ~mask
    mov eax, [rbx + SIG_OFF_PENDING]
    mov ecx, [rbx + SIG_OFF_MASK]
    not ecx
    and eax, ecx
    test eax, eax
    jz .done

    ; Find and clear first pending bit
    bsf ecx, eax
    lock btr dword [rbx + SIG_OFF_PENDING], ecx

    ; Get handler for this signal
    lea rax, [rbx + SIG_OFF_HANDLERS]
    mov rdi, [rax + rcx * 8]

    ; Check handler type
    cmp rdi, SIG_IGN
    je .done
    cmp rdi, SIG_DFL
    je .default_action
    jmp .done                       ; User handler: TODO later

.default_action:
    ; Terminate on fatal signals
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
    ; Mark process as zombie
    mov eax, r12d
    imul eax, PCB_SIZE
    lea rbx, [rel process_table + rax]
    mov byte [rbx + PCB_STATE], PROC_STATE_ZOMBIE

.done:
    pop r12
    pop rbx
    ret
