; ============================================================================
; SLAB.ASM - Slab Allocator
; ============================================================================
; Fast allocation for fixed-size objects: 32, 64, 128, 256, 512, 1024, 2048
; ============================================================================

[BITS 64]

; Uses constants from slab_const.asm (included before this file)

section .data

; Cache heads (one per size class)
slab_caches:        times SLAB_CACHE_COUNT dq 0

; Object sizes table
slab_sizes:         dd 32, 64, 128, 256, 512, 1024, 2048

section .text

; ============================================================================
; SLAB_ALLOC - Allocate object from slab cache
; ============================================================================
; Input:  EDI = requested size
; Output: RAX = pointer to object, or 0 if failed
; ============================================================================
slab_alloc:
    push rbx
    push rcx
    push rdx

    ; Find appropriate cache
    call slab_get_cache_index
    cmp eax, -1
    je .use_heap

    mov ecx, eax                         ; Cache index

    ; Get cache head
    lea rbx, [slab_caches]
    mov rax, [rbx + rcx * 8]
    test rax, rax
    jz .new_slab

    ; Get object from free list
    mov rdx, [rax + SLAB_HDR_FREE]
    test rdx, rdx
    jz .new_slab

    ; Pop from free list
    mov rbx, [rdx]                        ; Next free object
    mov [rax + SLAB_HDR_FREE], rbx
    inc dword [rax + SLAB_HDR_USED]
    mov rax, rdx
    jmp .done

.new_slab:
    ; Allocate new slab
    push rcx
    call slab_create
    pop rcx
    test rax, rax
    jz .fail

    ; Link to cache
    lea rbx, [slab_caches]
    mov rdx, [rbx + rcx * 8]
    mov [rax + SLAB_HDR_NEXT], rdx
    mov [rbx + rcx * 8], rax

    ; Get first object
    mov rdx, [rax + SLAB_HDR_FREE]
    mov rbx, [rdx]
    mov [rax + SLAB_HDR_FREE], rbx
    inc dword [rax + SLAB_HDR_USED]
    mov rax, rdx
    jmp .done

.use_heap:
    ; Size too large for slab, use heap
    call kmalloc
    jmp .done

.fail:
    xor eax, eax

.done:
    pop rdx
    pop rcx
    pop rbx
    ret

; ============================================================================
; SLAB_FREE - Return object to slab cache
; ============================================================================
; Input: RDI = pointer to object
; ============================================================================
slab_free:
    push rax
    push rbx

    ; Get slab header (page-aligned address)
    mov rax, rdi
    and rax, ~(PAGE_SIZE - 1)

    ; Validate this is a slab (check magic could be added)
    cmp dword [rax + SLAB_HDR_USED], 0
    jle .done                             ; Already empty or invalid

    ; Add to free list
    mov rbx, [rax + SLAB_HDR_FREE]
    mov [rdi], rbx
    mov [rax + SLAB_HDR_FREE], rdi
    dec dword [rax + SLAB_HDR_USED]

.done:
    pop rbx
    pop rax
    ret

; ============================================================================
; SLAB_GET_CACHE_INDEX - Get cache index for size
; ============================================================================
; Input:  EDI = requested size
; Output: EAX = cache index (0-6), or -1 if too large
; ============================================================================
slab_get_cache_index:
    cmp edi, 32
    jbe .c0
    cmp edi, 64
    jbe .c1
    cmp edi, 128
    jbe .c2
    cmp edi, 256
    jbe .c3
    cmp edi, 512
    jbe .c4
    cmp edi, 1024
    jbe .c5
    cmp edi, 2048
    jbe .c6
    mov eax, -1
    ret
.c0:
    xor eax, eax
    ret
.c1:
    mov eax, 1
    ret
.c2:
    mov eax, 2
    ret
.c3:
    mov eax, 3
    ret
.c4:
    mov eax, 4
    ret
.c5:
    mov eax, 5
    ret
.c6:
    mov eax, 6
    ret
