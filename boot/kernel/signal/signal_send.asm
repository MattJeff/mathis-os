; ============================================================================
; SIGNAL_SEND.ASM - Send signal to process
; ============================================================================
; Single responsibility: Set pending signal bit for target process
; ============================================================================

[BITS 64]

section .text

; ============================================================================
; SIGNAL_SEND - Send signal to process
; ============================================================================
; Input:  EDI = process index, ESI = signal number (1-31)
; Output: EAX = 0 success, -1 error
; Clobbers: RAX, RCX, RDX (scratch)
; ============================================================================
signal_send:
    ; Validate signal number
    test esi, esi
    jz .error
    cmp esi, MAX_SIGNALS
    jge .error

    ; Get process signal entry
    push rdi
    push rsi
    call signal_get_entry
    pop rsi
    pop rdi

    test rax, rax
    jz .error

    ; Set pending bit (atomic)
    mov ecx, esi
    lock bts dword [rax + SIG_PENDING_OFF], ecx

    xor eax, eax                        ; Return 0 = success
    ret

.error:
    mov eax, -1
    ret

; ============================================================================
; SIGNAL_SEND_PID - Send signal to process by PID
; ============================================================================
; Input:  EDI = pid, ESI = signal number (1-31)
; Output: EAX = 0 success, -1 error
; ============================================================================
signal_send_pid:
    push rbx
    push r12
    push r13

    mov r12d, edi                       ; Save pid
    mov r13d, esi                       ; Save signal

    ; Find process by PID
    lea rbx, [process_table]
    xor ecx, ecx

.search:
    cmp ecx, MAX_PROCESSES
    jge .not_found

    ; Skip free/zombie
    cmp byte [rbx + PCB_STATE], PROC_STATE_FREE
    je .next
    cmp byte [rbx + PCB_STATE], PROC_STATE_ZOMBIE
    je .next

    ; Check PID
    movzx eax, word [rbx + PCB_PID]
    cmp eax, r12d
    je .found

.next:
    add rbx, PCB_SIZE
    inc ecx
    jmp .search

.found:
    ; ecx = process index
    mov edi, ecx
    mov esi, r13d
    call signal_send
    jmp .done

.not_found:
    mov eax, -1

.done:
    pop r13
    pop r12
    pop rbx
    ret
