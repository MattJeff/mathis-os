; ============================================================================
; PIPE_DATA.ASM - Pipe table and init
; ============================================================================
; Pattern: CODE first, DATA at end (like scheduler.asm)
; ============================================================================

[BITS 64]

; ============================================================================
; PIPE_INIT - Initialize pipe subsystem
; ============================================================================
pipe_init:
    push rdi
    push rcx
    push rax

    lea rdi, [pipe_table]
    mov rcx, (PIPE_STRUCT_SIZE * MAX_PIPES) / 8
    xor rax, rax
    rep stosq

    mov dword [next_pipe_fd], PIPE_FD_BASE

    pop rax
    pop rcx
    pop rdi
    ret

; ============================================================================
; PIPE_GET_BY_FD - Find pipe by file descriptor
; ============================================================================
pipe_get_by_fd:
    push rbx
    push rcx

    lea rbx, [pipe_table]
    xor ecx, ecx

.search:
    cmp ecx, MAX_PIPES
    jge .not_found

    cmp dword [rbx + PIPE_SIZE], 0
    je .next

    cmp [rbx + PIPE_READ_FD], edi
    jne .check_write
    mov rax, rbx
    xor edx, edx
    jmp .done

.check_write:
    cmp [rbx + PIPE_WRITE_FD], edi
    jne .next
    mov rax, rbx
    mov edx, 1
    jmp .done

.next:
    add rbx, PIPE_STRUCT_SIZE
    inc ecx
    jmp .search

.not_found:
    xor eax, eax

.done:
    pop rcx
    pop rbx
    ret

; ============================================================================
; PIPE DATA (at end)
; ============================================================================
align 8
pipe_table:     times (PIPE_STRUCT_SIZE * MAX_PIPES) db 0
next_pipe_fd:   dd 0
