; ============================================================================
; THREAD_DATA.ASM - Thread table and init
; ============================================================================
; Pattern: CODE first, DATA at end (like scheduler.asm)
; ============================================================================

[BITS 64]

; ============================================================================
; THREAD_INIT - Initialize thread subsystem
; ============================================================================
thread_init:
    push rdi
    push rcx
    push rax

    lea rdi, [thread_table]
    mov rcx, (MAX_THREADS * TCB_SIZE) / 8
    xor rax, rax
    rep stosq

    mov word [next_tid], 1
    mov qword [current_thread], 0

    pop rax
    pop rcx
    pop rdi
    ret

; ============================================================================
; THREAD_GET_TCB - Get TCB by thread ID
; ============================================================================
thread_get_tcb:
    cmp edi, MAX_THREADS
    jge .invalid

    mov eax, edi
    imul eax, TCB_SIZE
    lea rax, [thread_table + rax]
    ret

.invalid:
    xor eax, eax
    ret

; ============================================================================
; THREAD DATA (at end)
; ============================================================================
align 8
thread_table:   times (TCB_SIZE * MAX_THREADS) db 0
next_tid:       dw 0
current_thread: dq 0
