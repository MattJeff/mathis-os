; ============================================================================
; PIPE_CLOSE.ASM - Close pipe file descriptor
; ============================================================================
; Single responsibility: Close pipe ends and cleanup
; ============================================================================

[BITS 64]


; ============================================================================
; PIPE_CLOSE - Close one end of a pipe
; ============================================================================
; Input:  EDI = file descriptor
; Output: RAX = 0 success, -1 error
; ============================================================================
pipe_close:
    push rbx
    push r12

    mov r12d, edi                       ; Save FD

    ; Find pipe by FD
    call pipe_get_by_fd
    test rax, rax
    jz .error

    mov rbx, rax                        ; Pipe pointer

    ; Check if read or write end (RDX set by pipe_get_by_fd)
    test edx, edx
    jnz .close_write

    ; Close read end
    lock dec dword [rbx + PIPE_READERS]
    jmp .check_cleanup

.close_write:
    ; Close write end
    lock dec dword [rbx + PIPE_WRITERS]

.check_cleanup:
    ; If both ends closed, free the pipe
    mov eax, [rbx + PIPE_READERS]
    add eax, [rbx + PIPE_WRITERS]
    test eax, eax
    jnz .success

    ; Free buffer
    mov rdi, [rbx + PIPE_BUFFER]
    test rdi, rdi
    jz .clear_struct
    call pmm_free_frame

.clear_struct:
    ; Clear pipe structure
    mov qword [rbx + PIPE_BUFFER], 0
    mov dword [rbx + PIPE_SIZE], 0

.success:
    xor eax, eax
    jmp .done

.error:
    mov rax, -1

.done:
    pop r12
    pop rbx
    ret
