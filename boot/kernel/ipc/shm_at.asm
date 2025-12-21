; ============================================================================
; SHM_AT.ASM - Attach/detach shared memory
; ============================================================================
; Single responsibility: Map/unmap shared memory to process
; ============================================================================

[BITS 64]


; ============================================================================
; SYS_SHMAT - Attach shared memory to process
; ============================================================================
; Input:  RDI = shm_id, RSI = shmaddr (0 = kernel chooses), RDX = flags
; Output: RAX = mapped address, or -1 on error
; Note: For simplicity, returns physical address (flat memory model)
; ============================================================================
sys_shmat:
    push rbx

    ; Validate shm_id
    cmp rdi, MAX_SHM_REGIONS
    jge .error

    ; Get SHM entry
    push rdi
    call shm_get_entry
    pop rdi
    test rax, rax
    jz .error

    mov rbx, rax

    ; Check if region exists
    cmp qword [rbx + SHM_SIZE], 0
    je .error

    ; Increment reference count
    lock inc dword [rbx + SHM_REFCOUNT]

    ; Return physical address
    ; In a full implementation, this would map to virtual address
    mov rax, [rbx + SHM_ADDR]
    jmp .done

.error:
    mov rax, -1

.done:
    pop rbx
    ret

; ============================================================================
; SYS_SHMDT - Detach shared memory from process
; ============================================================================
; Input:  RDI = shmaddr (address returned by shmat)
; Output: RAX = 0 success, -1 error
; ============================================================================
sys_shmdt:
    push rbx
    push rcx

    ; Find region by address
    lea rbx, [shm_table]
    xor ecx, ecx

.search:
    cmp ecx, MAX_SHM_REGIONS
    jge .error

    ; Skip empty
    cmp qword [rbx + SHM_SIZE], 0
    je .next

    ; Check address match
    cmp [rbx + SHM_ADDR], rdi
    je .found

.next:
    add rbx, SHM_STRUCT_SIZE
    inc ecx
    jmp .search

.found:
    ; Decrement reference count
    lock dec dword [rbx + SHM_REFCOUNT]

    xor eax, eax                        ; Success
    jmp .done

.error:
    mov rax, -1

.done:
    pop rcx
    pop rbx
    ret

; ============================================================================
; SYS_SHMCTL - Control shared memory
; ============================================================================
; Input:  RDI = shm_id, RSI = cmd, RDX = buf
; Output: RAX = 0 success, -1 error
; Note: Minimal implementation - only supports IPC_RMID (0)
; ============================================================================
sys_shmctl:
    push rbx

    ; Validate shm_id
    cmp rdi, MAX_SHM_REGIONS
    jge .error

    ; Get entry
    push rdi
    push rsi
    call shm_get_entry
    pop rsi
    pop rdi
    test rax, rax
    jz .error

    mov rbx, rax

    ; Only handle IPC_RMID (0)
    test rsi, rsi
    jnz .error

    ; Check refcount = 0 before removing
    cmp dword [rbx + SHM_REFCOUNT], 0
    jne .error

    ; Free physical memory
    mov rdi, [rbx + SHM_ADDR]
    test rdi, rdi
    jz .clear

    mov rsi, [rbx + SHM_SIZE]
    add rsi, 4095
    shr rsi, 12
    call pmm_free_pages

.clear:
    ; Clear structure
    mov qword [rbx + SHM_KEY], 0
    mov qword [rbx + SHM_ADDR], 0
    mov qword [rbx + SHM_SIZE], 0

    xor eax, eax
    jmp .done

.error:
    mov rax, -1

.done:
    pop rbx
    ret
