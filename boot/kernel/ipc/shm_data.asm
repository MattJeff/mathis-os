; ============================================================================
; SHM_DATA.ASM - Shared memory table and init
; ============================================================================
; Pattern: CODE first, DATA at end (like scheduler.asm)
; ============================================================================

[BITS 64]

; ============================================================================
; SHM_INIT - Initialize shared memory subsystem
; ============================================================================
shm_init:
    push rdi
    push rcx
    push rax

    lea rdi, [shm_table]
    mov rcx, (MAX_SHM_REGIONS * SHM_STRUCT_SIZE) / 8
    xor rax, rax
    rep stosq

    pop rax
    pop rcx
    pop rdi
    ret

; ============================================================================
; SHM_GET_ENTRY - Get SHM entry by ID
; ============================================================================
shm_get_entry:
    cmp edi, MAX_SHM_REGIONS
    jge .invalid

    mov eax, edi
    imul eax, SHM_STRUCT_SIZE
    lea rax, [shm_table + rax]
    ret

.invalid:
    xor eax, eax
    ret

; ============================================================================
; SHM DATA (at end)
; ============================================================================
align 8
shm_table:      times (SHM_STRUCT_SIZE * MAX_SHM_REGIONS) db 0
