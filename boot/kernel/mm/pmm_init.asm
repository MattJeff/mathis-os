; ============================================================================
; PMM_INIT.ASM - Physical Memory Manager Initialization
; ============================================================================
; Single Responsibility: Initialize PMM from E820 memory map
; Depends: pmm_const.asm, pmm_bitmap.asm, e820.asm
; ============================================================================

[BITS 64]

global pmm_free_count

section .text

; ============================================================================
; PMM_INIT - Initialize physical memory manager
; ============================================================================
; Uses E820 map to detect usable memory, marks free pages in bitmap
; Preserves: R12-R15, RBX, RBP
; ============================================================================
pmm_init:
    push rbx
    push r12
    push r13

    ; Clear bitmap (mark all pages as used)
    mov rdi, PMM_BITMAP_ADDR
    mov rcx, PMM_BITMAP_SIZE / 8
    mov rax, 0xFFFFFFFFFFFFFFFF
    rep stosq

    ; Reset free page counter
    mov qword [pmm_free_count], 0

    ; Parse E820 map
    call e820_get_entry_count
    test eax, eax
    jz .reserve_kernel

    mov r12d, eax                        ; Entry count
    xor r13d, r13d                       ; Current index

.parse_loop:
    mov edi, r13d
    call e820_get_entry                  ; RAX=base, RDX=len, ECX=type

    cmp ecx, E820_TYPE_USABLE
    jne .next_entry

    ; Mark usable region as free
    mov rdi, rax                         ; Base address
    mov rsi, rdx                         ; Length
    call pmm_mark_region_free

.next_entry:
    inc r13d
    cmp r13d, r12d
    jl .parse_loop

.reserve_kernel:
    ; Reserve first 2MB for kernel + bitmap
    xor edi, edi                         ; Start at page 0
    mov esi, PMM_RESERVED_END
    shr esi, PAGE_SHIFT                  ; Number of pages
    call pmm_mark_region_used

    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; PMM_MARK_REGION_FREE - Mark memory region as free
; ============================================================================
; Input: RDI = base address, RSI = length in bytes
; ============================================================================
pmm_mark_region_free:
    push r12
    push r13

    ; Align base up to page boundary
    add rdi, PAGE_SIZE - 1
    and rdi, ~(PAGE_SIZE - 1)

    ; Convert to frame index
    mov r12, rdi
    shr r12, PAGE_SHIFT

    ; Calculate page count
    mov r13, rsi
    shr r13, PAGE_SHIFT

.loop:
    test r13, r13
    jz .done

    mov rdi, r12
    call pmm_bitmap_clear
    inc qword [pmm_free_count]

    inc r12
    dec r13
    jmp .loop

.done:
    pop r13
    pop r12
    ret

; ============================================================================
; PMM_MARK_REGION_USED - Mark memory region as used
; ============================================================================
; Input: EDI = start frame index, ESI = frame count
; ============================================================================
pmm_mark_region_used:
    push r12
    push r13

    mov r12d, edi                        ; Zero-extends to r12
    mov r13d, esi                        ; Zero-extends to r13

.loop:
    test r13d, r13d
    jz .done

    mov rdi, r12
    call pmm_bitmap_set

    ; Decrement free count if was free
    cmp qword [pmm_free_count], 0
    je .skip_dec
    dec qword [pmm_free_count]
.skip_dec:

    inc r12
    dec r13
    jmp .loop

.done:
    pop r13
    pop r12
    ret

; ============================================================================
; DATA
; ============================================================================
section .data
pmm_free_count:     dq 0
