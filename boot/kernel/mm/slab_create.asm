; ============================================================================
; SLAB_CREATE.ASM - Slab Creation Helper
; ============================================================================
; Creates new slab pages for the slab allocator
; ============================================================================

[BITS 64]

; Uses constants from slab_const.asm (included before this file)
; Uses slab_sizes from slab.asm (included before this file)

section .text

; ============================================================================
; SLAB_CREATE - Create new slab page
; ============================================================================
; Input:  ECX = cache index
; Output: RAX = slab address, or 0 on failure
; ============================================================================
slab_create:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    mov r8d, ecx                         ; Save cache index

    ; Allocate page
    call pmm_alloc_frame
    test rax, rax
    jz .fail

    mov rbx, rax                         ; Slab base

    ; Get object size
    lea rdi, [slab_sizes]
    mov edx, [rdi + r8 * 4]

    ; Initialize header
    mov qword [rbx + SLAB_HDR_NEXT], 0
    mov dword [rbx + SLAB_HDR_USED], 0
    mov [rbx + SLAB_HDR_SIZE], edx
    mov [rbx + SLAB_HDR_CACHE], r8d

    ; Calculate slots per page
    mov eax, PAGE_SIZE
    sub eax, SLAB_HEADER_SIZE
    xor edx, edx
    mov ecx, [rbx + SLAB_HDR_SIZE]
    div ecx                               ; EAX = slot count

    ; Build free list
    lea rdi, [rbx + SLAB_HEADER_SIZE]    ; First slot
    mov [rbx + SLAB_HDR_FREE], rdi       ; Free list head

    mov ecx, eax                          ; Slot count
    dec ecx                               ; Last slot has no next
    mov edx, [rbx + SLAB_HDR_SIZE]       ; Object size

.build_list:
    test ecx, ecx
    jz .last_slot

    ; Current->next = current + size
    lea rsi, [rdi + rdx]
    mov [rdi], rsi
    mov rdi, rsi
    dec ecx
    jmp .build_list

.last_slot:
    ; Last slot->next = NULL
    mov qword [rdi], 0

    mov rax, rbx                          ; Return slab address
    jmp .done

.fail:
    xor eax, eax

.done:
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ============================================================================
; SLAB_INIT - Initialize slab allocator
; ============================================================================
slab_init:
    push rcx
    push rdi

    ; Clear all cache heads
    lea rdi, [slab_caches]
    mov ecx, SLAB_CACHE_COUNT
    xor rax, rax
    rep stosq

    pop rdi
    pop rcx
    ret
