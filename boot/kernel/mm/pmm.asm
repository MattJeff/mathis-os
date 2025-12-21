; ============================================================================
; PMM.ASM - Physical Memory Manager (Page Allocator)
; ============================================================================
; Bitmap-based page frame allocator
; Each bit represents one 4KB page: 0=free, 1=used
; ============================================================================

[BITS 64]

; Uses constants from pmm_const.asm (included before this file)

section .data
pmm_free_pages:     dq 0                ; Count of free pages
pmm_total_pages:    dq 0                ; Total pages in system

section .text

; ============================================================================
; PMM_ALLOC_PAGE - Allocate single physical page
; ============================================================================
; Output: RAX = physical address (page-aligned), or 0 if OOM
; Preserves: R12-R15, RBX, RBP
; ============================================================================
pmm_alloc_page:
    push rcx
    push rdx
    push rdi

    mov rdi, PMM_BITMAP_ADDR
    mov rcx, PMM_BITMAP_SIZE / 8

.search:
    mov rax, [rdi]
    not rax                              ; Invert: 1=free now
    test rax, rax
    jnz .found

    add rdi, 8
    dec rcx
    jnz .search

    ; No free pages
    xor eax, eax
    jmp .done

.found:
    ; Find first set bit (first free page)
    bsf rdx, rax                         ; RDX = bit index

    ; Mark as used (set bit in original)
    bts qword [rdi], rdx

    ; Calculate physical address
    sub rdi, PMM_BITMAP_ADDR
    shl rdi, 3                           ; * 8 bits per byte
    add rdi, rdx                         ; Total bit index
    shl rdi, PAGE_SHIFT                  ; * PAGE_SIZE
    mov rax, rdi

    ; Update free count
    dec qword [pmm_free_pages]

.done:
    pop rdi
    pop rdx
    pop rcx
    ret

; ============================================================================
; PMM_FREE_PAGE - Free single physical page
; ============================================================================
; Input: RDI = physical address (must be page-aligned)
; Preserves: R12-R15, RBX, RBP
; ============================================================================
pmm_free_page:
    push rax
    push rdx

    ; Validate: must be page-aligned
    test rdi, PAGE_SIZE - 1
    jnz .done

    ; Convert address to bit index
    shr rdi, PAGE_SHIFT                  ; Page index
    mov rax, rdi
    mov rdx, rax
    shr rdx, 6                           ; QWord index
    and eax, 63                          ; Bit within qword

    ; Clear bit (mark free)
    lea rdx, [PMM_BITMAP_ADDR + rdx * 8]
    btr qword [rdx], rax

    ; Update free count
    inc qword [pmm_free_pages]

.done:
    pop rdx
    pop rax
    ret

; ============================================================================
; PMM_GET_FREE_PAGES - Get count of free pages
; ============================================================================
; Output: RAX = number of free pages
; ============================================================================
pmm_get_free_pages:
    mov rax, [pmm_free_pages]
    ret

; ============================================================================
; PMM_ALLOC_PAGES - Allocate contiguous pages
; ============================================================================
; Input:  EDI = number of pages
; Output: RAX = physical address, or 0 if failed
; ============================================================================
pmm_alloc_pages:
    ; For now, allocate one at a time (non-contiguous fallback)
    ; TODO: Implement true contiguous allocation
    push rbx
    push rcx

    mov ecx, edi
    test ecx, ecx
    jz .fail

    call pmm_alloc_page
    test rax, rax
    jz .fail
    mov rbx, rax                         ; Save first page

    ; Allocate remaining pages (non-contiguous)
    dec ecx
.loop:
    test ecx, ecx
    jz .done
    push rcx
    call pmm_alloc_page
    pop rcx
    dec ecx
    jmp .loop

.done:
    mov rax, rbx
    pop rcx
    pop rbx
    ret

.fail:
    xor eax, eax
    pop rcx
    pop rbx
    ret
