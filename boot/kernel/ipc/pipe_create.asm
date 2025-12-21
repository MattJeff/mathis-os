; ============================================================================
; PIPE_CREATE.ASM - Create pipe syscall
; ============================================================================
; Single responsibility: Allocate and initialize new pipe
; ============================================================================

[BITS 64]


; ============================================================================
; SYS_PIPE - Create pipe pair
; ============================================================================
; Input:  RDI = int pipefd[2] (pointer to 2 ints)
; Output: RAX = 0 success, -1 error
;         pipefd[0] = read FD, pipefd[1] = write FD
; ============================================================================
sys_pipe:
    push rbx
    push r12

    mov r12, rdi                        ; Save pipefd pointer

    ; Find free pipe slot
    lea rbx, [pipe_table]
    xor ecx, ecx

.find_slot:
    cmp ecx, MAX_PIPES
    jge .error

    cmp dword [rbx + PIPE_SIZE], 0
    je .found_slot

    add rbx, PIPE_STRUCT_SIZE
    inc ecx
    jmp .find_slot

.found_slot:
    push rcx                            ; Save slot index

    ; Allocate buffer (1 page = 4KB)
    mov rdi, 1
    call pmm_alloc_frame
    test rax, rax
    jz .error_pop

    pop rcx                             ; Restore slot index

    ; Initialize pipe structure
    mov [rbx + PIPE_BUFFER], rax
    mov dword [rbx + PIPE_SIZE], PIPE_BUFFER_SIZE
    mov dword [rbx + PIPE_HEAD], 0
    mov dword [rbx + PIPE_TAIL], 0
    mov dword [rbx + PIPE_COUNT], 0
    mov dword [rbx + PIPE_READERS], 1
    mov dword [rbx + PIPE_WRITERS], 1
    mov dword [rbx + PIPE_FLAGS], 0

    ; Allocate file descriptors
    mov eax, [next_pipe_fd]
    mov [rbx + PIPE_READ_FD], eax
    inc eax
    mov [rbx + PIPE_WRITE_FD], eax
    inc eax
    mov [next_pipe_fd], eax

    ; Store FDs in user array
    mov eax, [rbx + PIPE_READ_FD]
    mov [r12], eax
    mov eax, [rbx + PIPE_WRITE_FD]
    mov [r12 + 4], eax

    xor eax, eax                        ; Return 0 = success
    jmp .done

.error_pop:
    pop rcx
.error:
    mov rax, -1

.done:
    pop r12
    pop rbx
    ret
