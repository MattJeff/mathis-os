; ============================================================================
; THREAD_CREATE.ASM - Create kernel thread
; ============================================================================
; Single responsibility: Allocate and initialize new thread
; ============================================================================

[BITS 64]


; ============================================================================
; THREAD_CREATE - Create new kernel thread
; ============================================================================
; Input:  RDI = entry point, RSI = argument, RDX = stack size (0 = default)
; Output: RAX = TID (>= 0), or -1 on error
; Clobbers: RAX, RCX, RDX (scratch)
; ============================================================================
thread_create:
    push rbx
    push r12
    push r13
    push r14

    mov r12, rdi                        ; Save entry point
    mov r13, rsi                        ; Save argument
    mov r14, rdx                        ; Save stack size
    test r14, r14
    jnz .has_size
    mov r14, THREAD_DEFAULT_STACK

.has_size:
    ; Find free TCB slot
    lea rbx, [thread_table]
    xor ecx, ecx

.find_slot:
    cmp ecx, MAX_THREADS
    jge .error

    cmp byte [rbx + TCB_STATE], PROC_STATE_FREE
    je .found_slot

    add rbx, TCB_SIZE
    inc ecx
    jmp .find_slot

.found_slot:
    push rcx                            ; Save slot index

    ; Allocate stack (1 page = 4KB minimum)
    mov rdi, r14
    add rdi, 4095
    shr rdi, 12                         ; Convert to pages
    call pmm_alloc_pages
    test rax, rax
    jz .error_pop

    mov r14, rax                        ; Stack base

    pop rcx                             ; Restore slot index

    ; Assign TID
    movzx eax, word [next_tid]
    mov [rbx + TCB_TID], ax
    inc word [next_tid]

    ; Get parent PID from current process
    mov rax, [current_process]
    movzx eax, word [rax + PCB_PID]
    mov [rbx + TCB_PID], ax

    ; Set state and priority
    mov byte [rbx + TCB_STATE], PROC_STATE_READY
    mov byte [rbx + TCB_PRIORITY], PRIO_NORMAL
    mov word [rbx + TCB_FLAGS], 0

    ; Setup stack info
    mov [rbx + TCB_STACK_BASE], r14
    mov dword [rbx + TCB_STACK_SIZE], THREAD_DEFAULT_STACK

    ; Setup execution context
    mov [rbx + TCB_ENTRY], r12
    mov [rbx + TCB_ARG], r13

    ; Setup initial RSP (top of stack, 16-byte aligned)
    mov rax, r14
    add rax, THREAD_DEFAULT_STACK
    and rax, ~0xF                       ; Align to 16 bytes
    sub rax, 8                          ; Space for return address
    mov [rbx + TCB_RSP], rax

    mov [rbx + TCB_RIP], r12
    mov qword [rbx + TCB_RFLAGS], 0x202 ; IF set

    ; Return TID
    movzx eax, word [rbx + TCB_TID]
    jmp .done

.error_pop:
    pop rcx
.error:
    mov rax, -1

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
