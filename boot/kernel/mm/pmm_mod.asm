; ============================================================================
; PMM_MOD.ASM - Physical Memory Manager (Modular)
; ============================================================================
; Bitmap-based page allocator for physical memory
; Each bit represents one 4KB page (0=free, 1=used)
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
PAGE_SIZE               equ 0x1000
PAGE_SHIFT              equ 12
PMM_BITMAP_ADDR         equ 0x200000
PMM_BITMAP_SIZE         equ 0x200000
FREE_MEM_START          equ 0x1400000

; ============================================================================
; EXPORTS
; ============================================================================
global pmm_init
global pmm_alloc_page
global pmm_free_page
global pmm_get_free_count

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; pmm_init - Initialize physical memory manager
; ----------------------------------------------------------------------------
pmm_init:
    push rax
    push rcx
    push rdi

    ; Clear bitmap (mark all as used)
    mov rdi, PMM_BITMAP_ADDR
    mov rcx, PMM_BITMAP_SIZE / 8
    mov rax, 0xFFFFFFFFFFFFFFFF
    rep stosq

    ; Mark pages from 20MB to 32MB as free (simplified)
    mov rdi, FREE_MEM_START
    mov rcx, (0x2000000 - FREE_MEM_START) / PAGE_SIZE

.mark_free:
    push rcx
    call pmm_free_page
    pop rcx
    add rdi, PAGE_SIZE
    loop .mark_free

    pop rdi
    pop rcx
    pop rax
    ret

; ----------------------------------------------------------------------------
; pmm_alloc_page - Allocate a physical page
; Output: RAX = physical address, or 0 if none
; ----------------------------------------------------------------------------
pmm_alloc_page:
    push rbx
    push rcx
    push rdi

    mov rdi, PMM_BITMAP_ADDR
    mov rcx, PMM_BITMAP_SIZE / 8

.search:
    mov rax, [rdi]
    cmp rax, 0xFFFFFFFFFFFFFFFF
    jne .found
    add rdi, 8
    loop .search

    xor eax, eax
    jmp .done

.found:
    mov rbx, rdi
    sub rbx, PMM_BITMAP_ADDR
    shl rbx, 3

    xor ecx, ecx
.find_bit:
    bt rax, rcx
    jnc .got_bit
    inc ecx
    cmp ecx, 64
    jl .find_bit

.got_bit:
    bts qword [rdi], rcx
    add rbx, rcx
    shl rbx, PAGE_SHIFT
    mov rax, rbx
    dec qword [pmm_free_pages]

.done:
    pop rdi
    pop rcx
    pop rbx
    ret

; ----------------------------------------------------------------------------
; pmm_free_page - Free a physical page
; Input: RDI = physical address
; ----------------------------------------------------------------------------
pmm_free_page:
    push rax
    push rbx
    push rcx

    mov rax, rdi
    shr rax, PAGE_SHIFT

    mov rbx, rax
    shr rbx, 3
    and eax, 7

    mov rcx, PMM_BITMAP_ADDR
    add rcx, rbx
    btr qword [rcx], rax

    inc qword [pmm_free_pages]

    pop rcx
    pop rbx
    pop rax
    ret

; ----------------------------------------------------------------------------
; pmm_get_free_count - Get free page count
; Output: RAX = count
; ----------------------------------------------------------------------------
pmm_get_free_count:
    mov rax, [pmm_free_pages]
    ret

; ============================================================================
; DATA
; ============================================================================
section .data

pmm_free_pages:     dq 0

section .bss
