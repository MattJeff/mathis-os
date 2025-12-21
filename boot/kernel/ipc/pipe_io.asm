; ============================================================================
; PIPE_IO.ASM - Pipe read/write operations
; ============================================================================
; Single responsibility: Data transfer through pipes
; ============================================================================

[BITS 64]


; ============================================================================
; PIPE_READ - Read from pipe
; ============================================================================
; Input:  RDI = pipe pointer, RSI = buffer, EDX = count
; Output: RAX = bytes read, 0 = EOF, -1 = error
; ============================================================================
pipe_read:
    push rbx
    push r12
    push r13
    push r14

    mov rbx, rdi                        ; Pipe pointer
    mov r12, rsi                        ; Dest buffer
    mov r13d, edx                       ; Count
    xor r14d, r14d                      ; Bytes read

.read_loop:
    test r13d, r13d
    jz .read_done

    ; Check if data available
    mov eax, [rbx + PIPE_COUNT]
    test eax, eax
    jz .check_writers

    ; Read one byte from buffer
    mov rdi, [rbx + PIPE_BUFFER]
    mov eax, [rbx + PIPE_TAIL]
    movzx ecx, byte [rdi + rax]
    mov [r12], cl

    ; Advance tail (circular)
    inc eax
    cmp eax, [rbx + PIPE_SIZE]
    jl .no_wrap_read
    xor eax, eax
.no_wrap_read:
    mov [rbx + PIPE_TAIL], eax
    lock dec dword [rbx + PIPE_COUNT]

    inc r12
    inc r14d
    dec r13d
    jmp .read_loop

.check_writers:
    ; No data - check if writers exist
    cmp dword [rbx + PIPE_WRITERS], 0
    je .read_done                       ; No writers = EOF

    ; Already read something? Return it
    test r14d, r14d
    jnz .read_done

    ; Block: yield and retry
    call yield_process
    jmp .read_loop

.read_done:
    mov eax, r14d

    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; PIPE_WRITE - Write to pipe
; ============================================================================
; Input:  RDI = pipe pointer, RSI = buffer, EDX = count
; Output: RAX = bytes written, -1 = error (broken pipe)
; ============================================================================
pipe_write:
    push rbx
    push r12
    push r13
    push r14

    mov rbx, rdi
    mov r12, rsi
    mov r13d, edx
    xor r14d, r14d                      ; Bytes written

.write_loop:
    test r13d, r13d
    jz .write_done

    ; Check if readers exist
    cmp dword [rbx + PIPE_READERS], 0
    je .broken_pipe

    ; Check if buffer full
    mov eax, [rbx + PIPE_COUNT]
    cmp eax, [rbx + PIPE_SIZE]
    jge .buffer_full

    ; Write one byte to buffer
    mov rdi, [rbx + PIPE_BUFFER]
    mov eax, [rbx + PIPE_HEAD]
    movzx ecx, byte [r12]
    mov [rdi + rax], cl

    ; Advance head (circular)
    inc eax
    cmp eax, [rbx + PIPE_SIZE]
    jl .no_wrap_write
    xor eax, eax
.no_wrap_write:
    mov [rbx + PIPE_HEAD], eax
    lock inc dword [rbx + PIPE_COUNT]

    inc r12
    inc r14d
    dec r13d
    jmp .write_loop

.buffer_full:
    ; Already wrote something? Return it
    test r14d, r14d
    jnz .write_done

    ; Block: yield and retry
    call yield_process
    jmp .write_loop

.write_done:
    mov eax, r14d
    jmp .done

.broken_pipe:
    mov eax, -1

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
