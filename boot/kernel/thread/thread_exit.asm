; ============================================================================
; THREAD_EXIT.ASM - Thread exit and join
; ============================================================================
; Single responsibility: Thread termination and synchronization
; ============================================================================

[BITS 64]


; ============================================================================
; THREAD_EXIT - Terminate current thread
; ============================================================================
; Input:  RDI = exit code (ignored for now)
; Output: Does not return
; ============================================================================
thread_exit:
    push rbx

    ; Get current thread TCB
    mov rbx, [current_thread]
    test rbx, rbx
    jz .no_thread

    ; Mark as zombie (join will cleanup)
    mov byte [rbx + TCB_STATE], PROC_STATE_ZOMBIE

    ; Reschedule to another thread/process
    call yield_process

    ; Should not reach here
.no_thread:
    pop rbx
    hlt
    jmp thread_exit

; ============================================================================
; THREAD_JOIN - Wait for thread to terminate
; ============================================================================
; Input:  RDI = TID to wait for
; Output: RAX = 0 success, -1 error
; ============================================================================
thread_join:
    push rbx
    push r12

    mov r12d, edi                       ; Save TID

    ; Validate TID range
    cmp edi, MAX_THREADS
    jge .error

    ; Get TCB
    call thread_get_tcb
    test rax, rax
    jz .error

    mov rbx, rax

.wait_loop:
    ; Check thread state
    movzx eax, byte [rbx + TCB_STATE]

    ; Already free = already joined/never existed
    cmp al, PROC_STATE_FREE
    je .success

    ; Zombie = finished, clean it up
    cmp al, PROC_STATE_ZOMBIE
    je .cleanup

    ; Still running, yield and retry
    call yield_process
    jmp .wait_loop

.cleanup:
    ; Free the stack
    mov rdi, [rbx + TCB_STACK_BASE]
    test rdi, rdi
    jz .mark_free

    mov esi, [rbx + TCB_STACK_SIZE]
    add rsi, 4095
    shr rsi, 12                         ; Pages
    call pmm_free_pages

.mark_free:
    ; Mark slot as free
    mov byte [rbx + TCB_STATE], PROC_STATE_FREE

.success:
    xor eax, eax
    jmp .done

.error:
    mov rax, -1

.done:
    pop r12
    pop rbx
    ret
