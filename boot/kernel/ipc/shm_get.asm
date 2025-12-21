; ============================================================================
; SHM_GET.ASM - Create/get shared memory region
; ============================================================================
; Single responsibility: Allocate or find shared memory by key
; ============================================================================

[BITS 64]


; ============================================================================
; SYS_SHMGET - Get or create shared memory region
; ============================================================================
; Input:  RDI = key (unique identifier), RSI = size, RDX = flags
; Output: RAX = shm_id (0-15), or -1 on error
; ============================================================================
sys_shmget:
    push rbx
    push r12
    push r13

    mov r12, rdi                        ; Save key
    mov r13, rsi                        ; Save size

    ; Search for existing key
    lea rbx, [shm_table]
    xor ecx, ecx

.search:
    cmp ecx, MAX_SHM_REGIONS
    jge .not_found

    ; Skip empty entries
    cmp qword [rbx + SHM_SIZE], 0
    je .next_search

    ; Check key match
    cmp [rbx + SHM_KEY], r12
    je .found

.next_search:
    add rbx, SHM_STRUCT_SIZE
    inc ecx
    jmp .search

.found:
    ; Return existing shm_id
    mov eax, ecx
    jmp .done

.not_found:
    ; Find free slot
    lea rbx, [shm_table]
    xor ecx, ecx

.find_free:
    cmp ecx, MAX_SHM_REGIONS
    jge .error

    cmp qword [rbx + SHM_SIZE], 0
    je .create

    add rbx, SHM_STRUCT_SIZE
    inc ecx
    jmp .find_free

.create:
    push rcx                            ; Save slot index

    ; Allocate physical pages
    mov rdi, r13
    add rdi, 4095
    shr rdi, 12                         ; Pages needed
    call pmm_alloc_pages
    test rax, rax
    jz .error_pop

    pop rcx                             ; Restore slot index

    ; Initialize structure
    mov [rbx + SHM_KEY], r12
    mov [rbx + SHM_ADDR], rax
    mov [rbx + SHM_SIZE], r13
    mov dword [rbx + SHM_REFCOUNT], 0
    mov dword [rbx + SHM_FLAGS], 0

    ; Set owner
    mov rax, [current_process]
    movzx eax, word [rax + PCB_PID]
    mov [rbx + SHM_OWNER], ax

    mov eax, ecx                        ; Return shm_id
    jmp .done

.error_pop:
    pop rcx
.error:
    mov rax, -1

.done:
    pop r13
    pop r12
    pop rbx
    ret
